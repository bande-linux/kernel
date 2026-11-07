# Bande kernel

Debian testing's kernel with the Bande patches for the Mac mini M2.

This repository builds only the kernel for Apple machines: Debian's `linux` source with our Mac
patches. Everyone else runs Debian's own kernel, so we never build or publish Debian's kernel
without our patches. This repository holds no kernel tree. It holds what we add to Debian's: our
patches, the few config options the Mac needs and a Debian flavour, `apple-arm64-16k`. Whenever
Debian testing gets a new `linux` package of a series we have patches for, `follow-debian.yml`
builds that same source with Debian's own build system, and the Bande archive publishes it to
the `apple` component.

All kernel development for the Mac happens here, as changes to `patches/`. The former kernel
tree, `bande-linux/linux`, is legacy: kept for its history, not developed any more.

| Path | What it is |
|---|---|
| `patches/<series>/` | our patches for one upstream series (`7.3`) with their `series`, applied after Debian's own, and `apple.config`, the options that need them |
| `patches/<series>/held/<topic>/` | finished patches not in the build yet, each topic with its own `series` (and `apple.config`), applying on top of the series |
| `config/apple.config` | the options added to Debian's `arm64-16k` config on every series |
| `debian/bande-os-apple/` | the `bande-os-apple` metapackage: `bande-desktop`, the Apple kernel, and an apt pin that keeps Debian's own kernels off the Mac |
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

1. `scripts/debian-version.sh` reads testing's `linux` version and `scripts/series.sh` our patch
   series for it. When testing is on an older series than our newest patches (now: testing has
   7.2, our patches are for 7.3), the run stops there with "no build: our patches are for a
   newer series": no build, nothing published. It resumes by itself in the first hourly run
   after testing reaches the series. Otherwise `scripts/version.sh` gives our version of it and
   `scripts/published.sh` the version the archive serves. Equal: nothing to do.
2. `scripts/build.sh fetch` gets Debian's source through apt, which checks it against testing's
   signed Release.
3. `scripts/prepare.sh` adds the flavour, the `bande` release and our patches for Debian's
   series, and fails rather than leave any of them out. For a newer series than ours it first
   starts `patches/<series>/` as a copy of our newest. A patch that doesn't apply stops it with
   exit 3. The workflow then runs Claude Code (secret `CLAUDE_CODE_OAUTH_TOKEN`) to refresh our
   patches against the new source (`scripts/refresh-prompt.md`), and prepares again from a
   fresh source. If that still fails, the run fails and nothing is published or committed. If
   it passes, the refreshed series is pushed to a `refresh/linux-<version>` branch, so the work
   survives a run that hits the time limit.
4. `scripts/build.sh compile` builds the flavour and `bande-os-apple`.
5. Checks: `scripts/config-diff.sh` generates Debian's own `arm64-16k` config from the same source
   and proves ours is that plus the listed options and nothing else, and `scripts/qemu-boot.sh` boots the kernel to userspace in QEMU (16k pages, UEFI).
6. Only after the checks, a refreshed or newly started series is committed to `main` (and its
   `refresh/` branch deleted). It uploads `bande-debs-arm64` and `bande-version-<version>`,
   which the archive's scheduled publish picks up.

## Changing a patch

Patches are changed in a git tree made from Debian's source with our series applied as
commits, then exported back. On the mini (any Debian machine works; no root needed):

```
# Debian's source, from a build directory (see Building on the mini) or apt-get source:
scripts/local-build.sh 7.3~rc7-1~exp1 /var/tmp/bande-kernel chroot fetch
scripts/dev-tree.sh /var/tmp/bande-kernel/work/linux-7.3~rc7 ~/src/kernel-7.3
cd ~/src/kernel-7.3
# change a commit (git rebase -i, git commit --fixup + autosquash, git am a new patch, ...)
cd -
scripts/export-tree.sh ~/src/kernel-7.3
git diff patches/                   # only the patches you meant to change
```

- `dev-tree.sh` copies the source with Debian's own patches applied (before `prepare.sh`)
  and commits it as `debian-base`. It then runs `git am` with each patch of the series, one
  commit per patch. If a patch doesn't apply, it stops there: fix it, run `git am --continue`,
  then run `dev-tree.sh` again to apply the rest.
- `export-tree.sh` rewrites `patches/<series>/` from `debian-base..HEAD` with
  `scripts/export-patches.sh`, one patch per commit. The patches carry no commit hashes, so
  only the commits you changed come out different; the numbering follows the commit order.
  Config options a new driver needs go into `patches/<series>/apple.config` by hand.
  `config/apple.config` is for options that need no patch.
- Held topics (`patches/<series>/held/<topic>/`) go on top: `git am
  patches/7.3/held/dp-altmode/*.patch` in the tree. To move one into the build, apply it, export
  the tree, add its `apple.config` lines and remove the held directory.
- Then build it locally (below) before committing: a commit here changes the version, and the
  hourly `follow-debian.yml` may build and publish it.

A dispatch of `follow-debian.yml` with `debian_version` test-builds any Debian version without
publishing it; `scripts/local-build.sh` is the same locally.

## Building on the mini

`scripts/local-build.sh <debian version> <dir> [step...]` runs CI's steps in a Debian testing
chroot. It needs no root and no containers: `mmdebstrap --mode=unshare` and a user namespace.
`kernel-build` runs it through the build queue, on a free build machine and never the mini, and
copies the debs back:

```
kernel-build 7.3~rc7-1~exp1
ls /var/tmp/bande-kernel/out        # the debs
kernel-build 7.3~rc7-1~exp1 clean
```

The directory must be outside your home (`/var/tmp`), because the chroot belongs to your
subordinate uids. A build needs about 35 GB: the chroot with its build dependencies, Debian's
source and the build tree with debug info (32 GB). It takes about 2.5 h on the mini. The
compiler is the one Debian's source names (`gcc-16` for 7.3), installed in the chroot, not
the mini's own. Clean up after a build.

### Until Debian testing has 7.3

Our patches are for 7.3; testing has 7.2 and experimental 7.3~rc7, so CI builds nothing.
Until then, test kernels for the mini are local builds of experimental's 7.3~rc7 with our 7.3
series, built as above and installed by hand (never published). Once testing reaches 7.3,
`follow-debian.yml` builds and publishes it by itself, and the mini follows the archive.

## Licence

MIT OR Apache-2.0 for this repository's own files; the patches carry the licence of the kernel
files they change (GPL-2.0).

Patches taken from Asahi Linux keep their original author, `Signed-off-by` and copyright lines.
Restore any that were lost in a rebase or squash before publishing or sending a patch upstream.
