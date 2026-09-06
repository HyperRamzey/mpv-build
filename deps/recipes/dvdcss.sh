# libdvdcss — videolan (meson)
GIT_URL="https://code.videolan.org/videolan/libdvdcss.git"
BUILD() {
	meson_driver "$SRC_ROOT/$NAME" "$BUILD_DIR/$NAME" \
		-Ddefault_library=static -Denable_docs=false -Denable_examples=false
}
