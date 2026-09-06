# libvpx — webmproject mirror (configure-based, nasm)
GIT_URL="https://github.com/webmproject/libvpx"
BUILD() {
	local d="$SRC_ROOT/$NAME"
	( cd "$d" && ./configure --prefix="$PREFIX" --target=x86_64-win64-gcc \
		--disable-examples --disable-tools --disable-docs --disable-unit-tests \
		--enable-vp9-highbitdepth --enable-pic --as=nasm \
		--extra-cflags="$CFLAGS" --extra-cxxflags="$CXXFLAGS" ) > >(tee -a "$LOGF") 2>&1
	# HAVE_GNU_STRIP=no: v1.17.0 strips release archives, but with thin-LTO
	# the .o members are LLVM bitcode and llvm-strip rejects them; stripping
	# happens at the final LTO link instead (--gc-sections)
	make -C "$d" -j"${JOBS:-14}" HAVE_GNU_STRIP=no >>"$LOGF" 2>&1
	make -C "$d" install >>"$LOGF" 2>&1
}
