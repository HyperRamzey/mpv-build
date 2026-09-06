# mujs — ccxvii/mujs (Makefile, static + pc); repo moved to codeberg
# CLI tools need readline; we build the lib via its pc/static targets only.
GIT_URL="https://codeberg.org/ccxvii/mujs"
BUILD() {
	local d="$SRC_ROOT/$NAME"
	make -C "$d" -j"${JOBS:-14}" build/release/libmujs.a build/release/mujs.pc >>"$LOGF" 2>&1 || \
		{ echo "mujs build FAILED" >>"$LOGF"; return 1; }
	install -Dm644 "$d/build/release/libmujs.a" "$PREFIX/lib/libmujs.a" >>"$LOGF" 2>&1
	install -Dm644 "$d/build/release/mujs.pc" "$PREFIX/lib/pkgconfig/mujs.pc" >>"$LOGF" 2>&1
	sed -i "s|^prefix=.*|prefix=$PREFIX|" "$PREFIX/lib/pkgconfig/mujs.pc" 2>>"$LOGF" || true
	install -Dm644 "$d/mujs.h" "$PREFIX/include/mujs.h" >>"$LOGF" 2>&1
	[[ -f "$PREFIX/lib/libmujs.a" ]] || { echo "mujs: libmujs.a missing" >>"$LOGF"; return 1; }
}
