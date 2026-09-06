# deps-build

The dependency framework behind the self-compiled
[mpv](https://github.com/HyperRamzey/mpv-build) +
[FFmpeg](https://github.com/HyperRamzey/ffmpeg-build) builds: ~45
external libraries, **all self-compiled per-target** (static-first)
from latest git masters with clang (MSYS2 CLANG64). No MSYS2 media
packages are linked into the media path.

| Target  | CPU                    | Prefix       |
|---------|------------------------|--------------|
| zn3     | Ryzen 5700X3D (znver3) | `deps-zn3`   |
| zn2     | Zen2 (znver2)          | `deps-zn2`   |
| 11700   | i7-11700 (rocketlake)  | `deps-11700` |
| 3050    | Zen2 (znver2)          | `deps-3050`  |

> [!CAUTION]
> **Binaries produced with these dependencies are NOT redistributable.**
> The stack includes GPL libraries (x264, x265, xvid, …) and the
> nonfree Fraunhofer FDK-AAC encoder, consumed by an FFmpeg configured
> with `--enable-gpl --enable-version3 --enable-nonfree`.
> See [NOTICE.md](NOTICE.md).

## Layout

```
deps-build/
├── common.sh                  target env (OPT flags), build-system drivers
├── recipes/*.sh               one file per lib: GIT_URL + BUILD()
├── build-one.sh <target> <lib>
├── build-deps.sh [targets]    tiered full matrix; stamp-cached (git HEAD)
├── pull-all.sh                git pull --ff-only all dep clones
├── fix-static-pcs.sh          post-pass over the merged prefix .pc files
├── patches/                   local patches (libmysofa-large-files.patch)
├── src/<lib>/                 git clones (submodules where needed)
├── build/<target>/<lib>/      out-of-tree build dirs
└── deps-<target>/             MERGED per-target prefix (bin/lib/include/pkgconfig)
```

## Usage

```powershell
$env:MSYSTEM='CLANG64'
# one dep, one target:
C:\msys64\usr\bin\bash.exe -lc '/g/deps-build/build-one.sh zn3 x265'
# force rebuild: FORCE=1 ; skip git sync: SKIP_SYNC=1
# full matrix (stamp-cached — only repos whose git HEAD moved rebuild):
C:\msys64\usr\bin\bash.exe -lc '/g/deps-build/build-deps.sh'
```

## Dependency matrix (recipes/)

- **foundation**: zlib zstd xz brotli expat libiconv libpng libjpeg-turbo
  lcms2 openssl
- **audio**: ogg vorbis speexdsp speex opus lame twolame fdk-aac
  opencore-amr vo-amrwbenc ilbc codec2 lc3 openal soxr rubberband
- **video**: x264 x265 libvpx aom dav1d svtav1 openh264 libwebp openjpeg
  jxl zimg vmaf vidstab theora rav1e* libxvid libmysofa vvenc xevd xeve
  uavs3d svtjpegxs oapv lcevcdec
- **text/subs**: freetype fribidi harfbuzz fontconfig libxml2
  libaribcaption uchardet libgme libmodplug libsixel dvdcss dvdread
  dvdnav luajit mujs libarchive frei0r subrandr* libass
- **net**: srt libssh libzmq librtmp librist
- **gpu**: vulkan-headers vulkan-loader glslang spirv-cross
  opencl-headers opencl-icd-loader ffnvcodec libvpl libdovi*
  vapoursynth* shaderc
- `*` = BEST_EFFORT (failure doesn't kill the run; downstream
  auto-disables)

## Flag rationale

- Per-target `-march/-mtune` (znver3/znver2/rocketlake),
  `-mprefer-vector-width=256`, `-O3 -funroll-loops -fomit-frame-pointer
  -fstrict-aliasing -fno-trapping-math`. **No fast-math** anywhere
  (IEEE codec math).
- Deps are thin-LTO by default (`DEPS_LTO`, default on);
  `DEPS_LTO=0` disables.
- Static-first: `--enable-static --disable-shared`, meson
  `default_library=static`, cmake `BUILD_SHARED_LIBS=OFF`. Exceptions:
  vapoursynth (shared, python-embedding model, best-effort).

## Notable local workarounds (kept current with git masters)

- **libmysofa**: local patch raises the mini-HDF5 reader caps so 1 GB
  ASH BRIR SOFA exports load (see `patches/`).
- **x264**: built without LTO — its configure self-adds
  `-mstack-alignment=64`, whose LTO module flag conflicts with
  FFmpeg's ThinLTO link.
- **lcevcdec**: built without LTO — LLVM 22 ThinLTO backend ICEs
  ("Do not know how to scalarize the result of this operator!") on
  `calculateDequant` for `-march=rocketlake`.
- **openapv**: pinned to `v0.3.0.0` — master broke the `oapvm_create()`
  API expected by FFmpeg.
- **vapoursynth**: upstream installs wheel-style into Python
  site-packages; the recipe relocates headers/DLLs/import-libs and
  generates a sane `.pc`.
