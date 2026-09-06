# NOTICE — binaries produced by this build are NOT redistributable

The FFmpeg builds in this repository are configured with:

```
--enable-gpl --enable-version3 --enable-nonfree
```

and link, among others:

- **GPL**: x264, x265, xvid, vapoursynth glue
- **nonfree**: Fraunhofer **FDK-AAC** (`--enable-libfdk-aac`)
- **Apple proprietary runtime**: `--enable-audiotoolbox` via the
  [wat4ff](https://github.com/chrdev/wat4ff) wrapper enables the
  `aac_at` encoder, which at runtime loads Apple's CoreAudio DLLs
  (iTunes / Apple Application Support / QTfiles64). Those DLLs are
  Apple's property, are NOT shipped with the builds, and must be
  obtained by the end user under Apple's own terms.

Per FFmpeg's own configure banner the resulting binaries are
**"nonfree and unredistributable"**.

- The release artifacts published via the companion
  [ffmpeg-releases](https://github.com/HyperRamzey/ffmpeg-releases)
  (FFmpeg) and [mpv-build](https://github.com/HyperRamzey/mpv-build)
  (mpv) repositories' GitHub Actions pipelines are **personal build
  artifacts of the repository owner only**.
- **Do not mirror, bundle, ship, or redistribute** the produced
  binaries or packaged zips — not even for free.
- For a redistributable build, drop `--enable-nonfree` (and
  libfdk-aac) and review every GPL component against your
  distribution obligations.

The build *scripts* here are the author's own work; this notice
governs the **binaries they produce**.
