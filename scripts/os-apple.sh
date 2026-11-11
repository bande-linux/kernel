#!/bin/bash
# os-apple.sh <version> <out dir>: builds bande-os-apple, the metapackage that makes a Debian
# forky install a Bande install for the Mac mini M2. It pulls in the Apple kernel and keeps
# Debian's own kernels, which can't run the Mac's hardware, from being installed beside it.
set -euo pipefail
version=$1 out=$(realpath -m "$2")
repo=$(dirname "$(dirname "$(realpath "$0")")")
root=$(mktemp -d)
mkdir -p "$root/DEBIAN" "$root/etc/apt/preferences.d" "$root/usr/share/doc/bande-os-apple"
cp "$repo/debian/bande-os-apple/preferences" "$root/etc/apt/preferences.d/bande-apple-kernel"
cp "$repo/LICENSE-MIT" "$root/usr/share/doc/bande-os-apple/copyright"
sed "s/@VERSION@/$version/" "$repo/debian/bande-os-apple/control" > "$root/DEBIAN/control"
echo /etc/apt/preferences.d/bande-apple-kernel > "$root/DEBIAN/conffiles"
mkdir -p "$out"
dpkg-deb --root-owner-group -Zxz --build "$root" "$out/bande-os-apple_${version}_arm64.deb" > /dev/null
rm -rf "$root"
