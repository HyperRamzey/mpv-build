@echo off
REM ==============================================================================
REM Full build orchestrator CMD wrapper
REM Runs build-all.sh which does:
REM   clean → git pull + libplacebo (zn3+zn2+11700) + FFmpeg (zn3+zn2+11700)
REM   + mpv (zn3+zn2+11700), all in correct dependency order.
REM 11700 = Intel Core i7-11700 (Rocket Lake) + RTX 4080 (sm_89).
REM ==============================================================================
setlocal
set MSYSTEM=CLANG64

echo.
echo === Starting full build (clean + git pull + libplacebo + FFmpeg + mpv) ===
echo === Targets: zn3 (Zen3), zn2 (Zen2), 11700 (RKL + RTX 4080) ===
echo.

C:\msys64\usr\bin\bash.exe -lc "/g/mpv-build/build-all.sh"

echo.
echo === Build complete. Check output above for errors. ===
echo.
echo mpv zn3 (Zen3):      G:\mpv-build\install-zn3\bin\mpv.exe
echo mpv zn2 (Zen2):      G:\mpv-build\install-zn2\bin\mpv.exe
echo mpv 11700 (RKL+4080): G:\mpv-build\install-11700\bin\mpv.exe
echo.
pause
