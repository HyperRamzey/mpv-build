#!/bin/bash
# pull-all.sh — git pull --ff-only every cloned dep (clones missing ones shallow-full)
# Each pull/clone is retried (CI egress flakes); a repo that still fails
# after retries lands in FAIL[] and the run exits 1 with the list.
set -Eeuo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/common.sh"
mkdir -p "$DEPS_ROOT/logs" "$SRC_ROOT"
FAIL=()
retry() { # retry <tries> <desc> <cmd...> — up to N attempts, 5s apart.
	# The command's stdout/stderr is suppressed (pull/clone noise); the
	# retry diagnostics go to the log like everything else.
	local n="$1" desc="$2"; shift 2
	local i
	for ((i = 1; i <= n; i++)); do
		if "$@" >/dev/null 2>&1; then return 0; fi
		log "retry $i/$n failed: $desc"
		[[ $i -lt $n ]] && sleep 5
	done
	return 1
}
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
		retry 3 "pull $name" git -C "$dir" pull --ff-only \
			&& log "pulled $name -> $(git -C "$dir" rev-parse --short HEAD)" \
			|| { log "WARN pull failed: $name"; FAIL+=("$name"); }
	elif [[ -n "${GIT_URL:-}" ]]; then
		retry 3 "clone $name" git clone ${GIT_BRANCH:+--branch "$GIT_BRANCH"} "$GIT_URL" "$dir" \
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
