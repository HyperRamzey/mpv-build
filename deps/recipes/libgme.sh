# game-music-emu — libgme (cmake, static)
GIT_URL="https://github.com/libgme/game-music-emu.git"
BUILD() {
	cmake_driver "$SRC_ROOT/$NAME" "$BUILD_DIR/$NAME" \
		-DBUILD_SHARED_LIBS=OFF -DENABLE_UBSAN=OFF
	# cmake-generated pc omits zlib (needed when linking the static lib)
	for pc in "$PREFIX/lib/pkgconfig/libgme.pc" "$PREFIX/lib/pkgconfig/gme.pc"; do
		[[ -f "$pc" ]] || continue
		grep -q zlib "$pc" || echo "Requires: zlib" >> "$pc"
	done
	[[ -f "$PREFIX/lib/libgme.a" ]] || { echo "libgme.a missing" >>"$LOGF"; return 1; }
}
