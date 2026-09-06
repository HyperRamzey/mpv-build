# nv-codec-headers (ffnvcodec) — FFmpeg mirror (make install, headers only)
GIT_URL="https://github.com/FFmpeg/nv-codec-headers"
BUILD() {
	local d="$SRC_ROOT/$NAME"
	make -C "$d" install PREFIX="$PREFIX" >>"$LOGF" 2>&1
}
