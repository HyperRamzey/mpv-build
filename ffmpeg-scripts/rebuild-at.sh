#!/bin/bash
# rebuild-ffmpeg-at.sh — rebuild local FFmpeg zn2/11700/3050 with aac_at
exec > /g/media-build/ffmpeg-build/rebuild-at.log 2>&1
echo "REBUILD_AT_START $(date)"
for t in zn2 11700 3050; do
	echo "=== ffmpeg $t ==="
	bash "/g/media-build/ffmpeg-build/build-$t.sh"
	echo "FFMPEG_${t}_EXIT=$?"
done
echo "REBUILD_AT_END $(date)"
