# xz/liblzma — tukaani-project/xz (cmake, static)
GIT_URL="https://github.com/tukaani-project/xz"
BUILD() {
	cmake_driver "$SRC_ROOT/$NAME" "$BUILD_DIR/$NAME" \
		-DBUILD_SHARED_LIBS=OFF -DXZ_TOOL_XZ=OFF -DXZ_TOOLS=OFF \
		-DXZ_BUILD_MANPAGES=OFF -DXZ_TOOL_SYMLINKS=OFF -DXZ_TOOL_LZMADECOMPRESS=OFF
}
