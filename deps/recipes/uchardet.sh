# uchardet — BYVoid/uchardet (cmake, static)
GIT_URL="https://github.com/BYVoid/uchardet"
BUILD() {
	cmake_driver "$SRC_ROOT/$NAME" "$BUILD_DIR/$NAME" \
		-DBUILD_SHARED_LIBS=OFF -DBUILD_BINARY=OFF
}
