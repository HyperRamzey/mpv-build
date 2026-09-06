#!/bin/bash
# copydlls.sh <prefix> [deps-prefix]
# Copies the RUNTIME DLL closure for a target install dir — LEAN by design.
#
# Old behaviour (wholesale-copy of deps-<t>/bin) shipped dead DLLs that
# nothing imported (shaderc/SPIRV/oapv/dovi/rav1e/subrandr/...): a static-
# first prefix has almost no shared runtime left.
#
# New behaviour — exact import closure:
#   1. Seed from deps-<t>/bin ONLY the DLLs that are actually imported
#      (objdump import table) by any exe/dll in <prefix>/bin.
#   2. Resolve the remaining imports against /clang64/bin (toolchain
#      runtime) — convergent passes over the growing set.
#   3. VapourSynth runtime: the frameserver is dlopen'd by name
#      (VSScript.dll by mpv/ffmpeg). Ship the VS family + its VSScript.dll
#      alias so vapoursynth works out of the box.
#   4. vulkan-1.dll: no static Vulkan loader on Windows (Khronos supports
#      APPLE_STATIC_LOADER only on macOS), so the loader DLL always ships.
#   5. Portable config snapshot (mpv.conf/fonts.conf/ir.wav) + register bats.
#
# NEVER copies /clang64/bin wholesale. Hard-fails on ggml/whisper pollution
# (defense in depth; they must never appear even via transitives).
set -eo pipefail
PREFIX="${1:?usage: copydlls.sh <install-prefix> [deps-prefix]}"
DEPS_PREFIX="${2:-}"

case "$PREFIX" in
*zn2*) DEPS_PREFIX="${DEPS_PREFIX:-/g/deps-build/deps-zn2}" ;;
*11700*) DEPS_PREFIX="${DEPS_PREFIX:-/g/deps-build/deps-11700}" ;;
*3050*) DEPS_PREFIX="${DEPS_PREFIX:-/g/deps-build/deps-3050}" ;;
*14600*) DEPS_PREFIX="${DEPS_PREFIX:-/g/deps-build/deps-14600}" ;;
*) DEPS_PREFIX="${DEPS_PREFIX:-/g/deps-build/deps-zn3}" ;;
esac

echo "=== copydlls: prefix=$PREFIX deps=$DEPS_PREFIX ==="
mkdir -p "$PREFIX/bin"
# purge stale AI-lib junk from any earlier polluted install
rm -f "$PREFIX"/bin/*ggml* "$PREFIX"/bin/*whisper* "$PREFIX"/bin/*parakeet* 2>/dev/null || true

# --- helper: collect imported DLL names of everything currently in bin -----
imports_of_bin() {
	local f
	for f in "$PREFIX"/bin/*.exe "$PREFIX"/bin/*.com "$PREFIX"/bin/*.dll; do
		[[ -e "$f" ]] || continue
		objdump -p "$f" 2>/dev/null | awk '/DLL Name:/ {print $3}'
	done | sort -u
}
copy_from() { # copy_from <src-dir> — copy imported DLLs present in <src-dir>
	local src="$1" dep dst new=0
	[[ -d "$src" ]] || return 0
	while read -r dep; do
		[[ -f "$src/$dep" && ! -f "$PREFIX/bin/$dep" ]] || continue
		cp "$src/$dep" "$PREFIX/bin/"
		new=$((new + 1))
	done < <(imports_of_bin)
	echo "$new"
}

# 1) Seed: DLLs self-built in the deps prefix that something in bin imports
seed=$(copy_from "$DEPS_PREFIX/bin")
echo "copydlls: seeded $seed DLLs from deps bin"

# 2) VapourSynth frameserver runtime (dlopen'd python-embedding model):
#    mpv/ffmpeg LoadLibrary("VSScript.dll") — the dll.a name is libvsscript.
#    Ship the family + alias so the runtime probe finds it either way.
vs_dlls=(libvapoursynth.dll libvapoursynthfilters.dll libvapoursynthfilters_avx2.dll
	libvapoursynthfilters_zn4.dll libvsscript.dll VSScript.dll)
for d in "${vs_dlls[@]}"; do
	if [[ -f "$DEPS_PREFIX/bin/$d" && ! -f "$PREFIX/bin/$d" ]]; then
		cp "$DEPS_PREFIX/bin/$d" "$PREFIX/bin/"
	fi
done
# VSScript.dll alias of libvsscript.dll (the actual export library name)
if [[ -f "$PREFIX/bin/libvsscript.dll" && ! -e "$PREFIX/bin/VSScript.dll" ]]; then
	cp -u "$PREFIX/bin/libvsscript.dll" "$PREFIX/bin/VSScript.dll"
fi

# 3) vulkan-1.dll: no static loader on Windows — always ship the loader
if compgen -G "$DEPS_PREFIX/bin/vulkan-1.dll" >/dev/null; then
	cp -u "$DEPS_PREFIX/bin/vulkan-1.dll" "$PREFIX/bin/"
fi

# 4) Toolchain-runtime closure from /clang64/bin ONLY, convergent passes
#    (newly copied DLLs can add imports). Static-linked binaries import
#    almost nothing here — libc++/winpthread/bz2/unibreak are embedded.
pass=0
while :; do
	pass=$((pass + 1))
	new=$(copy_from "/clang64/bin")
	echo "copydlls: pass $pass -> $new new DLLs from /clang64"
	[[ "$new" -eq 0 ]] && break
	[[ $pass -ge 8 ]] && {
		echo "WARN: closure did not converge after 8 passes"
		break
	}
done

# 5) Portable config (mpv.conf/fonts.conf/ir.wav/user shaders) from the
# project-local snapshot. Two copies on purpose:
#   bin/          — flat files for the classic portable layout
#   bin/mpv/      — mpv's win32 "global" config dir (exe_dir/mpv; the
#                  fallback when no portable_config dir exists). The mpv.conf
#                  lavfi-complex/~~/ paths resolve against this dir.
CONF_SRC="/g/mpv-build/portable-conf"
if [[ -d "$CONF_SRC" ]]; then
	cp -u "$CONF_SRC"/* "$PREFIX/bin/" 2>/dev/null || true
	mkdir -p "$PREFIX/bin/mpv"
	cp -u "$CONF_SRC"/* "$PREFIX/bin/mpv/" 2>/dev/null || true
fi

# 6) Sanity: forbidden AI-lib files must never appear (defense in depth)
if compgen -G "$PREFIX/bin/*ggml*" >/dev/null || compgen -G "$PREFIX/bin/*whisper*" >/dev/null; then
	echo "FATAL: ggml/whisper artifacts detected in $PREFIX/bin" >&2
	exit 1
fi

echo "copydlls: done — bin contents:"
ls "$PREFIX/bin"
