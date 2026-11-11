#!/bin/bash
# series.sh <debian version>: the patches/<series> directory for that Debian kernel.
# We only ever build Debian's kernel with our Mac patches, never a plain rebuild, so:
#   exit 0  prints the directory: we have patches for its upstream series;
#   exit 4  Debian is on an older series than our newest (forky lagging behind the series our
#           patches were moved to): nothing to build until it catches up;
#   exit 3  Debian is on a newer series than our newest: prints the newest directory, which
#           prepare.sh copies to the new series and the patches need porting forward;
#   exit 1  we have no patches at all, or the series lists none.
set -euo pipefail
repo=$(dirname "$(dirname "$(realpath "$0")")")
upstream=${1%%-*}
series=$(echo "${upstream%%~*}" | cut -d. -f1-2)
count() { grep -cv -e '^\s*$' -e '^#' "$1/series" || true; }
if [ -f "$repo/patches/$series/series" ]; then
    [ "$(count "$repo/patches/$series")" -gt 0 ] ||
        { echo "series: patches/$series/series lists no patches" >&2; exit 1; }
    echo "$repo/patches/$series"
    exit 0
fi
newest=$(find "$repo/patches" -mindepth 2 -maxdepth 2 -name series -printf '%h\n' | xargs -rn1 basename | sort -V | tail -1)
[ -n "$newest" ] || { echo "series: no patch series in $repo/patches" >&2; exit 1; }
if [ "$(printf '%s\n%s\n' "$series" "$newest" | sort -V | tail -1)" = "$newest" ]; then
    echo "series: Debian is on $series, older than our newest patches ($newest); nothing to build until it catches up" >&2
    exit 4
fi
echo "series: Debian is on $series but our newest patches are for $newest; they need porting forward" >&2
echo "$repo/patches/$newest"
exit 3
