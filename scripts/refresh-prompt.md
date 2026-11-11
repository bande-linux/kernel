You are refreshing the Bande kernel patches for a new Debian kernel. Bande builds Debian
forky's `linux` source package with our patches for the Apple Silicon Mac mini M2 added after
Debian's own patches. Debian has moved to a new version and at least one of our patches no
longer applies. When Debian moved to a new upstream series, our series directory for it was
just started as a copy of our previous series.

State: the Debian source has been unpacked with Debian's patches applied, and our patches were
appended to `debian/patches/series` under `features/arm64/apple/`. `quilt` (with
`QUILT_PATCHES=debian/patches`) stopped at the first of ours that fails; `quilt next` names it.

Do this, in the source directory, with `export QUILT_PATCHES=debian/patches QUILT_PC=.pc`:
1. For each of our patches that fails, `quilt push -f` it, resolve every rejected hunk in the
   source by hand so the patch keeps its original intent on the new code, delete the `.rej`
   files, and `quilt refresh` it. Keep its description header. Then continue with
   `quilt push --fuzz=0` until `quilt push -a --fuzz=0` reports the series fully applied.
2. Only touch our patches (`debian/patches/features/arm64/apple/*`). Never change Debian's
   patches, `debian/config`, or anything outside the source tree and our series directory (named below).
3. Copy every refreshed patch back over the file of the same name in our series directory,
   keeping its `series` file as it is (add or rename nothing). If a patch is already upstream
   or no longer makes sense (step 4), leave it and stop: the build then fails, and nothing is
   published or committed.
4. If the code a patch targets was rewritten upstream so much that the change no longer makes
   sense, or the fix is already upstream, say so plainly and stop without changing that patch:
   a person decides then.

Finish with a short report: each patch you refreshed and what you had to change.
