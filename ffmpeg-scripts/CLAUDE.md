# FFmpeg Custom Build — G:\media-build\ffmpeg-build

Custom FFmpeg build optimized for Ryzen 5700X3D (znver3) + RTX 5070 (sm_120),
compiled with clang 22 (MSYS2 CLANG64), thin-LTO, license tier: **nonfree and
unredistributable** (libfdk-aac). Do NOT share the binaries publicly.

## Layout

```
G:\media-build\ffmpeg-build\
├── ffmpeg\           FFmpeg git clone (github.com/FFmpeg/FFmpeg.git mirror —
│                     ffmpeg.org git remote is flaky, use the GitHub mirror)
├── install\bin\      ffmpeg.exe / ffprobe.exe / ffplay.exe + ~120 runtime DLLs
│                     (dynamic build: exes and DLLs are one unit, keep together;
│                     this folder is meant to be on PATH)
├── build.sh          ./configure with all flags (the source of truth)
├── make.sh           make -j14 + make install
├── copydlls.sh       copies the DLL dependency closure from /clang64/bin into install/bin
├── test_nvptx.sh     sm_120 PTX smoke test (run if clang or CUDA filters misbehave)
├── configure.log     last configure output
└── make.log          last make output
```

## Toolchain requirements

- MSYS2 at `C:\msys64`, packages from the **CLANG64** environment
  (`mingw-w64-clang-x86_64-*`). Target triple: x86_64-w64-windows-gnu, linker: lld.
- CRITICAL: every bash invocation from PowerShell/cmd MUST set `MSYSTEM=CLANG64`
  first, or clang won't be on PATH and configure fails with
  "clang: command not found":
  ```powershell
  $env:MSYSTEM='CLANG64'; C:\msys64\usr\bin\bash.exe -l /g/media-build/ffmpeg-build/<script>.sh
  ```
- No CUDA SDK / nvcc needed: CUDA filters compile via clang's NVPTX backend
  (`--enable-cuda-llvm`). NVENC/NVDEC use ffnvcodec headers
  (`mingw-w64-clang-x86_64-ffnvcodec-headers`).

## Rebuild (routine — newer FFmpeg master)

```powershell
git -C G:\media-build\ffmpeg-build\ffmpeg pull
$env:MSYSTEM='CLANG64'; C:\msys64\usr\bin\bash.exe -l /g/media-build/ffmpeg-build/build.sh     # configure
$env:MSYSTEM='CLANG64'; C:\msys64\usr\bin\bash.exe -l /g/media-build/ffmpeg-build/make.sh      # compile+install (~long; thin-LTO link at end)
$env:MSYSTEM='CLANG64'; C:\msys64\usr\bin\bash.exe -l /g/media-build/ffmpeg-build/copydlls.sh  # refresh DLLs
```

After a pull, MSYS2 packages may also need updating first:
`pacman -Syu --noconfirm` inside an MSYS2 shell (may need running twice;
pacman mirror timeouts are transient — just retry).

## Configure failure loop

When configure fails with "libfoo not found using pkg-config" but pacman says
it's installed, the real error is in `ffbuild/config.log` — `tail -60` it.
Usually a missing *transitive* header package (e.g. libplacebo needed
`mingw-w64-clang-x86_64-vulkan-headers`, not just `-vulkan` which is only the
loader). Install the missing `mingw-w64-clang-x86_64-<name>` package and re-run
build.sh. Note `--enable-cuda-llvm/--enable-nvenc/--enable-nvdec/--enable-cuvid/
--enable-ffnvcodec` do NOT appear in `configure --help` — they are valid
autodetect-component options; don't "fix" them.

## Flag rationale (do not change without reason)

- `--cpu=znver3` → configure emits `-march=znver3`; `-mtune=znver3` is added via
  `--extra-cflags`. `-mprefer-vector-width=256`
- **NO fast-math anywhere** (`-ffp-model=fast`, `-ffast-math`, nvcc
  `--use_fast_math` all deliberately omitted). FFmpeg requires IEEE float
  semantics for codec bit-exactness; its configure self-adds the only two safe
  flags (`-fno-math-errno -fno-signed-zeros`). `-fno-trapping-math` is safe and kept.
- `--enable-lto=thin` — thin-LTO; the final link step is single-threaded-looking
  and slow, that's normal.
- `--nvccflags="--cuda-gpu-arch=sm_120 -Xclang -target-feature -Xclang +ptx87 -O3"`
  — sm_120 is the RTX 5070. The `+ptx87` target-feature is REQUIRED: without the
  CUDA SDK installed, clang defaults to PTX ISA 4.2 which cannot encode sm_120
  ("Minimum required PTX version is 8.7"). If a future clang bumps its default
  PTX version this may become unnecessary, but it is harmless to keep.
- If a new GPU is installed, change `sm_120` to its compute capability and check
  the minimum PTX version; verify with `test_nvptx.sh`.

## Verify after rebuild

```powershell
G:\media-build\ffmpeg-build\install\bin\ffmpeg.exe -version              # banner shows git date + full configure line
G:\media-build\ffmpeg-build\install\bin\ffmpeg.exe -hide_banner -filters  | Select-String cuda   # expect scale_cuda etc.
G:\media-build\ffmpeg-build\install\bin\ffmpeg.exe -hide_banner -encoders | Select-String nvenc  # expect hevc_nvenc
```

Real-pipeline smoke test (matches modules/2.py usage in G:\2Stuff2Furious\unik):

```powershell
G:\media-build\ffmpeg-build\install\bin\ffmpeg.exe -y -hwaccel cuda -hwaccel_output_format cuda `
  -i <any source .mov> -t 3 -vf "scale_cuda=2160:3840:interp_algo=lanczos" `
  -c:v hevc_nvenc -preset p7 -tune uhq -rc constqp -qp 20 -c:a aac out_test.mov
```

Silent failure with exit code 53 and NO output = missing DLL next to the exe →
re-run copydlls.sh.

## Gotchas learned the hard way

- Dynamic build: exe is ~36 MB but that is NOT a stripped-down build — the
  ~70 external libs live in the DLLs (568 filters / 237 encoders / 551 decoders).
  Folder must stay intact; put `G:\media-build\ffmpeg-build\install\bin` on PATH rather than
  copying exes around.
- git clone from ffmpeg.org fails with "early EOF" — use the GitHub mirror.
- `spirv-headers not found` configure warning is cosmetic (swscale SPIR-V
  backend only), ignore.
- First NVENC session init after boot is slow (~8 s); short-clip speed numbers
  are not representative.
