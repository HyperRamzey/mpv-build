# libunibreak — adah1972/libunibreak (autotools, static) [REQUIRED]
# libass.pc Requires libunibreak; without this recipe the token resolves
# against /clang64's shared libunibreak-7.dll fallback. Static-first policy.
GIT_URL="https://github.com/adah1972/libunibreak"
GIT_SUBMODULES=0
BUILD() {
	autotools_driver "$SRC_ROOT/$NAME"
	[[ -f "$PREFIX/lib/libunibreak.a" ]] || { echo "libunibreak.a missing" >>"$LOGF"; return 1; }
}
