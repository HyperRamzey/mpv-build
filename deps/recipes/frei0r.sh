# Frei0r — dyne/Frei0r (cmake; plugin host API)
GIT_URL="https://github.com/dyne/Frei0r"
BUILD() {
	# upstream revived (2026) and renamed options to WITHOUT_*; the old
	# WITH_CAIRO=OFF flag no longer exists and cairo became REQUIRED
	cmake_driver "$SRC_ROOT/$NAME" "$BUILD_DIR/$NAME" \
		-DWITHOUT_OPENCV=ON -DWITHOUT_CAIRO=ON \
		-DBUILD_TESTING=OFF -DBUILD_EXAMPLES=OFF
}
