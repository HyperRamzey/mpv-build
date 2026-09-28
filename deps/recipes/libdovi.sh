# libdovi — quietvoid/dovi_tool dolby_vision crate (cargo-c staticlib) [BEST-EFFORT]
# NOTE: crate dir renamed libdovi/ -> dolby_vision/ upstream; cargo-c builds
# header + pkgconfig into dist/ automatically.
GIT_URL="https://github.com/quietvoid/dovi_tool"
# Pinned to the mainline by name, not left to origin/HEAD: this crate is wanted
# on the newest dolby_vision every run (mpv DoVi P7 FEL depends on it), and an
# upstream rename must stop the build with a message instead of quietly moving
# the pin. dovi_tool's mainline is `main`; there is no `master`.
GIT_BRANCH="main"
GIT_SUBMODULES=0
BUILD() {
	local d="$SRC_ROOT/$NAME/dolby_vision"
	[[ -d "$d" ]] || d="$SRC_ROOT/$NAME/libdovi"   # pre-rename layout fallback
	[[ -f "$d/Cargo.toml" ]] || { echo "dovi: crate dir not found" >>"$LOGF"; return 1; }
	( cd "$d" && CARGO_TARGET_DIR="$BUILD_DIR/$NAME" cargo cinstall --release \
		--prefix "$PREFIX" ) > >(tee -a "$LOGF") 2>&1
	[[ -f "$PREFIX/lib/pkgconfig/dovi.pc" ]] || { echo "dovi: pc missing" >>"$LOGF"; return 1; }
}
BEST_EFFORT=1
