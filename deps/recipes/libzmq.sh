# libzmq — zeromq/libzmq (cmake, static)
GIT_URL="https://github.com/zeromq/libzmq"
BUILD() {
	cmake_driver "$SRC_ROOT/$NAME" "$BUILD_DIR/$NAME" \
		-DENABLE_DRAFTS=OFF -DBUILD_TESTS=OFF -DENABLE_CURVE=OFF \
		-DENABLE_WS=OFF -DENABLE_CPACK=OFF -DWITH_LIBSODIUM=OFF \
		-DZMQ_BUILD_TESTS=OFF
}
