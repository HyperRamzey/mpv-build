# ffmpeg-build

Self-compiled **FFmpeg** for three CPU targets, built with clang
(MSYS2 CLANG64). Consumes the per-target static dependency prefixes
from [`deps-build`](https://github.com/HyperRamzey/deps-build) and the
libplacebo builds produced by
[`mpv-build`](https://github.com/HyperRamzey/mpv-build).

| Target  | CPU                    | GPU                  | CUDA arch | Install dir     |
|---------|------------------------|----------------------|-----------|-----------------|
| zn3     | Ryzen 5700X3D (znver3) | RTX 5070 (Blackwell) | sm_120a   | `install`       |
| zn2     | Zen2 (znver2)          | GTX 1650M (Turing)   | sm_75     | `install-zn2`   |
| 11700   | i7-11700 (rocketlake)  | RTX 4080 (Ada)       | sm_89     | `install-11700` |
| 3050    | Zen2 (znver2)          | RTX 3050M (Ampere)   | sm_86     | `install-3050`  |

> [!CAUTION]
> **Binaries produced by these scripts are NOT redistributable.**
> FFmpeg is configured with `--enable-gpl --enable-version3
> --enable-nonfree` and links GPL codecs (x264, x265, xvid, …) plus the
> nonfree Fraunhofer FDK-AAC encoder. See [NOTICE.md](NOTICE.md).

## Highlights

- `--enable-cuda-llvm`: CUDA kernels compiled with clang's NVPTX
  backend (no CUDA toolkit required at build time)
- `--enable-libplacebo` (shaderc SPIR-V), Vulkan, OpenCL, VPL, NVENC/
  NVDEC/CUVID, D3D11VA, libvmaf, Dolby Vision P7 FEL support
- Thin-LTO (`--enable-lto=thin`)
- TLS via self-compiled OpenSSL + Schannel
- Explicitly disabled: whisper/AI libs, caca, bs2b, aribb24/zvbi,
  gsm/rsvg/openmpt, vaapi/vdpau/drm/xlib

## Layout

- `build-zn3.sh` / `build-zn2.sh` / `build-11700.sh` — per-target
  configure + make + install + DLL closure (calls
  `/g/mpv-build/copydlls.sh`). Each script wipes its install prefix
  first so stale DLLs are never shipped.
- `quick-configure.sh` — fast re-configure helper (WARNING: it does
  `rm -rf ffbuild`; never run between target builds)

## Companion repositories

The scripts expect the sibling layout (hardcoded paths):

```
<g-root>/mpv-build       mpv + libplacebo scripts, copydlls.sh
<g-root>/ffmpeg-build    <- this repo (expects ffmpeg/ clone inside)
<g-root>/deps-build      dependency framework, deps-<target> prefixes
```

## Build one target

```powershell
$env:MSYSTEM='CLANG64'
C:\msys64\usr\bin\bash.exe -lc '/g/ffmpeg-build/build-zn3.sh'
```

The full end-to-end flow (deps → libplacebo → FFmpeg → mpv) is
orchestrated by `mpv-build/build-all.sh`.
