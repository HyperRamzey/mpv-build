#!/bin/bash
# ==============================================================================
# Build libplacebo for Zen3 (znver3) — self-hosted deps, installs to deps-zn3
# Required for Dolby Vision Profile 7 FEL (PL_API_VER >= 370).
# GLSL->SPIR-V via self-built shaderc (shared; bundles spirv-opt); libdovi best-effort (auto).
# ==============================================================================
set -euo pipefail
SRC=/g/mpv-build/libplacebo-src
DEPS=/g/deps-build/deps-zn3
LOG=/g/mpv-build/configure-libplacebo-zn3.log
OPT="-O3 -march=znver3 -mtune=znver3 -mprefer-vector-width=256 -fvectorize -fslp-vectorize -funroll-loops -fomit-frame-pointer -fstrict-aliasing -fno-trapping-math"

if [ ! -d "$SRC/.git" ]; then
  git clone https://code.videolan.org/videolan/libplacebo.git "$SRC"
fi
cd "$SRC"; git pull --ff-only 2>/dev/null || true
export PATH="/clang64/bin:$PATH"
export CMAKE_PREFIX_PATH="$DEPS"
export PKG_CONFIG_PATH="$DEPS/lib/pkgconfig:/clang64/lib/pkgconfig:${PKG_CONFIG_PATH:-}"
export LDFLAGS="-L$DEPS/lib ${LDFLAGS:-}"
rm -rf _build

/clang64/bin/meson setup _build \
  --prefix="$DEPS" \
  -Dvulkan=enabled -Dd3d11=enabled -Dopengl=enabled -Dlcms=enabled \
  -Ddovi=enabled -Dlibdovi=auto -Dshaderc=enabled -Dglslang=disabled \
  -Ddemos=false -Dtests=false -Dbench=false -Dfuzz=false -Dunwind=disabled -Dcmake_prefix_path="$DEPS" -Dvulkan-sdk="$DEPS" -Dprefer_static=true \
  -Dc_args="$OPT" -Dcpp_args="$OPT -I$DEPS/include" \
  -Dc_link_args="-Wl,--gc-sections -L$DEPS/lib" -Dcpp_link_args="-Wl,--gc-sections -L$DEPS/lib -lc++ -lunwind" \
  -Db_lto=true -Db_lto_mode=thin --buildtype=release 2>&1 | tee "$LOG"

/clang64/bin/meson compile -C _build
/clang64/bin/meson install -C _build
PL_API_VER=$(grep -oP '#define PL_API_VER \K\d+' "$DEPS/include/libplacebo/config.h" 2>/dev/null || echo "0")
echo "libplacebo zn3: PL_API_VER=$PL_API_VER -> $DEPS"
[ "$PL_API_VER" -ge 370 ] && echo "OK: FEL API available" || { echo "ERROR: PL_API_VER < 370"; exit 1; }