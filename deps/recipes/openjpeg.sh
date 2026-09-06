# openjpeg — uclouvain/openjpeg (cmake, static)
GIT_URL="https://github.com/uclouvain/openjpeg"
BUILD() {
	cmake_driver "$SRC_ROOT/$NAME" "$BUILD_DIR/$NAME" \
		-DBUILD_SHARED_LIBS=OFF -DBUILD_STATIC_LIBS=ON \
		-DBUILD_CODEC=OFF -DBUILD_TESTING=OFF
}
