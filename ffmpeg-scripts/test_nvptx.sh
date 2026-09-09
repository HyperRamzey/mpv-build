#!/bin/bash
export PATH=/clang64/bin:$PATH
SRC=/g/media-build/ffmpeg-build/ffmpeg
cat > /tmp/t.cu <<'EOF'
extern "C" {
    __global__ void hello(unsigned char *data) {}
}
EOF
for a in sm_120 sm_90; do
  if clang -x cuda /tmp/t.cu --cuda-gpu-arch=$a -Xclang -target-feature -Xclang +ptx87 -O2 -std=c++11 -m64 -S -nocudalib -nocudainc --cuda-device-only -Wno-c++11-narrowing -include $SRC/compat/cuda/cuda_runtime.h -o /tmp/t_$a.ptx 2>/tmp/err_$a.txt; then
    echo "$a OK -> $(grep -m1 -E '\.target|\.version' /tmp/t_$a.ptx) / $(grep -m1 '\.target' /tmp/t_$a.ptx)"
  else
    echo "$a FAIL:"; head -3 /tmp/err_$a.txt
  fi
done
