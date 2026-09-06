# libsoxr — chirlu/soxr (cmake, static; built-in PFFFT, no fftw)
GIT_URL="https://github.com/chirlu/soxr"
BUILD() {
	cmake_driver "$SRC_ROOT/$NAME" "$BUILD_DIR/$NAME" \
		-DWITH_CR32=ON -DWITH_CR64=ON -DWITH_VR32=ON \
		-DBUILD_TESTS=OFF -DBUILD_EXAMPLES=OFF -DBUILD_SHARED_LIBS=OFF -DWITH_OPENMP=OFF
}
