#!/bin/bash
# export-patches.sh <linux repo> <base> <branch> <series>: writes patches/<series>/ from a kernel
# branch, one patch per step of its first-parent history from <base>: a commit as itself, a
# merge as one patch carrying the merge message. The series then applies in order by
# construction. Our CI files and config fragments stay out; Debian's build replaces them. The
# project's former name in commit headers (branch names, image name) becomes Bande; code is
# never touched. Patches carry no commit hashes or git version, so exporting the same commits
# again, from any tree, changes nothing.
set -euo pipefail
linux=$(realpath "$1") base=$2 branch=$3 series=$4
repo=$(dirname "$(dirname "$(realpath "$0")")")
out=$repo/patches/$series
old=un$(printf bound)
exclude=(':(exclude).github' ':(exclude,glob)arch/arm64/configs/**' ':(top,exclude)CLAUDE.md')
mkdir -p "$out"
rm -f "$out"/*.patch
: > "$out/series"
n=0
git -C "$linux" rev-list --first-parent --reverse "$base..$branch" | while read -r commit; do
    subject=$(git -C "$linux" log -1 --format=%s "$commit" | sed -e "s/$old-/bande-/g" -e "s/${old^} /Bande /g")
    slug=$(printf '%s' "$subject" | tr -c 'A-Za-z0-9' '-' | tr -s '-' | sed 's/^-//; s/-$//' | cut -c1-52)
    n=$((n + 1))
    name=$(printf '%04d-%s.patch' "$n" "$slug")
    if git -C "$linux" rev-parse -q --verify "$commit^2" > /dev/null; then
        diff=$(git -C "$linux" diff --stat=72 --patch "$commit^1" "$commit" -- . "${exclude[@]}")
        [ -n "$diff" ] || continue
        {
            git -C "$linux" log -1 --format='From 0000000000000000000000000000000000000000 Mon Sep 17 00:00:00 2001%nFrom: %an <%ae>%nDate: %aD%nSubject: [PATCH] %s%n%n%b' "$commit"
            echo '---'
            printf '%s\n' "$diff"
        } > "$out/$name"
    else
        git -C "$linux" format-patch --stdout --stat=72 --zero-commit --no-signature "$commit^!" -- . "${exclude[@]}" > "$out/$name"
        grep -q '^diff --git' "$out/$name" || { rm "$out/$name"; continue; }
    fi
    perl -0pi -e 'my ($h, $rest) = split(/^---$/m, $_, 2); $h =~ s/'"$old"'-/bande-/g; $h =~ s/'"${old^}"' /Bande /g; $_ = $h . "---" . $rest' "$out/$name"
    echo "$name" >> "$out/series"
done
echo "export-patches: $(wc -l < "$out/series") patches in patches/$series from $(git -C "$linux" rev-parse --short "$branch")"
