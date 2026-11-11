#!/bin/bash
# debian-version.sh: the newest version of the linux source package in Debian forky, its point
# releases (forky) and its security updates (forky-security).
set -euo pipefail
for index in https://deb.debian.org/debian/dists/forky/main/source/Sources.xz \
    https://security.debian.org/debian-security/dists/forky-security/main/source/Sources.xz; do
    curl -fsSL "$index" | xz -d
done | awk '/^Package: / { p = ($2 == "linux") } p && /^Version: / { print $2 }' | sort -V | tail -1
