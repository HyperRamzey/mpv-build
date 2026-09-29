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
		# exit 2 = "could not reach upstream", which build-deps.sh treats as
		# fatal even for a BEST_EFFORT lib: not being able to fetch the newest
		# source is not the same as an optional build failing, and building a
		# stale or missing tree is exactly what must never happen silently.
		if ! sync_src "$NAME" "$GIT_URL" "${GIT_BRANCH:-}"; then
			die "$NAME: could not be synced to upstream (exit 2) — refusing to build a stale tree"
			exit 2
		fi
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

# --- build (unguarded subshell + ERR trap => a failed step IS a failed build) -
log "BUILD $NAME @$TARGET ($TARGET_CPU) -> $(basename "$PREFIX")"
rm -rf "$BUILD_DIR/$NAME"
mkdir -p "$BUILD_DIR/$NAME"
START=$(date +%s)
# `if ! ( set -e; ... )` looks correct and is not: bash disables errexit for
# every command inside a compound command that runs in a tested context, so
# BUILD's own `set -e` was a no-op and a failing make was reported as a
# successful build. That is how luajit lost luajit.pc on 11700/x64v4 and the
# deps job stayed green — twice (2026-09-13, 2026-09-29) — with the only
# symptom a missing .pc discovered much later, in the mpv job.
#
# So the subshell runs unguarded (where set -e is honoured) and an ERR trap
# does what the old `if` did: drop the stamp so the next run retries, and name
# the log. A recipe that reaches its last command with an earlier failure still
# has a zero status, so the trap alone cannot see that — that is why the
# recipes that install something the build depends on now assert the artefact
# exists (see recipes/luajit.sh).
trap 'rc=$?; rm -f "$STAMP"; trap - ERR; log "$NAME@$TARGET FAILED after $(($(date +%s) - START))s (rc=$rc) — see logs/${NAME}-${TARGET}.log"; exit $rc' ERR
( set -e; cd /; BUILD )
trap - ERR

echo "$FP" > "$STAMP"
"$HERE/fix-static-pcs.sh" "$PREFIX" >>"$LOGF" 2>&1 || true
"$HERE/sanitize-prefix.sh" "$PREFIX" >>"$LOGF" 2>&1 || true
log "OK $NAME@$TARGET in $(($(date +%s)-START))s"
