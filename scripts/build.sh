#!/bin/bash
# build.sh: run as root in debian:testing, in three steps sharing <work dir>.
#   build.sh fetch <debian version> <work dir>   Debian's linux source through apt, which checks
#                                                it against testing's signed Release
#   (then scripts/prepare.sh <work dir>/linux-* <version>)
#   build.sh compile <version> <work dir> <out>   the apple-arm64-16k flavour with Debian's own
#                                                build, plus bande-os-apple, into <out>
set -euo pipefail
repo=$(dirname "$(dirname "$(realpath "$0")")")
export DEBIAN_FRONTEND=noninteractive
profiles="pkg.linux.notools nodoc pkg.linux.nokerneldbg noudeb"

case ${1:-} in
fetch)
    debver=$2 work=$(realpath -m "$3")
    sed -i 's/^Types: deb$/Types: deb deb-src/' /etc/apt/sources.list.d/debian.sources
    printf 'Types: deb-src\nURIs: http://deb.debian.org/debian\nSuites: unstable experimental\nComponents: main\nSigned-By: /usr/share/keyrings/debian-archive-keyring.pgp\n' \
        > /etc/apt/sources.list.d/debian-newer-src.sources
    apt-get update -qq
    apt-get install -y -qq --no-install-recommends devscripts quilt python3 python3-dacite \
        python3-jinja2 debhelper dpkg-dev fakeroot ca-certificates > /dev/null
    mkdir -p "$work"
    cd "$work"
    apt-get source -qq "linux=$debver" > /dev/null
    ls -d "$work"/linux-*/
    ;;
compile)
    version=$2 work=$(realpath "$3") out=$(realpath -m "$4")
    src=$(ls -d "$work"/linux-*/ | head -1)
    cd "$src"
    apt-get build-dep -y -qq --build-profiles="${profiles// /,}" . > /dev/null
    start=$SECONDS
    DEB_BUILD_PROFILES="$profiles" DEB_BUILD_OPTIONS="parallel=$(nproc) nocheck" \
        make -f debian/rules.gen binary-arch_arm64_none_apple-arm64-16k
    echo "build: $(( (SECONDS - start) / 60 )) min"
    mkdir -p "$out"
    for deb in "$work"/linux-*-apple-*_"$version"_arm64.deb; do
        case $(dpkg-deb -f "$deb" Package) in
            linux-headers-*) ;;
            *) cp "$deb" "$out/" ;;
        esac
    done
    "$repo/scripts/os-apple.sh" "$version" "$out"
    ls -l "$out"
    ;;
*)
    sed -n '2,7s/^# \{0,1\}//p' "$0" >&2
    exit 2
    ;;
esac
