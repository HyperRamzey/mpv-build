# xeve — mpeg5/xeve (cmake) MPEG-5 EVC encoder
GIT_URL="https://github.com/mpeg5/xeve"
BUILD() {
	cmake_driver "$SRC_ROOT/$NAME" "$BUILD_DIR/$NAME" \
		-DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=OFF
}
