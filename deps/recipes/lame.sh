# lame — lameproject/lame (autotools)
GIT_URL="https://github.com/lameproject/lame"
BUILD() { autotools_driver "$SRC_ROOT/$NAME" --disable-decoder --disable-frontend --disable-gtktest; }
