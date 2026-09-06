# libjxl — libjxl/libjxl (cmake; bundled highway/brotli/skcms via submodules)
GIT_URL="https://github.com/libjxl/libjxl"
GIT_SUBMODULES=1
BUILD() {
	cmake_driver "$SRC_ROOT/$NAME" "$BUILD_DIR/$NAME" \
		-DJPEGXL_ENABLE_BENCHMARK=OFF -DJPEGXL_ENABLE_EXAMPLES=OFF \
		-DJPEGXL_ENABLE_MANPAGES=OFF -DJPEGXL_ENABLE_JNI=OFF \
		-DJPEGXL_ENABLE_SJPEG=ON -DJPEGXL_ENABLE_OPENEXR=OFF \
		-DJPEGXL_ENABLE_SKCMS=ON -DJPEGXL_FORCE_SYSTEM_BROTLI=ON \
		-DJPEGXL_ENABLE_PLUGINS=OFF -DJPEGXL_ENABLE_DEVTOOLS=OFF \
		-DJPEGXL_ENABLE_VIEWERS=OFF -DBUILD_TESTING=OFF \
		-DJPEGXL_STATIC=OFF
	# cmake-generated pcs miss the C++ runtime for static linking
	for pc in libjxl.pc libjxl_threads.pc libjxl_cms.pc; do
		[[ -f "$PREFIX/lib/pkgconfig/$pc" ]] || continue
		grep -q -- "-lc++" "$PREFIX/lib/pkgconfig/$pc" || \
			sed -i "s|^Libs.private:|Libs.private: -lc++ -lunwind|" "$PREFIX/lib/pkgconfig/$pc"
	done
}
