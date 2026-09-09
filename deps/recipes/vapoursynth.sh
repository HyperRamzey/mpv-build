# vapoursynth — vapoursynth/vapoursynth (meson; python3 host tools) [BEST-EFFORT]
# Builds SHARED (python-embedding model); everything else in deps stays static.
# The VS DLLs embed STATIC libc++ (explicit .a paths via LDFLAGS) so the
# bundles don't need a shared libc++.dll just for the VS runtime.
GIT_URL="https://github.com/vapoursynth/vapoursynth"
BUILD() {
	# embed the STATIC C++ runtime into the shared VS DLLs (EXTRA_LINK_ARGS
	# flows into meson c/cpp_link_args) so bundles don't need libc++.dll for them.
	# NOTE: meson hands these to native clang.exe WITHOUT bash path conversion,
	# so they must be native Windows paths, not MSYS /clang64/... forms. Derive
	# the clang64 root via cygpath -m: C:/msys64/clang64 locally, but
	# D:/a/_temp/msys64/clang64 on the GH runner (a hardcoded C:/ broke CI).
	local croot
	croot="$(cygpath -m /clang64)"
	EXTRA_LINK_ARGS="$croot/lib/libc++.a $croot/lib/libunwind.a" \
		meson_driver "$SRC_ROOT/$NAME" "$BUILD_DIR/$NAME" \
		-Ddefault_library=shared -Denable_x86_asm=true \
		-Denable_guard_pattern=false
	# Upstream now installs EVERYTHING into python site-packages (wheel-style
	# layout). Relocate what FFmpeg needs into the canonical prefix: headers
	# (configure's require_headers), DLLs (runtime dlopen; copydlls ships
	# deps-<t>/bin), import libs + a sane .pc for completeness.
	local sp
	sp="$(ls -d "$PREFIX"/lib/python3.*/site-packages/vapoursynth 2>/dev/null | head -1)"
	[[ -n "$sp" ]] || {
		echo "vapoursynth: site-packages dir not found" >>"$LOGF"
		return 1
	}
	mkdir -p "$PREFIX/include/vapoursynth"
	cp -f "$sp"/include/*.h "$PREFIX/include/vapoursynth/" >>"$LOGF" 2>&1
	cp -f "$sp"/*.dll "$PREFIX/bin/" >>"$LOGF" 2>&1
	cp -f "$sp"/*.dll.a "$PREFIX/lib/" >>"$LOGF" 2>&1
	{
		echo "prefix=$PREFIX"
		echo "includedir=\${prefix}/include"
		echo "libdir=\${prefix}/lib"
		echo ""
		echo "Name: vapoursynth"
		echo "Description: A frameserver for the 21st century"
		echo "Version: $(sed -n 's/^Version: //p' "$sp/pkgconfig/vapoursynth.pc")"
		echo "Libs: -L\${libdir} -lvapoursynth"
		# Both include roots: FFmpeg includes <vapoursynth/VSScript4.h>
		# (needs -Iincludedir), mpv includes <VSScript4.h> flat (needs
		# -Iincludedir/vapoursynth). Emit both so either resolves.
		echo "Cflags: -I\${includedir} -I\${includedir}/vapoursynth"
	} >"$PREFIX/lib/pkgconfig/vapoursynth.pc"
}
BEST_EFFORT=1
