# Vulkan-Loader — KhronosGroup (cmake; needs python3, headers)
GIT_URL="https://github.com/KhronosGroup/Vulkan-Loader"
BUILD() {
	cmake_driver "$SRC_ROOT/$NAME" "$BUILD_DIR/$NAME" \
		-DBUILD_TESTS=OFF -DBUILD_LOADER=ON -DUSE_GAS=ON \
		-DVULKAN_HEADERS_INSTALL_DIR="$PREFIX" \
		-DBUILD_STATIC_LOADER=ON
}
