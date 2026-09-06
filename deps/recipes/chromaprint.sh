# chromaprint — acoustid/chromaprint (cmake) AcoustID fingerprinting
GIT_URL="https://github.com/acoustid/chromaprint"
BUILD() {
	cmake_driver "$SRC_ROOT/$NAME" "$BUILD_DIR/$NAME" \
		-DBUILD_SHARED_LIBS=OFF -DBUILD_TOOLS=OFF -DBUILD_TESTS=OFF \
		-DCMAKE_BUILD_TYPE=Release
}
