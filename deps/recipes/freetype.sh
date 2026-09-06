# freetype — freetype/freetype (meson, static; NO harfbuzz here to avoid cycle)
GIT_URL="https://github.com/freetype/freetype"
BUILD() {
	meson_driver "$SRC_ROOT/$NAME" "$BUILD_DIR/$NAME" \
		-Ddefault_library=static -Dzlib=system -Dbzip2=disabled \
		-Dpng=disabled -Dharfbuzz=disabled -Dbrotli=disabled -Dtests=disabled
}
