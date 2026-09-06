# opus — xiph (cmake preferred on mingw)
GIT_URL="https://github.com/xiph/opus"
BUILD() {
	cmake_driver "$SRC_ROOT/$NAME" "$BUILD_DIR/$NAME" \
		-DOPUS_BUILD_SHARED_LIBRARY=OFF -DBUILD_TESTING=OFF \
		-DOPUS_BUILD_PROGRAMS=OFF -DOPUS_ENABLE_FLOAT_API=ON
}
