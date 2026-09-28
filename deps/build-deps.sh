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

# --- post-build contract check ------------------------------------------------
# mpv's meson hard-requires the .pc files below. The lua one is the sharp edge:
# build-<t>.sh passes -Dlua=luajit, which takes mpv/meson.build:756's REQUIRED
# dependency() path instead of the `required: false` auto path on :751 — so a
# missing luajit.pc is a fatal configure error, not a silently disabled feature.
#
# WHY assert it here: a deps run can exit 0 with a .pc absent, and the symptom
# only surfaces ~2h later in the mpv job as an opaque
#   ERROR: Dependency "luajit" not found (tried pkg-config and cmake)
# with a green deps job and no hint at the cause. Observed 2026-09-13 on 11700
# + x64v4 only (mujs/lcms2/libarchive/iconv all resolved; luajit alone missing;
# deps job green; same SHA built clean a week later). Check the contract in the
# job that owns the prefix so the failure names the file.
#
# libplacebo is deliberately NOT in this list: it is not a build-deps.sh recipe
# at all. It is built per-target by mpv-build/build-libplacebo-<t>.sh, which
# runs AFTER this script (locally as build-all.sh step 3, in CI as the very next
# step of the deps job), so on any fresh prefix libplacebo.pc cannot exist yet
# and asserting it here fails all 8 targets unconditionally. It did exactly that
# on 2026-09-25 (dispatch) and 2026-09-27 (weekly), in both repos — and never
# reproduced locally, because a local prefix still carries the libplacebo.pc
# installed by the previous run. The libplacebo half of the contract is asserted
# by build-libplacebo-<t>.sh, the step that can actually observe it.
#
# All 18 are present in every local deps-<t> prefix; keep this list in sync if
# mpv's meson.build hard-dependency set changes.
REQUIRED_PCS=(
	luajit libass iconv mujs lcms2 libarchive
	zlib libjpeg zimg sdl2 rubberband libbluray uchardet
	shaderc spirv-cross-c-shared libsixel vulkan openal
)
verify_prefix_pcs() {
	local t="$1" pc f missing=()
	for pc in "${REQUIRED_PCS[@]}"; do
		[[ -f "$PREFIX/lib/pkgconfig/$pc.pc" ]] || missing+=("$pc.pc")
	done
	if (( ${#missing[@]} > 0 )); then
		log "FATAL: target $t prefix missing required pkg-config file(s):"
		for f in "${missing[@]}"; do
			log "         $PREFIX/lib/pkgconfig/$f"
		done
		log "         mpv hard-requires these (see REQUIRED_PCS in build-deps.sh)"
		exit 1
	fi
	log "OK $t: all ${#REQUIRED_PCS[@]} required .pc files present"
}

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
	verify_prefix_pcs "$t"
done

log "=========== SUMMARY ==========="
if [[ ${#FAILED[@]} -gt 0 ]]; then
	log "completed with ${#FAILED[@]} best-effort failure(s): ${FAILED[*]}"
else
	log "all dependencies built for: ${TARGETS[*]}"
fi