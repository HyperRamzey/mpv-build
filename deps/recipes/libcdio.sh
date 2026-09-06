# libcdio — savannah/libcdio (autotools, in-source) CD-ROM access
GIT_URL="https://git.savannah.gnu.org/git/libcdio.git"
BUILD() {
	# MAKEINFO=true: git checkouts lack generated doc/version.texi (no-op info build).
	# release-2.1.1: man pages only generate in maintainer mode, so disable all
	# CLI tools (we only need the libs); drops previously-unrecognized flags too.
	# --host=x86_64-w64-mingw32: under MSYS2 config.guess reports
	# x86_64-pc-cygwin, which takes the cygwin branch and never runs
	# AC_CHECK_HEADERS(windows.h); nrg.c's _WIN32 code path then
	# compiles without windows.h. Forcing the mingw host selects the
	# mingw*) branch (CC stays clang via autotools_driver).
	autotools_driver "$SRC_ROOT/$NAME" \
		--host=x86_64-w64-mingw32 \
		--disable-cxx --without-cd-drive --without-cd-info \
		--without-cd-read --without-iso-info --without-iso-read \
		--disable-example-progs --disable-joliet \
		MAKEINFO=true
}
