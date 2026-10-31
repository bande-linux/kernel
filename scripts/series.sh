#!/bin/bash
# series.sh <debian version>: the patches/<series> directory for that Debian kernel.
# Prints the directory when we have patches for its upstream series, prints nothing when the
# series is older than all of ours (Debian testing still lags behind: build without them),
# and exits 3 when it's newer than all of ours (the patches need porting forward).
set -euo pipefail
repo=$(dirname "$(dirname "$(realpath "$0")")")
upstream=${1%%-*}
series=$(echo "${upstream%%~*}" | cut -d. -f1-2)
if [ -f "$repo/patches/$series/series" ]; then
    echo "$repo/patches/$series"
    exit 0
fi
newest=$(find "$repo/patches" -mindepth 2 -maxdepth 2 -name series -printf '%h\n' | xargs -rn1 basename | sort -V | tail -1)
if [ -z "$newest" ] || [ "$(printf '%s\n%s\n' "$series" "$newest" | sort -V | tail -1)" = "$newest" ]; then
    echo "series: no patches for $series; Debian is behind our newest series ${newest:-none}, building without them" >&2
    exit 0
fi
echo "series: Debian is on $series but our newest patches are for $newest; they need porting forward" >&2
exit 3
