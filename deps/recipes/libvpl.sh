# oneVPL (libvpl) — oneapi-src (cmake static dispatcher)
GIT_URL="https://github.com/oneapi-src/oneVPL"
BUILD() {
	cmake_driver "$SRC_ROOT/$NAME" "$BUILD_DIR/$NAME" \
		-DBUILD_SHARED_LIBS=OFF -DBUILD_DISPATCHER=ON -DBUILD_DEV=ON \
		-DINSTALL_DEV=ON -DBUILD_TOOLS=OFF -DBUILD_TESTS=OFF
	# vpl.pc uses ${pcfiledir}/../.. which pkgconf mangles on Windows paths
	[[ -f "$PREFIX/lib/pkgconfig/vpl.pc" ]] && \
		sed -i "s|^prefix=.*|prefix=$PREFIX|; s|^libdir=.*|libdir=\${prefix}/lib|; s|^includedir=.*|includedir=\${prefix}/include|" \
		"$PREFIX/lib/pkgconfig/vpl.pc" && \
		sed -i "s|^Libs.private:.*|Libs.private: -lc++ -lunwind|" "$PREFIX/lib/pkgconfig/vpl.pc"
}
