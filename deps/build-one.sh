#!/bin/bash
# build-one.sh <target> <lib> — sync + build + install one dep for one target
set -Eeuo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=common.sh
. "$HERE/common.sh"

[[ $# -eq 2 ]] || die "usage: build-one.sh <zn2|zn3|11700> <lib>"
target_env "$1"
NAME="$2"
RECIPE="$HERE/recipes/$NAME.sh"
[[ -f "$RECIPE" ]] || die "no recipe: recipes/$NAME.sh"
mkdir -p "$DEPS_ROOT/logs"
LOGF="$DEPS_ROOT/logs/${NAME}-${TARGET}.log"
: > "$LOGF"

# shellcheck source=/dev/null
. "$RECIPE"

# --- acquire source ----------------------------------------------------------
SRCD="$SRC_ROOT/$NAME"
if [[ "${SKIP_SYNC:-0}" != "1" ]]; then
	if [[ -n "${GIT_URL:-}" ]]; then
		sync_src "$NAME" "$GIT_URL" "${GIT_BRANCH:-}"
	elif [[ -n "${SRC_URL:-}" ]]; then
		if [[ ! -f "$SRCD/.tarball-done" ]]; then
			log "fetch $NAME (release tarball — no usable upstream git)"
			rm -rf "$SRCD"; mkdir -p "$SRCD"
			tflag=-xJz
			case "$SRC_URL" in
				*.tar.gz)  tflag=-xz ;;
				*.tgz)     tflag=-xz ;;
				*.tar.bz2) tflag=-xj ;;
				*.tar.xz)  tflag=-xJ ;;
				*.tar.lz)  tflag=-xl ;;
			esac
			# download to a file first (pipe-to-tar hides partial fetches);
			# retry + mirror fallback: ftp.gnu.org et al. flake from CI runners
			tmp="$SRC_ROOT/.$NAME.tarball"
			mapfile -t urls < <(mirror_urls "$SRC_URL")
			fetch_url "$tmp" "${urls[@]}" \
				>>"$DEPS_ROOT/logs/pull-$NAME.log" 2>&1 \
				|| die "$NAME: tarball fetch failed"
			tar $tflag --strip-components=1 -C "$SRCD" < "$tmp" \
				>>"$DEPS_ROOT/logs/pull-$NAME.log" 2>&1 \
				|| die "$NAME: tarball extract failed"
			rm -f "$tmp"
			echo "$SRC_URL" > "$SRCD/.tarball-done"
		fi
	else
		die "$NAME: recipe defines neither GIT_URL nor SRC_URL"
	fi
fi

# --- idempotence: stamp = git HEAD + recipe hash + toolchain/flags fingerprint -------
STAMP="$(stamp_file "$NAME")"
HEAD="$(head_of "$NAME")"
[[ -f "$SRCD/.tarball-done" ]] && HEAD="tarball-$(cat "$SRCD/.tarball-done")"
FP="$HEAD|$(md5sum "$RECIPE" | cut -d" " -f1)|$(clang --version 2>/dev/null | head -1)|$(echo "$OPT $LDFLAGS" | md5sum | cut -d" " -f1)"
if [[ "${FORCE:-0}" != "1" && -f "$STAMP" && "$(cat "$STAMP" 2>/dev/null)" == "$FP" ]]; then
	log "SKIP $NAME@$TARGET (${HEAD:0:9}; FORCE=1 to rebuild)"
	exit 0
fi

# --- build (subshell + set -e => any step failure kills BUILD) ---------------
log "BUILD $NAME @$TARGET ($TARGET_CPU) -> $(basename "$PREFIX")"
rm -rf "$BUILD_DIR/$NAME"
mkdir -p "$BUILD_DIR/$NAME"
START=$(date +%s)
if ! ( set -e; cd /; BUILD ); then
	rm -f "$STAMP"
	die "$NAME@$TARGET FAILED ($(($(date +%s)-START))s) — see logs/${NAME}-${TARGET}.log"
fi

echo "$FP" > "$STAMP"
"$HERE/fix-static-pcs.sh" "$PREFIX" >>"$LOGF" 2>&1 || true
"$HERE/sanitize-prefix.sh" "$PREFIX" >>"$LOGF" 2>&1 || true
log "OK $NAME@$TARGET in $(($(date +%s)-START))s"
