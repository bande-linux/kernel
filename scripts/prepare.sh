#!/bin/bash
# prepare.sh <debian source dir> <version>
# Turns Debian's linux source into ours: the apple-arm64-16k flavour on top of Debian's own
# arm64-16k config, our patches after Debian's own, and the bande release with its +bande ABI.
# Exits 3 when one of our patches doesn't apply, leaving quilt at the failing patch.
set -euo pipefail
src=$(realpath "$1") version=$2
repo=$(dirname "$(dirname "$(realpath "$0")")")
cd "$src"

python3 - debian/config/defines.toml debian/config/arm64/defines.toml <<'EOF'
import sys
top, arm64 = sys.argv[1:]
s = open(top).read()
if "name_regex = 'bande'" not in s:
    i = s.index('[[debianrelease]]')
    s = s[:i] + """[[debianrelease]]
name_regex = 'bande'
abi_suffix = '+bande'
revision_regex = '\\d+(\\.\\d+)?\\+bande\\d+'

""" + s[i:]
    open(top, 'w').write(s)
s = open(arm64).read()
if "name = 'apple-arm64-16k'" not in s:
    s += """
[[flavour]]
name = 'apple-arm64-16k'
[flavour.build]
config = ['arm64/config-page-16k', 'arm64/config.apple']
enable_signed = false
[flavour.description]
hardware = 'Apple Silicon Macs with 16k pages'
hardware_long = 'Apple Silicon Macs (Mac mini M2), with the Bande Apple patches'
"""
    open(arm64, 'w').write(s)
EOF
cp "$repo/config/apple.config" debian/config/arm64/config.apple

apple=debian/patches/features/arm64/apple
mkdir -p "$apple"
while read -r patch; do
    [ -n "$patch" ] && [ "${patch#\#}" = "$patch" ] || continue
    cp "$repo/patches/$patch" "$apple/"
    grep -qxF "features/arm64/apple/$patch" debian/patches/series ||
        echo "features/arm64/apple/$patch" >> debian/patches/series
done < "$repo/patches/series"
export QUILT_PATCHES=debian/patches QUILT_PC=.pc
if ! quilt push -a -q --fuzz=0 >/dev/null; then
    [ "$(quilt next 2>/dev/null)" = "" ] || { echo "prepare: $(quilt next) does not apply" >&2; exit 3; }
fi

if [ "$(dpkg-parsechangelog -S Version)" != "$version" ]; then
    DEBEMAIL=ci@bande-linux.github.io DEBFULLNAME="Bande CI" \
        dch -v "$version" -D bande --force-distribution "Build the apple-arm64-16k flavour with the Bande patches." 2>/dev/null
fi
debian/rules debian/control-real > /dev/null 2>&1 || true
grep -q '^Package: linux-image-apple-arm64-16k$' debian/control ||
    { echo "prepare: debian/control has no apple-arm64-16k flavour" >&2; exit 1; }
echo "prepare: $(dpkg-parsechangelog -S Version), $(grep -c "^features/arm64/apple/" debian/patches/series) Bande patches"
