# LCEVCdec — v-novaltd/LCEVCdec (cmake) MPEG-5 LCEVC enhancement decoder
GIT_URL="https://github.com/v-novaltd/LCEVCdec"
BUILD() {
	# LLVM 22 ThinLTO ICE: the backend crashes with
	#   "Do not know how to scalarize the result of this operator!"
	# in X86 DAG instruction selection on calculateDequant (dequant.c)
	# when FFmpeg's -flto=thin link imports this lib's bitcode for
	# -march=rocketlake (reproduced standalone). Non-LTO codegen of the
	# same source/target is fine, so build plain objects — the final
	# FFmpeg link then treats them as native COFF and never runs the
	# crashing backend path. (Same pattern as the x264 recipe.)
	# libc++ 23 (clang64 >= 23.1.3) also stopped the C-compatibility
	# headers from declaring names in namespace std: api_utility's
	# picture_layout.cpp calls std::exit(EXIT_FAILURE) with only C
	# headers transitively present, so force <cstdlib> in.
	local no_lto_cflags no_lto_cxxflags
	no_lto_cflags="$(sed -E 's/-flto(=thin)?//g' <<<"$CFLAGS")"
	no_lto_cxxflags="$(sed -E 's/-flto(=thin)?//g' <<<"$CXXFLAGS")"
	cmake_driver "$SRC_ROOT/$NAME" "$BUILD_DIR/$NAME" \
		-DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=OFF \
		-DBUILD_APPS=OFF -DBUILD_TESTS=OFF -DBUILD_SAMPLES=OFF \
		-DUSE_TIMING=OFF \
		-DCMAKE_C_FLAGS="-include errno.h $no_lto_cflags" \
		-DCMAKE_CXX_FLAGS="-include errno.h -include cstdlib $no_lto_cxxflags"
}
BEST_EFFORT=1
