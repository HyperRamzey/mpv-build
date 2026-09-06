# libvorbis — xiph (autotools, needs ogg)
GIT_URL="https://github.com/xiph/vorbis"
BUILD() { autotools_driver "$SRC_ROOT/$NAME" --with-ogg="$PREFIX"; }
