# snappy — google/snappy (cmake C++) compression for Hap/qtrle
GIT_URL="https://github.com/google/snappy"
BUILD() {
	cmake_driver "$SRC_ROOT/$NAME" "$BUILD_DIR/$NAME" \
		-DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=OFF \
		-DSNAPPY_BUILD_TESTS=OFF -DSNAPPY_BUILD_BENCHMARKS=OFF \
		-DSNAPPY_REQUIRE_AVX2=OFF
}
