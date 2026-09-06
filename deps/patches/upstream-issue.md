# libmysofa: files >32MB fail with MYSOFA_UNSUPPORTED_FORMAT (10001) — arbitrary offset caps in the minimal HDF5 reader

## Summary
libmysofa (master) cannot load valid SOFA files whose HDF5 metadata blocks
(object-header continuations, data layouts) are located beyond ~32 MB / 256 MB
in the file. Modern BRIR exports (e.g. ASH Toolset, ~1 GB,
netCDF 4.9.2 / HDF5 1.14) always fail with err=10001 while the official SOFA
API reads them fine. Small HRTFs load — which is why this went unnoticed.

## Root cause (verified with VDEBUG tracing on a 989 MB SimpleFreeFieldHRIR file)
`src/hdf/dataobject.c` and `src/hdf/fractalhead.c` contain arbitrary caps that
do not exist in the HDF5 specification:

| location | cap | effect on large files |
|---|---|---|
| dataobject.c:893 `readOHDRHeaderMessageContinue` | `offset > 0x2000000` (32 MB) | object-header continuation blocks placed after large raw datasets are rejected -> 10001 |
| dataobject.c:510 `readOHDRHeaderMessageDataLayout` | `data_size > 0x10000000` (256 MB) | contiguous Data.IR of ~1 GB (M x R x N float64) rejected |
| fractalhead.c:113 | `offset > 0x10000000` (256 MB) | fractal-heap blocks beyond 256 MB rejected |
| dataobject.c:220 `readOHDRHeaderMessageDatatype` | `dt->size > 64` | fixed-string attributes longer than 63 chars (e.g. Title) rejected |

Failure path on the 989 MB file: root group parses -> fractal heap walk ->
first dim-scale object "I" -> OHDR continuation message (type 16) -> contained
offset > 32 MB -> `MYSOFA_UNSUPPORTED_FORMAT`.

## Fix (3-line patch, attached, verified: 989 MB file loads in ~1.1 s)
Raise the caps to values that cannot be hit by legitimate files:
- continuation offset: 0x2000000 -> 0x10000000000ULL
- contiguous data_size: 0x10000000 -> 0x1000000000ULL
- fractal-head offset: 0x10000000 -> 0x10000000000ULL
- datatype size: 64 -> 4096

Note: `data->data = calloc(1, data_size)` already loads the whole dataset into
RAM by design, so the old caps only blocked large files without protecting
memory use in any way.

## Repro
Any SOFA > ~32 MB written by netCDF 4.8+/HDF5 1.10+ where metadata blocks are
placed after the raw IR arrays (typical write order: attributes, then Data.IR).
ASH Toolset 4.x BRIR exports reproduce this 100%.
