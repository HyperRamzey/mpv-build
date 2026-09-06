# vid.stab — georgmartius/vid.stab (cmake; no OpenMP)
GIT_URL="https://github.com/georgmartius/vid.stab"
BUILD() {
	cmake_driver "$SRC_ROOT/$NAME" "$BUILD_DIR/$NAME" \
		-DUSE_OMP=OFF -DBUILD_TESTING=OFF
}
