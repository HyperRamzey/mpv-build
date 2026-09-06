# dav1d — videolan (meson + nasm)
GIT_URL="https://code.videolan.org/videolan/dav1d.git"
BUILD() {
	meson_driver "$SRC_ROOT/$NAME" "$BUILD_DIR/$NAME" \
		-Ddefault_library=static -Denable_tools=false -Denable_tests=false \
		-Denable_examples=false -Denable_docs=false
}
