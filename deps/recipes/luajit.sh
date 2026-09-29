# LuaJIT 2.1 - LuaJIT/LuaJIT (Makefile, static lib + host tools)
GIT_URL="https://github.com/LuaJIT/LuaJIT"
GIT_BRANCH="v2.1"
BUILD() {
	local d="$SRC_ROOT/$NAME"
	# CFLAGS is emptied ON PURPOSE, and this is not cosmetic.
	#
	# common.sh exports CFLAGS with the TARGET's -march. luajit's
	# src/Makefile:190 is `ASOPTIONS= $(CCOPT) $(CCWARN) $(XCFLAGS) $(CFLAGS)`,
	# and ASOPTIONS reaches the HOST build through
	# HOST_ACFLAGS= $(CCOPTIONS) $(HOST_XCFLAGS) $(TARGET_ARCH) $(HOST_CFLAGS).
	# So minilua / buildvm / dynasm — tools that must RUN on the build machine
	# — get compiled for the target CPU. On a runner without that ISA they die
	# with SIGILL mid-generation:
	#     make: *** [Makefile:677: host/buildvm_arch.h] Illegal instruction
	# which leaves the prefix without luajit.pc.
	#
	# That is why exactly the two AVX-512 targets failed (11700 rocketlake,
	# x64v4 skylake-avx512) while zn3/zn2/3050/14600/x64v2/x64v3 passed — the
	# same pair that failed on 2026-09-13 and that the mpv -Dlua=luajit path
	# needs. The library itself still gets the target ISA, through the
	# STATIC_CCFLAGS/DYNAMIC_CCFLAGS that are passed below.
	#
	# CC and the flag set are repeated on the install invocation on purpose: the
	# top-level Makefile re-enters `make -C src` and would otherwise fall back
	# to its DEFAULT_CC=gcc, which CLANG64 does not have
	# ("make[1]: gcc: No such file or directory").
	local mk=(
		-j"${JOBS:-14}" BUILDMODE=static CCDEBUG=-g CC="$CC"
		CFLAGS=
		STATIC_CCFLAGS="$CFLAGS" DYNAMIC_CCFLAGS="$CFLAGS"
		TARGET_LDFLAGS="$LDFLAGS" XCFLAGS="-DLUAJIT_ENABLE_GC64"
	)
	make -C "$d/src" "${mk[@]}" >>"$LOGF" 2>&1
	make -C "$d" install PREFIX="$PREFIX" "${mk[@]}" >>"$LOGF" 2>&1
	# luajit.pc ships with relative prefix fixups; normalize
	sed -i "s|^prefix=.*|prefix=$PREFIX|" "$PREFIX/lib/pkgconfig/luajit.pc" 2>>"$LOGF" || true
	# the .pc is what mpv's meson resolves; never report success without it
	[[ -f "$PREFIX/lib/pkgconfig/luajit.pc" ]] || {
		echo "luajit: luajit.pc missing after install — the build-time tools" \
			"probably died on an ISA this build host lacks" >>"$LOGF"
		return 1
	}
}
