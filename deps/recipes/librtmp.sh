# rtmpdump/librtmp — ShiftMediaProject fork + local OpenSSL-3 patch
# (patches/librtmp-openssl3.patch: opaque DH/HMAC_CTX accessors, generated via
#  patches/make-librtmp-openssl3-patch.sh + extend-librtmp-patch.sh)
GIT_URL="https://github.com/ShiftMediaProject/rtmpdump.git"
BUILD() {
	local d="$SRC_ROOT/$NAME"
	git -C "$d" apply --whitespace=nowarn "$HERE/patches/librtmp-openssl3.patch" \
		2>>"$LOGF" || log "librtmp patch: already applied (continuing)"
	make -C "$d/librtmp" -j"${JOBS:-14}" CC="$CC" CRYPTO=OPEN_SSL OPT="$CFLAGS" \
		XLDFLAGS="$LDFLAGS" SHARED=no prefix="$PREFIX" >>"$LOGF" 2>&1 || \
		{ echo "librtmp make FAILED" >>"$LOGF"; return 1; }
	make -C "$d/librtmp" install CC="$CC" CRYPTO=OPEN_SSL SHARED=no prefix="$PREFIX" >>"$LOGF" 2>&1 || \
		{ echo "librtmp install FAILED" >>"$LOGF"; return 1; }
	# makefile-generated pc lacks static deps
	[[ -f "$PREFIX/lib/pkgconfig/librtmp.pc" ]] && \
		grep -q -- "-lssl" "$PREFIX/lib/pkgconfig/librtmp.pc" || \
		echo "Libs.private: -lssl -lcrypto -lz -lws2_32 -lwinmm -lcrypt32 -lbcrypt -ladvapi32 -luser32 -luuid" >> "$PREFIX/lib/pkgconfig/librtmp.pc"
}
