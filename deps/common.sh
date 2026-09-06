#!/bin/bash
# deps-build: shared environment + helpers for self-compiled per-target dependency builds
# Targets: zn2 (Zen2/Pascal sm_75) | zn3 (Zen3/Blackwell sm_120a) | 11700 (RKL/Ada sm_89)
#          | 3050 (Zen2/Ampere sm_86) | 14600 (RPL/Blackwell sm_120a)

set -Eeuo pipefail
export MSYSTEM=CLANG64
export DEBIAN_FRONTEND=noninteractive

DEPS_ROOT="${DEPS_ROOT:-/g/deps-build}"
SRC_ROOT="$DEPS_ROOT/src"
BUILD_ROOT="$DEPS_ROOT/build"

log() { printf '\033[1;36m[deps]\033[0m %s\n' "$*"; }
die() { printf '\033[1;31m[deps:FATAL]\033[0m %s\n' "$*" >&2; exit 1; }

# fetch_url <dest> <url...> — try each URL with retries (CI egress flakes)
fetch_url() {
	local out="$1" u; shift
	for u in "$@"; do
		log "fetch: $u"
		if curl -fL --retry 3 --retry-delay 3 --retry-all-errors \
			-o "$out" "$u" >/dev/null 2>&1; then
			return 0
		fi
	done
	return 1
}
# mirror_urls <url> — primary first, then known-good mirrors
mirror_urls() {
	local u="$1"
	echo "$u"
	case "$u" in
		https://ftp.gnu.org/pub/gnu/*)
			echo "https://ftpmirror.gnu.org/${u#https://ftp.gnu.org/pub/gnu/}" ;;
		https://ftp.gnu.org/gnu/*)
			echo "https://ftpmirror.gnu.org/${u#https://ftp.gnu.org/gnu/}" ;;
	esac
}

# Per-target CPU codegen. GPU arch lives ONLY in FFmpeg scripts (clang NVPTX).
target_env() {
	local t="$1"
	case "$t" in
		zn2)   ARCH=znver2;      TARGET_CPU="Zen2 + GTX 1650M (Pascal)" ;;
		zn3)   ARCH=znver3;      TARGET_CPU="Zen3 + RTX 5070 (Blackwell)" ;;
		11700) ARCH=rocketlake;  TARGET_CPU="i7-11700 (RKL) + RTX 4080 (Ada)" ;;
		3050)  ARCH=znver2;      TARGET_CPU="Zen2 + RTX 3050M (Ampere)" ;;
		14600) ARCH=raptorlake;  TARGET_CPU="i5-14600 (RPL) + RTX 50-series (Blackwell)" ;;
		*) die "unknown target '$t' (want: zn2|zn3|11700|3050|14600)" ;;
	esac
	TARGET="$t"
	PREFIX="$DEPS_ROOT/deps-$t"
	BUILD_DIR="$BUILD_ROOT/$t"
	mkdir -p "$PREFIX" "$BUILD_DIR"

	export CC=clang CXX=clang++
	# Max per-target optimization. NO fast-math anywhere (IEEE codec math).
	OPT="-O3 -march=$ARCH -mtune=$ARCH -mprefer-vector-width=256 -fvectorize -fslp-vectorize -funroll-loops -fomit-frame-pointer -fstrict-aliasing -fno-trapping-math"
	if [[ "${DEPS_LTO:-1}" == "1" ]]; then
		OPT+=" -flto=thin"
	fi
	export CFLAGS="$OPT"
	export CXXFLAGS="$OPT"
	export CPPFLAGS="-I$PREFIX/include"
	export LDFLAGS="-O3 -L$PREFIX/lib -Wl,--gc-sections${DEPS_LTO:+ }"
	if [[ "${DEPS_LTO:-1}" == "1" ]]; then export LDFLAGS+=" -flto=thin"; fi
	# Self-built deps ALWAYS win over MSYS2 (pkg-config + linker order).
	export PKG_CONFIG_PATH="$PREFIX/lib/pkgconfig:/clang64/lib/pkgconfig"
	export PKG_CONFIG_SYSROOT_DIR=""
	export PATH="/clang64/bin:$PREFIX/bin:$PATH"
}

# Idempotence stamp: skip rebuild when HEAD unchanged unless FORCE=1
stamp_file() { echo "$SRC_ROOT/$1/.built-$TARGET"; }
head_of() { git -C "$SRC_ROOT/$1" rev-parse HEAD 2>/dev/null || echo unknown; }

sync_src() {
	local name="$1" url="$2" branch="${3:-}"
	local dir="$SRC_ROOT/$name"
	if [[ -d "$dir/.git" ]]; then
		log "pull $name ($(git -C "$dir" rev-parse --abbrev-ref HEAD))"
		if ! git -C "$dir" pull --ff-only >>"$DEPS_ROOT/logs/pull-$name.log" 2>&1; then
			if git -C "$dir" status --porcelain 2>/dev/null | grep -q "^ M"; then
				log "FATAL: $name pull conflicts with locally-mutated files — refusing to freeze at stale HEAD"
				return 1
			fi
			log "WARN: ff-only pull failed for $name (clean tree) — keeping HEAD"
		fi
	else
		log "clone $name"
		mkdir -p "$SRC_ROOT"
		if [[ -n "$branch" ]]; then
			git clone --branch "$branch" "$url" "$dir" >>"$DEPS_ROOT/logs/pull-$name.log" 2>&1 \
				|| { log "ERROR: clone failed for $name"; return 1; }
		else
			git clone "$url" "$dir" >>"$DEPS_ROOT/logs/pull-$name.log" 2>&1 \
				|| { log "ERROR: clone failed for $name"; return 1; }
		fi
	fi
	# all sublibs enabled: recursive submodules where the recipe opts in
	if [[ "${GIT_SUBMODULES:-0}" == "1" && -d "$dir/.git" ]]; then
		git -C "$dir" submodule update --init --recursive --depth 1 \
			>>"$DEPS_ROOT/logs/pull-$name.log" 2>&1 \
			|| log "WARN: submodule init failed for $name"
	fi
}

# --- build-system drivers ----------------------------------------------------
# posix path -> physical native path with forward slashes. On CI, /g is a
# SUBST drive; meson resolves source dirs to the physical target (D:/a/...)
# while ninja's cwd stays on the subst letter, so generator scripts that
# relpath(src, builddir) (harfbuzz gen-harfbuzzcc.py) die with
# "path is on mount 'G:', start on mount 'D:'". python realpath resolves
# subst drives; on real drives (local) it is a no-op.
_real_native() {
	python3 -c 'import os,sys; print(os.path.realpath(sys.argv[1]).replace(chr(92),"/"))' \
		"$(cygpath -am "$1")"
}

meson_driver() { # args: srcdir builddir [meson options...]
	local sd bd
	sd="$( _real_native "$1")"; bd="$(_real_native "$2")"; shift 2
	local lto_args=()
	[[ "${DEPS_LTO:-1}" == "1" ]] && lto_args+=(-Db_lto=true -Db_lto_mode=thin)
	# EXTRA_LINK_ARGS: appended verbatim to BOTH c/cpp link args (recipes use
	# this to e.g. embed the static C++ runtime archives into shared libs)
	local ela="${EXTRA_LINK_ARGS:-}"
	local cla="-Wl,--gc-sections${ela:+ $ela}"
	meson setup "$bd" "$sd" --prefix="$PREFIX" --buildtype=release \
		-Dc_args="$OPT" -Dcpp_args="$OPT" \
		-Dc_link_args="$cla" -Dcpp_link_args="$cla" \
		"${lto_args[@]}" \
		"$@" >&"$LOGF" || { echo "meson setup FAILED ($NAME)" >>"$LOGF"; return 1; }
	ninja -C "$bd" -j"${JOBS:-14}" >>"$LOGF" 2>&1 || { echo "ninja FAILED ($NAME)" >>"$LOGF"; return 1; }
	ninja -C "$bd" install >>"$LOGF" 2>&1 || { echo "install FAILED ($NAME)" >>"$LOGF"; return 1; }
}

cmake_driver() { # args: srcdir builddir [cmake options...]   (NO_CXX=1 skips CXX flags for pure-C projects)
	local sd="$1" bd="$2"; shift 2
	local cxx_args=(-DCMAKE_CXX_COMPILER=clang++ -DCMAKE_CXX_FLAGS="$OPT")
	[[ "${NO_CXX:-0}" == "1" ]] && cxx_args=()
	cmake -S "$sd" -B "$bd" -G Ninja \
		-DCMAKE_INSTALL_PREFIX="$PREFIX" \
		-DCMAKE_BUILD_TYPE=Release \
		-DCMAKE_C_COMPILER=clang -DCMAKE_C_FLAGS="$OPT" \
		"${cxx_args[@]}" \
		-DCMAKE_EXE_LINKER_FLAGS="-Wl,--gc-sections" \
		-DCMAKE_SHARED_LINKER_FLAGS="-Wl,--gc-sections" \
		-DCMAKE_PREFIX_PATH="$PREFIX" \
		-DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
		-DBUILD_SHARED_LIBS=OFF -DBUILD_STATIC_LIBS=ON \
		"$@" > >(tee -a "$LOGF") 2>&1 || { echo "cmake configure FAILED ($NAME)" >>"$LOGF"; return 1; }
	cmake --build "$bd" -j"${JOBS:-14}" >>"$LOGF" 2>&1 || { echo "cmake build FAILED ($NAME)" >>"$LOGF"; return 1; }
	cmake --install "$bd" >>"$LOGF" 2>&1 || { echo "cmake install FAILED ($NAME)" >>"$LOGF"; return 1; }
}

autotools_driver() { # args: srcdir [configure options...]
	local sd="$1"; shift
	# git checkouts of autotools projects often lack generated configure
	if [[ ! -f "$sd/configure" && ! -f "$sd/configure.ac" && ! -f "$sd/configure.in" ]]; then
		echo "ERROR ($NAME): no configure or configure.ac — cannot bootstrap" >>"$LOGF"; return 1
	fi
	if [[ ! -f "$sd/configure" ]]; then
		( cd "$sd" && autoreconf -fi ) >>"$LOGF" 2>&1 || { echo "autoreconf FAILED ($NAME)" >>"$LOGF"; return 1; }
	fi
	# in-tree build: wipe stale state so a reconfigure with different
	# flags never archives old objects (e.g. libsixel curl refs)
	( cd "$sd" && make distclean ) >>"$LOGF" 2>&1 || true
	( cd "$sd" && ./configure --prefix="$PREFIX" \
		--disable-dependency-tracking --enable-static --disable-shared \
		CFLAGS="$CFLAGS" CXXFLAGS="$CXXFLAGS" CPPFLAGS="$CPPFLAGS" LDFLAGS="$LDFLAGS" \
		CC="$CC" CXX="$CXX" PKG_CONFIG_PATH="$PKG_CONFIG_PATH" \
		"$@" ) > >(tee -a "$LOGF") 2>&1 || { echo "configure FAILED ($NAME)" >>"$LOGF"; return 1; }
	make -C "$sd" -j"${JOBS:-14}" >>"$LOGF" 2>&1 || { echo "make FAILED ($NAME)" >>"$LOGF"; return 1; }
	make -C "$sd" install >>"$LOGF" 2>&1 || { echo "make install FAILED ($NAME)" >>"$LOGF"; return 1; }
}
