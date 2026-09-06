# libsrt — Haivision/srt (cmake; OpenSSL backend)
GIT_URL="https://github.com/Haivision/srt"
BUILD() {
	cmake_driver "$SRC_ROOT/$NAME" "$BUILD_DIR/$NAME" \
		-DENABLE_SHARED=OFF -DENABLE_STATIC=ON -DENABLE_APPS=OFF \
		-DENABLE_ENCRYPTION=ON -DUSE_OPENSSL_PC=ON -DENABLE_TESTING=OFF
}
