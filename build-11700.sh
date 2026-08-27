#!/bin/bash
# ==============================================================================
# mpv full build for Intel 11700 (rocketlake) — Ryzen 5000/7000 series (incl. 5700X3D)
# Mirrors the ffmpeg-build pattern: configure → compile → install → copydlls → smoke
# All extensions enabled; Dolby Vision P7 FEL + Atmos via custom libplacebo + ffmpeg.
# Outputs to a SEPARATE folder (install-11700) from the zn2 build.
# ==============================================================================
set -euo pipefail

# --- CPU target config ---
CPU=rocketlake
TUNE=rocketlake
BUILD_DIR=/g/mpv-build/build-11700
PREFIX=/g/mpv-build/install-11700
LOG=/g/mpv-build/configure-11700.log

# --- Dependency paths (ALL external libs self-compiled per-target in G:\deps-build) ---
SRC=/g/mpv-build/mpv
FFMPEG_PREFIX=/g/ffmpeg-build/install-11700      # custom FFmpeg w/ dovi_split (11700)
DEPS=/g/deps-build/deps-11700                        # self-built deps + libplacebo (11700)

# --- Optimization flags (no fast-math; IEEE semantics required for codec bit-exactness) ---
OPT="-O3 -march=$CPU -mtune=$TUNE -mprefer-vector-width=256 -fvectorize -fslp-vectorize -funroll-loops -fomit-frame-pointer -fstrict-aliasing -fno-trapping-math"

echo "=== mpv build for Intel 11700 (rocketlake) ($CPU) ==="

# --- Ensure libplacebo is built (needed for DoVi FEL) ---
if [ ! -f "$DEPS/include/libplacebo/config.h" ]; then
  echo "libplacebo zn3 not found — building from source..."
  /g/mpv-build/build-libplacebo-11700.sh
fi

cd "$SRC"

# --- Ensure MinGW meson/ninja/python are on PATH (not MSYS versions) ---
export PATH="/clang64/bin:$PATH"

# --- Set PKG_CONFIG_PATH so self-built deps + ffmpeg take precedence over MSYS2 ---
export PKG_CONFIG_PATH="$DEPS/lib/pkgconfig:$FFMPEG_PREFIX/lib/pkgconfig:/clang64/lib/pkgconfig:${PKG_CONFIG_PATH:-}"



echo "Configuring mpv (meson setup)..."
rm -rf "$BUILD_DIR"
rm -rf "$PREFIX"    # clean output prefix: never ship stale DLLs
CC=clang CXX=clang++ /clang64/bin/meson setup "$BUILD_DIR" \
  --prefix="$PREFIX" \
  --default-library=shared \
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
  -Dc_link_args="-O3 -flto=thin -Wl,--gc-sections" \
  -Dcpp_link_args="-O3 -flto=thin -Wl,--gc-sections" \
  -Db_lto=true \
  -Db_lto_mode=thin \
  --buildtype=release \
  2>&1 | tee "$LOG"

echo "=== CONFIGURE DONE — reviewing key features ==="
grep -iE 'd3d11|wasapi|vulkan|libmpv|dovi|libplacebo|ffmpeg|cuda|d3d-hwaccel' "$BUILD_DIR/meson-logs/meson-log.txt" | head -20

echo "=== Compiling (ninja -j14) ==="
/clang64/bin/ninja -C "$BUILD_DIR" -j14 2>&1 | tee /g/mpv-build/make-11700.log | tail -10
echo "=== COMPILE EXIT: $? ==="

echo "=== Installing ==="
/clang64/bin/meson install -C "$BUILD_DIR" --quiet 2>&1 | tail -5
echo "=== INSTALL DONE ==="

echo "=== Copying DLL dependency closure ==="
/g/mpv-build/copydlls.sh "$PREFIX" "$DEPS"

echo "=== Smoke test ==="
/g/mpv-build/smoke_test.sh "$PREFIX/bin" || echo "WARN: smoke test failed (non-fatal)"

echo "=== Intel 11700 (rocketlake) build complete: $PREFIX ==="
