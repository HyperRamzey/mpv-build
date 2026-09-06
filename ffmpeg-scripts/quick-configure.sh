#!/bin/bash
export PATH="/usr/bin:/bin:/clang64/bin:$PATH"
export MSYSTEM=CLANG64
cd /g/ffmpeg-build/ffmpeg
rm -rf ffbuild
echo "Starting configure..."
./configure --prefix=/g/ffmpeg-build/install --cc=clang >/g/ffmpeg-build/configure-quick.log 2>&1
echo "Configure exit code: $?"
if [ -f ffbuild/common.mak ]; then
	echo "ffbuild/common.mak OK"
else
	echo "ffbuild/common.mak MISSING"
	tail -20 /g/ffmpeg-build/configure-quick.log
fi
