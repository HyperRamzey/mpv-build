# x265 — multicoreware (cmake multilib 8+10+12bit)
GIT_URL="https://bitbucket.org/multicoreware/x265_git.git"
BUILD() {
	local d="$SRC_ROOT/$NAME/source" b="$BUILD_DIR/$NAME"
	cmake_driver "$d" "$b/12" -DENABLE_SHARED=OFF -DENABLE_CLI=OFF -DEXPORT_C_API=OFF \
		-DHIGH_BIT_DEPTH=ON -DEXTENDED_12BIT=ON -DMAIN12=ON \
		-DENABLE_MULTIVIEW=OFF -DENABLE_MULTIVIEW_ENCODER=OFF
	mv "$PREFIX/lib/libx265.a" "$PREFIX/lib/libx265_main12.a" 2>>"$LOGF" || true
	cmake_driver "$d" "$b/10" -DENABLE_SHARED=OFF -DENABLE_CLI=OFF -DEXPORT_C_API=OFF -DHIGH_BIT_DEPTH=ON
	mv "$PREFIX/lib/libx265.a" "$PREFIX/lib/libx265_main10.a" 2>>"$LOGF" || true
	cmake_driver "$d" "$b/08" -DENABLE_SHARED=OFF -DENABLE_CLI=OFF -DEXTRA_LIB="x265_main10.a;x265_main12.a" \
		-DEXTRA_LINK_FLAGS="-L$PREFIX/lib" -DLINKED_10BIT=ON -DLINKED_12BIT=ON
	( cd "$b/08" && cp libx265.a "$PREFIX/lib/" ) >>"$LOGF" 2>&1
	# multilib: the 8-bit archive references the 10/12-bit archives
	[[ -f "$PREFIX/lib/pkgconfig/x265.pc" ]] && \
		sed -i "s|^Libs.private:.*|Libs.private: -lx265_main10 -lx265_main12 -lc++ -lunwind|" \
		"$PREFIX/lib/pkgconfig/x265.pc"
}
