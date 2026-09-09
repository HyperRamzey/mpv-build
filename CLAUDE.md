# mpv Custom Build — G:\media-build\mpv-build + G:\media-build\ffmpeg-build + G:\media-build\deps-build

Self-compiled mpv + libmpv for EIGHT build targets (5 hardware + 3
generic ISA levels), built with clang 22
(MSYS2 CLANG64). **ALL external libraries are self-compiled per-target**
(static-first) from latest git masters via the deps framework —
no MSYS2 media packages are linked.

> **2-repo model**: everything needed to build is vendored INSIDE this
> repo — `deps/` (the dependency framework) and `ffmpeg-scripts/` (the
> FFmpeg per-target build scripts). CI materializes them to the hardcoded
> /g/media-build/deps-build + /g/media-build/ffmpeg-build paths (see .github/workflows/release.yml).
> The local machine may keep the historical separate checkouts at
> G:\media-build\deps-build / G:\media-build\ffmpeg-build (they are now materialized copies of this
> repo's folds); the ONLY other repo is ffmpeg-releases (FFmpeg-only CI).

| Target  | CPU               | GPU          | CUDA arch |
|---------|-------------------|--------------|-----------|
| zn3     | Ryzen 5700X3D (znver3) | RTX 5070 (Blackwell) | sm_120a |
| zn2     | Zen2 (znver2)     | GTX 1650M (Pascal)   | sm_75   |
| 11700   | Intel i7-11700 (rocketlake) | RTX 4080 (Ada) | sm_89  |
| 3050    | Zen2 (znver2)     | RTX 3050M (Ampere)   | sm_86   |
| 14600   | i5-14600 (raptorlake) | RTX 50-series (Blackwell) | sm_120a |
| x64v2   | generic nehalem (v2/SSE4.2) | any NVIDIA (allcuda) | sm_75 PTX |
| x64v3   | generic haswell (v3/AVX2)   | any NVIDIA (allcuda) | sm_75 PTX |
| x64v4   | generic skylake-avx512 (v4/AVX-512) | any NVIDIA (allcuda) | sm_75 PTX |

The x64v* rows are CI-oriented generic builds (clang lacks GCC's
`x86-64-vN` names — nehalem/haswell/skylake-avx512 are the concrete
equivalents). allcuda = sm_75 PTX 6.3, driver-JITs to every NVIDIA GPU.
See ADD-A-TARGET.md for the full guide.

Dolby Vision Profile 7 FEL + Atmos via self-compiled libplacebo
(PL_API_VER >= 370) + custom FFmpeg. Full D3D11/WASAPI/Vulkan/gpu-next.

## Layout

```
G:\media-build\mpv-build\                 THE ONE BUILD REPO (self-contained)
├── mpv\                       mpv git clone
├── libplacebo-src\            libplacebo git clone
├── deps\                      VENDORED dependency framework (fold of the
│                              old deps-build repo; CI copies this to
│                              /g/media-build/deps-build — "materialize" step)
│   ├── common.sh              target env (OPT flags), build-system drivers
│   ├── recipes/*.sh           one file per lib: GIT_URL + BUILD()
│   ├── patches/               local patches (libmysofa-large-files!)
│   ├── build-one.sh / build-deps.sh / pull-all.sh / sanitize-prefix.sh
├── ffmpeg-scripts\            VENDORED FFmpeg per-target build scripts (fold
│                              of the old ffmpeg-build repo → /g/media-build/ffmpeg-build)
├── build-libplacebo-<t>.sh    → STATIC libplacebo into deps-<t> (embedded
├── build-<t>.sh               mpv per target → install-<t>\bin
├── build-all.sh               ONE-SCRIPT e2e orchestrator (per TARGETS)
├── copydlls.sh                EXACT-import-closure runtime DLLs (lean)
├── smoke_test.sh              12 checks (AI-lib guard, VSScript alias,
│                              dovi_split BSF, ISA-skip for foreign CPUs)
├── portable-conf\             mpv.conf/fonts.conf/ir.wav + user GLSL → bin
├── install-<t>\bin\           outputs (17 files: exe/com + libmpv + vulkan
│                              + VapourSynth runtime + config)
└── logs, configure-*.log, make-*.log, smoke.log

G:\media-build\ffmpeg-build\               materialized copy of ffmpeg-scripts/ (live
└── ffmpeg\                    FFmpeg git clone + install* outputs)
G:\media-build\deps-build\                 materialized copy of deps/ (live: src/,
└── src/, build/, deps-<t>/    clones, out-of-tree builds, merged prefixes)
G:\media-build\ffmpeg-releases\          FFmpeg-only GitHub release workflow repo

G:\media-build\build_all.bat              THE single visible entry point
                                          (drives mpv-build/build-all.sh)
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
$env:MSYSTEM='CLANG64'; C:\msys64\usr\bin\bash.exe -lc '/g/media-build/mpv-build/build-all.sh'
```

## Rebuild (routine)

```powershell
# FULL e2e: clean → pull ALL (~48 repos) → deps → libplacebo → FFmpeg → mpv → verify
cd G:\media-build && build_all.bat

# knobs (env): TARGETS="zn3 14600" | CLEAN=0 incremental |
#              FORCE_DEPS=1 rebuild all deps | DEPS_LTO=1 thin-LTO deps
#              (slow) | JOBS=N (default 14)
$env:MSYSTEM='CLANG64'; C:\msys64\usr\bin\bash.exe -lc '/g/media-build/mpv-build/build-all.sh'
```

Dependency builds are **stamp-cached**: only repos whose git HEAD moved get
rebuilt. A routine "rebuild everything latest" = just run build-all.sh.

Individual pieces:

```powershell
# one dep, one target:
bash -lc '/g/media-build/deps-build/build-one.sh zn3 x265'
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

## Self-compiled dependency matrix (G:\media-build\deps-build\recipes)

- **foundation**: zlib zstd xz brotli expat libiconv libpng libjpeg-turbo lcms2 openssl
- **audio**: ogg vorbis speexdsp speex opus lame twolame fdk-aac opencore-amr
  vo-amrwbenc ilbc codec2 lc3 openal soxr rubberband
- **video**: x264 x265 libvpx aom dav1d svtav1 openh264 libwebp openjpeg jxl
  zimg vmaf vidstab theora rav1e* libxvid libmysofa
- **text/subs**: freetype fribidi harfbuzz fontconfig libxml2 libaribcaption
  uchardet libgme libmodplug libsixel dvdcss dvdread dvdnav luajit mujs libarchive frei0r
- **net**: srt libssh libzmq librtmp
- **gpu**: vulkan-headers vulkan-loader glslang shaderc spirv-cross opencl-headers
  opencl-icd-loader ffnvcodec libvpl libdovi*vapoursynth* wat4ff
- `*` = BEST_EFFORT (failure doesn't kill the run; downstream auto-disables)
- libplacebo builds into deps-<t> per target (shaderc route, glslang off).
- **Apple AAC (`aac_at`)**: FFmpeg `--enable-audiotoolbox` via wat4ff
  wrapper (deps recipe). make runs with `LD=$DEPS/wat4ff_ld
  WAT4FF_TRUELD=clang` (rewrites `-framework AudioToolbox` →
  `-lwat4ff`); post-install the ffmpeg .pc files are sed-sanitized the
  same way so mpv can link. Runtime needs Apple's proprietary DLLs
  (iTunes/Apple Application Support or QTfiles64 next to ffmpeg.exe) —
  NOT shipped (see ffmpeg-releases README).

## Dolby Vision P7 FEL + ASH BRIR SOFA support

- libplacebo master (PL_API 371) per-target in deps-<t>.
- **libmysofa carries a local patch** (`patches/libmysofa-large-files.patch`,
  auto-applied by the recipe): upstream's mini HDF5 reader caps continuation
  offsets at 32 MB / datasets at 256 MB / strings at 64 B — 1 GB ASH BRIR
  exports fail with err 10001. Patch raises the caps; verified: 989 MB
  `Studio-AS-058...sofa` loads in ~1.1 s, filterlength=36000.
  Upstream issue draft: `G:\media-build\deps-build\patches\upstream-issue.md`.
- mpv usage once rebuilt: `mpv --af=lavfi=[sofalizer=sofa=<file>] <media>`
  (BRIRs are time-domain FIR; default sofalizer type=time is correct).

## Releases (GitHub Actions)

- **mpv releases**: mpv-build repo workflow (`release.yml`) → 4 zips
  (mpv-zn3/zn2/11700/3050), mpv-only since 2026-08.
- **FFmpeg releases**: dedicated **ffmpeg-releases** repo workflow →
  4 zips (ffmpeg-zn3/zn2/11700/3050). Same deps+ffmpeg pipeline,
  checks out deps-build/ffmpeg-build/mpv-build (libplacebo scripts).
- Both releases carry a prominent NON-REDISTRIBUTABLE notice
  (`--enable-gpl --enable-version3 --enable-nonfree` + FDK-AAC).
- Tarball deps (libiconv/gavl) fetch with retry + GNU mirror fallback
  (ftpmirror.gnu.org) — ftp.gnu.org flakes from GH runners.

## Verify after rebuild

```powershell
G:\media-build\mpv-build\install-zn3\bin\mpv.exe -version        # git master + full configure line
G:\media-build\ffmpeg-build\install\bin\ffmpeg.exe -version
G:\media-build\mpv-build\smoke_test.sh G:\media-build\mpv-build\install-zn3\bin   # 10 checks, incl. no ggml/whisper
ldd G:\media-build\mpv-build\install-zn3\bin\mpv.exe | Select-String "not found"
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
