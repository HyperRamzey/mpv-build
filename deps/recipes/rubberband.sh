# rubberband — Breakfastquay/rubberband (meson; built-in FFT + BQ resampler)
GIT_URL="https://github.com/breakfastquay/rubberband"
BUILD() {
	meson_driver "$SRC_ROOT/$NAME" "$BUILD_DIR/$NAME" \
		-Ddefault_library=static \
		-Dfft=builtin -Dresampler=builtin \
		-Dladspa=disabled -Dlv2=disabled -Dvamp=disabled -Djni=disabled \
		-Dcmdline=disabled -Dtests=disabled
}
