# libsixel — saitoha/libsixel (autotools; PNG loader off: uses libpng 1.4 API
# removed upstream, and mpv only needs the sixel ENCODER)
# --without-libcurl: configure auto-detects libcurl and, when found
# (MSYS2 /clang64 libcurl), the loader references __imp_curl_* which
# breaks the all-static mpv link (no curl in our stack).
GIT_URL="https://github.com/saitoha/libsixel"
BUILD() {
	autotools_driver "$SRC_ROOT/$NAME" --without-png --disable-sixel2png \
		--without-libcurl
}
