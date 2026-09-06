# OpenCL-ICD-Loader — KhronosGroup (cmake static; replaces MSYS2 opencl-icd)
GIT_URL="https://github.com/KhronosGroup/OpenCL-ICD-Loader"
BUILD() {
	cmake_driver "$SRC_ROOT/$NAME" "$BUILD_DIR/$NAME" \
		-DBUILD_SHARED_LIBS=OFF -DENABLE_OPENCL_LAYER=OFF
	# cmake installs "OpenCL.a" (no lib prefix) which -lOpenCL never finds
	[[ -f "$PREFIX/lib/libOpenCL.a" ]] || \
		cp "$PREFIX/lib/OpenCL.a" "$PREFIX/lib/libOpenCL.a" 2>>"$LOGF" || \
		{ echo "libOpenCL.a missing" >>"$LOGF"; return 1; }
	# static ICD loader needs cfgmgr32 (CM_* devnode APIs)
	[[ -f "$PREFIX/lib/pkgconfig/OpenCL.pc" ]] && \
		grep -q cfgmgr32 "$PREFIX/lib/pkgconfig/OpenCL.pc" || \
		echo "Libs.private: -lcfgmgr32" >> "$PREFIX/lib/pkgconfig/OpenCL.pc"
}
