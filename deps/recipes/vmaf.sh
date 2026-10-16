# libvmaf — Netflix/vmaf (meson in libvmaf/)
GIT_URL="https://github.com/Netflix/vmaf"
# Patches:
#  - vmaf-libcxx23-swap.patch: svm.cpp defines a file-local global-namespace
#    swap() template; libc++ 23's __split_buffer::__swap_layouts calls
#    unqualified swap() on raw pointers, ADL finds the template for
#    svm_node*, and the overload set becomes ambiguous (build fails on
#    clang64 >= 23.1.3). Renames the helper to vmaf_swap().
BUILD() {
	local d="$SRC_ROOT/$NAME"
	git -C "$d" apply --whitespace=nowarn "$HERE/patches/vmaf-libcxx23-swap.patch" \
		2>>"$LOGF" || log "vmaf patch: already applied (continuing)"
	meson_driver "$SRC_ROOT/$NAME/libvmaf" "$BUILD_DIR/$NAME" \
		-Ddefault_library=static -Denable_docs=false -Denable_tests=false \
		-Denable_avx512=true
}
