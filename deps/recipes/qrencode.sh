# libqrencode — fukuchi/libqrencode (cmake) QR code generation filter
GIT_URL="https://github.com/fukuchi/libqrencode"
BUILD() {
	cmake_driver "$SRC_ROOT/$NAME" "$BUILD_DIR/$NAME" \
		-DBUILD_SHARED_LIBS=OFF -DBUILD_TOOLS=OFF -DBUILD_TESTS=OFF \
		-DWITH_TOOLS=OFF -DWITH_TESTS=OFF -DWITH_MAN=OFF \
		-DCMAKE_BUILD_TYPE=Release
}
