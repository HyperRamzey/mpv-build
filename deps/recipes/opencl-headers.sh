# OpenCL-Headers — KhronosGroup (cmake install only)
GIT_URL="https://github.com/KhronosGroup/OpenCL-Headers"
BUILD() { cmake_driver "$SRC_ROOT/$NAME" "$BUILD_DIR/$NAME" -DBUILD_TESTING=OFF; }
