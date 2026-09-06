# LuaJIT 2.1 — LuaJIT/LuaJIT (Makefile, static lib + host tools)
GIT_URL="https://github.com/LuaJIT/LuaJIT"
GIT_BRANCH="v2.1"
BUILD() {
	local d="$SRC_ROOT/$NAME"
	make -C "$d/src" -j"${JOBS:-14}" BUILDMODE=static CCDEBUG=-g \
		CC="$CC" STATIC_CCFLAGS="$CFLAGS" DYNAMIC_CCFLAGS="$CFLAGS" \
		TARGET_LDFLAGS="$LDFLAGS" XCFLAGS="-DLUAJIT_ENABLE_GC64" \
		>>"$LOGF" 2>&1
	make -C "$d" install PREFIX="$PREFIX" >>"$LOGF" 2>&1
	# luajit.pc ships with relative prefix fixups; normalize
	sed -i "s|^prefix=.*|prefix=$PREFIX|" "$PREFIX/lib/pkgconfig/luajit.pc" 2>>"$LOGF" || true
}
