# liblc3 — google/liblc3 (meson, static)
GIT_URL="https://github.com/google/liblc3"
BUILD() { meson_driver "$SRC_ROOT/$NAME" "$BUILD_DIR/$NAME" -Ddefault_library=static -Dtools=false; }
