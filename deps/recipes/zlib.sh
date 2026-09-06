# zlib — madler/zlib, native configure (static), no patches needed
GIT_URL="https://github.com/madler/zlib"
BUILD() {
	local d="$SRC_ROOT/$NAME"
	( cd "$d" && ./configure --static --prefix="$PREFIX" ) > >(tee -a "$LOGF") 2>&1
	make -C "$d" -j"${JOBS:-14}" >>"$LOGF" 2>&1
	make -C "$d" install >>"$LOGF" 2>&1
}
