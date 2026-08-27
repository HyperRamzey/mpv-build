#!/bin/bash
# ==============================================================================
# Full orchestrator: clean → git pull ALL → deps ×3 → libplacebo ×3 → FFmpeg ×3
# → mpv ×3, all from latest git masters with per-target max optimization.
#
# Targets: znver3 (Zen3/RTX 5070 sm_120a), znver2 (Zen2/GTX 1650M sm_75),
#          rocketlake (i7-11700/RTX 4080 sm_89)
#
# Env knobs:
#   CLEAN=0    skip step 0 (incremental; default is FULL CLEAN of outputs+builds,
#              deps are stamp-cached and only rebuild when their git HEAD moves)
#   FORCE_DEPS=1  force rebuild every dependency (ignore stamps)
#   DEPS_LTO=1    thin-LTO the dependency libs too (much slower)
#   JOBS=N        parallel jobs per build (default 14)
# ==============================================================================
set -euo pipefail

echo "############################################################"
echo "# FULL E2E BUILD ORCHESTRATOR"
echo "# deps(~45 libs) + libplacebo + FFmpeg + mpv × znver3/znver2/11700"
echo "# $(date)"
echo "############################################################"

export MSYSTEM=CLANG64

# ==============================================================================
# Step 0: Clean output/build dirs (deps keep stamp cache unless FORCE_DEPS=1)
# ==============================================================================
if [ "${CLEAN:-1}" = "1" ]; then
	echo ""
	echo "=== STEP 0/6: Clean all build artifacts ==="
	rm -rf /g/mpv-build/build-zn3 /g/mpv-build/build-zn2 /g/mpv-build/build-11700
	rm -rf /g/mpv-build/libplacebo-src/_build* 
	for d in /g/mpv-build/install-zn3 /g/mpv-build/install-zn2 /g/mpv-build/install-11700; do
		# tolerate ghost-locked files (dead handles): clear contents, not the dir
		rm -rf "$d"/bin "$d"/lib "$d"/etc "$d"/share "$d"/include 2>/dev/null || \
			rm -f "$d"/bin/* 2>/dev/null || true
	done
	rm -rf /g/ffmpeg-build/install /g/ffmpeg-build/install-zn2 /g/ffmpeg-build/install-11700
	cd /g/ffmpeg-build/ffmpeg && make clean 2>/dev/null || true
	[ "${FORCE_DEPS:-0}" = "1" ] && rm -f /g/deps-build/src/*/.built-*
else
	echo "=== STEP 0/6 skipped (CLEAN=0) ==="
fi

# ==============================================================================
# Step 1: git pull EVERYTHING — deps (~44 repos), mpv, ffmpeg, libplacebo
# ==============================================================================
echo ""
echo "=== STEP 1/6: git pull all sources ==="
/g/deps-build/pull-all.sh
git -C /g/mpv-build/mpv           pull --ff-only 2>/dev/null || echo "mpv: pull failed"
git -C /g/ffmpeg-build/ffmpeg     pull --ff-only 2>/dev/null || echo "ffmpeg: pull failed"
git -C /g/mpv-build/libplacebo-src pull --ff-only 2>/dev/null || echo "libplacebo: pull failed"
echo "--- heads ---"
git -C /g/mpv-build/mpv log -1 --oneline
git -C /g/ffmpeg-build/ffmpeg log -1 --oneline
git -C /g/mpv-build/libplacebo-src log -1 --oneline

# ==============================================================================
# Step 2: dependencies ×3 (stamp-cached; only changed repos rebuild)
# ==============================================================================
echo ""
echo "=== STEP 2/6: self-built dependency matrix (zn3 → zn2 → 11700) ==="
[ "${FORCE_DEPS:-0}" = "1" ] && export FORCE=1
[ "${DEPS_LTO:-0}" = "1" ] && export DEPS_LTO=1
/g/deps-build/build-deps.sh zn3 zn2 11700

# ==============================================================================
# Step 3: libplacebo ×3 → per-target deps prefixes
# ==============================================================================
echo ""
echo "=== STEP 3/6: libplacebo zn3 ==="; /g/mpv-build/build-libplacebo-zn3.sh
echo ""; echo "=== STEP 3/6: libplacebo zn2 ==="; /g/mpv-build/build-libplacebo-zn2.sh
echo ""; echo "=== STEP 3/6: libplacebo 11700 ==="; /g/mpv-build/build-libplacebo-11700.sh

# ==============================================================================
# Step 4: FFmpeg ×3
# ==============================================================================
echo ""
echo "=== STEP 4/6: FFmpeg zn3 (sm_120a) ==="; /g/ffmpeg-build/build-zn3.sh
echo ""
echo "=== STEP 4/6: FFmpeg zn2 (sm_75) ==="; /g/ffmpeg-build/build-zn2.sh
echo ""
echo "=== STEP 4/6: FFmpeg 11700 (sm_89) ==="; /g/ffmpeg-build/build-11700.sh

# ==============================================================================
# Step 5: mpv ×3
# ==============================================================================
echo ""
echo "=== STEP 5/6: mpv zn3 ==="; /g/mpv-build/build-zn3.sh
echo ""
echo "=== STEP 5/6: mpv zn2 ==="; /g/mpv-build/build-zn2.sh
echo ""
echo "=== STEP 5/6: mpv 11700 ==="; /g/mpv-build/build-11700.sh

# ==============================================================================
# Step 6: verification summary
# ==============================================================================
echo ""
echo "=== STEP 6/6: verification ==="
for t in zn3 zn2 11700; do
	case $t in
		zn3)   FP=/g/ffmpeg-build/install;      MP=/g/mpv-build/install-zn3/bin ;;
		zn2)   FP=/g/ffmpeg-build/install-zn2;  MP=/g/mpv-build/install-zn2/bin ;;
		11700) FP=/g/ffmpeg-build/install-11700; MP=/g/mpv-build/install-11700/bin ;;
	esac
	echo "--- $t ---"
	"$MP/mpv.exe" --version 2>/dev/null | head -1 || echo "mpv.exe MISSING for $t"
	"$FP/bin/ffmpeg.exe" -version 2>/dev/null | head -1 || echo "ffmpeg.exe MISSING for $t"
	if compgen -G "$MP/*ggml*" >/dev/null || compgen -G "$MP/*whisper*" >/dev/null; then
		echo "!!! FAIL: ggml/whisper in $MP"; exit 1
	else
		echo "OK: no ggml/whisper in $MP"
	fi
done

echo ""
echo "############################################################"
echo "# ALL BUILDS COMPLETE $(date)"
echo "############################################################"