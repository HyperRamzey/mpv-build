# theora — xiph/theora (autotools, needs ogg+vorbis)
GIT_URL="https://github.com/xiph/theora"
BUILD() { autotools_driver "$SRC_ROOT/$NAME" --with-ogg="$PREFIX" --disable-spec --disable-doc --disable-examples; }
