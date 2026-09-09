#!/bin/bash
# ==============================================================================
# Full orchestrator: clean → git pull ALL → deps ×3 → libplacebo ×3 → FFmpeg ×3
# → mpv ×3, all from latest git masters with per-target max optimization.
#
# Targets: znver3 (Zen3/RTX 5070 sm_120a), znver2 (Zen2/GTX 1650M sm_75),
#          rocketlake (i7-11700/RTX 4080 sm_89), 3050 (Zen2/RTX 3050M sm_86),
#          raptorlake (i5-14600/RTX 50-series sm_120a), x64v2/v3/v4 (generic
#          ISA levels + allcuda — CI-oriented, not in the local default set)
#
# Env knobs:
#   TARGETS="t1 t2 ..."  space-separated target subset (default: the five
#                        hardware targets; x64v2/v3/v4 are CI-oriented and
#                        built by the GitHub workflows)
#   CLEAN=0    skip step 0 (incremental; default is FULL CLEAN of outputs+builds,
#              deps are stamp-cached and only rebuild when their git HEAD moves)
#   FORCE_DEPS=1  force rebuild every dependency (ignore stamps)
#   DEPS_LTO=1    thin-LTO the dependency libs too (much slower)
#   JOBS=N        parallel jobs per build (default 14)
# ==============================================================================
set -euo pipefail

# TARGETS governs every per-target step below (deps/libplacebo/ffmpeg/mpv/verify)
TARGETS=${TARGETS:-"zn3 zn2 11700 3050 14600"}
echo "############################################################"
echo "# FULL E2E BUILD ORCHESTRATOR"
echo "# deps(~45 libs) + libplacebo + FFmpeg + mpv × $TARGETS"
echo "# $(date)"
echo "############################################################"

export MSYSTEM=CLANG64

# ==============================================================================
# Step 0: Clean output/build dirs (deps keep stamp cache unless FORCE_DEPS=1)
# ==============================================================================
if [ "${CLEAN:-1}" = "1" ]; then
	echo ""
	echo "=== STEP 0/6: Clean all build artifacts ==="
	rm -rf /g/media-build/mpv-build/build-zn3 /g/media-build/mpv-build/build-zn2 /g/media-build/mpv-build/build-11700 /g/media-build/mpv-build/build-3050 /g/media-build/mpv-build/build-14600 \
		/g/media-build/mpv-build/build-x64v2 /g/media-build/mpv-build/build-x64v3 /g/media-build/mpv-build/build-x64v4
	rm -rf /g/media-build/mpv-build/libplacebo-src/_build*
	for d in /g/media-build/mpv-build/install-zn3 /g/media-build/mpv-build/install-zn2 /g/media-build/mpv-build/install-11700 /g/media-build/mpv-build/install-3050 /g/media-build/mpv-build/install-14600 \
		/g/media-build/mpv-build/install-x64v2 /g/media-build/mpv-build/install-x64v3 /g/media-build/mpv-build/install-x64v4; do
		# tolerate ghost-locked files (dead handles): clear contents, not the dir
		rm -rf "$d"/bin "$d"/lib "$d"/etc "$d"/share "$d"/include 2>/dev/null ||
			rm -f "$d"/bin/* 2>/dev/null || true
	done
	rm -rf /g/media-build/ffmpeg-build/install /g/media-build/ffmpeg-build/install-zn2 /g/media-build/ffmpeg-build/install-11700 /g/media-build/ffmpeg-build/install-3050 /g/media-build/ffmpeg-build/install-14600 \
		/g/media-build/ffmpeg-build/install-x64v2 /g/media-build/ffmpeg-build/install-x64v3 /g/media-build/ffmpeg-build/install-x64v4
	cd /g/media-build/ffmpeg-build/ffmpeg && make clean 2>/dev/null || true
	[ "${FORCE_DEPS:-0}" = "1" ] && rm -f /g/media-build/deps-build/src/*/.built-*
else
	echo "=== STEP 0/6 skipped (CLEAN=0) ==="
fi

# ==============================================================================
# Step 1: git pull EVERYTHING — deps (~44 repos), mpv, ffmpeg, libplacebo
# ==============================================================================
echo ""
echo "=== STEP 1/6: git pull all sources ==="
/g/media-build/deps-build/pull-all.sh
git -C /g/media-build/mpv-build/mpv pull --ff-only 2>/dev/null || echo "mpv: pull failed"
git -C /g/media-build/ffmpeg-build/ffmpeg pull --ff-only 2>/dev/null || echo "ffmpeg: pull failed"
git -C /g/media-build/mpv-build/libplacebo-src pull --ff-only 2>/dev/null || echo "libplacebo: pull failed"
echo "--- heads ---"
git -C /g/media-build/mpv-build/mpv log -1 --oneline
git -C /g/media-build/ffmpeg-build/ffmpeg log -1 --oneline
git -C /g/media-build/mpv-build/libplacebo-src log -1 --oneline

# ==============================================================================
# Step 2: dependencies ×3 (stamp-cached; only changed repos rebuild)
# ==============================================================================
echo ""
echo "=== STEP 2/6: self-built dependency matrix ($TARGETS) ==="
[ "${FORCE_DEPS:-0}" = "1" ] && export FORCE=1
[ "${DEPS_LTO:-0}" = "1" ] && export DEPS_LTO=1
/g/media-build/deps-build/build-deps.sh $TARGETS

# ==============================================================================
# Step 3: libplacebo per target → per-target deps prefixes
# ==============================================================================
for t in $TARGETS; do
	echo ""
	echo "=== STEP 3/6: libplacebo $t ==="
	/g/media-build/mpv-build/build-libplacebo-$t.sh
done

# ==============================================================================
# Step 4: FFmpeg per target
# ==============================================================================
for t in $TARGETS; do
	echo ""
	echo "=== STEP 4/6: FFmpeg $t ==="
	/g/media-build/ffmpeg-build/build-$t.sh
done

# ==============================================================================
# Step 5: mpv per target
# ==============================================================================
for t in $TARGETS; do
	echo ""
	echo "=== STEP 5/6: mpv $t ==="
	/g/media-build/mpv-build/build-$t.sh
done

# ==============================================================================
# Step 6: verification summary
# ==============================================================================
echo ""
echo "=== STEP 6/6: verification ==="
for t in $TARGETS; do
	case $t in
	zn3)
		FP=/g/media-build/ffmpeg-build/install
		MP=/g/media-build/mpv-build/install-zn3/bin
		;;
	zn2)
		FP=/g/media-build/ffmpeg-build/install-zn2
		MP=/g/media-build/mpv-build/install-zn2/bin
		;;
	11700)
		FP=/g/media-build/ffmpeg-build/install-11700
		MP=/g/media-build/mpv-build/install-11700/bin
		;;
	3050)
		FP=/g/media-build/ffmpeg-build/install-3050
		MP=/g/media-build/mpv-build/install-3050/bin
		;;
	14600)
		FP=/g/media-build/ffmpeg-build/install-14600
		MP=/g/media-build/mpv-build/install-14600/bin
		;;
	x64v2)
		FP=/g/media-build/ffmpeg-build/install-x64v2
		MP=/g/media-build/mpv-build/install-x64v2/bin
		;;
	x64v3)
		FP=/g/media-build/ffmpeg-build/install-x64v3
		MP=/g/media-build/mpv-build/install-x64v3/bin
		;;
	x64v4)
		FP=/g/media-build/ffmpeg-build/install-x64v4
		MP=/g/media-build/mpv-build/install-x64v4/bin
		;;
	esac
	echo "--- $t ---"
	"$MP/mpv.exe" --version 2>/dev/null | head -1 || echo "mpv.exe MISSING for $t"
	"$FP/bin/ffmpeg.exe" -version 2>/dev/null | head -1 || echo "ffmpeg.exe MISSING for $t"
	if compgen -G "$MP/*ggml*" >/dev/null || compgen -G "$MP/*whisper*" >/dev/null; then
		echo "!!! FAIL: ggml/whisper in $MP"
		exit 1
	else
		echo "OK: no ggml/whisper in $MP"
	fi
done

echo ""
echo "############################################################"
echo "# ALL BUILDS COMPLETE $(date)"
echo "############################################################"
