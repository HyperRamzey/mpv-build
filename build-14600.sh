#!/bin/bash
# ==============================================================================
# mpv full build for target 14600 (raptorlake CPU / RTX 50-series Blackwell GPU)
# STATIC-first linkage: mpv.exe / libmpv-2.dll embed libplacebo+libdovi (DoVi
# P7 FEL), shaderc (combined static archive), spirv-cross, SDL2, libzmq,
# xevd/xeve, unibreak, bz2, libc++/libunwind (fully static C++ runtime).
# The only shipped runtime DLLs: vulkan-1.dll (no static loader on Windows)
# + the VapourSynth frameserver DLLs (dlopen'd python-embedding runtime).
# Outputs to install-14600.
# ==============================================================================
set -euo pipefail

# --- CPU target config ---
CPU=raptorlake
TUNE=raptorlake
BUILD_DIR=/g/media-build/mpv-build/build-14600
PREFIX=/g/media-build/mpv-build/install-14600
LOG=/g/media-build/mpv-build/configure-14600.log

# --- Dependency paths (ALL external libs self-compiled per-target in G:\media-build\deps-build) ---
SRC=/g/media-build/mpv-build/mpv
FFMPEG_PREFIX=/g/media-build/ffmpeg-build/install-14600     # custom FFmpeg w/ dovi_split BSF (14600)
DEPS=/g/media-build/deps-build/deps-14600                   # self-built deps + static libplacebo (14600)

# --- Optimization flags (no fast-math; IEEE semantics required for codec bit-exactness) ---
OPT="-O3 -march=$CPU -mtune=$TUNE -mprefer-vector-width=256 -fvectorize -fslp-vectorize -funroll-loops -fomit-frame-pointer -fstrict-aliasing -fno-trapping-math"

echo "=== mpv build for target 14600 (raptorlake) ($CPU) ==="

# --- Ensure libplacebo is built (needed for DoVi FEL) ---
if [ ! -f "$DEPS/include/libplacebo/config.h" ]; then
  echo "libplacebo 14600 not found — building from source..."
  /g/media-build/mpv-build/build-libplacebo-14600.sh
fi

cd "$SRC"

# --- Ensure MinGW meson/ninja/python are on PATH (not MSYS versions) ---
export PATH="/clang64/bin:$PATH"

# --- PKG_CONFIG_PATH: self-built deps + ffmpeg take precedence over MSYS2 ---
export PKG_CONFIG_PATH="$DEPS/lib/pkgconfig:$FFMPEG_PREFIX/lib/pkgconfig:/clang64/lib/pkgconfig:${PKG_CONFIG_PATH:-}"

echo "Configuring mpv (meson setup)..."
rm -rf "$BUILD_DIR"
rm -rf "$PREFIX"    # clean output prefix: never ship stale DLLs
CC=clang CXX=clang++ /clang64/bin/meson setup "$BUILD_DIR" \
  --prefix="$PREFIX" \
  --default-library=shared \
  -Dprefer_static=true \
  -Dlibmpv=true \
  -Dcplayer=true \
  -Dwasapi=enabled \
  -Dd3d11=enabled \
  -Dd3d-hwaccel=enabled \
  -Dd3d9-hwaccel=disabled \
  -Dvulkan=enabled \
  -Dcuda-hwaccel=disabled \
  -Dvaapi=disabled \
  -Dvaapi-win32=disabled \
  -Dvaapi-drm=disabled \
  -Dvaapi-wayland=disabled \
  -Dvaapi-x11=disabled \
  -Dgl=disabled \
  -Dgl-cocoa=disabled \
  -Dgl-dxinterop=disabled \
  -Dgl-win32=disabled \
  -Dgl-x11=disabled \
  -Degl=disabled \
  -Degl-drm=disabled \
  -Degl-wayland=disabled \
  -Degl-x11=disabled \
  -Degl-angle-lib=auto \
  -Degl-angle-win32=auto \
  -Dx11=disabled \
  -Dwayland=disabled \
  -Ddrm=disabled \
  -Dgbm=disabled \
  -Dvdpau=disabled \
  -Dvdpau-gl-x11=disabled \
  -Dxv=disabled \
  -Dsixel=enabled \
  -Dlua=luajit \
  -Djavascript=enabled \
  -Dlcms2=enabled \
  -Djpeg=enabled \
  -Dlibarchive=enabled \
  -Dsubrandr=disabled \
  -Dlibcurl=disabled \
  -Duchardet=enabled \
  -Dvapoursynth=enabled \
  -Dshaderc=enabled \
  -Dspirv-cross=auto \
  -Dzimg=enabled \
  -Drubberband=enabled \
  -Dcdda=disabled \
  -Ddvdnav=enabled \
  -Dsdl2-audio=enabled \
  -Dsdl2-gamepad=enabled \
  -Dwin32-smtc=enabled \
  -Dwin32-subsystem=windows \
  -Damf=disabled \
  -Dpulse=disabled \
  -Djack=disabled \
  -Dopenal=disabled \
  -Doss-audio=disabled \
  -Dsndio=disabled \
  -Dalsa=disabled \
  -Dios-gl=disabled \
  -Dvideotoolbox-gl=disabled \
  -Dvideotoolbox-pl=disabled \
  -Dcocoa=disabled \
  -Dpdf-build=disabled \
  -Dhtml-build=disabled \
  -Dmanpage-build=disabled \
  -Dbuild-date=true \
  -Dc_args="$OPT" \
  -Dcpp_args="$OPT" \
  -Dc_link_args="-O3 -flto=thin -static -Wl,--gc-sections" \
  -Dcpp_link_args="-O3 -flto=thin -static -Wl,--gc-sections" \
  -Db_lto=true \
  -Db_lto_mode=thin \
  --buildtype=release \
  2>&1 | tee "$LOG"

echo "=== CONFIGURE DONE — reviewing key features ==="
grep -iE 'd3d11|wasapi|vulkan|libmpv|dovi|libplacebo|ffmpeg|cuda|d3d-hwaccel' "$BUILD_DIR/meson-logs/meson-log.txt" | head -20

echo "=== Compiling (ninja -j14) ==="
/clang64/bin/ninja -C "$BUILD_DIR" -j14 2>&1 | tee /g/media-build/mpv-build/make-14600.log | tail -10
echo "=== COMPILE EXIT: $? ==="

echo "=== Installing ==="
/clang64/bin/meson install -C "$BUILD_DIR" --quiet 2>&1 | tail -5
echo "=== INSTALL DONE ==="

echo "=== Copying runtime DLLs (lean closure) ==="
/g/media-build/mpv-build/copydlls.sh "$PREFIX" "$DEPS"

echo "=== Smoke test ==="
/g/media-build/mpv-build/smoke_test.sh "$PREFIX/bin" || echo "WARN: smoke test failed (non-fatal)"

echo "=== 14600 build complete: $PREFIX ==="
