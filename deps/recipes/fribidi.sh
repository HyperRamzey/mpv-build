# fribidi — fribidi/fribidi (meson, static)
# bin=false: gen.tab codegen tools are built with target flags and RUN on the
# build host (crashes with AVX-512 codegen on non-AVX512 hosts); the library
# doesn't need them (generated tables ship in-tree).
GIT_URL="https://github.com/fribidi/fribidi"
BUILD() {
	# gen.tab codegen tools RUN on the build host: neutralize target -march
	# (AVX-512 codegen crashes non-AVX512 hosts); last -march wins.
	sed -i "s|native_args = \['-UHAVE_CONFIG_H'\]|native_args = ['-UHAVE_CONFIG_H', '-march=x86-64']|" \
		"$SRC_ROOT/$NAME/gen.tab/meson.build" 2>>"$LOGF" || true
	meson_driver "$SRC_ROOT/$NAME" "$BUILD_DIR/$NAME" \
		-Ddefault_library=static -Dtests=false -Ddocs=false -Dbin=false
}
