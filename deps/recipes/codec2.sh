# codec2 — drowe67/codec2 (cmake, static)
# Upstream's install step includes cmake/GetPrerequisites.cmake — a CMake <3.30
# builtin that no longer ships, and it only matters for shared-lib DLL bundling.
# We stub it no-op (static build has no libcodec2.dll to scan).
GIT_URL="https://github.com/drowe67/codec2"
BUILD() {
	local d="$SRC_ROOT/$NAME"
	if [[ ! -f "$d/cmake/GetPrerequisites.cmake" ]]; then
		cat > "$d/cmake/GetPrerequisites.cmake" <<'EOF'
# local stub (deps-build): upstream expects the CMake<3.30 builtin module;
# static builds have no libcodec2.dll, so prerequisite bundling is a no-op.
function(get_prerequisites)
endfunction()
EOF
	fi
	# codec2 and speex both export lpc_to_lsp/lsp_to_lpc globally -> duplicate
	# symbols when ffmpeg static-links both. Namespace codec2's copies.
	sed -i 's/\blpc_to_lsp\b/c2_lpc_to_lsp/g; s/\blsp_to_lpc\b/c2_lsp_to_lpc/g' \
		"$d/src/lsp.c" "$d/src/lsp.h" "$d/src/codec2.c" "$d/src/c2sim.c" \
		"$d/src/quantise.c" 2>>"$LOGF" || true
	# generate_codebook.exe RUNS at build time on this host — strip target
	# -march (AVX-512 code crashes non-AVX512 hosts); last -march wins
	grep -q generate_codebook_hostfix "$d/src/CMakeLists.txt" || \
		echo 'set_source_files_properties(generate_codebook.c PROPERTIES COMPILE_FLAGS "-O3 -march=x86-64-v3") # generate_codebook_hostfix' >> "$d/src/CMakeLists.txt"
	cmake_driver "$d" "$BUILD_DIR/$NAME" \
		-DUNITTEST=OFF -DINSTALL_EXAMPLES=OFF -DBUILD_CMD_DEMO=OFF
}
