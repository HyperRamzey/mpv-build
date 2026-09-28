#!/bin/bash
# pull-all.sh - bring every cloned dep to its upstream tip (clone what is missing)
# Each repo is handed to sync-repo.sh, which retries on CI egress flakes, and
# treats a pinned tag as pinned. A repo that cannot be synced lands in FAIL[]
# and the run exits 1 with the list — a stale tree is never quietly accepted,
# because this job's output is the src cache every later job restores from.
set -Eeuo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/common.sh"
mkdir -p "$DEPS_ROOT/logs" "$SRC_ROOT"
FAIL=()
for r in "$HERE"/recipes/*.sh; do
	name="$(basename "$r" .sh)"
	GIT_URL=""
	GIT_BRANCH=""
	SRC_URL=""
	# shellcheck disable=SC1090
	. "$r" 2>/dev/null || true
	dir="$SRC_ROOT/$name"
	if [[ -n "${GIT_URL:-}" ]]; then
		# covers all three shapes: missing dir (clone), cached clone (update),
		# recipe pinned to a tag or branch (left on the pin)
		if "$HERE/sync-repo.sh" -q "$dir" "$GIT_URL" "${GIT_BRANCH:-}"; then
			log "synced $name @ $(git -C "$dir" rev-parse --short HEAD)"
		else
			log "WARN sync failed: $name"
			FAIL+=("$name")
		fi
	elif [[ -n "${SRC_URL:-}" ]]; then
		# tarball-based recipe: fetch once so the deps jobs hit the cache
		if [[ -f "$dir/.tarball-done" ]]; then
			log "tarball cached: $name"
		else
			log "fetch tarball: $name"
			rm -rf "$dir"
			mkdir -p "$dir"
			tflag=-xJz
			case "$SRC_URL" in
			*.tar.gz | *.tgz) tflag=-xz ;;
			*.tar.bz2) tflag=-xj ;;
			*.tar.xz) tflag=-xJ ;;
			*.tar.lz) tflag=-xl ;;
			esac
			tmp="$SRC_ROOT/.$name.tarball"
			mapfile -t urls < <(mirror_urls "$SRC_URL")
			if fetch_url "$tmp" "${urls[@]}" &&
				tar $tflag --strip-components=1 -C "$dir" <"$tmp"; then
				echo "$SRC_URL" >"$dir/.tarball-done"
				rm -f "$tmp"
				log "fetched $name"
			else
				rm -f "$tmp"
				log "WARN tarball fetch failed: $name"
				FAIL+=("$name")
			fi
		fi
	fi
done
[[ ${#FAIL[@]} -eq 0 ]] || {
	log "FAILED repos: ${FAIL[*]}"
	exit 1
}
log "all sources synced"
