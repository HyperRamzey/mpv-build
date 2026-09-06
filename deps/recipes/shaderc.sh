# shaderc — google/shaderc (cmake; glslang/spirv-tools pinned via
# utils/update_glslang_sources.py + known_good.json). mpv's d3d11 VO requires
# shaderc AND spirv-cross. Static.
GIT_URL="https://github.com/google/shaderc"
GIT_SUBMODULES=0
BUILD() {
	local d="$SRC_ROOT/$NAME"
	# timeout guard: git-sync-deps can hang (observed: stuck `git rev-parse`
	# children); better to fail fast on the third_party check below
	timeout 600 python3 "$d/utils/git-sync-deps" >>"$LOGF" 2>&1 || true
	for dep in glslang spirv-tools spirv-headers; do
		[[ -d "$d/third_party/$dep/.git" ]] || \
			{ echo "shaderc: third_party/$dep missing" >>"$LOGF"; return 1; }
	done
	cmake_driver "$d" "$BUILD_DIR/$NAME" \
		-DSHADERC_SKIP_TESTS=ON -DSHADERC_SKIP_EXAMPLES=ON \
		-DSHADERC_SKIP_COPYRIGHT_CHECK=ON -DENABLE_GLSLANG_BINARIES=OFF \
		-DSHADERC_ENABLE_WGSL_OUTPUT=OFF
	for pc in shaderc.pc shaderc-shared.pc shaderc-static.pc; do
		[[ -f "$PREFIX/lib/pkgconfig/$pc" ]] && \
			sed -i "s|^prefix=.*|prefix=$PREFIX|; s|^libdir=.*|libdir=\${prefix}/lib|" \
			"$PREFIX/lib/pkgconfig/$pc"
	done
	[[ -f "$PREFIX/lib/pkgconfig/shaderc.pc" ]] || { echo "shaderc.pc missing" >>"$LOGF"; return 1; }
}
