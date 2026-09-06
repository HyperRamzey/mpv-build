# zimg — sekrit-twc/zimg (autotools; graphengine submodule)
GIT_URL="https://github.com/sekrit-twc/zimg"
GIT_SUBMODULES=1
BUILD() { autotools_driver "$SRC_ROOT/$NAME" --disable-testapp; }
