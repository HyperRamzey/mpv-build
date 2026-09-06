# libssh — gitlab mirror (cmake; OpenSSL backend)
# pc fixes: LIBSSH_STATIC cflag (headers dllimport otherwise) + static deps
GIT_URL="https://gitlab.com/libssh/libssh-mirror.git"
BUILD() {
	cmake_driver "$SRC_ROOT/$NAME" "$BUILD_DIR/$NAME" \
		-DWITH_STATIC_LIB=ON -DBUILD_SHARED_LIBS=OFF -DWITH_EXAMPLES=OFF \
		-DWITH_SERVER=OFF -DWITH_GSSAPI=OFF -DWITH_ZLIB=OFF -DUNIT_TESTING=OFF \
		-DOPENSSL_ROOT_DIR="$PREFIX"
	local pc="$PREFIX/lib/pkgconfig/libssh.pc"
	[[ -f "$pc" ]] || { echo "libssh.pc missing" >>"$LOGF"; return 1; }
	grep -q LIBSSH_STATIC "$pc" || sed -i "s|^Cflags:|Cflags: -DLIBSSH_STATIC|" "$pc"
	grep -q -- "-lssl" "$pc" || echo "Libs.private: -lssl -lcrypto -lws2_32 -lcrypt32 -lbcrypt -ladvapi32 -luser32 -luuid -liphlpapi -lpthread" >> "$pc"
}
