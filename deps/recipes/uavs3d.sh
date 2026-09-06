# uavs3d — uavs3/uavs3d (cmake) AVS3-P2 decoder
GIT_URL="https://github.com/uavs3/uavs3d"
BUILD() {
	cmake_driver "$SRC_ROOT/$NAME" "$BUILD_DIR/$NAME" \
		-DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=OFF -DBUILD_APP=OFF
}
