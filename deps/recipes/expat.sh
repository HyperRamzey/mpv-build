# expat — libexpat/libexpat (cmake, static)
GIT_URL="https://github.com/libexpat/libexpat"
GIT_BRANCH="master"
BUILD() {
	cmake_driver "$SRC_ROOT/$NAME/expat" "$BUILD_DIR/$NAME" \
		-DEXPAT_BUILD_EXAMPLES=OFF -DEXPAT_BUILD_TESTS=OFF -DEXPAT_BUILD_DOCS=OFF \
		-DEXPAT_SHARED_LIBS=OFF -DEXPAT_CHAR_TYPE=char
}
