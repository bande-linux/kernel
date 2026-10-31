#!/bin/bash
# debian-version.sh: the version of the linux source package in Debian testing.
set -euo pipefail
curl -fsSL https://deb.debian.org/debian/dists/testing/main/source/Sources.xz | xz -d |
    awk '/^Package: / { p = ($2 == "linux") } p && /^Version: / { print $2 }' | sort -V | tail -1
