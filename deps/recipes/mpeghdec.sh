# mpeghdec — Fraunhofer-IIS/mpeghdec (cmake) MPEG-H 3D Audio low-complexity decoder
GIT_URL="https://github.com/Fraunhofer-IIS/mpeghdec"
BUILD() {
	cmake_driver "$SRC_ROOT/$NAME" "$BUILD_DIR/$NAME" \
		-DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=OFF \
		-DBUILD_TESTING=OFF -DBUILD_TOOLS=OFF \
		-DCMAKE_C_FLAGS="-D_SH_DENYNO=0x40 -D_S_IREAD=0x0100 -D_S_IWRITE=0x0080 $CFLAGS" \
		-DCMAKE_CXX_FLAGS="-D_SH_DENYNO=0x40 -D_S_IREAD=0x0100 -D_S_IWRITE=0x0080 $CXXFLAGS"
}
BEST_EFFORT=1
