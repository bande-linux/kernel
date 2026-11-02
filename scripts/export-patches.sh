#!/bin/bash
# export-patches.sh <linux repo> <base> <branch> <series>: writes patches/<series>/ from a kernel
# branch without merges, one patch per commit from <base>. Our CI files and config fragments stay
# out; Debian's build replaces them. Patches carry no commit hashes or git version, so exporting
# the same commits again, from any tree, changes nothing.
set -euo pipefail
linux=$(realpath "$1") base=$2 branch=$3 series=$4
repo=$(dirname "$(dirname "$(realpath "$0")")")
out=$repo/patches/$series
exclude=(':(exclude).github' ':(exclude,glob)arch/arm64/configs/**' ':(top,exclude)CLAUDE.md')
mkdir -p "$out"
rm -f "$out"/*.patch
: > "$out/series"
n=0
git -C "$linux" rev-list --reverse "$base..$branch" | while read -r commit; do
    subject=$(git -C "$linux" log -1 --format=%s "$commit")
    slug=$(printf '%s' "$subject" | tr -c 'A-Za-z0-9' '-' | tr -s '-' | sed 's/^-//; s/-$//' | cut -c1-52)
    n=$((n + 1))
    name=$(printf '%04d-%s.patch' "$n" "$slug")
    git -C "$linux" format-patch --stdout --stat=72 --zero-commit --no-signature "$commit^!" -- . "${exclude[@]}" > "$out/$name"
    grep -q '^diff --git' "$out/$name" || { rm "$out/$name"; continue; }
    echo "$name" >> "$out/series"
done
echo "export-patches: $(wc -l < "$out/series") patches in patches/$series from $(git -C "$linux" rev-parse --short "$branch")"
