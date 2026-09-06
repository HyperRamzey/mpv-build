# glslang — KhronosGroup (cmake static, no spirv-tools)
GIT_URL="https://github.com/KhronosGroup/glslang"
BUILD() {
	cmake_driver "$SRC_ROOT/$NAME" "$BUILD_DIR/$NAME" \
		-DENABLE_OPT=OFF -DBUILD_SHARED_LIBS=OFF \
		-DENABLE_GLSLANG_BINARIES=OFF -DENABLE_SPVREMAPPER=OFF \
		-DGLSLANG_TESTS=OFF
	# Ship a glslang.pc so consumers' pkg-config lookup resolves OUR static
	# libs instead of falling through to MSYS2's shared import libs.
	if [[ -f "$PREFIX/lib/pkgconfig/glslang.pc" ]]; then
		sed -i "s|^prefix=.*|prefix=$PREFIX|" "$PREFIX/lib/pkgconfig/glslang.pc"
	else
		cat > "$PREFIX/lib/pkgconfig/glslang.pc" <<EOF
prefix=$PREFIX
libdir=\${prefix}/lib
includedir=\${prefix}/include

Name: glslang
Description: Khronos-reference front end for GLSL/ESSL (static)
Version: 15.0.0
Libs: -L\${libdir} -lglslang -lSPIRV -lOSDependent -lMachineIndependent -lGenericCodeGen
Libs.private: -lc++ -lunwind
Cflags: -I\${includedir}
EOF
	fi
	[[ -f "$PREFIX/lib/pkgconfig/glslang.pc" ]] || { echo "glslang.pc missing" >>"$LOGF"; return 1; }
}
