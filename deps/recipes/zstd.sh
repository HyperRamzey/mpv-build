# zstd — facebook/zstd (cmake via build/cmake, static)
GIT_URL="https://github.com/facebook/zstd"
GIT_BRANCH="dev"
BUILD() {
	NO_CXX=1	# pure-C project; CXX flag probes break its flag module
	cmake_driver "$SRC_ROOT/$NAME/build/cmake" "$BUILD_DIR/$NAME" \
		-DZSTD_BUILD_PROGRAMS=OFF -DZSTD_BUILD_CONTRIB=OFF -DZSTD_BUILD_TESTS=OFF \
		-DZSTD_BUILD_SHARED=OFF -DZSTD_BUILD_STATIC=ON
}
