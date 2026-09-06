# bzip2 — bzip2/bzip2 (cmake, static) [REQUIRED]
# Self-compiled per the no-MSYS2-media policy: ffmpeg --enable-bzlib and
# libarchive link -lbz2; with this recipe the token resolves to OUR static
# archive in deps-<t>/lib instead of MSYS2's shared libbz2-1.dll fallback.
# NOTE: upstream moved from sourceware to its own GitLab group
# (gitlab.com/bzip2/bzip2); the old sourceware path HANGS on clone.
GIT_URL="https://gitlab.com/bzip2/bzip2"
GIT_SUBMODULES=0
BUILD() {
	# ENABLE_LIB_ONLY: no bzip2.exe/bunzip.exe/... apps in the prefix bin
	cmake_driver "$SRC_ROOT/$NAME" "$BUILD_DIR/$NAME" \
		-DENABLE_LIB_ONLY=ON -DENABLE_SHARED_LIB=OFF -DENABLE_STATIC_LIB=ON
	# upstream cmake names the archive libbz2_static.a; consumers expect -lbz2
	if [[ -f "$PREFIX/lib/libbz2_static.a" && ! -f "$PREFIX/lib/libbz2.a" ]]; then
		mv "$PREFIX/lib/libbz2_static.a" "$PREFIX/lib/libbz2.a"
	fi
	# upstream bzip2.pc may point at -lbz2_static
	[[ -f "$PREFIX/lib/pkgconfig/bzip2.pc" ]] && \
		sed -i 's/-lbz2_static/-lbz2/' "$PREFIX/lib/pkgconfig/bzip2.pc"
	[[ -f "$PREFIX/lib/libbz2.a" ]] || { echo "libbz2.a missing" >>"$LOGF"; return 1; }
}
