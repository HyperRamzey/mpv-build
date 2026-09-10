#!/bin/bash
# ==============================================================================
# Smoke test: verify mpv build is functional and has all required features
# Checks: version, gpu-next (D3D11), WASAPI, Vulkan, libmpv, DoVi FEL readiness
# ==============================================================================
set +e

PREFIX="${1:-/g/media-build/mpv-build/install-zn3/bin}"
LOG=/g/media-build/mpv-build/smoke.log
PASS=0
FAIL=0
SKIP=0

echo "=== mpv smoke test: $PREFIX ===" | tee "$LOG"

cd "$PREFIX" || {
  echo "FAIL: cannot cd to $PREFIX" | tee -a "$LOG"
  exit 1
}

MPV="./mpv.com" # console wrapper: works headless (nohup/CI), mpv.exe detaches

# Helper: run mpv with timeout, capture output
run_mpv() {
  timeout 15 "$MPV" "$@" 2>&1
}

# --- CPU ISA guard -------------------------------------------------------
# Cross-arch smoke testing: a binary built with -march=<foreign-isa> (e.g.
# rocketlake's AVX-512 on an AMD Zen host, or raptorlake on Zen) dies with
# SIGILL (rc=132) before main() runs — no feature list is retrievable on
# this machine. That is a property of the HOST, not a build defect; the
# binary must be smoke-tested on its own target hardware (or a runner with
# a compatible CPU — GH windows-2025 Xeons have AVX-512, so rocketlake and
# raptorlake binaries run there fine).
ISA_INCOMPAT=0
ISA_OUT=$(run_mpv --no-config --version)
if ! echo "$ISA_OUT" | grep -q "mpv v"; then
  rc_probe=$(
    timeout 15 "$MPV" --no-config --version >/dev/null 2>&1
    echo $?
  )
  if [ "$rc_probe" = "132" ] || [ "$rc_probe" = "136" ]; then
    ISA_INCOMPAT=1
  fi
fi

# 1. mpv --version (shows full configure line + lib versions)
echo "--- mpv --version ---" | tee -a "$LOG"
VER_OUT=$(run_mpv --version)
echo "$VER_OUT" | tee -a "$LOG"
if echo "$VER_OUT" | grep -q "mpv v"; then
  PASS=$((PASS + 1))
  echo "PASS: mpv runs successfully" | tee -a "$LOG"
elif [ "$ISA_INCOMPAT" = "1" ]; then
  echo "SKIP: binary uses an ISA this host CPU lacks (SIGILL before main) —" \
    "smoke features unverifiable on this machine; test on target hw" | tee -a "$LOG"
  SKIP=$((SKIP + 1))
else
  echo "FAIL: mpv did not run" | tee -a "$LOG"
  FAIL=$((FAIL + 1))
fi

# 2. Check gpu-next VO (D3D11 rendering via libplacebo)
echo "--- gpu-next VO (D3D11) check ---" | tee -a "$LOG"
VO_OUT=$(run_mpv --vo=help)
if echo "$VO_OUT" | grep -qi 'gpu-next'; then
  echo "PASS: gpu-next VO available (D3D11 via libplacebo)" | tee -a "$LOG"
  PASS=$((PASS + 1))
elif [ "$ISA_INCOMPAT" = "1" ]; then
  echo "SKIP: gpu-next VO check (ISA-incompatible host)" | tee -a "$LOG"
  SKIP=$((SKIP + 1))
else
  echo "FAIL: gpu-next VO not found" | tee -a "$LOG"
  FAIL=$((FAIL + 1))
fi

# 3. Check WASAPI audio output
echo "--- WASAPI AO check ---" | tee -a "$LOG"
AO_OUT=$(run_mpv --ao=help)
if echo "$AO_OUT" | grep -qi wasapi; then
  echo "PASS: wasapi AO available" | tee -a "$LOG"
  PASS=$((PASS + 1))
elif [ "$ISA_INCOMPAT" = "1" ]; then
  echo "SKIP: wasapi AO check (ISA-incompatible host)" | tee -a "$LOG"
  SKIP=$((SKIP + 1))
else
  echo "FAIL: wasapi AO not found" | tee -a "$LOG"
  FAIL=$((FAIL + 1))
fi

# 4. Check D3D11 hardware decoding (d3d11va)
echo "--- D3D11 hwdec check ---" | tee -a "$LOG"
HW_OUT=$(run_mpv --hwdec=help)
if echo "$HW_OUT" | grep -qi 'd3d11va'; then
  echo "PASS: d3d11va hwdec available" | tee -a "$LOG"
  PASS=$((PASS + 1))
elif [ "$ISA_INCOMPAT" = "1" ]; then
  echo "SKIP: d3d11va hwdec check (ISA-incompatible host)" | tee -a "$LOG"
  SKIP=$((SKIP + 1))
else
  echo "FAIL: d3d11va hwdec not found" | tee -a "$LOG"
  FAIL=$((FAIL + 1))
fi

# 5. Check Vulkan support (for gpu-next gpu-api=vulkan)
echo "--- Vulkan check ---" | tee -a "$LOG"
GPU_OUT=$(run_mpv --gpu-api=help 2>&1)
if echo "$GPU_OUT" | grep -qi vulkan; then
  echo "PASS: vulkan GPU API available" | tee -a "$LOG"
  PASS=$((PASS + 1))
elif [ "$ISA_INCOMPAT" = "1" ]; then
  echo "SKIP: vulkan check (ISA-incompatible host)" | tee -a "$LOG"
  SKIP=$((SKIP + 1))
else
  # Also check via --help
  HELP_OUT=$(run_mpv --no-config --help)
  if echo "$HELP_OUT" | grep -qi vulkan; then
    echo "PASS: vulkan support available" | tee -a "$LOG"
    PASS=$((PASS + 1))
  else
    echo "FAIL: vulkan API not found" | tee -a "$LOG"
    FAIL=$((FAIL + 1))
  fi
fi

# 6. Check libmpv DLL exists
echo "--- libmpv DLL check ---" | tee -a "$LOG"
if [ -f "libmpv-2.dll" ]; then
  echo "PASS: libmpv-2.dll present" | tee -a "$LOG"
  PASS=$((PASS + 1))
else
  echo "FAIL: libmpv-2.dll missing" | tee -a "$LOG"
  FAIL=$((FAIL + 1))
fi

# 7. Check DLL closure (ignore Windows api-ms-win-* stubs)
echo "--- DLL closure check ---" | tee -a "$LOG"
MISSING=$(timeout 15 ldd mpv.exe 2>&1 | grep -v "api-ms-win" | grep -c "not found" || true)
if [ "$MISSING" -eq 0 ]; then
  echo "PASS: no missing DLLs" | tee -a "$LOG"
  PASS=$((PASS + 1))
else
  echo "FAIL: $MISSING missing DLLs (non-Windows)" | tee -a "$LOG"
  timeout 15 ldd mpv.exe 2>&1 | grep "not found" | grep -v "api-ms-win" | tee -a "$LOG"
  FAIL=$((FAIL + 1))
fi

# 8. Check libplacebo version (PL_API_VER >= 370 for DoVi P7 FEL) — numeric compare
echo "--- libplacebo version check ---" | tee -a "$LOG"
PL_FULL=$(echo "$VER_OUT" | grep -oP 'libplacebo version: v\K[0-9]+\.[0-9]+\.[0-9]+' || echo "0.0.0")
ver_cmp() { # returns 0 if $1 >= $2 (numeric dotted)
  local a b
  a=$(echo "$1" | awk -F. '{printf "%d%03d%03d",$1,$2,$3}')
  b=$(echo "$2" | awk -F. '{printf "%d%03d%03d",$1,$2,$3}')
  [ "$a" -ge "$b" ]
}
if ver_cmp "$PL_FULL" "7.370.0"; then
  echo "PASS: libplacebo v$PL_FULL (>= 7.370 / PL_API_VER >= 371 for DoVi FEL)" | tee -a "$LOG"
  PASS=$((PASS + 1))
elif [ "$ISA_INCOMPAT" = "1" ]; then
  echo "SKIP: libplacebo version check (ISA-incompatible host)" | tee -a "$LOG"
  SKIP=$((SKIP + 1))
else
  echo "FAIL: libplacebo v$PL_FULL (< 7.370, DoVi P7 FEL NOT available)" | tee -a "$LOG"
  FAIL=$((FAIL + 1))
fi

# 9. Check mpv.conf compatibility (config lives in the mpv/ config dir —
# mpv's win32 "global" config dir exe_dir/mpv; no flat copy next to exe)
echo "--- Config compatibility check ---" | tee -a "$LOG"
CONF=mpv/mpv.conf
if [ -f "$CONF" ]; then
  if grep -qiE "gpu-next|d3d11|wasapi|dolbyvision|enhancement-layer" "$CONF"; then
    echo "PASS: mpv.conf has gpu-next/d3d11/wasapi/DoVi config" | tee -a "$LOG"
    PASS=$((PASS + 1))
  else
    echo "WARN: mpv.conf present but missing key features" | tee -a "$LOG"
  fi
else
  echo "FAIL: mpv/mpv.conf not found (portable config not staged)" | tee -a "$LOG"
  FAIL=$((FAIL + 1))
fi

# 10. AI-lib pollution guard: no ggml/whisper/llama artifacts may ship
echo "--- AI-lib pollution check ---" | tee -a "$LOG"
JUNK=$(ls | grep -iE 'ggml|whisper|llama' || true)
if [ -z "$JUNK" ]; then
  echo "PASS: no ggml/whisper/llama artifacts in bin" | tee -a "$LOG"
  PASS=$((PASS + 1))
else
  echo "FAIL: AI-lib artifacts present:" | tee -a "$LOG"
  echo "$JUNK" | tee -a "$LOG"
  FAIL=$((FAIL + 1))
fi

# 11. VapourSynth runtime: mpv/ffmpeg dlopen "VSScript.dll" by name; the
# build installs libvsscript.dll — copydlls ships an alias. If the alias is
# missing the vapoursynth filter silently fails at runtime.
echo "--- VapourSynth runtime (VSScript.dll alias) check ---" | tee -a "$LOG"
if [ -f "VSScript.dll" ] && [ -f "libvapoursynth.dll" ]; then
  echo "PASS: VapourSynth runtime present (VSScript.dll + libvapoursynth.dll)" | tee -a "$LOG"
  PASS=$((PASS + 1))
elif [ -f "libvapoursynth.dll" ]; then
  echo "FAIL: libvapoursynth.dll present but VSScript.dll alias missing — vapoursynth will not load" | tee -a "$LOG"
  FAIL=$((FAIL + 1))
else
  echo "WARN: VapourSynth runtime DLLs absent (best-effort dep may have failed)" | tee -a "$LOG"
fi

# 12. DoVi P7 FEL chain: FFmpeg dovi_split BSF presence (mpv splits BL/EL with
# it when demuxing profile 7 FEL tracks)
echo "--- DoVi FEL: ffmpeg dovi_split BSF check ---" | tee -a "$LOG"
FFP=""
for c in /g/media-build/ffmpeg-build/install/bin/ffmpeg.exe /g/media-build/ffmpeg-build/install-zn2/bin/ffmpeg.exe \
  /g/media-build/ffmpeg-build/install-11700/bin/ffmpeg.exe /g/media-build/ffmpeg-build/install-3050/bin/ffmpeg.exe \
  /g/media-build/ffmpeg-build/install-14600/bin/ffmpeg.exe; do
  # pick the first candidate that EXECUTES on this host — a foreign-ISA
  # ffmpeg (e.g. rocketlake AVX-512 on an AVX-512-less runner) SIGILLs
  # before printing anything, and a silent -bsfs must not read as
  # "dovi_split missing". Same SKIP-not-FAIL rule as every other
  # ISA-affected check in this file.
  [ -x "$c" ] || continue
  if timeout 15 "$c" -hide_banner -version >/dev/null 2>&1; then
    FFP="$c"
    break
  fi
done
if [ -n "$FFP" ]; then
  if "$FFP" -hide_banner -bsfs 2>/dev/null | grep -q "dovi_split"; then
    echo "PASS: dovi_split BSF available in ffmpeg ($FFP)" | tee -a "$LOG"
    PASS=$((PASS + 1))
  else
    echo "FAIL: dovi_split BSF missing — DoVi P7 FEL EL cannot be separated" | tee -a "$LOG"
    FAIL=$((FAIL + 1))
  fi
else
  echo "SKIP: no ffmpeg on this host can execute (ISA-incompatible) — BSF check deferred to target hw" | tee -a "$LOG"
  SKIP=$((SKIP + 1))
fi

echo "" | tee -a "$LOG"
echo "=== Smoke test results: $PASS passed, $FAIL failed, $SKIP skipped ===" | tee -a "$LOG"

if [ "$FAIL" -gt 0 ]; then
  echo "SMOKE TEST FAILED" | tee -a "$LOG"
  exit 1
fi
echo "SMOKE TEST PASSED" | tee -a "$LOG"
