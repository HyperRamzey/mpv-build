#!/bin/bash
# build-deps.sh [targets...] — full dependency matrix, dependency-tiered
#   default targets: zn3 zn2 11700 3050
# Env: FORCE=1 rebuild-all, DEPS_LTO=1 thin-LTO deps, JOBS=N parallel make
set -Eeuo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/common.sh"

TARGETS=("$@")
[[ ${#TARGETS[@]} -eq 0 ]] && TARGETS=(zn3 zn2 11700 3050 14600)
mkdir -p "$DEPS_ROOT/logs" "$SRC_ROOT" "$BUILD_ROOT"

# Tier order matters (topological)
TIERS=(
	"zlib zstd xz brotli expat libiconv libpng libjpeg-turbo lcms2 openssl dlfcn snappy quirc qrencode chromaprint"
	"ogg vorbis speexdsp speex opus lame twolame fdk-aac opencore-amr vo-amrwbenc ilbc codec2 lc3 openal soxr rubberband unibreak bzip2"
	"x264 x265 libvpx aom dav1d svtav1 openh264 libwebp openjpeg jxl zimg vmaf vidstab theora rav1e libxvid libmysofa vvenc uavs3d xevd xeve openapv svtjpegxs lcevcdec mpeghdec avisynth"
	"freetype fribidi harfbuzz fontconfig libxml2 libass libbluray libaribcaption uchardet libgme libmodplug libsixel dvdcss dvdread dvdnav libcdio libcdio-paranoia luajit mujs libarchive gavl frei0r sdl2"
	"srt libssh libzmq librtmp librist subrandr"
	"vulkan-headers vulkan-loader glslang shaderc spirv-cross opencl-headers opencl-icd-loader ffnvcodec libvpl libdovi vapoursynth wat4ff"
)

FAILED=()
for t in "${TARGETS[@]}"; do
	target_env "$t"
	log "===== TARGET $t — $TARGET_CPU ====="
	for tier in "${TIERS[@]}"; do
		for lib in $tier; do
			if ! "$HERE/build-one.sh" "$t" "$lib"; then
				# best-effort libs don't kill the run
				if grep -q '^BEST_EFFORT=1' "$HERE/recipes/$lib.sh" 2>/dev/null; then
					log "WARN: best-effort '$lib' failed — downstream configure will auto-disable it"
					FAILED+=("$lib@$t(BEST-EFFORT)")
				else
					log "FATAL: required '$lib' failed on target $t"
					exit 1
				fi
			fi
		done
	done
	"$HERE/fix-static-pcs.sh" "$PREFIX"
	"$HERE/sanitize-prefix.sh" "$PREFIX"
done

log "=========== SUMMARY ==========="
if [[ ${#FAILED[@]} -gt 0 ]]; then
	log "completed with ${#FAILED[@]} best-effort failure(s): ${FAILED[*]}"
else
	log "all dependencies built for: ${TARGETS[*]}"
fi