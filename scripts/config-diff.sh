#!/bin/bash
# config-diff.sh <source dir>: run in debian:testing after build.sh compile.
# Proves our kernel is Debian's arm64-16k kernel plus config/apple.config (and the series'
# patches/<series>/apple.config when it has our patches): generates Debian's own arm64-16k
# config from the same source with Debian's build, and fails if any option Debian sets differs
# in our built config without being listed, or if a listed option didn't take effect. Options
# Debian doesn't have at all (the Apple drivers and what they enable) are only listed.
set -euo pipefail
src=$(realpath "$1")
repo=$(dirname "$(dirname "$(realpath "$0")")")
cd "$src"
DEB_BUILD_PROFILES="pkg.linux.notools nodoc pkg.linux.nokerneldbg noudeb" \
    make -s -f debian/rules.gen setup_arm64_none_arm64-16k > /dev/null
theirs=debian/build/build_arm64_none_arm64-16k/.config
ours=debian/build/build_arm64_none_apple-arm64-16k/.config
[ -f "$ours" ] || { echo "config-diff: no built apple-arm64-16k config in $src" >&2; exit 1; }
patches=$("$repo/scripts/series.sh" "$(dpkg-parsechangelog -S Version)")
wanted=$(mktemp)
cat "$repo/config/apple.config" ${patches:+"$patches/apple.config"} > "$wanted"

python3 - "$theirs" "$ours" "$wanted" <<'EOF'
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
print(f'config-diff: {len(wanted)} listed options, {len(new)} options Debian lacks: {" ".join(new)}')
if bad:
    print('config-diff: differs from Debian beyond the listed options:', *bad, sep='\n  ')
    sys.exit(1)
print('config-diff: identical to Debian arm64-16k apart from the listed options')
EOF
