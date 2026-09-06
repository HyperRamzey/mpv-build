# speex — xiph (autotools, needs speexdsp+ogg)
GIT_URL="https://github.com/xiph/speex"
BUILD() { autotools_driver "$SRC_ROOT/$NAME" --with-ogg="$PREFIX" --with-speexdsp="$PREFIX" --disable-binaries; }
