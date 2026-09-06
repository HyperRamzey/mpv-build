# SPIRV-Cross — KhronosGroup (static c-abi; mpv d3d11 needs the c API)
GIT_URL="https://github.com/KhronosGroup/SPIRV-Cross"
BUILD() {
	cmake_driver "$SRC_ROOT/$NAME" "$BUILD_DIR/$NAME" \
		-DSPIRV_CROSS_ENABLE_TESTS=OFF -DSPIRV_CROSS_SHARED=OFF \
		-DSPIRV_CROSS_STATIC=ON -DSPIRV_CROSS_CLI=OFF \
		-DSPIRV_CROSS_ENABLE_HLSL=ON -DSPIRV_CROSS_ENABLE_MSL=OFF \
		-DSPIRV_CROSS_ENABLE_REFLECT=ON -DSPIRV_CROSS_ENABLE_UTIL=ON
	# normalize cmake-generated pcs; headers live in include/spirv_cross/.
	# NOTE: mpv/libplacebo look up 'spirv-cross-c-shared' (upstream name for
	# the c-abi) — install the static c lib under BOTH pc names so the dep
	# resolves to libspirv-cross-c.a regardless of which name is probed.
	for pc in spirv-cross-c spirv-cross-c-shared; do
		[[ -f "$PREFIX/lib/pkgconfig/$pc.pc" ]] && continue
		local ver="$(grep -m1 'SPIRV_Cross_VERSION' "$SRC_ROOT/$NAME"/CMakeLists.txt 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || echo 0.68.0)"
		# STATIC c-abi closure: the wrapper archive references C++ symbols
		# in the sub-archives (cpp/hlsl/glsl reflect util core) — consumers
		# (mpv gpu-next, libplacebo d3d11) must link them all; order matters
		# (dependents before dependencies, core last)
		cat > "$PREFIX/lib/pkgconfig/$pc.pc" <<PC
prefix=$PREFIX
exec_prefix=\${prefix}
libdir=\${prefix}/lib
includedir=\${prefix}/include

Name: spirv-cross-$pc
Description: SPIRV-Cross (static c-abi + full closure)
Version: $ver
Libs: -L\${libdir} -lspirv-cross-c -lspirv-cross-cpp -lspirv-cross-hlsl -lspirv-cross-glsl -lspirv-cross-reflect -lspirv-cross-util -lspirv-cross-core -lc++ -lunwind
Cflags: -I\${includedir} -I\${includedir}/spirv_cross
PC
	done
	[[ -f "$PREFIX/lib/pkgconfig/spirv-cross-c.pc" ]] || { echo "spirv-cross-c.pc missing" >>"$LOGF"; return 1; }
}
