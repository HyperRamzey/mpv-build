# libass — libass/libass (meson, static; freetype/fribidi/harfbuzz are hard deps)
GIT_URL="https://github.com/libass/libass"
BUILD() {
	meson_driver "$SRC_ROOT/$NAME" "$BUILD_DIR/$NAME" \
		-Ddefault_library=static -Dtest=disabled -Dcompare=disabled \
		-Dprofile=disabled -Dfuzz=disabled -Dcheckasm=disabled -Dasm=enabled \
		-Dfontconfig=enabled -Ddirectwrite=enabled -Dcoretext=disabled
}
