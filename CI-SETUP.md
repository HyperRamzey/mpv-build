# CI pipeline setup (GitHub Actions)

`.github/workflows/release.yml` reproduces the local `build-all.sh`
flow 1:1 on GitHub-hosted Windows runners. This document covers the
one-time repository setup.

## Repository layout

Three sibling repositories under the SAME GitHub owner (user or org):

| Repo           | Local source     | Contents                                    |
|----------------|------------------|---------------------------------------------|
| `mpv-build`    | `G:\mpv-build`   | this workflow + mpv/libplacebo scripts      |
| `ffmpeg-build` | `G:\ffmpeg-build`| FFmpeg per-target build scripts             |
| `deps-build`   | `G:\deps-build`  | dependency framework (recipes, patches)     |

The workflow checks out all three and maps them to `G:\` via `subst`,
because every script hardcodes `/g/mpv-build`, `/g/ffmpeg-build`,
`/g/deps-build` and `/clang64/...` paths.

## One-time push (run once, from each local tree)

Each tree already carries a `.gitignore` that excludes upstream clones,
build dirs, prefixes, installs and logs, so a plain `git add -A` stages
exactly the tracked content (scripts, recipes, patches, docs, NOTICE,
workflow).

```powershell
# mpv-build (contains .github/workflows/release.yml)
cd G:\mpv-build
git init -b main; git config core.autocrlf false
git add -A
git commit -m "mpv build scripts + CI pipeline"
git remote add origin https://github.com/<OWNER>/mpv-build.git
git push -u origin main

# ffmpeg-build
cd G:\ffmpeg-build
git init -b main; git config core.autocrlf false
git add -A
git commit -m "FFmpeg per-target build scripts"
git remote add origin https://github.com/<OWNER>/ffmpeg-build.git
git push -u origin main

# deps-build
cd G:\deps-build
git init -b main; git config core.autocrlf false
git add -A
git commit -m "self-compiled dependency framework"
git remote add origin https://github.com/<OWNER>/deps-build.git
git push -u origin main
```

`<OWNER>` must be identical for all three repos (the workflow resolves
siblings via `${{ github.repository_owner }}`). If you use different
names, adjust the `repository:` inputs in `release.yml`.

## Triggers

- **Push a tag** `v*` → full build + GitHub Release with 6 zips
  (mpv/ffmpeg × zn3/zn2/11700) under that tag.
- **Actions → release → Run workflow** → full build; with a
  `release_tag` the Release is created under that tag, without one a
  `build-<UTC stamp>` tag is auto-created so every successful run
  posts a Release. The release body carries the prominent
  NOT-REDISTRIBUTABLE notice.
  Knobs: `force_deps` (rebuild all deps), `deps_lto` (default on,
  matches local `common.sh`).

## Runner + toolchain notes

- `windows-2025` (4 vCPU / 16 GB). `-j14` is hardcoded inside the
  mpv/ffmpeg scripts (kept 1:1); it oversubscribes 4 cores but is
  correct. On larger runners it is a speed win without changes.
- MSYS2 CLANG64 is installed to `C:\msys64` (so `/clang64` resolves
  exactly like locally) with the same package set as the local
  machine: clang 22, meson, ninja, cmake, nasm, python, rust,
  cargo-c, pkgconf, autotools chain, gperf/flex/bison, gettext.
- **No CUDA toolkit is installed.** `--enable-cuda-llvm` makes FFmpeg
  compile CUDA kernels with clang's NVPTX backend against ffmpeg's own
  `compat/cuda/cuda_runtime.h` (`-nocudainc -nocudalib
  --cuda-device-only`); `ffmpeg/configure` never touches the toolkit
  (`check_nvcc` runs `$nvcc`, which is `clang`). The `CUDA_PATH`/PATH
  exports in the ffmpeg scripts are harmless no-ops on the runner.
  NVENC/NVDEC come from self-built `ffnvcodec` headers and load the
  user's GPU driver at runtime.

## Caching / timing

- First (cold) run clones ~90 dep repos + mpv + ffmpeg + libplacebo
  and builds everything from scratch. On the standard 4-vCPU runner
  the per-target `deps` job is the long pole (a few hours); each job
  stays under its `timeout-minutes`.
- Later runs restore the source clones and per-target prefixes; the
  stamp cache (`src/<lib>/.built-<target>`, same mechanism as local)
  rebuilds only libraries whose git HEAD moved.
- Cache budget is 10 GB per repo; entries are LRU-evicted. Keys:
  `src-*` (sources), `dpfx-<target>-*` (deps prefix + stamps),
  `ffinst-<target>-*` (FFmpeg install). The `src-` entry holds ~90
  full (non-shallow) clones plus mpv/ffmpeg/libplacebo and is the
  biggest entry (~5 GB); keep an eye on the repo cache usage page —
  if LRU pressure evicts it, the next run simply re-clones (the deps
  job pins LF line endings so a cold clone is safe).

## Differences from local (deliberate, documented)

1. `build-all.sh` step 0 (clean) is a no-op: runners are pristine.
2. The smoke test is **fatal** in CI (locally it only warns), so a
   regression fails the pipeline instead of shipping silently.
3. `lint-scripts` job runs `check-scripts.sh` (bash -n + broken
   line-continuation scan) and gates the build (`deps` needs it).
4. Smoke/verify steps run headless: all checks are feature-list based
   (`--vo=help`, `--hwdec=help`, ldd closure) and need no GPU.
