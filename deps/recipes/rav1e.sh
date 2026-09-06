# rav1e — xiph/rav1e (cargo-c staticlib + proper .pc/header) [BEST-EFFORT]
GIT_URL="https://github.com/xiph/rav1e"
BUILD() {
	local d="$SRC_ROOT/$NAME"
	( cd "$d" && CARGO_TARGET_DIR="$BUILD_DIR/$NAME" \
		cargo cinstall --release --prefix "$PREFIX" ) > >(tee -a "$LOGF") 2>&1
}
BEST_EFFORT=1
