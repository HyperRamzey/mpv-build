# wat4ff — AudioToolbox wrapper for Windows (chrdev/wat4ff, 0BSD).
# Lets FFmpeg use Apple's CoreAudio AAC encoder (aac_at) on Windows:
# headers + libwat4ff.a + wat4ff_ld linker wrapper that rewrites
# "-framework AudioToolbox" into "-lwat4ff" (lazy-loads Apple's DLLs).
# RUNTIME: needs Apple Application Support DLLs (iTunes install, or the
# QTfiles64 set next to ffmpeg.exe). The DLLs are Apple property and are
# NOT shipped in our releases.
GIT_URL="https://github.com/chrdev/wat4ff.git"
BUILD() {
	cmake_driver "$SRC_ROOT/$NAME" "$BUILD_DIR/$NAME"
	# wrapper script lands in the prefix root; keep it there (ffmpeg scripts
	# reference $DEPS/wat4ff_ld)
	[[ -f "$PREFIX/wat4ff_ld" ]] || { echo "wat4ff_ld missing" >>"$LOGF"; return 1; }
}
