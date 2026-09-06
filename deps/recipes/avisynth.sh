# AviSynthPlus — AviSynth/AviSynthPlus (cmake) headers-only for ffmpeg avisynth demuxer
GIT_URL="https://github.com/AviSynth/AviSynthPlus"
BUILD() {
	cmake_driver "$SRC_ROOT/$NAME" "$BUILD_DIR/$NAME" \
		-DHEADERS_ONLY=ON -DCMAKE_BUILD_TYPE=Release
}
BEST_EFFORT=1
