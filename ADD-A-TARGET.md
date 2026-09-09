# Adding a build target

This repo builds one set of scripts per **hardware target** (CPU
microarchitecture + GPU CUDA arch). A target is identified by a short
name — e.g. `zn3`, `14600`, `x64v3` — and touches exactly **nine
places**. Everything else (deps matrix, libplacebo, ffmpeg, mpv, CI,
smoke test) is generic and picks the target up automatically.

This guide walks through a real example: adding `x64v3`
(x86-64-v3: AVX2/AVX2 CPUs, Haswell 2013 → Comet Lake 2020) with the
`allcuda` CUDA profile.

## The nine places

| # | File | What to add |
| --- | ------ | ------------- |
| 1 | `deps/common.sh` — `target_env()` | `ARCH` (-march/-mtune value) + human label |
| 2 | `deps/build-deps.sh` — default `TARGETS` | append the name (local default build set) |
| 3 | `build-libplacebo-<t>.sh` (repo root) | copy of an existing one; OPT march + paths |
| 4 | `ffmpeg-scripts/build-<t>.sh` | copy; OPT march, `--cpu=`, NVCCFLAGS |
| 5 | `build-<t>.sh` (repo root) | copy; CPU/TUNE, paths, LOG names |
| 6 | `build-all.sh` | clean list, step 3/4/5 lines, verify-map case |
| 7 | `.github/workflows/release.yml` — `TARGET_TABLE` | one row: name cpu gpu-label cuda |
| 8 | `.gitignore` (root) | `/install-<t>/` (+ ffmpeg-scripts `.gitignore` in the fold mirrors: actually only root matters — installs live in mpv-build; ffmpeg installs are CI/cache-only) |
| 9 | `CLAUDE.md` / `README.md` target tables | documentation row |

`deps/status.sh` also prints per-target stamp counts — add the name to
its loop (optional, cosmetic).

## 1. CPU: deps/common.sh `target_env()`

```bash
target_env() {
    local t="$1"
    case "$t" in
    ...
    x64v3) ARCH=x86-64-v3;  TARGET_CPU="generic x86-64-v3 (AVX2)" ;;
    *) die "unknown target '$t' (want: zn2|zn3|11700|3050|14600|x64v3)" ;;
    esac
```

`ARCH` flows into `OPT="-O3 -march=$ARCH -mtune=$ARCH ..."` for every
dependency. Use **concrete arch names** — clang (MSYS2) does not
accept GCC's generic level names (`x86-64-v2/v3/v4` are rejected);
use their concrete equivalents with the same ISA floor:

| name | `-march` (clang) | GCC-level equivalent | ISA floor | example CPUs |
| ------ | ------------------ | ---------------------- | ----------- | -------------- |
| `x64v2` | `nehalem` | x86-64-v2 | SSE4.2/POPCNT | Nehalem+, most 2009+ x86-64 |
| `x64v3` | `haswell` | x86-64-v3 | AVX2/BMI2 | Haswell … Comet Lake, Zen 1..3 |
| `x64v4` | `skylake-avx512` | x86-64-v4 | AVX-512 | Skylake-X, Zen 4/5, Raptor Lake P-cores |

(`-mtune=<same>` only shapes scheduling — the binary still runs on every
CPU at or above the ISA floor. Vendor-specific values work identically:
`znver2`, `znver3`, `rocketlake`, `raptorlake`, `alderlake`,
`sapphirerapids`, ... — full list: `clang -march=` error message.)

**Host caveat**: a binary SIGILLs on any CPU missing the ISA floor
(e.g. `x64v4` on Zen 3). The smoke test detects this (rc 132/136) and
reports SKIP for the run-dependent checks — build it anywhere, test it
on matching hardware.

## 2. deps default set: deps/build-deps.sh

```bash
[[ ${#TARGETS[@]} -eq 0 ]] && TARGETS=(zn3 zn2 11700 3050 14600 x64v2 x64v3 x64v4)
```

(Appending is optional — `build-deps.sh <t>` takes explicit lists too —
but the local default should match what you actually want locally.)

## 3. libplacebo: `build-libplacebo-<t>.sh`

Copy `build-libplacebo-14600.sh` → `build-libplacebo-x64v3.sh` and
change four lines: `DEPS=`, `LOG=`, the `OPT=` march pair, and the
echo strings. Everything else (static install, `--default-library=static`,
sanitize, PL_API_VER ≥ 370 + `PL_HAVE_LIBDOVI` guard) stays identical.

## 4. FFmpeg: `ffmpeg-scripts/build-<t>.sh`

Copy an existing script; change:

- `PREFIX=/g/media-build/ffmpeg-build/install-x64v3`, `LOG=`, `DEPS=`
- `OPT="-O3 -march=x86-64-v3 -mtune=x86-64-v3 ..."`
- `--cpu=x86-64-v3`
- **`NVCCFLAGS`** — the CUDA profile:

| profile | NVCCFLAGS | runs on |
|---------|-----------|---------|
| specific | `--cuda-gpu-arch=sm_120a -Xclang -target-feature -Xclang +ptx87 -O3` | that arch only (e.g. Blackwell) |
| **allcuda** | `--cuda-gpu-arch=sm_75 -Xclang -target-feature -Xclang +ptx63 -O3` | **every NVIDIA GPU ≥ Pascal** — the driver JIT-compiles the embedded PTX 6.3 to the local arch at runtime |

How CUDA works here: `--enable-cuda-llvm` compiles every `.cu` to PTX
assembly (`clang -S --cuda-device-only`), embeds it via `bin2c`, and
`cuModuleLoadData` JITs it at runtime. PTX **forwards**-JITs (old PTX on
new GPUs) but never backwards — so the lowest arch you want to support
sets the profile. The PTX version flag must satisfy
`arch ≤ PTX` (sm_75 needs 6.3, sm_86 7.1, sm_89 7.8, sm_120a 8.7);
clang's default (4.2) is too old for anything past sm_50 — always pass
the `+ptxNN` feature.

NVENC/NVDEC/CUVID are arch-independent (dynlinked from ffnvcodec;
the user's driver provides them at runtime).

## 5. mpv: `build-<t>.sh`

Copy `build-14600.sh` → `build-x64v3.sh`; change `CPU=`/`TUNE=`,
`BUILD_DIR=`, `PREFIX=`, `FFMPEG_PREFIX=`, `DEPS=`, `LOG=`, make-log
name, and the libplacebo fallback line. The meson option block is
target-independent — do not edit it.

## 6. Orchestrator: `build-all.sh`

Add the target in five spots:

```bash
# step 0 clean list
rm -rf ... /g/media-build/mpv-build/build-x64v3
for d in ... /g/media-build/mpv-build/install-x64v3; do
rm -rf ... /g/media-build/ffmpeg-build/install-x64v3
# step 3 (libplacebo), 4 (ffmpeg), 5 (mpv): one line each
echo "=== STEP 3/6: libplacebo x64v3 ==="; /g/media-build/mpv-build/build-libplacebo-x64v3.sh
# step 6 verify-map case
x64v3) FP=/g/media-build/ffmpeg-build/install-x64v3; MP=/g/media-build/mpv-build/install-x64v3/bin ;;
```

## 7. CI: `.github/workflows/release.yml` TARGET_TABLE

One row in the top-level `env:` block:

```yaml
  TARGET_TABLE: |
    zn3   znver3     Ryzen-5700X3D+RTX-5070-Blackwell sm_120a
    ...
    x64v3 x86-64-v3 generic-AVX2+allCUDA              allcuda
```

Fields: `<name> <cpu-for-labels> <gpu-label> <cuda-or-allcuda>`. The
`setup` job parses this into the build matrix; the `targets` dispatch
input then selects any subset — **no other workflow edits needed**.
Adding the row is what makes the target buildable on GitHub.

Note the row's last field is documentation + artifact naming only;
the actual codegen comes from the scripts (steps 1–5). Keep them in
sync. `cuda=allcuda` rows also exist in `ffmpeg-releases/.github/
workflows/release.yml` — add the same row there (it builds from this
repo's folds).

## 8. `.gitignore`

`/install-x64v3/` under the root ignores (ffmpeg installs are only
produced inside `G:\media-build\ffmpeg-build`/CI caches, not committed).

## 9. Docs

Add the row to the target tables in `CLAUDE.md` and `README.md`
(and `ffmpeg-releases/README.md` for the ffmpeg bundles).

## Verify

```powershell
# one dependency, one target — ~minutes, catches target_env/recipe issues
$env:MSYSTEM='CLANG64'; C:\msys64\usr\bin\bash.exe -lc '/g/media-build/deps-build/build-one.sh x64v3 x264'

# full local chain for the target (deps first, then):
bash -lc '/g/media-build/mpv-build/build-libplacebo-x64v3.sh && /g/media-build/ffmpeg-build/build-x64v3.sh && /g/media-build/mpv-build/build-x64v3.sh'
bash -lc '/g/media-build/mpv-build/smoke_test.sh /g/media-build/mpv-build/install-x64v3/bin'
```

Then push and dispatch CI with `targets = x64v3` (or add it to the
default list) and check the run's job names — the matrix tuple
(`x64v3, x86-64-v3, generic-AVX2+allCUDA, allcuda, install-x64v3`)
appears verbatim.

## CI-only targets

Targets can exist for GitHub builds only — nothing requires a local
`deps-<t>` prefix or install dir. Everything still works locally if
you later run the scripts; the CI matrix is the sole consumer until
then. (This is how `x64v2/v3/v4 + allcuda` ship: scripts + CI rows,
no local disk usage.)
