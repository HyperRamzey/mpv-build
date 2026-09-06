# lcms2 — mm2/Little-CMS (meson, static)
GIT_URL="https://github.com/mm2/Little-CMS"
BUILD() {
	meson_driver "$SRC_ROOT/$NAME" "$BUILD_DIR/$NAME" \
		-Ddefault_library=static -Dutils=false -Dfastfloat=true
}
