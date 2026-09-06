# speexdsp — xiph (autotools; fixed-point off, float SIMD ok)
GIT_URL="https://github.com/xiph/speexdsp"
BUILD() { autotools_driver "$SRC_ROOT/$NAME" --with-ogg="$PREFIX" --disable-binaries; }
