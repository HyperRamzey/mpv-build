# libvpl — oneapi-src/oneVPL (cmake static dispatcher)
# Local patch:
#   patches/libvpl-stralign.patch — the MSVC-only wcscpy_s/wcscat_s shim
#   macros (#if _MSC_VER < 1400) are ALSO active under clang, where
#   _MSC_VER is undefined (0 < 1400): the macro rewrites wcscpy_s()
#   calls MSYS2's stralign.h emits into garbage and breaks the build
#   against mingw-w64 headers. Guard with defined(_MSC_VER) so the shim
#   only exists under real MSVC.
GIT_URL="https://github.com/oneapi-src/oneVPL"
BUILD() {
	local d="$SRC_ROOT/$NAME"
	# reverse-check first: already-applied patch must not double-apply
	if git -C "$d" apply --reverse --check "$HERE/patches/libvpl-stralign.patch" 2>>"$LOGF"; then
		log "patch already applied"
	elif git -C "$d" apply --whitespace=nowarn "$HERE/patches/libvpl-stralign.patch" 2>>"$LOGF"; then
		log "patch applied"
	else
		echo "libvpl patch FAILED to apply (upstream drift?)" >>"$LOGF"
		return 1
	fi
	grep -q "defined(_MSC_VER) && _MSC_VER < 1400" \
		"$d/libvpl/src/windows/mfx_dispatcher_defs.h" 2>>"$LOGF" || \
		{ echo "libvpl patch marker missing — NOT patched" >>"$LOGF"; return 1; }
	cmake_driver "$d" "$BUILD_DIR/$NAME" \
		-DBUILD_SHARED_LIBS=OFF -DBUILD_DISPATCHER=ON -DBUILD_DEV=ON \
		-DINSTALL_DEV=ON -DBUILD_TOOLS=OFF -DBUILD_TESTS=OFF
	# vpl.pc uses ${pcfiledir}/../.. which pkgconf mangles on Windows paths
	[[ -f "$PREFIX/lib/pkgconfig/vpl.pc" ]] && \
		sed -i "s|^prefix=.*|prefix=$PREFIX|; s|^libdir=.*|libdir=\${prefix}/lib|; s|^includedir=.*|includedir=\${prefix}/include|" \
		"$PREFIX/lib/pkgconfig/vpl.pc" && \
		sed -i "s|^Libs.private:.*|Libs.private: -lc++ -lunwind|" "$PREFIX/lib/pkgconfig/vpl.pc"
}
