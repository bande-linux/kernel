#!/bin/bash
# published.sh: the version of bande-os-apple that the Bande archive serves, empty if none.
set -euo pipefail
curl -fsSL https://bande-linux.github.io/apt/dists/rolling/apple/binary-arm64/Packages.xz 2>/dev/null | xz -d 2>/dev/null |
    awk '/^Package: / { p = ($2 == "bande-os-apple") } p && /^Version: / { print $2 }' || true
