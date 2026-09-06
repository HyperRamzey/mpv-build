# librist — nanake/librist (meson) Reliable Internet Stream Transport; bundled mbedtls
GIT_URL="https://github.com/nanake/librist"
BUILD() {
	# -Dtest=false: HEAD's test/rist/meson.build references tools_dependencies
	# which only exists when built_tools=true (upstream regression).
	# -Dhave_mingw_pthreads=true: without it meson never probes clock_gettime
	# on Windows, so contrib/time-shim.c redefines it and clashes with the
	# winpthreads declaration in pthread_time.h
	meson_driver "$SRC_ROOT/$NAME" "$BUILD_DIR/$NAME" \
		-Ddefault_library=static -Dbuilt_tools=false -Dtest=false \
		-Dhave_mingw_pthreads=true \
		-Duse_mbedtls=true -Duse_nettle=false
}
