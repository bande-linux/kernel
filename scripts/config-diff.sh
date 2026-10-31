#!/bin/bash
# config-diff.sh <out dir> <debian version>: run in debian:testing.
# Proves our kernel is Debian's arm64-16k kernel plus config/apple.config: compares our built
# config with the one Debian ships for the same version, and fails if any option Debian sets
# differs without being in apple.config, or if any line of apple.config didn't take effect.
# Options Debian doesn't have at all (new ones the Apple options make visible) are listed.
set -euo pipefail
out=$(realpath "$1") debver=$2
repo=$(dirname "$(dirname "$(realpath "$0")")")
work=$(mktemp -d)

config_of() {
    local dir=$1
    for deb in "$dir"/linux-base-*.deb "$dir"/linux-binary-*.deb; do
        [ -e "$deb" ] || continue
        dpkg-deb -x "$deb" "$work/x"
    done
    find "$work/x" -path '*/boot/config-*' -o -path '*/usr/lib/modules/*/config' | head -1
}

ours=$(config_of "$out"); cp "$ours" "$work/ours"; rm -rf "$work/x"
upstream=${debver%-*}
apt-get update -qq
names=$(apt-cache search --names-only "^linux-(base|binary-unsigned)-${upstream//./\\.}\+deb[0-9]+-arm64-16k\$" | awk '{print $1}')
[ -n "$names" ] || { echo "config-diff: Debian has no arm64-16k packages for $upstream" >&2; exit 1; }
mkdir -p "$work/debian"
(cd "$work/debian" && apt-get download -qq $names)
theirs=$(config_of "$work/debian")
[ -n "$theirs" ] || { echo "config-diff: no config in Debian's packages" >&2; exit 1; }

python3 - "$theirs" "$work/ours" "$repo/config/apple.config" <<'EOF'
import re, sys
def parse(path):
    vals = {}
    for line in open(path):
        m = re.match(r'(CONFIG_\w+)=(.*)', line) or re.match(r'# (CONFIG_\w+) is not set', line)
        if m:
            vals[m.group(1)] = m.group(2) if m.lastindex == 2 else 'n'
    return vals
theirs, ours, wanted = (parse(p) for p in sys.argv[1:])
bad = [f'{k}: apple.config asks {v}, built {ours.get(k, "n")}' for k, v in wanted.items() if ours.get(k, 'n') != v]
bad += [f'{k}: Debian {v}, ours {ours.get(k, "n")} (not in apple.config)'
        for k, v in theirs.items() if k not in wanted and k != 'CONFIG_BUILD_SALT' and ours.get(k, 'n') != v]
new = sorted(k for k in ours if k not in theirs and ours[k] != 'n')
print(f'config-diff: {len(wanted)} apple.config options, {len(new)} options Debian lacks: {" ".join(new)}')
if bad:
    print('config-diff: differs from Debian beyond apple.config:', *bad, sep='\n  ')
    sys.exit(1)
print('config-diff: identical to Debian arm64-16k apart from apple.config')
EOF
