# subrandr — afishhh/subrandr (cargo xtask) SRV3/WebVTT subtitle rendering for mpv
GIT_URL="https://github.com/afishhh/subrandr"
BUILD() {
	cd "$SRC_ROOT/$NAME" || return 1
	# MSYS2 rust may target x86_64-pc-windows-gnu OR -gnullvm; set the
	# prefix -L path for both or the cdylib link misses freetype/harfbuzz.
	# lld is a native tool: give it a Windows path (cygpath -m), and append
	# the full static closure (zlib etc.) from pkg-config after the crate's
	# own -lfreetype/-lharfbuzz so the single-pass link resolves.
	# NOTE: do NOT pass -C target-cpu=$ARCH here. RUSTFLAGS also applies to
	# build scripts, which run on the HOST; a target-cpu with ISA extensions
	# the host lacks (e.g. rocketlake AVX-512 on a Zen3 builder) crashes
	# them with STATUS_ILLEGAL_INSTRUCTION. host==target triple, so there is
	# no env scope that excludes build scripts.
	local winlib closure rf l
	winlib="$(cygpath -m "$PREFIX")/lib"
	closure="$(PKG_CONFIG_PATH="$PREFIX/lib/pkgconfig" \
		pkg-config --static --libs freetype2 harfbuzz 2>/dev/null | \
		tr ' ' '\n' | grep -v '^-L' | sort -u | tr '\n' ' ')"
	rf="-C link-arg=-L$winlib"
	for l in $closure; do rf="$rf -C link-arg=$l"; done
	CARGO_TARGET_X86_64_PC_WINDOWS_GNU_RUSTFLAGS="$rf" \
	CARGO_TARGET_X86_64_PC_WINDOWS_GNULLVM_RUSTFLAGS="$rf" \
		cargo xtask install --prefix "$PREFIX" || return 1
}
BEST_EFFORT=1
