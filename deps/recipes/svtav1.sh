# SVT-AV1 — AOMediaCodec (cmake)
GIT_URL="https://gitlab.com/AOMediaCodec/SVT-AV1.git"
BUILD() {
	cmake_driver "$SRC_ROOT/$NAME" "$BUILD_DIR/$NAME" \
		-DBUILD_APP=OFF -DBUILD_DEC=OFF -DBUILD_SHARED_LIBS=OFF
}
