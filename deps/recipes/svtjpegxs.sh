# SVT-JPEG-XS — OpenVisualCloud/SVT-JPEG-XS (cmake+nasm) JPEG-XS codec
GIT_URL="https://github.com/OpenVisualCloud/SVT-JPEG-XS"
BUILD() {
	cmake_driver "$SRC_ROOT/$NAME" "$BUILD_DIR/$NAME" \
		-DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=OFF -DBUILD_APPS=OFF \
		-DENABLE_NASM=ON
}
