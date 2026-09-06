#!/bin/bash
# fix-static-pcs.sh <prefix> — ensure Libs.private carries the C++ runtime
# (-lc++ -lunwind) for every static archive that actually needs it. Meson/cmake
# don't emit these, which breaks consumers' single-lib pkg-config link tests
# (ffmpeg configure). Also strips GNU -lstdc++ residue (libc++ toolchain).
# Idempotent.
PREFIX="${1:?usage: fix-static-pcs.sh <deps-prefix>}"
PCDIR="$PREFIX/lib/pkgconfig"
[[ -d "$PCDIR" ]] || exit 0
fixed=0
for a in "$PREFIX"/lib/*.a; do
	name="$(basename "$a" .a)"          # e.g. libopenh264
	# shaderc's pc is consumed only by libplacebo, whose meson links the
	# static libc++.a by full path itself; -lc++ here would resolve to
	# libc++.dll.a (import lib) -> duplicate C++ runtime symbols at link
	case "$name" in libshaderc*) continue ;; esac
	pc=""
	for cand in "$PCDIR/$name.pc" "$PCDIR/${name#lib}.pc" \
		"$PCDIR/$(echo "${name#lib}" | tr "A-Z" "a-z").pc"; do
		[[ -f "$cand" ]] && { pc="$cand"; break; }
	done
	[[ -n "$pc" ]] || continue
	# does the archive contain C++ runtime references? (exceptions, std, new/delete)
	if nm "$a" 2>/dev/null | grep -qE "__cxa_|_ZSt|_Znwm|_ZdlPv|_ZdaPv"; then
		if ! grep -q -- "-lc++" "$pc"; then
			if grep -q "^Libs.private:" "$pc"; then
				sed -i "s| -lstdc++||; s|^Libs.private:|Libs.private: -lc++ -lunwind|" "$pc"
			else
				echo "Libs.private: -lc++ -lunwind" >> "$pc"
			fi
			fixed=$((fixed+1))
			echo "fix-static-pcs: $name -> -lc++ -lunwind"
		fi
	fi
done

# libarchive: mpv's meson consumes its pc WITHOUT --static, so the zstd/
# bz2/lzma/... closure in Libs.private never reaches the link line
# (undefined ZSTD_* at mpv.exe link). Our prefixes are static-only, so
# promote Libs.private into Libs. Idempotent (marker: -lzstd in Libs).
la="$PCDIR/libarchive.pc"
if [[ -f "$la" ]]; then
	if grep -q '^Libs.private:' "$la" \
		&& ! grep '^Libs:' "$la" | grep -q -- '-lzstd'; then
		priv="$(sed -n 's/^Libs.private:[[:space:]]*//p' "$la" | tr -d '\r')"
		sed -i 's/\r$//' "$la"
		sed -i "s|^Libs:.*|& $priv|" "$la"
		echo "fix-static-pcs: libarchive Libs += Libs.private"
	else
		echo "fix-static-pcs: libarchive.pc skip" \
			"(has-private=$(grep -c '^Libs.private:' "$la")," \
			"zstd-in-libs=$(grep '^Libs:' "$la" | grep -c -- '-lzstd'))"
	fi
else
	echo "fix-static-pcs: no libarchive.pc in $PCDIR"
fi

echo "fix-static-pcs: $fixed pc files patched"