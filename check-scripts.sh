#!/bin/bash
# check-scripts.sh — syntax check + broken-continuation detector for build scripts
set -u
SCRIPTS=(
  /g/media-build/mpv-build/build-all.sh /g/media-build/mpv-build/build-zn3.sh /g/media-build/mpv-build/build-zn2.sh /g/media-build/mpv-build/build-11700.sh /g/media-build/mpv-build/build-3050.sh /g/media-build/mpv-build/build-14600.sh /g/media-build/mpv-build/build-x64v2.sh /g/media-build/mpv-build/build-x64v3.sh /g/media-build/mpv-build/build-x64v4.sh
  /g/media-build/mpv-build/build-libplacebo-zn3.sh /g/media-build/mpv-build/build-libplacebo-zn2.sh /g/media-build/mpv-build/build-libplacebo-11700.sh /g/media-build/mpv-build/build-libplacebo-3050.sh /g/media-build/mpv-build/build-libplacebo-14600.sh /g/media-build/mpv-build/build-libplacebo-x64v2.sh /g/media-build/mpv-build/build-libplacebo-x64v3.sh /g/media-build/mpv-build/build-libplacebo-x64v4.sh
  /g/media-build/mpv-build/copydlls.sh /g/media-build/mpv-build/smoke_test.sh
  /g/media-build/ffmpeg-build/build-zn3.sh /g/media-build/ffmpeg-build/build-zn2.sh /g/media-build/ffmpeg-build/build-11700.sh /g/media-build/ffmpeg-build/build-3050.sh /g/media-build/ffmpeg-build/build-14600.sh /g/media-build/ffmpeg-build/build-x64v2.sh /g/media-build/ffmpeg-build/build-x64v3.sh /g/media-build/ffmpeg-build/build-x64v4.sh
  /g/media-build/deps-build/build-deps.sh /g/media-build/deps-build/build-one.sh /g/media-build/deps-build/common.sh /g/media-build/deps-build/pull-all.sh /g/media-build/deps-build/fix-static-pcs.sh /g/media-build/deps-build/sanitize-prefix.sh
)
rc=0
for f in "${SCRIPTS[@]}"; do
  [[ -f $f ]] || {
    echo "MISSING: $f"
    rc=1
    continue
  }
  if ! bash -n "$f" 2>/tmp/synerr; then
    echo "SYNTAX FAIL: $f"
    cat /tmp/synerr
    rc=1
  fi
done
echo "--- bash -n done (rc=$rc) ---"

# Continuation detector: a line that begins (after whitespace) like a continued
# flag/option (--enable/--disable/-D/--with/--prefix= etc.) whose PREVIOUS
# physical line does NOT end with a backslash is a broken continuation.
echo "--- continuation scan ---"
for f in "${SCRIPTS[@]}"; do
  [[ -f $f ]] || continue
  awk '
    NR>1 && $0 ~ /^[ \t]+(--(enable|disable|with|prefix|extra|nvcc|cpu|cc|cxx|host|build|target)|-D[A-Za-z_]|--buildtype|pkg)/ {
      if (prev !~ /\\[ \t\r]*$/) {
        printf "BROKEN-CONTINUATION: %s:%d: %s\n", FILENAME, NR, $0
        bad=1
      }
    }
    { prev=$0 }
    END { }
  ' "$f"
done
echo "--- continuation scan done ---"
exit $rc
