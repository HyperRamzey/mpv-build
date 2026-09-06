# libcdio-paranoia — rocky/libcdio-paranoia (autotools, in-source) CDDA extraction
GIT_URL="https://github.com/rocky/libcdio-paranoia"
BUILD() {
	# autoconf 2.72's AC_PROG_CC bakes -std=gnu23 into CC; the bundled K&R
	# getopt.h ("extern int getopt();") is invalid in C23. Last -std wins on
	# the command line, so force gnu17 via CFLAGS.
	# --host=x86_64-w64-mingw32: same config.guess->cygwin problem as
	# libcdio (mingw*) branch with AC_CHECK_HEADERS(windows.h) skipped).
	CFLAGS="$CFLAGS -std=gnu17" autotools_driver "$SRC_ROOT/$NAME" \
		--host=x86_64-w64-mingw32 \
		--disable-example-progs --with-libcdio-prefix="$PREFIX"
}
