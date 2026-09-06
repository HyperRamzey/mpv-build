# fontconfig — freedesktop (meson; expat backend)
GIT_URL="https://gitlab.freedesktop.org/fontconfig/fontconfig.git"
BUILD() {
	meson_driver "$SRC_ROOT/$NAME" "$BUILD_DIR/$NAME" \
		-Ddefault_library=static -Dtools=disabled -Dtests=disabled \
		-Dcache-build=disabled -Ddoc=disabled -Dnls=disabled \
		-Dxml-backend=expat
}
