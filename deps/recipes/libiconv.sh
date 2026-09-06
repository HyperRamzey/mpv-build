# libiconv — GNU (autotools from release tarball; upstream git on savannah is unreachable)
# regen via Makefile.devel needs gperf; tarball ships pregenerated configure
SRC_URL="https://ftp.gnu.org/pub/gnu/libiconv/libiconv-1.19.tar.gz"
BUILD() {
	local d="$SRC_ROOT/$NAME"
	[[ -f "$d/configure" ]] || ( cd "$d" && make -f Makefile.devel all ) >>"$LOGF" 2>&1
	autotools_driver "$d" --enable-extra-encodings --disable-rpath --disable-nls --enable-relocatable
	# manual iconv.pc (upstream ships none)
	cat > "$PREFIX/lib/pkgconfig/iconv.pc" <<EOF
prefix=$PREFIX
exec_prefix=\${prefix}
libdir=\${prefix}/lib
includedir=\${prefix}/include

Name: iconv
Description: Character set conversion library
Version: 1.19
Libs: -L\${libdir} -liconv
Cflags: -I\${includedir}
EOF
}
