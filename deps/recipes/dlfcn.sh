# dlfcn-win32 — dlfcn-win32/dlfcn-win32 (configure+make; dlopen API for Windows)
GIT_URL="https://github.com/dlfcn-win32/dlfcn-win32"
BUILD() {
	local d="$SRC_ROOT/$NAME"
	( cd "$d" && ./configure --prefix="$PREFIX" --disable-shared --enable-static \
		--cc="$CC" ) > >(tee -a "$LOGF") 2>&1 || \
		{ echo "dlfcn configure FAILED" >>"$LOGF"; return 1; }
	make -C "$d" -j"${JOBS:-14}" >>"$LOGF" 2>&1 || { echo "dlfcn make FAILED" >>"$LOGF"; return 1; }
	make -C "$d" install >>"$LOGF" 2>&1 || { echo "dlfcn install FAILED" >>"$LOGF"; return 1; }
}
