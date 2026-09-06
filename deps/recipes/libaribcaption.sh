# libaribcaption — xqq (cmake, static; replaces aribb24/zvbi)
GIT_URL="https://github.com/xqq/libaribcaption"
BUILD() {
	local d="$SRC_ROOT/$NAME"
	# bundled md5 clashes with OpenSSL's MD5_* when both are static-linked
	# into one binary; namespace aribcaption's copies
	sed -i 's/\bMD5_Init\b/aribcc_internal_MD5_Init/g; s/\bMD5_Update\b/aribcc_internal_MD5_Update/g; s/\bMD5_Final\b/aribcc_internal_MD5_Final/g' \
		"$d/src/base/md5.c" "$d/src/base/md5.h" "$d/src/base/md5_helper.hpp" 2>>"$LOGF" || true
	cmake_driver "$SRC_ROOT/$NAME" "$BUILD_DIR/$NAME" \
		-DBUILD_SHARED_LIBS=OFF -DBUILD_TESTING=OFF
}
