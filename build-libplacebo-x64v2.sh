#!/bin/bash
# ==============================================================================
# Build libplacebo for x64v2 (nehalem) — STATIC install into deps-x64v2.
# Required for Dolby Vision P7 FEL (PL_API_VER >= 370). The static archive is
# embedded directly into mpv.exe / libmpv-2.dll / ffmpeg.exe, so no
# libplacebo DLL ships in the bundles.
# GLSL->SPIR-V via self-built shaderc static combined archive; libdovi
# static (embedded; RPU parsing for the FEL EL); spirv-cross static c-abi.
# ==============================================================================
set -euo pipefail
SRC=/g/media-build/mpv-build/libplacebo-src
DEPS=/g/media-build/deps-build/deps-x64v2
LOG=/g/media-build/mpv-build/configure-libplacebo-x64v2.log
# nehalem: SSE4.2 only (no AVX) — vector width 128; 256 is ISA-impossible
# (legalized-pair IR crashes LLVM 22 ThinLTO Register Coalescer)
OPT="-O3 -march=nehalem -mtune=nehalem -mprefer-vector-width=128 -fvectorize -fslp-vectorize -funroll-loops -fomit-frame-pointer -fstrict-aliasing -fno-trapping-math"

# Upstream to latest on every run. The old `git pull --ff-only || true` was
# silent about the two ways it fails here — a cache-restored detached HEAD and
# any non-fast-forward upstream move — so libplacebo could be compiled from a
# commit weeks old with nothing in the log but a swallowed exit status. -s: the
# glad/fast_float/jinja/Vulkan-Headers submodules are required by meson setup.
bash /g/media-build/deps-build/sync-repo.sh -s "$SRC" \
  https://code.videolan.org/videolan/libplacebo.git
cd "$SRC"
export PATH="/clang64/bin:$PATH"
export CMAKE_PREFIX_PATH="$DEPS"
export PKG_CONFIG_PATH="$DEPS/lib/pkgconfig:/clang64/lib/pkgconfig:${PKG_CONFIG_PATH:-}"
# static-first: meson probes with --static when prefer_static=true, so
# Requires.private closures are honored and .a archives win
export LDFLAGS="-L$DEPS/lib ${LDFLAGS:-}"
rm -rf _build

/clang64/bin/meson setup _build \
  --prefix="$DEPS" \
  --default-library=static \
  -Dvulkan=enabled -Dd3d11=enabled -Dopengl=enabled -Dlcms=enabled \
  -Ddovi=enabled -Dlibdovi=auto -Dshaderc=enabled -Dglslang=disabled \
  -Ddemos=false -Dtests=false -Dbench=false -Dfuzz=false -Dunwind=disabled -Dcmake_prefix_path="$DEPS" -Dvulkan-sdk="$DEPS" -Dprefer_static=true \
  -Dc_args="$OPT" -Dcpp_args="$OPT -I$DEPS/include" \
  -Dc_link_args="-Wl,--gc-sections -L$DEPS/lib" -Dcpp_link_args="-Wl,--gc-sections -L$DEPS/lib -lc++ -lunwind" \
  -Db_lto=true -Db_lto_mode=thin --buildtype=release 2>&1 | tee "$LOG"

/clang64/bin/meson compile -C _build
/clang64/bin/meson install -C _build
# libplacebo.pc is one of mpv's hard-required .pc files, and the one half of
# that contract build-deps.sh cannot check: it runs BEFORE this script, so on a
# fresh prefix the file does not exist yet. Assert it here, where it exists.
[ -f "$DEPS/lib/pkgconfig/libplacebo.pc" ] \
  || { echo "ERROR: libplacebo.pc missing from $DEPS after meson install"; exit 1; }
# static-first policy: libplacebo is embedded into consumers, never a DLL
/g/media-build/deps-build/sanitize-prefix.sh "$DEPS"
PL_API_VER=$(grep -oP '#define PL_API_VER \K\d+' "$DEPS/include/libplacebo/config.h" 2>/dev/null || echo "0")
grep -q "PL_HAVE_LIBDOVI 1" "$DEPS/include/libplacebo/config.h" \
  || { echo "ERROR: libplacebo built WITHOUT libdovi — DoVi P7 FEL RPU parsing unavailable"; exit 1; }
echo "libplacebo x64v2: PL_API_VER=$PL_API_VER -> $DEPS"
[ "$PL_API_VER" -ge 370 ] && echo "OK: FEL API available" || { echo "ERROR: PL_API_VER < 370"; exit 1; }
