# mpv-build

Self-compiled **mpv + libmpv** for five CPU targets, built with clang
(MSYS2 CLANG64). All external libraries are self-compiled per-target
(static-first) from git masters via the companion
[`deps-build`](https://github.com/HyperRamzey/deps-build) framework —
no MSYS2 media packages are linked.

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

- `build-all.sh` — one-script end-to-end orchestrator
  (clean → pull all sources → deps ×5 → libplacebo ×5 → FFmpeg ×5 →
  mpv ×5 → verification). Driven by `build_all.cmd`.
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
  (tag push `v*` or manual dispatch). See [CI-SETUP.md](CI-SETUP.md).

## Companion repositories

The build system is TWO repos total. This repo is **self-contained** —
it vendors the dependency framework (`deps/`, the fold of the old
deps-build repo) and the FFmpeg per-target build scripts
(`ffmpeg-scripts/`, the fold of the old ffmpeg-build repo). CI
materializes both folds to the hardcoded `/g/deps-build` +
`/g/ffmpeg-build` paths, so every script runs byte-identical to local:

```
<repo> mpv-build        <- THIS repo (everything: mpv scripts + deps/ +
                           ffmpeg-scripts/ + workflows + releases)
<repo> ffmpeg-releases  <- FFmpeg-only release workflow (checks out
                           mpv-build the same self-contained way)
```

Locally the checkouts live at `G:\mpv-build`, `G:\ffmpeg-releases`,
with `G:\deps-build` / `G:\ffmpeg-build` as the materialized (copied)
working trees carrying the source clones, build dirs and prefixes.

```powershell
cd G:\mpv-build && build_all.cmd   # full e2e for all five targets
```

## Routine rebuild

```powershell
# FULL e2e: clean -> pull ALL (~48 repos) -> deps x3 -> libplacebo x3
#           -> FFmpeg x3 -> mpv x3 -> verify
cd G:\mpv-build && build_all.cmd

# knobs (env): CLEAN=0 incremental | FORCE_DEPS=1 rebuild all deps |
#              DEPS_LTO=1 thin-LTO deps | JOBS=N (default 14)
$env:MSYSTEM='CLANG64'; C:\msys64\usr\bin\bash.exe -lc '/g/mpv-build/build-all.sh'
```

## Verify after rebuild

```powershell
G:\mpv-build\install-zn3\bin\mpv.exe -version
G:\ffmpeg-build\install\bin\ffmpeg.exe -version
G:\mpv-build\smoke_test.sh G:\mpv-build\install-zn3\bin
ldd G:\mpv-build\install-zn3\bin\mpv.exe | Select-String "not found"
```
