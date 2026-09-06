# libdvdread — videolan (meson; static link against our libdvdcss)
# meson runs `git log` (cwd=build dir) to generate ChangeLog; init a stub repo.
GIT_URL="https://code.videolan.org/videolan/libdvdread.git"
BUILD() {
	git init -q "$BUILD_DIR/$NAME" 2>>"$LOGF" && git -C "$BUILD_DIR/$NAME" -c user.email=d@l -c user.name=d commit -q --allow-empty -m x 2>>"$LOGF" || true
	meson_driver "$SRC_ROOT/$NAME" "$BUILD_DIR/$NAME" \
		-Ddefault_library=static -Denable_docs=false \
		-Dlibdvdcss=enabled -Ddlfcn=builtin
}
