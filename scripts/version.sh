#!/bin/bash
# version.sh <debian version>: our version of that Debian kernel, <debian version>+bandeN, where
# N counts this repository's commits, so a change to the patches or config of the same Debian
# kernel always gives a newer version.
set -euo pipefail
repo=$(dirname "$(dirname "$(realpath "$0")")")
echo "${1:?usage: version.sh <debian version>}+bande$(git -C "$repo" rev-list --count HEAD)"
