#!/bin/bash
# sanitize-prefix.sh <deps-prefix> — enforce the static-first policy.
#
# WHY: several recipes historically installed shared artifacts (import libs
# *.dll.a + runtime DLLs). The recipes were later converted to static, but a
# prefix is never wiped between builds, so stale *.dll.a import libs survive
# forever. On the linker command line a -lfoo picks libfoo.dll.a BEFORE
# libfoo.a (mingw link order), so every consumer (FFmpeg, mpv) silently links
# the OLD shared library and the install dir ends up importing e.g.
# libzmq.dll / libxevd.dll that nothing needs — plus the runtime DLLs get
# wholesale-copied into the bundle by copydlls.sh.
#
# This pass removes, per prefix, every import lib + DLL whose recipe is now
# static-first (or that never belongs in a static prefix). It is idempotent,
# safe to run any number of times, and after it the only remaining DLLs are
# the ones with a genuine shared-runtime reason:
#   - vapoursynth family (python-embedding frameserver, upstream model)
#   - vulkan-1.dll (Vulkan loader; static loader unsupported on Windows)
# Everything else links statically.
#
# Rules are expressed as: <pc-or-lib name> -> purge-import-libs + DLLs
set -uo pipefail
PREFIX="${1:?usage: sanitize-prefix.sh <deps-prefix>}"
[[ -d "$PREFIX/lib" ]] || exit 0
removed=0

purge() { # purge <name-token> — remove lib<token>*.dll.a, <token>*.dll.a, <token>*.dll, lib<token>*.dll
	local tok="$1" f
	for f in "$PREFIX"/lib/"$tok"*.dll.a "$PREFIX"/lib/"lib$tok"*.dll.a \
	         "$PREFIX"/bin/"$tok"*.dll "$PREFIX"/bin/"lib$tok"*.dll; do
		[[ -e "$f" ]] || continue
		echo "sanitize: rm $(basename "$f")"
		rm -f "$f"
		removed=$((removed+1))
	done
}

# --- libraries whose recipes are static-first; shared artifacts are stale ---
for tok in xevd xeve zmq subrandr shaderc_shared shaderc-shared SPIRV-Tools-shared; do
	purge "$tok"
done

# shaderc: keep only the static archives (libshaderc.a, libshaderc_combined.a)
rm -f "$PREFIX"/bin/libshaderc_shared.dll "$PREFIX"/bin/libshaderc.dll
rm -f "$PREFIX"/lib/libshaderc_shared.dll.a

# spirv-cross: static c-abi (spirv-cross-c.pc); the c-shared DLL is stale
rm -f "$PREFIX"/bin/libspirv-cross-c-shared.dll "$PREFIX"/lib/libspirv-cross-c-shared.dll.a

# libdovi/rav1e: cargo-c staticlib; the shared DLLs are stale
rm -f "$PREFIX"/bin/dovi.dll "$PREFIX"/bin/rav1e.dll "$PREFIX"/lib/dovi.dll.a
rm -f "$PREFIX"/lib/rav1e.dll.a "$PREFIX"/lib/librav1e.dll.a

# SDL2: STATIC by policy (mpv/ffmpeg link the static archive); runtime DLL is stale
rm -f "$PREFIX"/bin/SDL2.dll "$PREFIX"/lib/libSDL2.dll.a "$PREFIX"/lib/libSDL2main.dll.a

# libplacebo: static by policy (embedded into mpv/ffmpeg); DLL is stale
rm -f "$PREFIX"/bin/libplacebo-*.dll "$PREFIX"/lib/libplacebo.dll.a

# openapv (liboapv): recipe is -DOAPV_BUILD_SHARED=OFF; DLL is stale
rm -f "$PREFIX"/bin/liboapv.dll

# spirv-cross: static c-abi wrapper references C++ symbols in the
# sub-archives; the pc must carry the full closure in link order
# (dependents first, core last) — mpv gpu-next / libplacebo d3d11 need it.
# NOTE: match the bare token (no trailing space) — cmake-generated pcs end
# the Libs line with it.
for pc in spirv-cross-c spirv-cross-c-shared; do
	f="$PREFIX/lib/pkgconfig/$pc.pc"
	[[ -f "$f" ]] || continue
	if grep -q -- "-lspirv-cross-c\b" "$f" && ! grep -q -- "-lspirv-cross-core" "$f"; then
		sed -i "s|-lspirv-cross-c\b|-lspirv-cross-c -lspirv-cross-cpp -lspirv-cross-hlsl -lspirv-cross-glsl -lspirv-cross-reflect -lspirv-cross-util -lspirv-cross-core|" "$f"
		echo "sanitize: $pc.pc -> full static closure"
	fi
done

# C++ static archives must carry the C++ runtime in Libs.private so
# C-mode pkg-config probes (ffmpeg configure test_cc) can link them:
# libplacebo/shaderc/spirv-cross are C++ but ffmpeg checks them with the
# C linker — without -lc++ -lunwind the probe fails with
# "undefined symbol: __gxx_personality_seh0" under -static linkage.
for pc in libplacebo shaderc shaderc_combined shaderc-static; do
	f="$PREFIX/lib/pkgconfig/$pc.pc"
	[[ -f "$f" ]] || continue
	if grep -q -- " -lc++" "$f"; then continue; fi
	if grep -q "^Libs.private:" "$f"; then
		sed -i "s|^Libs.private:|Libs.private: -lc++ -lunwind|" "$f"
	else
		echo "Libs.private: -lc++ -lunwind" >> "$f"
	fi
echo "sanitize: $pc.pc -> Libs.private +(-lc++ -lunwind)"
done

# libzmq: static archive + ZMQ_STATIC define (upstream zmq.h defaults to
# __declspec(dllimport) on Windows without it — lld then rejects the static
# archive's plain symbols). Also widen Libs.private with the C++/pthread
# closure so consumers' --static pkg-config probes link.
if [[ -f "$PREFIX/lib/pkgconfig/libzmq.pc" && -f "$PREFIX/lib/libzmq.a" ]]; then
	grep -q -- "-DZMQ_STATIC" "$PREFIX/lib/pkgconfig/libzmq.pc" || \
		sed -i "s|^Cflags:.*|& -DZMQ_STATIC|" "$PREFIX/lib/pkgconfig/libzmq.pc"
	grep -q -- "-lwinpthread" "$PREFIX/lib/pkgconfig/libzmq.pc" || \
		sed -i "s|^Libs.private:.*|& -lrpcrt4 -lwinpthread|" "$PREFIX/lib/pkgconfig/libzmq.pc"
fi

# --- scrub -lstdc++ residue from every pc: the token resolves against the
# MSYS cygwin toolchain (/usr/lib/gcc/x86_64-pc-cygwin), NOT our libc++
# mingw one — at best dead weight, at worst cygwin runtime pollution -----
for f in "$PREFIX"/lib/pkgconfig/*.pc; do
	[[ -f "$f" ]] || continue
	if grep -q -- " -lstdc++" "$f"; then
		sed -i "s/ -lstdc++//g" "$f"
		echo "sanitize: scrubbed -lstdc++ from $(basename "$f")"
	fi
	# luajit.pc carries GNU-ld-only "-Wl,-E" (export-all on ELF); lld PE
	# errors out with "unknown argument: -E" — scrub it too
	if grep -q -- "-Wl,-E" "$f"; then
		sed -i "s/ -Wl,-E//g" "$f"
		echo "sanitize: scrubbed -Wl,-E from $(basename "$f")"
	fi
done

# vulkan.pc: cmake emits "Libs: -L${libdir} -lvulkan-1.dll". Under a -static
# link lld refuses .dll.a suffix search for -l tokens (verified: "unable to
# find library -lvulkan-1"), so consumers (ffmpeg/mpv) would fail to link.
# A FULL-PATH import library always works under -static (verified) and the
# loader DLL ships in the bundle, so keep dynamic loading + static search.
if [[ -f "$PREFIX/lib/pkgconfig/vulkan.pc" ]]; then
	if grep -q -- '-lvulkan-1' "$PREFIX/lib/pkgconfig/vulkan.pc"; then
		sed -i "s|-L\${libdir} -lvulkan-1\.dll|\${libdir}/libvulkan-1.dll.a|; s|-lvulkan-1\.dll|\${libdir}/libvulkan-1.dll.a|" \
			"$PREFIX/lib/pkgconfig/vulkan.pc"
		echo "sanitize: vulkan.pc -> full-path import lib"
	fi
fi

# --- promote subdir static archives that upstream cmake installs into
# lib/<name>/ while the pc files point at lib/ (xevd/xeve): without this
# -lxevd resolves to the stale import lib instead of lib/xevd/libxevd.a ---
for sub in xevd xeve oapv; do
	if [[ -f "$PREFIX/lib/$sub/lib$sub.a" && ! -f "$PREFIX/lib/lib$sub.a" ]]; then
		cp -f "$PREFIX/lib/$sub/lib$sub.a" "$PREFIX/lib/lib$sub.a"
		echo "sanitize: promoted lib$sub.a to lib root"
	fi
done

# --- pc-file surgery: consumers must link the static forms ------------------
pcsed() { # pcsed <file> <sed-expr...>
	local f="$1"; shift
	[[ -f "$f" ]] || return 0
	sed -i "$@" "$f"
}
# shaderc.pc / shaderc-static: point at the combined static archive
pcsed "$PREFIX/lib/pkgconfig/shaderc.pc" 's/-lshaderc_shared/-lshaderc_combined/'
pcsed "$PREFIX/lib/pkgconfig/shaderc-static.pc" 's/-lshaderc_shared/-lshaderc_combined/'
pcsed "$PREFIX/lib/pkgconfig/shaderc-shared.pc" 's/-lshaderc_shared/-lshaderc_combined/'
# spirv-cross: mpv/libplacebo dep name is spirv-cross-c-shared, but the
# library actually present is the static spirv-cross-c; make the pc resolve
pcsed "$PREFIX/lib/pkgconfig/spirv-cross-c-shared.pc" 's/-lspirv-cross-c-shared/-lspirv-cross-c/'
# libzmq: strip the shared import-lib line if it survived
pcsed "$PREFIX/lib/pkgconfig/libzmq.pc" 's/-lzmq\.dll//g'

# vulkan.pc: cmake writes Libs: -lvulkan-1.dll (import lib); with the DLL
# shipped this still resolves; leave alone unless it breaks -static links.

echo "sanitize: $removed stale shared artifact(s) removed from $PREFIX"
exit 0
