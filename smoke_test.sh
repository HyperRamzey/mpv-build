#!/bin/bash
# ==============================================================================
# Smoke test: verify mpv build is functional and has all required features
# Checks: version, gpu-next (D3D11), WASAPI, Vulkan, libmpv, DoVi FEL readiness
# ==============================================================================
set +e

PREFIX="${1:-/g/mpv-build/install-zn3/bin}"
LOG=/g/mpv-build/smoke.log
PASS=0
FAIL=0

echo "=== mpv smoke test: $PREFIX ===" | tee "$LOG"

cd "$PREFIX" || { echo "FAIL: cannot cd to $PREFIX" | tee -a "$LOG"; exit 1; }

MPV="./mpv.com"   # console wrapper: works headless (nohup/CI), mpv.exe detaches

# Helper: run mpv with timeout, capture output
run_mpv() {
  timeout 15 "$MPV" "$@" 2>&1
}

# 1. mpv --version (shows full configure line + lib versions)
echo "--- mpv --version ---" | tee -a "$LOG"
VER_OUT=$(run_mpv --version)
echo "$VER_OUT" | tee -a "$LOG"
if echo "$VER_OUT" | grep -q "mpv v"; then
  PASS=$((PASS+1))
  echo "PASS: mpv runs successfully" | tee -a "$LOG"
else
  echo "FAIL: mpv did not run" | tee -a "$LOG"
  FAIL=$((FAIL+1))
fi

# 2. Check gpu-next VO (D3D11 rendering via libplacebo)
echo "--- gpu-next VO (D3D11) check ---" | tee -a "$LOG"
VO_OUT=$(run_mpv --vo=help)
if echo "$VO_OUT" | grep -qi 'gpu-next'; then
  echo "PASS: gpu-next VO available (D3D11 via libplacebo)" | tee -a "$LOG"
  PASS=$((PASS+1))
else
  echo "FAIL: gpu-next VO not found" | tee -a "$LOG"
  FAIL=$((FAIL+1))
fi

# 3. Check WASAPI audio output
echo "--- WASAPI AO check ---" | tee -a "$LOG"
AO_OUT=$(run_mpv --ao=help)
if echo "$AO_OUT" | grep -qi wasapi; then
  echo "PASS: wasapi AO available" | tee -a "$LOG"
  PASS=$((PASS+1))
else
  echo "FAIL: wasapi AO not found" | tee -a "$LOG"
  FAIL=$((FAIL+1))
fi

# 4. Check D3D11 hardware decoding (d3d11va)
echo "--- D3D11 hwdec check ---" | tee -a "$LOG"
HW_OUT=$(run_mpv --hwdec=help)
if echo "$HW_OUT" | grep -qi 'd3d11va'; then
  echo "PASS: d3d11va hwdec available" | tee -a "$LOG"
  PASS=$((PASS+1))
else
  echo "FAIL: d3d11va hwdec not found" | tee -a "$LOG"
  FAIL=$((FAIL+1))
fi

# 5. Check Vulkan support (for gpu-next gpu-api=vulkan)
echo "--- Vulkan check ---" | tee -a "$LOG"
GPU_OUT=$(run_mpv --gpu-api=help 2>&1)
if echo "$GPU_OUT" | grep -qi vulkan; then
  echo "PASS: vulkan GPU API available" | tee -a "$LOG"
  PASS=$((PASS+1))
else
  # Also check via --help
  HELP_OUT=$(run_mpv --no-config --help)
  if echo "$HELP_OUT" | grep -qi vulkan; then
    echo "PASS: vulkan support available" | tee -a "$LOG"
    PASS=$((PASS+1))
  else
    echo "FAIL: vulkan API not found" | tee -a "$LOG"
    FAIL=$((FAIL+1))
  fi
fi

# 6. Check libmpv DLL exists
echo "--- libmpv DLL check ---" | tee -a "$LOG"
if [ -f "libmpv-2.dll" ]; then
  echo "PASS: libmpv-2.dll present" | tee -a "$LOG"
  PASS=$((PASS+1))
else
  echo "FAIL: libmpv-2.dll missing" | tee -a "$LOG"
  FAIL=$((FAIL+1))
fi

# 7. Check DLL closure (ignore Windows api-ms-win-* stubs)
echo "--- DLL closure check ---" | tee -a "$LOG"
MISSING=$(timeout 15 ldd mpv.exe 2>&1 | grep -v "api-ms-win" | grep -c "not found" || true)
if [ "$MISSING" -eq 0 ]; then
  echo "PASS: no missing DLLs" | tee -a "$LOG"
  PASS=$((PASS+1))
else
  echo "FAIL: $MISSING missing DLLs (non-Windows)" | tee -a "$LOG"
  timeout 15 ldd mpv.exe 2>&1 | grep "not found" | grep -v "api-ms-win" | tee -a "$LOG"
  FAIL=$((FAIL+1))
fi

# 8. Check libplacebo version (PL_API_VER >= 370 for DoVi P7 FEL) — numeric compare
echo "--- libplacebo version check ---" | tee -a "$LOG"
PL_FULL=$(echo "$VER_OUT" | grep -oP 'libplacebo version: v\K[0-9]+\.[0-9]+\.[0-9]+' || echo "0.0.0")
ver_cmp() { # returns 0 if $1 >= $2 (numeric dotted)
  local a b; a=$(echo "$1" | awk -F. '{printf "%d%03d%03d",$1,$2,$3}')
  b=$(echo "$2" | awk -F. '{printf "%d%03d%03d",$1,$2,$3}')
  [ "$a" -ge "$b" ]
}
if ver_cmp "$PL_FULL" "7.370.0"; then
  echo "PASS: libplacebo v$PL_FULL (>= 7.370 / PL_API_VER >= 371 for DoVi FEL)" | tee -a "$LOG"
  PASS=$((PASS+1))
else
  echo "FAIL: libplacebo v$PL_FULL (< 7.370, DoVi P7 FEL NOT available)" | tee -a "$LOG"
  FAIL=$((FAIL+1))
fi

# 9. Check mpv.conf compatibility
echo "--- Config compatibility check ---" | tee -a "$LOG"
if [ -f "mpv.conf" ]; then
  if grep -qiE "gpu-next|d3d11|wasapi|dolbyvision|enhancement-layer" mpv.conf; then
    echo "PASS: mpv.conf has gpu-next/d3d11/wasapi/DoVi config" | tee -a "$LOG"
    PASS=$((PASS+1))
  else
    echo "WARN: mpv.conf present but missing key features" | tee -a "$LOG"
  fi
else
  echo "WARN: mpv.conf not found" | tee -a "$LOG"
fi

# 10. AI-lib pollution guard: no ggml/whisper/llama artifacts may ship
echo "--- AI-lib pollution check ---" | tee -a "$LOG"
JUNK=$(ls | grep -iE 'ggml|whisper|llama' || true)
if [ -z "$JUNK" ]; then
  echo "PASS: no ggml/whisper/llama artifacts in bin" | tee -a "$LOG"
  PASS=$((PASS+1))
else
  echo "FAIL: AI-lib artifacts present:" | tee -a "$LOG"
  echo "$JUNK" | tee -a "$LOG"
  FAIL=$((FAIL+1))
fi

echo "" | tee -a "$LOG"
echo "=== Smoke test results: $PASS passed, $FAIL failed ===" | tee -a "$LOG"

if [ "$FAIL" -gt 0 ]; then
  echo "SMOKE TEST FAILED" | tee -a "$LOG"
  exit 1
fi
echo "SMOKE TEST PASSED" | tee -a "$LOG"
