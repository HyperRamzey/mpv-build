# libpng — pnggroup/libpng (cmake, static)
GIT_URL="https://github.com/pnggroup/libpng"
BUILD() {
	cmake_driver "$SRC_ROOT/$NAME" "$BUILD_DIR/$NAME" \
		-DPNG_TESTS=OFF -DPNG_TOOLS=OFF -DPNG_EXECUTABLES=OFF \
		-DPNG_SHARED=OFF -DPNG_STATIC=ON -DSKIP_INSTALL_FILES=OFF
}
