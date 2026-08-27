# mpv Custom Build — G:\mpv-build + G:\ffmpeg-build + G:\deps-build

Self-compiled mpv + libmpv for three CPU targets, built with clang 22
(MSYS2 CLANG64). **ALL external libraries are self-compiled per-target**
(static-first) from latest git masters via the G:\deps-build framework —
no MSYS2 media packages are linked.

| Target  | CPU               | GPU          | CUDA arch |
|---------|-------------------|--------------|-----------|
| zn3     | Ryzen 5700X3D (znver3) | RTX 5070 (Blackwell) | sm_120a |
| zn2     | Zen2 (znver2)     | GTX 1650M (Pascal)   | sm_75   |
| 11700   | Intel i7-11700 (rocketlake) | RTX 4080 (Ada) | sm_89  |

Dolby Vision Profile 7 FEL + Atmos via self-compiled libplacebo
(PL_API_VER >= 370) + custom FFmpeg. Full D3D11/WASAPI/Vulkan/gpu-next.

## Layout

```
G:\deps-build\                 THE DEP FRAMEWORK (~45 self-compiled libs)
├── common.sh                  target env (OPT flags), build-system drivers
├── recipes/*.sh               one file per lib: GIT_URL + BUILD()
├── build-one.sh <target> <lib>
├── build-deps.sh [targets]    tiered full matrix; stamp-cached (git HEAD)
├── pull-all.sh                git pull --ff-only all dep clones
├── patches/                   local patches (libmysofa-large-files.patch!)
├── src/<lib>/                 git clones (submodules where needed)
├── build/<target>/<lib>/      out-of-tree build dirs
├── deps-<zn3|zn2|11700>/      MERGED per-target prefix (bin/lib/include/pkgconfig)
└── logs/                      per-lib per-target build logs

G:\mpv-build\
├── mpv\                       mpv git clone
├── libplacebo-src\            libplacebo git clone
├── build-libplacebo-<t>.sh    → installs INTO deps-<t>
├── build-<t>.sh               mpv per target → install-<t>\bin
├── build-all.sh               ONE-SCRIPT e2e orchestrator (see below)
├── build_all.cmd              CMD wrapper
├── copydlls.sh                DLL closure (deps-<t>/bin + ldd vs /clang64 ONLY;
│                              never wholesale-copies; ggml/whisper tripwire)
├── smoke_test.sh              10 checks incl. AI-lib pollution guard
├── portable-conf\             mpv.conf/fonts.conf/ir.wav → copied into installs
├── install-<t>\bin\           outputs
└── logs, configure-*.log, make-*.log, smoke.log

G:\ffmpeg-build\
├── ffmpeg\                    FFmpeg git clone
├── build-<t>.sh               per-target; consumes deps-<t> + installs install[-zn2|-11700]
└── install*\bin\              ffmpeg/ffplay/ffprobe per target
```

## Toolchain

- MSYS2 CLANG64 (`mingw-w64-clang-x86_64-*`), clang 22, meson, ninja, cmake,
  nasm, rust/cargo (rav1e + libdovi), python (h5py for SOFA tooling),
  autotools chain, gperf/flex/bison, patch.
- MSYS2 runtime-only leftovers (allowed, not linked into media path):
  gettext-runtime, SDL2 (ffplay), python/perl (build tools).
- CUDA Toolkit v13.3 (clang NVPTX for --enable-cuda-llvm; PTX87 + sm_XX).

CRITICAL: every bash invocation MUST set `MSYSTEM=CLANG64`:

```powershell
$env:MSYSTEM='CLANG64'; C:\msys64\usr\bin\bash.exe -lc '/g/mpv-build/build-all.sh'
```

## Rebuild (routine)

```powershell
# FULL e2e: clean → pull ALL (~48 repos) → deps ×3 → libplacebo ×3 → FFmpeg ×3 → mpv ×3 → verify
cd G:\mpv-build && build_all.cmd

# knobs (env): CLEAN=0 incremental | FORCE_DEPS=1 rebuild all deps |
#              DEPS_LTO=1 thin-LTO deps (slow) | JOBS=N (default 14)
$env:MSYSTEM='CLANG64'; C:\msys64\usr\bin\bash.exe -lc '/g/mpv-build/build-all.sh'
```

Dependency builds are **stamp-cached**: only repos whose git HEAD moved get
rebuilt. A routine "rebuild everything latest" = just run build-all.sh.

Individual pieces:

```powershell
# one dep, one target:
bash -lc '/g/deps-build/build-one.sh zn3 x265'
# force: FORCE=1 ; skip sync: SKIP_SYNC=1
```

## Flag rationale (do not change without reason)

- Per-target `-march/-mtune` (znver3/znver2/rocketlake), `-mprefer-vector-width=256`
  (Zen3 double-pumps 512b; RKL: avoid AVX-512 throttling), `-O3 -funroll-loops
  -fomit-frame-pointer -fstrict-aliasing -fno-trapping-math`. **NO fast-math**
  anywhere (IEEE codec math).
- mpv/FFmpeg/libplacebo: `-Db_lto=true -Db_lto_mode=thin`. Deps: LTO opt-in
  via DEPS_LTO=1 (default off for build time).
- Deps are **static-first** (`--enable-static --disable-shared`, meson
  `default_library=static`, cmake `BUILD_SHARED_LIBS=OFF`). Exceptions:
  vapoursynth (shared, python-embedding model, best-effort).
- FFmpeg TLS: **OpenSSL (self) + Schannel**; gnutls dropped (huge chain).
- FFmpeg explicitly disables: whisper (AI — hard requirement), caca, bs2b
  (dead upstream), aribb24/zvbi (superseded by libaribcaption), gsm/rsvg/
  openmpt (no viable git/self-build on Windows), vaapi/vdpau/drm/xlib.

## Self-compiled dependency matrix (G:\deps-build\recipes)

- **foundation**: zlib zstd xz brotli expat libiconv libpng libjpeg-turbo lcms2 openssl
- **audio**: ogg vorbis speexdsp speex opus lame twolame fdk-aac opencore-amr
  vo-amrwbenc ilbc codec2 lc3 openal soxr rubberband
- **video**: x264 x265 libvpx aom dav1d svtav1 openh264 libwebp openjpeg jxl
  zimg vmaf vidstab theora rav1e* libxvid libmysofa
- **text/subs**: freetype fribidi harfbuzz fontconfig libxml2 libaribcaption
  uchardet libgme libmodplug libsixel dvdcss dvdread dvdnav luajit mujs libarchive frei0r
- **net**: srt libssh libzmq librtmp
- **gpu**: vulkan-headers vulkan-loader glslang spirv-cross opencl-headers
  opencl-icd-loader ffnvcodec libvpl libdovi* vapoursynth*
- `*` = BEST_EFFORT (failure doesn't kill the run; downstream auto-disables)
- libplacebo builds into deps-<t> per target (glslang route, shaderc off).

## Dolby Vision P7 FEL + ASH BRIR SOFA support

- libplacebo master (PL_API 371) per-target in deps-<t>.
- **libmysofa carries a local patch** (`patches/libmysofa-large-files.patch`,
  auto-applied by the recipe): upstream's mini HDF5 reader caps continuation
  offsets at 32 MB / datasets at 256 MB / strings at 64 B — 1 GB ASH BRIR
  exports fail with err 10001. Patch raises the caps; verified: 989 MB
  `Studio-AS-058...sofa` loads in ~1.1 s, filterlength=36000.
  Upstream issue draft: `G:\deps-build\patches\upstream-issue.md`.
- mpv usage once rebuilt: `mpv --af=lavfi=[sofalizer=sofa=<file>] <media>`
  (BRIRs are time-domain FIR; default sofalizer type=time is correct).

## Verify after rebuild

```powershell
G:\mpv-build\install-zn3\bin\mpv.exe -version        # git master + full configure line
G:\ffmpeg-build\install\bin\ffmpeg.exe -version
G:\mpv-build\smoke_test.sh G:\mpv-build\install-zn3\bin   # 10 checks, incl. no ggml/whisper
ldd G:\mpv-build\install-zn3\bin\mpv.exe | Select-String "not found"
```

## Gotchas

- **Never wholesale-copy /clang64/bin** into an install dir — that was the
  original bug that shipped ggml/whisper/LLVM (450 MB junk). copydlls.sh now
  copies deps-<t>/bin + ldd closure from /clang64 only, and hard-fails if
  ggml/whisper files appear.
- MSYS2 ggml/whisper.cpp/openblas packages were REMOVED (pacman -Rn); SDL2
  kept for ffplay. If ffmpeg configure ever says `whisper=yes`, something
  reintroduced whisper.pc — stop and investigate.
- PKG_CONFIG_PATH order is load-bearing: deps-<t> → ffmpeg install → /clang64.
- Stamp cache: `.built-<target>` in each src/<lib> holds the git HEAD. Delete
  to force rebuild; FORCE=1 env overrides once.
- `GIT_SUBMODULES=1` in a recipe = recursive submodule init (ilbc→abseil,
  jxl→highway/brotli/skcms).
- Autotools git checkouts without `configure` get `autoreconf -fi` automatically.
- Use `bash -lc '/script.sh'` to pass args. First NVENC session after boot ~8s.
- mpv tree: core.autocrlf=false is set (CRLF churn used to bake `-dirty` into
  version strings).
- quick-configure.sh in ffmpeg-build does `rm -rf ffbuild` — do not run
  between target builds.
