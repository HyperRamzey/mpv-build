# NOTICE — binaries produced by this build are NOT redistributable

The FFmpeg in this build is configured with:

```
--enable-gpl --enable-version3 --enable-nonfree
```

and links, among others:

- **GPL**: x264, x265, xvid, dav1d/SVT-AV1 tooling, vapoursynth glue
- **nonfree**: Fraunhofer **FDK-AAC** (`--enable-libfdk-aac`)

Per FFmpeg's own configure banner the resulting binaries are
**"nonfree and unredistributable"**. The same applies to the mpv
binaries linked against that FFmpeg/libav* build.

Consequences:

- The release zips published by the GitHub Actions pipeline are
  **personal build artifacts of the repository owner only**.
- **Do not mirror, bundle, ship, or redistribute** the produced
  `ffmpeg.exe` / `ffplay.exe` / `ffprobe.exe` / `mpv.exe` binaries or
  the packaged zips — not even for free.
- If you need a redistributable build, reconfigure FFmpeg without
  `--enable-nonfree` (drop libfdk-aac) and review every GPL component
  against your distribution obligations.

The build *scripts* in this repository are the author's own work; this
notice governs the **binaries they produce**, which incorporate
third-party code under the licenses listed above (see each upstream
project for its terms).
