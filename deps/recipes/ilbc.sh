# libilbc — TimothyGu/libilbc (cmake static; abseil-cpp submodule required)
GIT_URL="https://github.com/TimothyGu/libilbc"
GIT_SUBMODULES=1
BUILD() { cmake_driver "$SRC_ROOT/$NAME" "$BUILD_DIR/$NAME"; }
