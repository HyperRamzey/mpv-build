#!/bin/bash
# copydlls.sh <prefix> [deps-prefix]
# Copies runtime DLL closure for a target install dir:
#   1. DLLs self-built in the per-target deps prefix (deps-znX/bin) — copied wholesale (trusted, small)
#   2. ldd import closure of everything in <prefix>/bin resolved against /clang64/bin ONLY
#      (system runtime: CRT, toolchain, gettext, python-for-vapoursynth, SDL2 for ffplay...)
# NEVER copies /clang64/bin wholesale. This was the old bug that shipped ggml/whisper/LLVM.
set -eo pipefail
PREFIX="${1:?usage: copydlls.sh <install-prefix> [deps-prefix]}"
DEPS_PREFIX="${2:-}"

case "$PREFIX" in
	*zn2*)          DEPS_PREFIX="${DEPS_PREFIX:-/g/deps-build/deps-zn2}" ;;
	*11700*)        DEPS_PREFIX="${DEPS_PREFIX:-/g/deps-build/deps-11700}" ;;
	*)              DEPS_PREFIX="${DEPS_PREFIX:-/g/deps-build/deps-zn3}" ;;
esac

echo "=== copydlls: prefix=$PREFIX deps=$DEPS_PREFIX ==="
mkdir -p "$PREFIX/bin"
# purge stale AI-lib junk from any earlier polluted install
rm -f "$PREFIX"/bin/*ggml* "$PREFIX"/bin/*whisper* "$PREFIX"/bin/*parakeet* 2>/dev/null || true

# 1) Self-built deps runtime DLLs (static-first policy => only a handful: vapoursynth etc.)
if [[ -d "$DEPS_PREFIX/bin" ]]; then
	for dll in "$DEPS_PREFIX"/bin/*.dll; do
		[[ -e "$dll" ]] || continue
		cp -u "$dll" "$PREFIX/bin/"
	done
fi

# 2) Import closure against /clang64/bin only (convergent: newly copied DLLs add imports)
pass=0
copied_total=0
while : ; do
	pass=$((pass+1))
	new=0
	while read -r dep; do
		src="/clang64/bin/$dep"
		dst="$PREFIX/bin/$dep"
		if [[ -f "$src" && ! -f "$dst" ]]; then
			cp "$src" "$dst"
			new=$((new+1))
			copied_total=$((copied_total+1))
		fi
	done < <(timeout 60 ldd "$PREFIX"/bin/*.exe "$PREFIX"/bin/*.com "$PREFIX"/bin/*.dll 2>/dev/null \
		| awk '$3 ~ /\/clang64\/bin\// { print $3 }' | xargs -r -n1 basename | sort -u)
	echo "copydlls: pass $pass -> $new new DLLs"
	[[ $new -eq 0 ]] && break
	[[ $pass -ge 6 ]] && { echo "WARN: closure did not converge after 6 passes"; break; }
done

# 3) Portable config (mpv.conf/fonts.conf/ir.wav) from project-local snapshot
CONF_SRC="/g/mpv-build/portable-conf"
if [[ -d "$CONF_SRC" ]]; then
	cp -u "$CONF_SRC"/* "$PREFIX/bin/" 2>/dev/null || true
fi

# 4) Sanity: forbidden AI-lib files must never appear (defense in depth)
if compgen -G "$PREFIX/bin/*ggml*" >/dev/null || compgen -G "$PREFIX/bin/*whisper*" >/dev/null; then
	echo "FATAL: ggml/whisper artifacts detected in $PREFIX/bin" >&2
	exit 1
fi

echo "copydlls: total copied from /clang64: $copied_total; bin contents:"
ls "$PREFIX/bin" | wc -l