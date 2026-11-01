#!/bin/bash
# local-build.sh <debian version> <dir> [step...]: the CI build on a Debian machine, without
# root or containers: a Debian testing chroot made with mmdebstrap's unshare mode, entered
# through a user namespace. Any Debian linux version works (testing, unstable, experimental),
# like follow-debian.yml's test-build dispatch; nothing is published. <dir> must be reachable by
# other users (/var/tmp/..., not under a private home), because the chroot belongs to your
# subordinate uids. Steps, all but clean by default:
#   chroot   make <dir>/chroot (once)
#   fetch    Debian's source into <dir>/work (emptied first), checked by apt
#   prepare  our flavour, release and patches (prepare.sh), from this checkout
#   compile  build the packages into <dir>/out (emptied first)
#   check    config-diff.sh
#   boot     qemu-boot.sh
#   clean    remove <dir>, chroot included
# The version is scripts/version.sh's, from this checkout's commit count.
set -euo pipefail
debver=$1 dir=$(realpath -m "$2"); shift 2
repo=$(dirname "$(dirname "$(realpath "$0")")")
version=$("$repo/scripts/version.sh" "$debver")
steps=("$@"); [ ${#steps[@]} -gt 0 ] || steps=(chroot fetch prepare compile check boot)

# Root in a user namespace: your uid is root, your subordinate uids are the rest.
as_root() { unshare --map-auto --map-root-user --mount --pid --fork --kill-child "$@"; }
in_chroot() {
    mkdir -p "$dir/repo" "$dir/work" "$dir/out"
    rsync -a --delete --exclude .git "$repo/" "$dir/repo/"
    as_root bash -c '
        d=$0; c=$d/chroot
        mount -t proc proc "$c/proc"
        mount --rbind /dev "$c/dev"
        for m in repo work out; do mkdir -p "$c/$m"; mount --bind "$d/$m" "$c/$m"; done
        cp /etc/resolv.conf "$c/etc/resolv.conf"
        exec /usr/sbin/chroot "$c" env -i PATH=/usr/sbin:/usr/bin:/sbin:/bin HOME=/root LANG=C.UTF-8 "$@"
    ' "$dir" "$@"
}

for step in "${steps[@]}"; do
    echo "local-build: $step ($version)"
    case $step in
    chroot)
        [ -d "$dir/chroot/etc" ] && continue
        mkdir -p "$dir"
        chmod 755 "$dir"
        mmdebstrap --mode=unshare --variant=buildd --include=ca-certificates testing "$dir/chroot"
        ;;
    fetch)
        as_root rm -rf "$dir/work"
        in_chroot /repo/scripts/build.sh fetch "$debver" /work
        ;;
    prepare) in_chroot sh -c '/repo/scripts/prepare.sh /work/linux-*/ "$0"' "$version" ;;
    compile)
        as_root rm -rf "$dir/out"
        in_chroot /repo/scripts/build.sh compile "$version" /work /out
        ;;
    check) in_chroot sh -c '/repo/scripts/config-diff.sh /work/linux-*/' ;;
    boot) in_chroot /repo/scripts/qemu-boot.sh /out ;;
    clean) as_root rm -rf "$dir" ;;
    *) echo "local-build: unknown step $step" >&2; exit 2 ;;
    esac
done
