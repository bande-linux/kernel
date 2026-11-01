#!/bin/bash
# dev-tree.sh <debian source dir> <tree> [<series>]: a git working tree to change our patches in.
# Copies Debian's linux source with Debian's own patches applied (as apt-get source or
# build.sh fetch unpacks it, before prepare.sh) to <tree>, commits it as the base, tags it
# debian-base, and applies patches/<series>/ on top with git am, one commit per patch. The
# series defaults to the one scripts/series.sh picks for the source's version. If a patch
# doesn't apply, it stops there with git am in progress: fix it, `git am --continue`, then
# run this again with the same arguments to apply the rest. Export the commits back with
# scripts/export-tree.sh.
set -euo pipefail
src=$(realpath "$1") tree=$(realpath -m "$2")
repo=$(dirname "$(dirname "$(realpath "$0")")")
version=$(dpkg-parsechangelog -l "$src/debian/changelog" -S Version)
if [ -n "${3:-}" ]; then
    patches=$repo/patches/$3
else
    patches=$("$repo/scripts/series.sh" "$version")
fi
[ -n "$patches" ] && [ -f "$patches/series" ] || { echo "dev-tree: no patch series for $version" >&2; exit 1; }
[ ! -d "$src/.pc/features/arm64/apple" ] && ! grep -q '^features/arm64/apple/' "$src/debian/patches/series" ||
    { echo "dev-tree: $src already has our patches (prepare.sh ran); use a fresh source" >&2; exit 1; }

if [ ! -d "$tree/.git" ]; then
    mkdir -p "$tree"
    tar -C "$src" --exclude=./debian --exclude=./.pc -cf - . | tar -C "$tree" -xf -
    git -C "$tree" init -q
    # git am needs a committer; the exported patches keep only the author.
    git -C "$tree" config user.name >/dev/null || git -C "$tree" config user.name "$(git -C "$repo" config user.name || echo Bande)"
    git -C "$tree" config user.email >/dev/null || git -C "$tree" config user.email "$(git -C "$repo" config user.email || echo dev@bande-linux.invalid)"
    git -C "$tree" add -A -f
    git -C "$tree" -c user.name=Debian -c user.email=debian-kernel@lists.debian.org \
        commit -q -m "Debian linux $version" -m "Debian's source with Debian's own patches applied."
    git -C "$tree" tag debian-base
fi
cd "$tree"
[ ! -d .git/rebase-apply ] || { echo "dev-tree: git am is in progress in $tree; finish it first" >&2; exit 1; }

# Resume after the patches already applied: commits on top of debian-base, in series order.
done_count=$(git rev-list --count debian-base..HEAD)
n=0
while read -r patch; do
    [ -n "$patch" ] && [ "${patch#\#}" = "$patch" ] || continue
    n=$((n + 1))
    [ $n -gt "$done_count" ] || continue
    git am -q --keep-cr --keep-non-patch --committer-date-is-author-date "$patches/$patch" || {
        echo "dev-tree: $patch does not apply; fix it, git am --continue, then rerun dev-tree.sh" >&2
        exit 1
    }
done < "$patches/series"
echo "dev-tree: $tree, $(git rev-list --count debian-base..HEAD) patches on Debian linux $version"
