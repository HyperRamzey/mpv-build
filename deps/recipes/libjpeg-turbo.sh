# libjpeg-turbo — cmake+nasm, static, JPEG8 ABI
GIT_URL="https://github.com/libjpeg-turbo/libjpeg-turbo"
BUILD() {
	cmake_driver "$SRC_ROOT/$NAME" "$BUILD_DIR/$NAME" \
		-DWITH_JPEG8=ON -DENABLE_SHARED=OFF -DENABLE_STATIC=ON \
		-DWITH_TURBOJPEG=OFF -DFORCE_INLINE=ON
}
