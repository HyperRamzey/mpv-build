#!/bin/bash
# FFmpeg build for Intel i7-11700 (rocketlake / RTX 4080 sm_89) — clang 22 / CLANG64
# All external libs SELF-COMPILED per-target via G:\media-build\deps-build (static-first)
set -eo pipefail
export MSYSTEM=CLANG64
SRC=/g/media-build/ffmpeg-build/ffmpeg
PREFIX=/g/media-build/ffmpeg-build/install-11700
LOG=/g/media-build/ffmpeg-build/configure-11700.log
DEPS=/g/media-build/deps-build/deps-11700
cd "$SRC"

export PATH="/clang64/bin:/usr/bin:/c/Program Files/NVIDIA GPU Computing Toolkit/CUDA/v13.3/bin:$PATH"
export CUDA_PATH="/c/Program Files/NVIDIA GPU Computing Toolkit/CUDA/v13.3"
# Self-built deps FIRST; /clang64 only for system runtime bits (gettext, SDL2-for-ffplay)
export PKG_CONFIG_PATH="$DEPS/lib/pkgconfig:/clang64/lib/pkgconfig:${PKG_CONFIG_PATH:-}"
export LDFLAGS="-static -L$DEPS/lib -L/clang64/lib ${LDFLAGS:-}"

OPT="-O3 -march=rocketlake -mtune=rocketlake -mprefer-vector-width=256 -fvectorize -fslp-vectorize -funroll-loops -fomit-frame-pointer -fstrict-aliasing -fno-trapping-math"

# CUDA nvcc flags: sm_89 (Blackwell RTX 5070), clang NVPTX backend
NVCCFLAGS="--cuda-gpu-arch=sm_89 -Xclang -target-feature -Xclang +ptx87 -O3"
# Clean the output prefix FIRST: never ship stale DLLs (old libplacebo etc.)
rm -rf "$PREFIX"
if [[ -f ffbuild/config.mak ]]; then make clean; fi  # fresh clones have no config yet
echo "=== FFmpeg configure (rocketlake / sm_89) ==="
./configure \
	--prefix="$PREFIX" \
	--cc=clang --cxx=clang++ --pkg-config-flags=--static \
	--cpu=rocketlake \
	--extra-cflags="$OPT -I$DEPS/include -DLIBTWOLAME_STATIC -DLIBSSH_STATIC -DMODPLUG_STATIC" --extra-cxxflags="$OPT -I$DEPS/include" \
	--extra-ldflags="-static -Wl,--gc-sections -L$DEPS/lib" --extra-libs="-lcfgmgr32 -lole32 -luuid" \
	--enable-gpl --enable-version3 --enable-nonfree \
	--enable-audiotoolbox \
	--enable-lto=thin --disable-debug --disable-doc \
	--enable-ffnvcodec --enable-cuda-llvm --enable-nvenc --enable-nvdec --enable-cuvid \
	--nvccflags="$NVCCFLAGS" \
	--enable-opencl --enable-vulkan --enable-libplacebo --enable-libvpl \
	--enable-libx264 --enable-libx265 --enable-libxvid --enable-libvpx \
--enable-libvvenc --enable-avisynth --enable-liblcevc-dec --enable-liboapv --enable-libsvtjpegxs --enable-libuavs3d --enable-libxevd --enable-libxeve --enable-libsnappy --enable-libqrencode --enable-vapoursynth \
	--enable-libaom --enable-libdav1d --enable-libsvtav1 \
	--enable-libopenh264 --enable-libfdk-aac --enable-libmp3lame \
	--enable-libopus --enable-libvorbis --enable-libspeex \
	--enable-libtheora --enable-libtwolame \
	--enable-libopencore-amrnb --enable-libopencore-amrwb \
	--enable-libvo-amrwbenc --enable-libilbc --enable-libcodec2 \
	--enable-liblc3 --enable-libwebp --enable-libopenjpeg \
	--enable-libjxl --enable-libzimg \
	--enable-libvmaf --enable-libsoxr \
	--enable-libmysofa --enable-librubberband \
	--enable-libvidstab --enable-libass \
	--enable-libfreetype --enable-libfontconfig \
	--enable-libharfbuzz --enable-libfribidi \
	--enable-libxml2 --enable-libbluray \
	--enable-libgme --enable-libmodplug \
	--enable-libsrt \
	--enable-libssh --enable-librtmp \
	--enable-libzmq --enable-openssl \
	--enable-libaribcaption \
	--enable-frei0r \
	--enable-bzlib --enable-zlib --enable-lzma \
	--enable-iconv --enable-lcms2 \
	--disable-libcurl --disable-libmfx --disable-libcaca --disable-libbs2b --disable-libaribb24 \
	--disable-gnutls --disable-whisper --disable-sndio --disable-libxcb \
	--disable-xlib --disable-vaapi --disable-vdpau --disable-libdrm \
	--disable-libzvbi --disable-librsvg --disable-libopenmpt --disable-libgsm 2>&1 | tee "$LOG"

echo "=== CONFIGURE DONE ==="
echo "=== Compiling (make -j14) ==="
make LD="$DEPS/wat4ff_ld" WAT4FF_TRUELD=clang -j14 2>&1 | tee /g/media-build/ffmpeg-build/make-11700.log | grep -E '^(CC|CXX|LD|CUDA|error|Error|warning:)' | tail -5
echo "=== MAKE EXIT: $? ==="
make install 2>&1 | tail -3
# aac_at: -framework is Darwin syntax; Windows consumers (mpv meson) must
# link the wat4ff wrapper instead
sed -i "s/-framework AudioToolbox/-lwat4ff/g" "$PREFIX"/lib/pkgconfig/*.pc
# scrub -lstdc++ residue (vvenc/xeve upstream pcs): the token resolves
# against the MSYS cygwin toolchain, not our libc++ mingw one
sed -i "s/ -lstdc++//g" "$PREFIX"/lib/pkgconfig/*.pc
/g/media-build/mpv-build/copydlls.sh "$PREFIX" "$DEPS"
echo "=== FFmpeg 11700 installed to $PREFIX ==="
