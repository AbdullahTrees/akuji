#!/usr/bin/env bash
# Builds the PortMaster release inside the aarch64 build image:
#
#   tools/package-portmaster.sh          (from the host, runs this in Docker)
#
# 1. the game, optimised and stripped, as bin/akuji
# 2. a minimal FluidSynth, with every audio driver and optional dependency
#    off: the game only calls the synth/player API and renders into its own
#    SDL audio device, so the library needs nothing but libc
# 3. dist/Akuji (the PR folder) and dist/akuji.zip (the testing zip)

set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
HERE="$REPO/portmaster"
DIST="$REPO/dist"
STAGE="$DIST/Akuji"
GAME="$STAGE/akuji"
FS_VER="${FS_VER:-2.4.6}"

cd "$REPO"

[ "$(uname -m)" = "aarch64" ] || {
    echo "build this on an aarch64 Linux (the PortMaster build image)" >&2
    exit 1
}

# Copies a library's NEEDED closure into libs.aarch64/, each under the exact
# SONAME the loader asks for. The CFW baseline is left to the device: glibc,
# the C++ runtime, zlib, SDL2, and the GPU/display stack are built and patched
# per device, and a bundled copy shadows them - which is how ports get
# device-only input, display and segfault bugs. What remains is the port's own
# dependency chain (FluidSynth, its DLS/soundfile libraries, and their glib),
# none of which the baseline promises.
copy_closure() {
    local src="$1" soname dep
    for soname in $(readelf -d "$src" | sed -n 's/.*Shared library: \[\(.*\)\]/\1/p'); do
        case "$soname" in
            libc.so.6|libm.so.6|libpthread.so.0|libdl.so.2|librt.so.1|ld-linux-aarch64.so.1|\
            libstdc++.so.6|libgcc_s.so.1|libz.so.1|\
            libSDL2*|libGL.so*|libGLX*|libEGL*|libGLES*|libdrm.so*|libgbm.so*|libwayland*|libmali*)
                continue ;;
        esac
        [ -e "$GAME/libs.aarch64/$soname" ] && continue
        dep="$(find /usr/lib/aarch64-linux-gnu /lib/aarch64-linux-gnu /usr/lib /lib \
                     -maxdepth 1 -name "$soname" 2>/dev/null | head -1)"
        [ -n "$dep" ] || { echo "missing $soname" >&2; exit 1; }
        cp -L "$dep" "$GAME/libs.aarch64/$soname"
        copy_closure "$GAME/libs.aarch64/$soname"
    done
}

# --- the game -----------------------------------------------------------------
echo "== game"
RELEASE=1 tools/build.sh
[ -f bin/akuji ] || { echo "no bin/akuji after the build" >&2; exit 1; }

# --- FluidSynth ---------------------------------------------------------------
echo "== fluidsynth $FS_VER"
DL="$REPO/.toolchain/downloads"
SRC="$DL/fluidsynth-$FS_VER.tar.gz"
mkdir -p "$DL"
[ -f "$SRC" ] || curl -fsSL -o "$SRC" \
    "https://github.com/FluidSynth/fluidsynth/archive/refs/tags/v$FS_VER.tar.gz"

# libinstpatch is what lets FluidSynth load DLS banks, so an optional gm.dls
# works; only its development headers are missing from the image.
pkg-config --exists libinstpatch-1.0 || {
    apt-get update -qq
    apt-get install -y --no-install-recommends libinstpatch-dev > /dev/null
}

BUILD="$(mktemp -d)"
trap 'rm -rf "$BUILD"' EXIT
tar -xzf "$SRC" -C "$BUILD"
cd "$BUILD/fluidsynth-$FS_VER"
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=ON \
    -Denable-alsa=OFF -Denable-pulseaudio=OFF -Denable-pipewire=OFF \
    -Denable-jack=OFF -Denable-sdl2=OFF -Denable-sdl3=OFF -Denable-oss=OFF \
    -Denable-dsound=OFF -Denable-wasapi=OFF -Denable-waveout=OFF \
    -Denable-coreaudio=OFF -Denable-coremidi=OFF -Denable-dart=OFF \
    -Denable-kai=OFF -Denable-portaudio=OFF -Denable-opensles=OFF \
    -Denable-oboe=OFF -Denable-aufile=OFF -Denable-midishare=OFF \
    -Denable-libsndfile=ON -Denable-libinstpatch=ON -Denable-dbus=OFF \
    -Denable-readline=OFF -Denable-ladspa=OFF -Denable-openmp=OFF \
    -Denable-network=OFF -Denable-ipv6=OFF -Denable-systemd=OFF \
    -Denable-framework=OFF > "$BUILD/cmake.log" 2>&1
cmake --build build --parallel "$(nproc)" >> "$BUILD/cmake.log" 2>&1
FS_LIB="$(find build -name 'libfluidsynth.so.3*' -type f | head -1)"
[ -n "$FS_LIB" ] || { tail -30 "$BUILD/cmake.log"; exit 1; }
FS_LIB="$(realpath "$FS_LIB")"

# --- stage --------------------------------------------------------------------
echo "== package"
cd "$REPO"
rm -rf "$DIST"
mkdir -p "$GAME/libs.aarch64" "$GAME/licenses"
cp bin/akuji "$GAME/akuji.aarch64"
cp "$FS_LIB" "$GAME/libs.aarch64/libfluidsynth.so.3"
copy_closure "$GAME/libs.aarch64/libfluidsynth.so.3"
cp "$HERE/akuji.ini" "$GAME/"
cp "$HERE"/licenses/* "$GAME/licenses/"

# The data the game loads, without the player's files or Microsoft's bank.
DATA="$DIST/data"
mkdir -p "$DATA"
cp -r assets "$DATA/assets"
rm -f "$DATA/assets/data/save.dat" "$DATA/assets/data/system.dat" \
      "$DATA/assets/soundfonts/gm.dls"
# The repo copy is a desktop one; the port starts fullscreen with the free bank,
# and leaves the log on: this package goes to testers, who need akuji.log.
sed -i 's/^fullscreen=.*/fullscreen=on/; s/^soundfont=.*/soundfont=gs/; s/^enabled=.*/enabled=on/' "$DATA/assets/system.ini"
tar -C "$DATA" -czhf "$GAME/gamedata.tar.gz" --owner=0 --group=0 \
    --numeric-owner assets
rm -rf "$DATA"

cp "$HERE/port.json" "$HERE/README.md" "$HERE/gameinfo.xml" \
   "$HERE/testing_thread.txt" "$HERE/Akuji.sh" "$STAGE/"
for img in screenshot.png cover.png; do
    [ -f "$HERE/$img" ] && cp "$HERE/$img" "$STAGE/"
done

# The testing zip uses the installed layout: metadata inside the game folder.
TESTING="$DIST/testing"
mkdir -p "$TESTING"
cp "$STAGE/Akuji.sh" "$TESTING/"
cp -r "$GAME" "$TESTING/akuji"
cp "$HERE/port.json" "$HERE/README.md" "$HERE/gameinfo.xml" \
   "$HERE/testing_thread.txt" "$TESTING/akuji/"
for img in screenshot.png cover.png; do
    [ -f "$HERE/$img" ] && cp "$HERE/$img" "$TESTING/akuji/"
done
(cd "$TESTING" && zip -qr "$DIST/akuji.zip" "Akuji.sh" akuji)
rm -rf "$TESTING"

# --- checks -------------------------------------------------------------------
echo "== checks"
fail=0
check() { "$@" || { echo "FAILED: $*" >&2; fail=1; }; }

check test -x "$GAME/akuji.aarch64"
file "$GAME/akuji.aarch64" | grep -q "ARM aarch64" \
    || { echo "FAILED: not an aarch64 binary" >&2; fail=1; }
! readelf -d "$GAME/akuji.aarch64" | grep -q "libX11" \
    || { echo "FAILED: libX11 is still NEEDED" >&2; fail=1; }
[ -z "$(find "$GAME/libs.aarch64" -name 'libSDL2*')" ] \
    || { echo "FAILED: SDL2 is bundled" >&2; fail=1; }
[ -z "$(find "$GAME/libs.aarch64" \( -name 'libstdc++*' -o -name 'libgcc_s*' -o -name 'libz.so*' \
    -o -name 'libGL*' -o -name 'libEGL*' -o -name 'libGLES*' -o -name 'libdrm*' -o -name 'libgbm*' \
    -o -name 'libwayland*' \) )" ] \
    || { echo "FAILED: a core system library is bundled" >&2; fail=1; }
[ -z "$(find "$DIST" -type l)" ] \
    || { echo "FAILED: package contains symlinks" >&2; fail=1; }
! tar -tzf "$GAME/gamedata.tar.gz" | grep -qE 'save\.dat|system\.dat|gm\.dls' \
    || { echo "FAILED: player files or gm.dls are in the archive" >&2; fail=1; }
[ -f "$GAME/gamedata.tar.gz" ] || { echo "FAILED: no data archive" >&2; fail=1; }
[ -f "$DIST/akuji.zip" ] || { echo "FAILED: no testing zip" >&2; fail=1; }

echo
echo "binary NEEDED:"
readelf -d "$GAME/akuji.aarch64" | grep NEEDED
echo "bundled library NEEDED:"
readelf -d "$GAME/libs.aarch64/libfluidsynth.so.3" | grep NEEDED
echo
echo "glibc maxima:"
for f in "$GAME/akuji.aarch64" "$GAME/libs.aarch64"/*.so*; do
    printf '  %-45s ' "$(basename "$f")"
    objdump -T "$f" | grep -o 'GLIBC_[0-9.]*\|GLIBCXX_[0-9.]*' | sort -Vu | tail -1
done
echo
echo "data archive: $(stat -c %s "$GAME/gamedata.tar.gz") bytes, \
$(tar -tzf "$GAME/gamedata.tar.gz" | wc -l) entries"
echo "package:      $(find "$STAGE" -type f | wc -l) files"
echo "testing zip:  $(stat -c %s "$DIST/akuji.zip") bytes"
[ -f "$HERE/screenshot.png" ] || echo "note: no portmaster/screenshot.png yet"
[ -f "$HERE/cover.png" ] || echo "note: no portmaster/cover.png yet"

[ "$fail" = 0 ] && echo "OK" || exit 1
