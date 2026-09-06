# x264 — videolan (custom configure, nasm asm)
GIT_URL="https://code.videolan.org/videolan/x264.git"
BUILD() {
	local d="$SRC_ROOT/$NAME"
	# x264's configure self-adds -mstack-alignment=64 (clang path), baking an
	# override-stack-alignment=64 module flag into LTO bitcode that clashes
	# with FFmpeg's default-16 objects at the ThinLTO link. Build x264 as
	# plain (non-LTO) objects: its hot paths are hand asm anyway.
	local xcflags="${CFLAGS//-flto=thin/}"; xcflags="${xcflags//-flto/}"
	local xldflags="${LDFLAGS//-flto=thin/}"; xldflags="${xldflags//-flto/}"
	# configure also inherits CFLAGS/LDFLAGS from the environment, so the
	# stripped variants must be re-exported, not just passed as --extra-*
	( cd "$d" && CFLAGS="$xcflags" LDFLAGS="$xldflags" \
		./configure --prefix="$PREFIX" --enable-static --disable-cli --disable-opencl \
		--host=x86_64-w64-mingw32 --extra-cflags="$xcflags" --extra-ldflags="$xldflags" ) > >(tee -a "$LOGF") 2>&1
	make -C "$d" -j"${JOBS:-14}" >>"$LOGF" 2>&1
	make -C "$d" install >>"$LOGF" 2>&1
}
