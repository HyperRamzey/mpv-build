# aom — aomedia.googlesource (cmake + perl)
GIT_URL="https://aomedia.googlesource.com/aom"
BUILD() {
	cmake_driver "$SRC_ROOT/$NAME" "$BUILD_DIR/$NAME" \
		-DENABLE_TESTS=OFF -DENABLE_TESTDATA=OFF -DENABLE_DOCS=OFF \
		-DENABLE_EXAMPLES=OFF -DENABLE_TOOLS=OFF \
		-DCONFIG_AV1_HIGHBITDEPTH=1
}
