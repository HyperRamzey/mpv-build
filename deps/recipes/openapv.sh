# openapv — AcademySoftwareFoundation/openapv (cmake) APV professional codec
# PINNED to v0.3.0.0: master's 83937c6 ("per-instance custom memory allocator")
# changed oapvm_create() to take a cdesc arg, breaking FFmpeg's liboapvenc.c.
# Unpin once FFmpeg master adapts to the new API.
GIT_URL="https://github.com/AcademySoftwareFoundation/openapv"
GIT_BRANCH="v0.3.0.0"
BUILD() {
	cmake_driver "$SRC_ROOT/$NAME" "$BUILD_DIR/$NAME" \
		-DOAPV_BUILD_APPS=OFF -DOAPV_BUILD_SHARED=OFF \
		-DCMAKE_BUILD_TYPE=Release
}
