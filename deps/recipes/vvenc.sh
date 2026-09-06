# vvenc — fraunhoferhhi/vvenc (cmake) VVC/H.266 encoder
GIT_URL="https://github.com/fraunhoferhhi/vvenc"
BUILD() {
	cmake_driver "$SRC_ROOT/$NAME" "$BUILD_DIR/$NAME" \
		-DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=OFF \
		-DVVENC_ENABLE_WERROR=OFF -DVVENC_BUILD_APP=OFF \
		-DVVENC_ENABLE_X86_SIMD=ON
}
