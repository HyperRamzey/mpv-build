#!/bin/bash
# status.sh — one-glance deps build progress
L=/g/media-build/deps-build/logs/build-deps-master.log
echo "=== last events ==="
grep -E "OK |FATAL|WARN|TARGET" "$L" | tail -6
echo "=== stamps ==="
for t in zn3 zn2 11700 3050 14600; do
  printf "%-7s %2d/45\n" "$t" "$(ls /g/media-build/deps-build/src/*/.built-$t 2>/dev/null | wc -l)"
done