# mpv-build

Self-compiled **mpv + libmpv** for five CPU targets, built with clang
(MSYS2 CLANG64). All external libraries are self-compiled per-target
(static-first) from git masters via the vendored `deps/` framework
(the fold of the old separate deps-build repo) — no MSYS2 media
packages are linked.

| Target  | CPU                    | GPU                  | CUDA arch |
|---------|------------------------|----------------------|-----------|
| zn3     | Ryzen 5700X3D (znver3) | RTX 5070 (Blackwell) | sm_120a   |
| zn2     | Zen2 (znver2)          | GTX 1650M (Turing)   | sm_75     |
| 11700   | i7-11700 (rocketlake)  | RTX 4080 (Ada)       | sm_89     |
| 3050    | Zen2 (znver2)          | RTX 3050M (Ampere)   | sm_86     |
| 14600   | i5-14600 (raptorlake)  | RTX 50-series (Blackwell) | sm_120a |
| x64v2   | generic (nehalem)      | any NVIDIA GPU       | allcuda   |
| x64v3   | generic (haswell)       | any NVIDIA GPU       | allcuda   |
| x64v4   | generic (skylake-avx512)| any NVIDIA GPU       | allcuda   |

The `x64v*` targets are the clang equivalents of the GCC `x86-64-v2/v3/v4`
portable ISA levels (SSE4.2 / AVX2 / AVX-512) paired with the **allcuda**
CUDA profile (sm_75 PTX 6.3 — the NVIDIA driver JIT-compiles it to every
GPU from Pascal up at runtime). They are CI-oriented: dispatch
`targets = x64v3 ...` to build any subset. See [ADD-A-TARGET.md](ADD-A-TARGET.md)
for the full how-to.Dolby Vision Profile 7 FEL + Atmos via self-compiled libplacebo
(PL_API_VER >= 370, shaderc SPIR-V, statically embedded libdovi) +
custom FFmpeg (native `dovi_split` BSF). Full D3D11/WASAPI/Vulkan/
gpu-next.

> [!CAUTION]
> **Binaries produced by these scripts are NOT redistributable.**
> FFmpeg is configured with `--enable-gpl --enable-version3
> --enable-nonfree` and links GPL codecs (x264, x265, xvid, …) plus the
> nonfree Fraunhofer FDK-AAC encoder. See [NOTICE.md](NOTICE.md).

## Lean static linkage

mpv.exe and libmpv-2.dll statically embed libplacebo (with libdovi),
shaderc, spirv-cross, SDL2, libzmq, xevd/xeve, libunibreak, bzip2 and
the full libc++/libunwind C++ runtime. The only runtime DLLs shipped
besides the binaries are `vulkan-1.dll` (no static Vulkan loader on
Windows) and the VapourSynth frameserver DLLs (dlopen'd, with a
`VSScript.dll` alias so mpv/ffmpeg find them by their probe name).

## Layout

The local working tree is ONE consolidated root, `G:\media-build\`,
holding all four build trees side by side:

````text
G:\media-build\
  build_all.bat          <- THE single visible entry point (see below)
  mpv-build\             <- THIS repo (git): mpv scripts + deps/ +
                           ffmpeg-scripts/ folds + workflows + releases
  ffmpeg-build\          <- materialized working tree (FFmpeg clone,
                           per-target installs) — no git, build artifacts
  deps-build\            <- materialized working tree (~90 source
                           clones, build dirs, per-target prefixes)
  ffmpeg-releases\       <- the FFmpeg-release repo (git, workflows only)
````

- `build_all.bat` (at the consolidated root) — THE single entry point:
  drives `build-all.sh` end to end with TARGETS/CLEAN/FORCE_DEPS/
  DEPS_LTO/JOBS knobs
- `build-all.sh` — one-script end-to-end orchestrator
  (clean → pull all sources → deps ×N → libplacebo ×N → FFmpeg ×N →
  mpv ×N → verification). Local default: the five hardware targets;
  `TARGETS="zn3 x64v3 ..."` selects any subset.
- `build-<target>.sh` — mpv per target → `install-<target>\bin`
- `build-libplacebo-<target>.sh` — STATIC libplacebo into the per-target
  deps prefix (embedded into mpv/ffmpeg; no libplacebo DLL ships)
- `copydlls.sh` — exact-import-closure runtime DLLs for an install dir
  (vulkan-1.dll + VapourSynth set + imported clang64 runtime only;
  hard-fails if ggml/whisper files appear)
- `smoke_test.sh` — 12 post-build checks incl. AI-lib pollution guard,
  VapourSynth VSScript.dll alias and ffmpeg dovi_split BSF presence
- `portable-conf/` — `mpv.conf` / `fonts.conf` / `ir.wav` copied into
  the installs
- `.github/workflows/release.yml` — GitHub Actions pipeline mirroring
  the local flow 1:1; posts a GitHub Release on every successful run
  (tag push `v*`, manual dispatch, or the weekly schedule).
  See [CI-SETUP.md](CI-SETUP.md).

## Companion repositories

The build system is TWO repos total. This repo is **self-contained** —
it vendors the dependency framework (`deps/`, the fold of the old
deps-build repo) and the FFmpeg per-target build scripts
(`ffmpeg-scripts/`, the fold of the old ffmpeg-build repo). CI
materializes both folds to the hardcoded `/g/media-build/deps-build` +
`/g/media-build/ffmpeg-build` paths, so every script runs byte-identical to local:

```
<repo> mpv-build        <- THIS repo (everything: mpv scripts + deps/ +
                           ffmpeg-scripts/ + workflows + releases)
<repo> ffmpeg-releases  <- FFmpeg-only release workflow (checks out
                           mpv-build the same self-contained way)
```

Locally the checkouts live at `G:\media-build\mpv-build` and
`G:\media-build\ffmpeg-releases`, with `G:\media-build\deps-build` /
`G:\media-build\ffmpeg-build` as the materialized (copied)
working trees carrying the source clones, build dirs and prefixes.

```powershell
cd G:\media-build && build_all.bat   # full e2e for all five targets
```

## Routine rebuild

```powershell
# FULL e2e: clean -> pull ALL (~48 repos) -> deps -> libplacebo
#           -> FFmpeg -> mpv -> verify  (from the consolidated root)
cd G:\media-build && build_all.bat

# target subset / knobs (env):
#   TARGETS="zn3 14600" CLEAN=0 FORCE_DEPS=1 DEPS_LTO=1 JOBS=14
# defaults: all five hardware targets, full clean, stamps respected
```

## Verify after rebuild

```powershell
G:\media-build\mpv-build\install-zn3\bin\mpv.exe -version
G:\media-build\ffmpeg-build\install\bin\ffmpeg.exe -version
G:\media-build\mpv-build\smoke_test.sh G:\media-build\mpv-build\install-zn3\bin
ldd G:\media-build\mpv-build\install-zn3\bin\mpv.exe | Select-String "not found"
```
