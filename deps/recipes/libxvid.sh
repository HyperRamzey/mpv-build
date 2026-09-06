# libxvid — ShiftMediaProject mirror (upstream gitlab now auth-walled/discontinued)
# Patches:
#  - libxvid-clang.patch: SYSTEM_INFO block is MSVC-only (clang-win breaks it)
# xvid is C89-era code (typedefs bool); must compile with -std=c89 under clang.
GIT_URL="https://github.com/ShiftMediaProject/xvid.git"
BUILD() {
	local d="$SRC_ROOT/$NAME"
	git -C "$d" apply --whitespace=nowarn "$HERE/patches/libxvid-clang.patch" \
		2>>"$LOGF" || log "xvid patch: already applied (continuing)"
	local b="$d/build/generic"
	# fresh clones only carry configure.in; generate configure (+guess/sub)
	if [[ ! -f "$b/configure" ]]; then
		( cd "$b" && autoreconf -fi ) >>"$LOGF" 2>&1 ||
			{ echo "xvid autoreconf FAILED" >>"$LOGF"; return 1; }
	fi
	( cd "$b" && CFLAGS="$CFLAGS -std=c89 -DWIN32" LDFLAGS="$LDFLAGS" \
		./configure --prefix="$PREFIX" --disable-pthread ) > >(tee -a "$LOGF") 2>&1 || \
		{ echo "xvid configure FAILED" >>"$LOGF"; return 1; }
	make -C "$b" -j"${JOBS:-14}" libxvidcore.a >>"$LOGF" 2>&1 || { echo "xvid make FAILED" >>"$LOGF"; return 1; }
	# make install depends on the (flaky, unneeded) shared lib — install manually
	mkdir -p "$PREFIX/lib" "$PREFIX/include"
	cp "$b/=build/libxvidcore.a" "$PREFIX/lib/" 2>>"$LOGF" \
		|| cp "$b/libxvidcore.a" "$PREFIX/lib/" 2>>"$LOGF" \
		|| { echo "xvid: static lib copy failed" >>"$LOGF"; return 1; }
	cp "$SRC_ROOT/$NAME/src/xvid.h" "$PREFIX/include/" >>"$LOGF" 2>&1
	[[ -f "$PREFIX/lib/libxvidcore.a" ]] || { echo "xvid: static lib missing" >>"$LOGF"; return 1; }
}
