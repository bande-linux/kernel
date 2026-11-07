#!/bin/bash
# avd-packages.sh <version> <out dir>: builds what hardware video decode on the Mac needs next to the
# kernel's avd driver. bande-avd-firmware is the open coprocessor firmware (AsahiLinux/avd-fw, MIT).
# bande-avd-gstreamer is just the v4l2codecs and videoparsersbad plugins of Debian's gst-plugins-bad:
# the whole package would pull GTK 3 and SDL into the desktop. They install in a folder of their own
# in GStreamer's plugin path, so they can sit beside Debian's package.
set -euo pipefail
version=$1 out=$(realpath -m "$2")
repo=$(dirname "$(dirname "$(realpath "$0")")")
firmware_commit=c870554fce20b9ee5ac46885c698d11e6a313948
multiarch=$(dpkg-architecture -qDEB_HOST_MULTIARCH)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
mkdir -p "$out"

package() {
    local name=$1 root=$2 depends=$3
    mkdir -p "$root/DEBIAN" "$root/usr/share/doc/$name"
    cp "$repo/debian/bande-avd/$name.copyright" "$root/usr/share/doc/$name/copyright"
    sed -e "s/@VERSION@/$version/" -e "s/@DEPENDS@/$depends/" "$repo/debian/bande-avd/$name.control" > "$root/DEBIAN/control"
    dpkg-deb --root-owner-group -Zxz --build "$root" "$out/${name}_${version}_arm64.deb" > /dev/null
}

git init -q "$work/fw"
git -C "$work/fw" fetch -q --depth 1 https://github.com/AsahiLinux/avd-fw "$firmware_commit"
git -C "$work/fw" checkout -q FETCH_HEAD
(cd "$work/fw" && meson setup -q build --cross-file arm-none-eabi-gcc.ini -Dvideo-codecs=all --prefix=/usr && ninja -C build -v > /dev/null)
root=$work/firmware-root
install -D -m 644 "$work/fw/build/avd-fw-v3-t1.bin" "$root/usr/lib/firmware/apple/avd-fw-v3-t1.bin"
package bande-avd-firmware "$root" ""

(cd "$work" && apt-get source -qq gst-plugins-bad1.0 > /dev/null)
source=$(find "$work" -maxdepth 1 -type d -name 'gst-plugins-bad1.0-*' | head -1)
(cd "$source" && meson setup -q build --prefix=/usr --libdir="lib/$multiarch" --buildtype=release \
    -Dauto_features=disabled -Dgpl=disabled -Dexamples=disabled -Dtests=disabled -Ddoc=disabled \
    -Dintrospection=disabled -Dnls=disabled -Dtools=disabled \
    -Dv4l2codecs=enabled -Dvideoparsers=enabled &&
    ninja -C build > /dev/null)
root=$work/gstreamer-root
plugins=$root/usr/lib/$multiarch/gstreamer-1.0/bande-avd
install -D -m 644 "$source/build/sys/v4l2codecs/libgstv4l2codecs.so" "$plugins/libgstv4l2codecs.so"
install -D -m 644 "$source/build/gst/videoparsers/libgstvideoparsersbad.so" "$plugins/libgstvideoparsersbad.so"
strip --strip-unneeded "$plugins"/*.so
mkdir -p "$work/debian" && touch "$work/debian/control"
depends=$(cd "$work" && dpkg-shlibdeps -O -l"$source/build/gst-libs/gst/codecparsers" "$plugins"/*.so 2>/dev/null | sed -n 's/^shlibs:Depends=//p')
package bande-avd-gstreamer "$root" "$depends"
ls -l "$out"/bande-avd-*
