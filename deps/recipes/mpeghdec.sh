# mpeghdec — Fraunhofer-IIS/mpeghdec (cmake) MPEG-H 3D Audio low-complexity decoder
GIT_URL="https://github.com/Fraunhofer-IIS/mpeghdec"
BUILD() {
	# clang64 headers 14.0.0.r426 (>= 23.1.3) dropped sec_api/ and moved
	# the MSVC-style *_s declarations inline into their home headers;
	# ilo's async_fileio_not_supported.cpp calls wcstombs_s but never
	# includes <stdlib.h> (it used to arrive transitively via wchar.h).
	cmake_driver "$SRC_ROOT/$NAME" "$BUILD_DIR/$NAME" \
		-DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=OFF \
		-DBUILD_TESTING=OFF -DBUILD_TOOLS=OFF \
		-DCMAKE_C_FLAGS="-D_SH_DENYNO=0x40 -D_S_IREAD=0x0100 -D_S_IWRITE=0x0080 $CFLAGS" \
		-DCMAKE_CXX_FLAGS="-include stdlib.h -D_SH_DENYNO=0x40 -D_S_IREAD=0x0100 -D_S_IWRITE=0x0080 $CXXFLAGS"
}
BEST_EFFORT=1
