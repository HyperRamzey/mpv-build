# mpv-build

Self-compiled **mpv + libmpv** for three CPU targets, built with clang
(MSYS2 CLANG64). All external libraries are self-compiled per-target
(static-first) from git masters via the companion
[`deps-build`](https://github.com/HyperRamzey/deps-build) framework —
no MSYS2 media packages are linked.

| Target  | CPU                    | GPU                  | CUDA arch |
|---------|------------------------|----------------------|-----------|
| zn3     | Ryzen 5700X3D (znver3) | RTX 5070 (Blackwell) | sm_120a   |
| zn2     | Zen2 (znver2)          | GTX 1650M (Turing)   | sm_75     |
| 11700   | i7-11700 (rocketlake)  | RTX 4080 (Ada)       | sm_89     |

Dolby Vision Profile 7 FEL + Atmos via self-compiled libplacebo
(PL_API_VER >= 370, shaderc SPIR-V) + custom FFmpeg. Full
D3D11/WASAPI/Vulkan/gpu-next.

> [!CAUTION]
> **Binaries produced by these scripts are NOT redistributable.**
> FFmpeg is configured with `--enable-gpl --enable-version3
> --enable-nonfree` and links GPL codecs (x264, x265, xvid, …) plus the
> nonfree Fraunhofer FDK-AAC encoder. See [NOTICE.md](NOTICE.md).

## Layout

- `build-all.sh` — one-script end-to-end orchestrator
  (clean → pull all sources → deps ×3 → libplacebo ×3 → FFmpeg ×3 →
  mpv ×3 → verification). Driven by `build_all.cmd`.
- `build-<target>.sh` — mpv per target → `install-<target>\bin`
- `build-libplacebo-<target>.sh` — libplacebo into the per-target deps
  prefix (shaderc enabled, glslang disabled)
- `copydlls.sh` — DLL closure for an install dir (deps prefix + ldd vs
  `/clang64` only; hard-fails if ggml/whisper files appear)
- `smoke_test.sh` — 10 post-build checks incl. AI-lib pollution guard
- `portable-conf/` — `mpv.conf` / `fonts.conf` / `ir.wav` copied into
  the installs
- `.github/workflows/release.yml` — GitHub Actions pipeline mirroring
  the local flow 1:1; posts a GitHub Release on every successful run
  (tag push `v*` or manual dispatch). See [CI-SETUP.md](CI-SETUP.md).

## Companion repositories

The CI pipeline and the local layout expect three sibling checkouts:

```
<g-root>/mpv-build       <- this repo
<g-root>/ffmpeg-build    <- FFmpeg per-target build scripts
<g-root>/deps-build      <- dependency framework (recipes, patches)
```

Locally they live at `G:\mpv-build`, `G:\ffmpeg-build`,
`G:\deps-build` (paths are hardcoded in the scripts; CI recreates the
layout with `subst G:`).

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
