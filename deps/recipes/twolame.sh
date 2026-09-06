# twolame — njh/twolame (autotools, needs sndfile only for tests)
GIT_URL="https://github.com/njh/twolame"
BUILD() {
	# git tree lacks generated manpage; stub it so doc subdir builds
	mkdir -p "$SRC_ROOT/$NAME/doc" && touch "$SRC_ROOT/$NAME/doc/twolame.1"
	autotools_driver "$SRC_ROOT/$NAME" --disable-sndfile
}
