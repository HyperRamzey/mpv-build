# NOTICE — dependency framework

This framework builds ~45 third-party libraries from their upstream
git masters. Each library is under its own license (BSD, MIT, LGPL,
GPL, ISC, ...); see the individual upstream projects.

Two framework-level caveats:

1. **Combined-output licensing.** When these dependencies are linked
   into FFmpeg configured with `--enable-gpl --enable-version3
   --enable-nonfree` (see the companion `ffmpeg-build` repo), the
   resulting binaries are **"nonfree and unredistributable"**
   (GPL codecs + nonfree FDK-AAC). Do not redistribute binaries
   produced by that pipeline.

2. **Local patch.** `patches/libmysofa-large-files.patch` raises
   libmysofa's HDF5 reader caps (32 MB continuation offsets / 256 MB
   datasets) so ~1 GB ASH BRIR SOFA files load. It is applied
   automatically by `recipes/libmysofa.sh`; an upstream issue draft
   lives in `patches/upstream-issue.md`.

The framework scripts themselves are the author's own work.
