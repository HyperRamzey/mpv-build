# openh264 — cisco (meson + nasm)
GIT_URL="https://github.com/cisco/openh264"
BUILD() {
	meson_driver "$SRC_ROOT/$NAME" "$BUILD_DIR/$NAME" \
		-Ddefault_library=static -Dtests=disabled
}
