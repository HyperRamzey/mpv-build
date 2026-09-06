# quirc — dlbeer/quirc (no build system; hand-rolled static lib)
GIT_URL="https://github.com/dlbeer/quirc"
BUILD() {
	local S="$SRC_ROOT/$NAME" B="$BUILD_DIR/$NAME"
	mkdir -p "$B"
	for f in decode identify version_db quirc; do
		$CC $CFLAGS -I"$S/lib" -c "$S/lib/$f.c" -o "$B/$f.o" || return 1
	done
	mkdir -p "$PREFIX/lib/pkgconfig" "$PREFIX/include/quirc"
	ar rcs "$PREFIX/lib/libquirc.a" "$B"/*.o || return 1
	cp "$S/lib/quirc.h" "$S/lib/quirc_internal.h" "$PREFIX/include/quirc/"
	cat > "$PREFIX/lib/pkgconfig/quirc.pc" << PCF
prefix=$PREFIX
libdir=\${prefix}/lib
includedir=\${prefix}/include

Name: quirc
Description: QR code detection library
Version: 1.2.0
Libs: -L\${libdir} -lquirc
Cflags: -I\${includedir}/quirc
PCF
}
