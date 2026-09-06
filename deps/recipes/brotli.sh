# brotli — google/brotli (cmake, static)
GIT_URL="https://github.com/google/brotli"
BUILD() {
	cmake_driver "$SRC_ROOT/$NAME" "$BUILD_DIR/$NAME" \
		-DBROTLI_BUNDLED_MODES=ON -DBROTLI_BUILD_TESTS=OFF -DBROTLI_BUILD_DOCUMENTATION=OFF
}
