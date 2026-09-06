# libvmaf — Netflix/vmaf (meson in libvmaf/)
GIT_URL="https://github.com/Netflix/vmaf"
BUILD() {
	meson_driver "$SRC_ROOT/$NAME/libvmaf" "$BUILD_DIR/$NAME" \
		-Ddefault_library=static -Denable_docs=false -Denable_tests=false \
		-Denable_avx512=true
}
