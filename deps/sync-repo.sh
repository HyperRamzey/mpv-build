#!/bin/bash
# sync-repo.sh [-q] [-s] <dir> [url] [branch]
#
#   -q  quiet: only failures and the final HEAD are printed
#   -s  also sync submodules (--init --recursive) after the checkout
#
# Put <dir> on the upstream tip of its default branch. Used by every code path
# that decides which upstream sources get built:
#   deps/common.sh sync_src()  - per-dep sync, runs in the deps job
#   deps/pull-all.sh            - warms the shared src cache (sync-sources job)
#   build-libplacebo-<t>.sh     - libplacebo, built after build-deps.sh
#   the CI ffmpeg / mpv jobs    - the two repos nobody else refreshes
#
# WHY this exists instead of `git pull --ff-only`: ff-only is best-effort in a
# way that silently ships stale binaries. It fails on a detached HEAD (which is
# what a cache-restored clone often is), on a renamed/deleted default branch, and
# on every upstream force-push or rebase of master — and the old callers answered
# that failure with "keeping HEAD" / "|| true" and kept compiling whatever was
# there. The stamp cache then recorded the stale HEAD as "built", so the release
# was reproducible and wrong. A fetch failure had the same effect: indistinguishable
# from "upstream did not move".
#
# Contract: on success, <dir>'s tracked tree IS origin/<branch> at fetch time.
#   * <dir> missing           -> git clone (url required)
#   * branch names a TAG      -> checked out as-is, never moved (pinned recipes)
#   * branch not given        -> origin/HEAD, else the current branch if origin
#                                still has it, else master/main
#   * dirty tracked files     -> the local patches in deps/patches (gavl,
#     libmysofa, librtmp, libvpl, libxvid) are stashed across the checkout and
#     popped back afterwards; a pop that conflicts is FATAL, never silent
#   * untracked files         -> left alone: recipes build in-tree (cargo
#     target/, meson _build/), so `git clean` would throw away real work
#   * fetch fails             -> FATAL (3 retries). Never "upstream has no news"
set -Eeuo pipefail

QUIET=0 SUBMODULES=0
while [[ ${1:-} == -* && $# -gt 0 ]]; do
	case "$1" in
	-q) QUIET=1 ;;
	-s) SUBMODULES=1 ;;
	-h | --help)
		sed -n '2,30p' "$0"
		exit 0
		;;
	*)
		printf 'sync-repo.sh: unknown flag %s\n' "$1" >&2
		exit 2
		;;
	esac
	shift
done

DIR="${1:?usage: sync-repo.sh [-q] [-s] <dir> [url] [branch]}"
URL="${2:-}"
WANT="${3:-}"

# same log line as deps/common.sh so the build log stays one voice; workflows
# call this outside a deps build, so log() cannot be borrowed from common.sh.
# NOTE: every conditional here is an `if`, never a trailing `((x)) && y`: under
# set -e a `&&` list whose left side is false kills the whole script, and that
# bit this script on its first quiet-mode log call.
log() {
	if ((!QUIET)); then
		printf '\033[1;36m[deps]\033[0m %s\n' "$*"
	fi
}
die() {
	printf '\033[1;31m[deps:FATAL]\033[0m %s\n' "$*" >&2
	exit 1
}
name() { basename "$DIR"; }

# 3 tries, 5s apart: CI egress flakes, and a flaky fetch must not be allowed to
# look like "no new commits" (that is the stale-build bug this script removes)
retry() {
	local n="$1" desc="$2" i
	shift 2
	for ((i = 1; i <= n; i++)); do
		if "$@" >/dev/null 2>&1; then return 0; fi
		if ((!QUIET)); then
			printf '\033[1;33m[deps]\033[0m retry %d/%d failed: %s\n' \
				"$i" "$n" "$desc" >&2
		fi
		if ((i < n)); then sleep 5; fi
	done
	return 1
}

if [[ ! -d "$DIR/.git" ]]; then
	[[ -n "$URL" ]] || die "$(name): no clone at $DIR and no url given"
	log "clone $(name) <- $URL${WANT:+ ($WANT)}"
	retry 3 "clone $(name)" git clone ${WANT:+--branch "$WANT"} "$URL" "$DIR" ||
		die "$(name): clone failed after 3 tries ($URL)"
fi

# a recipe that switched forks (or a workflow whose REPO var was repointed) must
# not keep pulling the old origin forever: the cached clone's remote wins over
# the URL the caller passes, which is one more way to build a stale tree
if [[ -n "$URL" ]]; then
	CUR=$(git -C "$DIR" remote get-url origin 2>/dev/null || echo "")
	if [[ -n "$CUR" && "$CUR" != "$URL" ]]; then
		log "origin moved $(name): $CUR -> $URL"
		git -C "$DIR" remote set-url origin "$URL" ||
			die "$(name): could not repoint origin at $URL"
	fi
fi
log "fetch $(name) (origin)"
retry 3 "fetch $(name)" git -C "$DIR" fetch --prune --tags --force origin ||
	die "$(name): fetch failed after 3 tries — refusing to assume upstream is unchanged"

# a branch name that is really a tag stays put (pinned recipes: openapv, etc.)
TAG=""
if [[ -n "$WANT" ]]; then
	if git -C "$DIR" rev-parse -q --verify "refs/tags/$WANT" >/dev/null 2>&1; then
		TAG="$WANT"
	elif ! git -C "$DIR" show-ref -q --verify "refs/remotes/origin/$WANT"; then
		# neither a tag nor a branch upstream: say so instead of letting
		# `checkout -B` fail with "refs/remotes/origin/X is not a commit"
		die "$(name): pinned to '$WANT' but origin has neither a tag nor a branch '$WANT' (upstream renamed or dropped it — update GIT_BRANCH in the recipe)"
	fi
fi

BRANCH=""
if [[ -z "$TAG" ]]; then
	if [[ -n "$WANT" ]]; then
		BRANCH="$WANT"
	else
		BRANCH=$(git -C "$DIR" symbolic-ref -q --short refs/remotes/origin/HEAD 2>/dev/null |
			sed 's#^origin/##')
		if [[ -z "$BRANCH" || "$BRANCH" == "HEAD" ]]; then
			# no origin/HEAD (fresh clone of an old git, or a cache-restored
			# tree): prefer whatever branch we are on, then master/main
			BRANCH=$(git -C "$DIR" rev-parse --abbrev-ref HEAD 2>/dev/null || true)
			[[ -n "$BRANCH" && "$BRANCH" != "HEAD" ]] || BRANCH=""
			[[ -n "$BRANCH" ]] || BRANCH=master
		fi
		if ! git -C "$DIR" show-ref -q --verify "refs/remotes/origin/$BRANCH"; then
			BRANCH=""
		fi
		if [[ -z "$BRANCH" ]]; then
			# nothing usable locally — ask the remote what HEAD points at
			BRANCH=$(git -C "$DIR" ls-remote --symref origin HEAD 2>/dev/null |
				sed -n 's#^ref: refs/heads/\(\S*\).*#\1#p')
			[[ -n "$BRANCH" ]] || die "$(name): cannot resolve origin's default branch"
		fi
	fi
fi

STASHED=0
# --ignore-submodules=all: a submodule whose worktree was built into or left
# dirty is not a reason to stash the whole parent tree, and stashing it wedges
# the next checkout. Submodule state is reconciled by `submodule update` below.
if [[ -z "$TAG" ]] &&
	[[ -n $(git -C "$DIR" status --porcelain --untracked-files=no --ignore-submodules=all) ]]; then
	# deps/patches are applied in-tree by the recipes; carry them across the
	# checkout instead of letting the reset wipe them
	log "stash $(name) (local patches in tree)"
	git -C "$DIR" stash push -q -m "sync-repo: local mods before upstream sync" ||
		die "$(name): could not stash local modifications"
	STASHED=1
fi

if [[ -n "$TAG" ]]; then
	log "pinned $(name) @ $TAG ($(git -C "$DIR" rev-parse --short HEAD))"
	# no -f: a pinned tree with local modifications must fail loudly here rather
	# than have them silently discarded
	git -C "$DIR" checkout -q "$TAG" ||
		die "$(name): cannot check out pinned $TAG — the tree has local modifications or the tag moved; inspect $DIR"
else
	BEFORE=$(git -C "$DIR" rev-parse --short HEAD 2>/dev/null || echo none)
	# -B does the whole job ff-only could not: re-attach a detached HEAD, adopt
	# a renamed branch, and follow a force-pushed master
	git -C "$DIR" checkout -q -B "$BRANCH" "refs/remotes/origin/$BRANCH" ||
		die "$(name): checkout of origin/$BRANCH failed"
	AFTER=$(git -C "$DIR" rev-parse --short HEAD)
	if [[ "$BEFORE" == "$AFTER" ]]; then
		log "up to date $(name) ($BRANCH @ $AFTER)"
	else
		log "updated $(name) $BEFORE -> $AFTER ($BRANCH)"
	fi
fi

if ((SUBMODULES)) && [[ -z "$TAG" ]] && [[ -f "$DIR/.gitmodules" ]]; then
	log "submodules $(name)"
	retry 3 "submodules $(name)" \
		git -C "$DIR" submodule update --init --recursive --force ||
		die "$(name): submodule update failed after 3 tries"
fi

# Self-check, and the reason this script exists: prove the tree being handed back
# IS the upstream tip, not merely one that a pull was attempted on. A pinned
# branch that upstream renamed dies here too, so "latest master" can never
# silently become "latest something-else".
if [[ -n "$TAG" ]]; then
	WANT_REF="refs/tags/$TAG"
else
	WANT_REF="refs/remotes/origin/$BRANCH"
fi
GOT=$(git -C "$DIR" rev-parse HEAD 2>/dev/null || echo none)
# ^{commit} matters for tags: refs/tags/v1 on an ANNOTATED tag is the tag
# object, whose sha is not what HEAD checks out — comparing raw would abort
# every pinned-tag recipe (openapv) on a pin that is perfectly correct
EXP=$(git -C "$DIR" rev-parse "$WANT_REF^{commit}" 2>/dev/null || echo none)
if [[ "$GOT" != "$EXP" ]]; then
	die "$(name): HEAD $GOT is not $WANT_REF ($EXP) after checkout — refusing to return a tree that is not upstream's tip"
fi
log "tip $(name) ${TAG:-$BRANCH}@${GOT:0:12} == ${WANT_REF}"
if ((STASHED)); then
	if ! git -C "$DIR" stash pop -q; then
		# A conflicted tree would wedge every later run too (the next stash
		# refuses to push on unmerged paths), so leave the tree clean at
		# upstream HEAD and hand the failure to the recipe, which reports
		# "upstream drift?" on its own `git apply`. The patch itself is not
		# lost — it lives in deps/patches/, which is how it got here.
		git -C "$DIR" reset -q --hard
		git -C "$DIR" stash drop -q stash@{0} 2>/dev/null || true
		die "$(name): local patch in $DIR no longer applies on $BRANCH — tree left clean at upstream HEAD. Re-check deps/patches against upstream and re-run; the recipe re-applies the patch on the next build."
	fi
	log "restored $(name) local patches"
fi

if ((!QUIET)); then
	# machine-readable summary: <dir>\t<full sha>\t<branch-or-tag>
	printf '%s\t%s\t%s\n' "$DIR" "$(git -C "$DIR" rev-parse HEAD)" \
		"${TAG:-$BRANCH}"
fi
