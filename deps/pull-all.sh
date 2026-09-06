#!/bin/bash
# pull-all.sh — git pull --ff-only every cloned dep (clones missing ones shallow-full)
set -Eeuo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/common.sh"
mkdir -p "$DEPS_ROOT/logs" "$SRC_ROOT"
FAIL=()
for r in "$HERE"/recipes/*.sh; do
	name="$(basename "$r" .sh)"
	GIT_URL=""; GIT_BRANCH=""; SRC_URL=""
	# shellcheck disable=SC1090
	. "$r" 2>/dev/null || true
	dir="$SRC_ROOT/$name"
	if [[ -d "$dir/.git" ]]; then
		# recipe pinned to a tag: ensure it's checked out, never pull
		if [[ -n "${GIT_BRANCH:-}" ]] && git -C "$dir" rev-parse -q --verify "refs/tags/$GIT_BRANCH" >/dev/null 2>&1; then
			git -C "$dir" checkout -q "$GIT_BRANCH" 2>/dev/null || true
			log "pinned $name @ $GIT_BRANCH ($(git -C "$dir" rev-parse --short HEAD))"
			continue
		fi
		git -C "$dir" pull --ff-only >/dev/null 2>&1 \
			&& log "pulled $name -> $(git -C "$dir" rev-parse --short HEAD)" \
			|| { log "WARN pull failed: $name"; FAIL+=("$name"); }
	elif [[ -n "${GIT_URL:-}" ]]; then
		git clone ${GIT_BRANCH:+--branch "$GIT_BRANCH"} "$GIT_URL" "$dir" >/dev/null 2>&1 \
			&& log "cloned $name" \
			|| { log "WARN clone failed: $name"; FAIL+=("$name"); }
	elif [[ -n "${SRC_URL:-}" ]]; then
		# tarball-based recipe: fetch once so the deps jobs hit the cache
		if [[ -f "$dir/.tarball-done" ]]; then
			log "tarball cached: $name"
		else
			log "fetch tarball: $name"
			rm -rf "$dir"; mkdir -p "$dir"
			tflag=-xJz
			case "$SRC_URL" in
				*.tar.gz|*.tgz) tflag=-xz ;;
				*.tar.bz2)      tflag=-xj ;;
				*.tar.xz)       tflag=-xJ ;;
				*.tar.lz)       tflag=-xl ;;
			esac
			tmp="$SRC_ROOT/.$name.tarball"
			mapfile -t urls < <(mirror_urls "$SRC_URL")
			if fetch_url "$tmp" "${urls[@]}" \
				&& tar $tflag --strip-components=1 -C "$dir" < "$tmp"; then
				echo "$SRC_URL" > "$dir/.tarball-done"
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
[[ ${#FAIL[@]} -eq 0 ]] || { log "FAILED repos: ${FAIL[*]}"; exit 1; }
log "all sources synced"
