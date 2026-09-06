# gavl — gmerlin/gavl (autotools from release tarball; required by frei0r)
# MSYS2's 64-bit cpu-detect patch applied (32-bit inline asm breaks x86_64).
SRC_URL="https://downloads.sourceforge.net/sourceforge/gmerlin/gavl-1.4.0.tar.gz"
BUILD() {
	local d="$SRC_ROOT/$NAME"
	patch -p1 -d "$d" --quiet < "$HERE/patches/gavl-64bit.patch" 2>>"$LOGF" \
		|| log "gavl patch: already applied (continuing)"
	# src/fill_test.c misses <string.h> (implicit memset, C99 error)
	sed -i '1i #include <string.h>' "$d/src/fill_test.c" 2>>"$LOGF" || true
	autotools_driver "$d" --without-doxygen --disable-ft --disable-x11
}
