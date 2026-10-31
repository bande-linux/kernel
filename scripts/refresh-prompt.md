You are refreshing the Bande kernel patches for a new Debian kernel. Bande builds Debian
testing's `linux` source package with our patches for the Apple Silicon Mac mini M2 added after
Debian's own patches. Debian has moved to a new version and at least one of our patches no
longer applies.

State: the Debian source has been unpacked with Debian's patches applied, and our patches were
appended to `debian/patches/series` under `features/arm64/apple/`. `quilt` (with
`QUILT_PATCHES=debian/patches`) stopped at the first of ours that fails; `quilt next` names it.

Do this, in the source directory, with `export QUILT_PATCHES=debian/patches QUILT_PC=.pc`:
1. For each of our patches that fails, `quilt push -f` it, resolve every rejected hunk in the
   source by hand so the patch keeps its original intent on the new code, delete the `.rej`
   files, and `quilt refresh` it. Keep its description header. Then continue with
   `quilt push --fuzz=0` until `quilt push -a --fuzz=0` reports the series fully applied.
2. Only touch our patches (`debian/patches/features/arm64/apple/*`). Never change Debian's
   patches, `debian/config`, or anything outside the source tree and `/repo/patches`.
3. Copy every refreshed patch back over the file of the same name in `/repo/patches/`, keeping
   `/repo/patches/series` as it is (add or rename nothing).
4. If the code a patch targets was rewritten upstream so much that the change no longer makes
   sense, or the fix is already upstream, say so plainly and stop without changing that patch:
   a person decides then.

Finish with a short report: each patch you refreshed and what you had to change.
