# Bande kernel

Debian testing's kernel with the Bande patches for the Mac mini M2.

This repository holds no kernel tree. It holds what we add to Debian's: our patches, the few
config options the Mac needs and a Debian flavour, `apple-arm64-16k`. Whenever Debian testing
gets a new `linux` package, `follow-debian.yml` builds that same source with Debian's own build
system, and the Bande archive publishes it to the `apple` component.

| Path | What it is |
|---|---|
| `patches/` | our patches and their `series`, applied after Debian's own `debian/patches/series` |
| `config/apple.config` | the only options added to Debian's `arm64-16k` config |
| `config/apple-pending.config` | options that need our patches; they move into `apple.config` with them |
| `debian/bande-os-apple/` | the `bande-os-apple` metapackage: `bande-os`, the Apple kernel, and an apt pin that keeps Debian's own kernels off the Mac |
| `scripts/` | the build, run the same way by CI and on the mini |

## What gets built

From `linux <debian-version>` in testing, `<debian-version>+bandeN` (N counts this repository's
commits, so any change here gives a newer version):

- `linux-image-<abi>-apple-arm64-16k`, with its `-binary`, `-modules` and `-base` parts, and the
  metapackages `linux-image-apple-arm64-16k` and `linux-base-apple-arm64-16k`. The ABI is
  `<upstream>+bande`, so no package name meets Debian's.
- `bande-os-apple`.

The flavour is Debian's `arm64-16k` with `config/apple.config` on top and signing disabled (Macs
have no UEFI Secure Boot). Headers are built but not published yet.

## How a build works

`follow-debian.yml` runs hourly and on dispatch:

1. `scripts/debian-version.sh` reads testing's `linux` version, `scripts/version.sh` our version
   of it, and `scripts/published.sh` the version the archive serves. Equal: nothing to do.
2. `scripts/build.sh fetch` gets Debian's source through apt, which checks it against testing's
   signed Release.
3. `scripts/prepare.sh` adds the flavour, the `bande` release and our patches. A patch that no
   longer applies stops it with exit 3; the workflow then runs Claude Code to refresh our
   patches against the new source, prepares again and commits the refreshed patches to `main`.
4. `scripts/build.sh compile` builds the flavour and `bande-os-apple`.
5. Checks: `scripts/config-diff.sh` proves the config is Debian's plus `apple.config` and nothing
   else, and `scripts/qemu-boot.sh` boots the kernel to userspace in QEMU (16k pages, UEFI).
6. It uploads `bande-debs-arm64` and `bande-version-<version>`, which the archive's scheduled
   publish picks up.

## Building on the mini

```
sudo mmdebstrap --variant=buildd testing chroot
# inside the chroot, with this repository at /repo:
/repo/scripts/build.sh fetch <debian-version> /work
/repo/scripts/prepare.sh /work/linux-<upstream> <version>
/repo/scripts/build.sh compile <version> /work /out
```

A full build needs about 20 GB of disk.

## Licence

MIT OR Apache-2.0 for this repository's own files; the patches carry the licence of the kernel
files they change (GPL-2.0).
