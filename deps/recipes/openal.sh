# openal-soft — kcat/openal-soft (cmake, static; no backend deps beyond system audio)
GIT_URL="https://github.com/kcat/openal-soft"
BUILD() {
	cmake_driver "$SRC_ROOT/$NAME" "$BUILD_DIR/$NAME" \
		-DLIBTYPE=STATIC -DALSOFT_EXAMPLES=OFF -DALSOFT_TESTS=OFF -DALSOFT_UTILS=OFF \
		-DALSOFT_NO_CONFIG_UTIL=ON -DALSOFT_REQUIRE_WASAPI=ON -DALSOFT_REQUIRE_DSOUND=OFF \
		-DALSOFT_REQUIRE_WINMM=OFF -DALSOFT_EMBED_HRTF_DATA=ON
}
