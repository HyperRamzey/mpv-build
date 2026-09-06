# openssl 3.x — static, mingw64 target, our OPT flags appended
GIT_URL="https://github.com/openssl/openssl"
BUILD() {
	local d="$SRC_ROOT/$NAME" bd="$BUILD_DIR/$NAME"
	( cd "$d" && perl Configure mingw64 no-shared no-docs no-tests \
		--prefix="$PREFIX" --libdir=lib \
		enable-camellia enable-idea enable-mdc2 enable-rc5 enable-rfc3779 \
		"$OPT" ) > >(tee -a "$LOGF") 2>&1
	make -C "$d" -j"${JOBS:-14}" >>"$LOGF" 2>&1
	make -C "$d" install_sw install_ssldirs >>"$LOGF" 2>&1
}
