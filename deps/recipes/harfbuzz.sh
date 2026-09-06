# harfbuzz — harfbuzz/harfbuzz (meson, static, links our freetype)
GIT_URL="https://github.com/harfbuzz/harfbuzz"
BUILD() {
	meson_driver "$SRC_ROOT/$NAME" "$BUILD_DIR/$NAME" \
		-Ddefault_library=static -Dfreetype=enabled -Dglib=disabled \
		-Dgobject=disabled -Dcairo=disabled -Dicu=disabled \
		-Dtests=disabled -Ddocs=disabled -Dbenchmark=disabled -Dutilities=disabled
}
