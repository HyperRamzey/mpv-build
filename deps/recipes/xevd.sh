# xevd — mpeg5/xevd (cmake) MPEG-5 EVC baseline/main decoder
GIT_URL="https://github.com/mpeg5/xevd"
BUILD() {
	cmake_driver "$SRC_ROOT/$NAME" "$BUILD_DIR/$NAME" \
		-DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=OFF
}
