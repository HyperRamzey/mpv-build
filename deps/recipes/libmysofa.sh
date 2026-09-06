# libmysofa — hoene/libmysofa (cmake static) + local patches:
#   patches/libmysofa-large-files.patch — raise arbitrary size/offset caps so
#   ~1GB ASH BRIR SOFAs load (continuation blocks & datasets past 32MB/256MB,
#   fixed-string attrs >64B). Upstream: https://github.com/hoene/libmysofa/issues
GIT_URL="https://github.com/hoene/libmysofa"
BUILD() {
	local d="$SRC_ROOT/$NAME"
	# reverse-check first: already-applied patch must not double-apply;
	# after apply, assert the marker so upstream drift fails LOUDLY
	# (silent skip = 1GB ASH BRIR SOFAs fail at runtime with err 10001)
	if git -C "$d" apply --reverse --check "$HERE/patches/libmysofa-large-files.patch" 2>>"$LOGF"; then
		log "patch already applied"
	elif git -C "$d" apply --whitespace=nowarn "$HERE/patches/libmysofa-large-files.patch" 2>>"$LOGF"; then
		log "patch applied"
	else
		echo "libmysofa patch FAILED to apply (upstream drift?)" >>"$LOGF"
		return 1
	fi
	grep -q "0x7FFF0000" "$d/src/hdf/dataobject.c" 2>>"$LOGF" || \
		{ echo "libmysofa patch marker missing — NOT patched" >>"$LOGF"; return 1; }
	cmake_driver "$d" "$BUILD_DIR/$NAME" \
		-DBUILD_SHARED_LIBS=OFF -DBUILD_STATIC_LIB=ON \
		-DBUILD_TESTS=OFF -DBUILD_TOOLS=OFF
}
