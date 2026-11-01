#!/bin/bash
# export-tree.sh <tree> [<series>]: writes the commits of a dev-tree.sh tree back into
# patches/<series>/, one patch per commit from debian-base to HEAD (scripts/export-patches.sh),
# keeping the series' apple.config. The series defaults to the one the tree was made for.
set -euo pipefail
tree=$(realpath "$1")
repo=$(dirname "$(dirname "$(realpath "$0")")")
if [ -n "${2:-}" ]; then
    series=$2
else
    version=$(git -C "$tree" log -1 --format=%s debian-base | sed 's/^Debian linux //')
    series=$(basename "$("$repo/scripts/series.sh" "$version")")
fi
[ -z "$(git -C "$tree" status --porcelain --untracked-files=no)" ] ||
    { echo "export-tree: $tree has uncommitted changes; commit them first" >&2; exit 1; }
[ "$(git -C "$tree" rev-list --merges --count debian-base..HEAD)" = 0 ] ||
    { echo "export-tree: $tree has merge commits; rebase them away first" >&2; exit 1; }
exec "$repo/scripts/export-patches.sh" "$tree" debian-base HEAD "$series"
