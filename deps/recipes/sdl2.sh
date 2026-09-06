# SDL2 — libsdl-org/SDL (cmake; STATIC archive for mpv sdl2-audio/gamepad +
# ffplay). Static-first policy: -lSDL2 resolves to libSDL2.a and neither mpv
# nor ffmpeg ships a SDL2.dll anymore. main branch is SDL3 now; SDL2 lives
# on release-2.32.x
GIT_URL="https://github.com/libsdl-org/SDL"
GIT_BRANCH="release-2.32.x"
BUILD() {
	cmake_driver "$SRC_ROOT/$NAME" "$BUILD_DIR/$NAME" \
		-DSDL_SHARED=OFF -DSDL_STATIC=ON -DSDL_TESTS=OFF -DSDL_EXAMPLES=OFF \
		-DSDL_DISABLE_INSTALL_DOCS=ON -DSDL_WERROR=OFF
	# static-first house style: normalize pc so -lSDL2 picks the .a
	[[ -f "$PREFIX/lib/pkgconfig/sdl2.pc" ]] && \
		sed -i "s|^prefix=.*|prefix=$PREFIX|; s|^libdir=.*|libdir=\${prefix}/lib|" \
		"$PREFIX/lib/pkgconfig/sdl2.pc"
	[[ -f "$PREFIX/lib/pkgconfig/sdl2.pc" ]] || { echo "sdl2.pc missing" >>"$LOGF"; return 1; }
}
