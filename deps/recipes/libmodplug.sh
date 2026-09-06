# libmodplug — Konstanty/libmodplug (autotools; cmake also present)
GIT_URL="https://github.com/Konstanty/libmodplug"
BUILD() {
	autotools_driver "$SRC_ROOT/$NAME"
	# static lib but header defaults to dllimport; advertise MODPLUG_STATIC
	[[ -f "$PREFIX/lib/pkgconfig/libmodplug.pc" ]] && \
		sed -i "s|^Cflags:|Cflags: -DMODPLUG_STATIC|" "$PREFIX/lib/pkgconfig/libmodplug.pc"
}
