# libbluray — videolan (meson; xml2 metadata + freetype/fontconfig text subs)
GIT_URL="https://code.videolan.org/videolan/libbluray.git"
BUILD() {
	meson_driver "$SRC_ROOT/$NAME" "$BUILD_DIR/$NAME" \
		-Ddefault_library=static -Denable_docs=false -Denable_tools=false \
		-Denable_devtools=false -Denable_examples=false -Dbdj_jar=disabled
}
