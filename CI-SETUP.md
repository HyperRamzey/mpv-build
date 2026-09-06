# CI pipeline setup (GitHub Actions) — 2-repo model

`.github/workflows/release.yml` in **this repo** reproduces the local
`build-all.sh` flow 1:1 on GitHub-hosted Windows runners. This document
covers the repository setup.

## Repository layout (TWO repos total)

Everything needed to build is vendored inside **mpv-build** — it is
self-contained:

| Repo              | Contents                                                     |
|-------------------|--------------------------------------------------------------|
| `mpv-build`       | THIS repo: mpv/libplacebo scripts, `.github/workflows/`, **`deps/`** (dependency framework fold), **`ffmpeg-scripts/`** (FFmpeg per-target build scripts fold). Posts the mpv releases. |
| `ffmpeg-releases` | FFmpeg-only release workflow. Checks out `mpv-build` (the same self-contained way) and posts the ffmpeg releases. |

On the runner, every job:

1. checks out **mpv-build** once,
2. *materializes* the folds: `deps/ -> g/deps-build`,
   `ffmpeg-scripts/ -> g/ffmpeg-build`,
3. maps the drive with `subst G: <workspace>\g` — all build scripts
   hardcode `/g/mpv-build`, `/g/ffmpeg-build`, `/g/deps-build` and
   `/clang64/...` paths, so they run verbatim, byte-identical to local.

MSYS2 is installed to `C:\msys64` so `/clang64` resolves exactly like on
the local machine (clang 22, meson, ninja, cmake, nasm, python, rust,
cargo-c, pkgconf, autotools chain, gperf/flex/bison, gettext).

## One-time push (run once, from each local tree)

```powershell
# mpv-build (contains everything: scripts + deps/ + ffmpeg-scripts/
#           + the workflow)
cd G:\mpv-build
git add -A
git commit -m "2-repo model: vendor deps/ + ffmpeg-scripts/; 14600 target;
               lean static linkage; configurable CI targets"
git push origin main

# ffmpeg-releases (workflow-only repo)
cd G:\ffmpeg-releases
git add -A
git commit -m "2-repo model: materialize mpv-build folds; 14600 target"
git push origin main
```

The historical `deps-build` / `ffmpeg-build` sibling repos are no longer
required by CI (the folds supersede them). They can be archived or kept
as local-only working trees; local builds keep working against
`G:\deps-build` / `G:\ffmpeg-build`, which the materialized copies
occupy.

## Triggers

- **Push a tag** `v*` → full build + GitHub Release under that tag
  (mpv zips from mpv-build, ffmpeg zips from ffmpeg-releases).
- **Actions → release → Run workflow** → full build with knobs:
  - `targets` — space-separated subset (default: all five:
    `zn3 zn2 11700 3050 14600`; e.g. just `14600` for one target)
  - `force_deps` — rebuild all dependencies (ignore stamp cache)
  - `deps_lto` — thin-LTO the dependency libs (default on)
  - `release_tag` — optional explicit tag; otherwise a
    `build-<UTC stamp>` tag is auto-created per successful run
- The release bodies carry the prominent NOT-REDISTRIBUTABLE notice.

## Runner + toolchain notes

- `windows-2025` (4 vCPU / 16 GB). `-j14` is hardcoded inside the
  mpv/ffmpeg scripts (kept 1:1); it oversubscribes 4 cores but is
  correct. On larger runners it is a speed win without changes.
- **No CUDA toolkit is installed.** `--enable-cuda-llvm` makes FFmpeg
  compile CUDA kernels with clang's NVPTX backend against ffmpeg's own
  `compat/cuda/cuda_runtime.h` (`-nocudainc -nocudalib
  --cuda-device-only`). NVENC/NVDEC come from self-built `ffnvcodec`
  headers and load the user's GPU driver at runtime.
- Cross-ISA smoke: binaries built for a CPU the runner lacks SIGILL
  before `main()`; the smoke test detects this and reports SKIP (not
  FAIL) for the affected feature checks. GH `windows-2025` Xeons have
  AVX-512, so all five targets (incl. rocketlake/raptorlake) run there.

## Caching / timing

- First (cold) run clones ~90 dep repos + mpv + ffmpeg + libplacebo
  and builds everything from scratch. On the standard 4-vCPU runner
  the per-target `deps` job is the long pole (a few hours); each job
  stays under its `timeout-minutes`.
- Later runs restore the source clones and per-target prefixes; the
  stamp cache (`src/<lib>/.built-<target>`) rebuilds only libraries
  whose git HEAD **or recipe file** changed.
- Cache budget is 10 GB per repo; entries are LRU-evicted. Keys:
  `src-*` (sources), `dpfx-<target>-*` (deps prefix + stamps),
  `ffinst-<target>-*` (FFmpeg install).

## Differences from local (deliberate, documented)

1. `build-all.sh` step 0 (clean) is a no-op: runners are pristine.
2. The smoke test is **fatal** in CI (locally it only warns).
3. `lint-scripts` gates the build (`deps` needs it).
4. Smoke/verify steps run headless: all checks are feature-list based
   (`--vo=help`, `--hwdec=help`, ldd closure) and need no GPU.
