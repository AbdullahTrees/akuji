#!/usr/bin/env bash
# Fetch Free Pascal 3.2.2 into .toolchain/ and print the path of its fpc.
#
#     tools/fetch-fpc.sh
#
# Linux only: on Windows the Free Pascal inside a Lazarus install is used, and
# there is nothing to fetch. Distribution packages are not used on purpose -
# Ubuntu 20.04, the PortMaster build image, ships 3.0.4, and the game is built
# and tested with 3.2.2.
#
# The official release for this machine's architecture is downloaded once, its
# SHA-256 checked against the value pinned below, and only the parts the game
# needs are unpacked: the compiler with its runtime, fcl-base and x11. Nothing
# is installed system-wide and nothing needs root; delete .toolchain/ and it is
# gone.
#
# Progress goes to stderr; stdout is only the path, so a caller can capture it.

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FPC_VERSION=3.2.2

say() { echo "fetch-fpc: $*" >&2; }

if [ "$(uname -s)" != "Linux" ]; then
    say "only fetches for Linux; elsewhere install Lazarus or Free Pascal $FPC_VERSION"
    exit 2
fi

# The tarball's target, its compiler's name, and its checksum. The checksums
# are of the files downloads.freepascal.org serves, taken when this was
# written; SourceForge serves the same bytes.
case "$(uname -m)" in
    aarch64|arm64)
        TARGET=aarch64-linux; PPC=ppca64
        SHA256=b39470f9b6b5b82f50fc8680a5da37d2834f2129c65c24c5628a80894d565451 ;;
    x86_64|amd64)
        TARGET=x86_64-linux; PPC=ppcx64
        SHA256=5adac308a5534b6a76446d8311fc340747cbb7edeaacfe6b651493ff3fe31e83 ;;
    armv7*|armv6*|armhf|arm)
        TARGET=arm-linux; PPC=ppcarm
        SHA256=971bbcaa1934286ccdaf3998d338afc19a33235e910f8881c75579ed5d6adefd ;;
    *)
        say "no Free Pascal $FPC_VERSION release is known for $(uname -m)"
        exit 2 ;;
esac

PREFIX="$REPO/.toolchain/fpc-$FPC_VERSION-$TARGET"
FPC="$PREFIX/bin/fpc"
CFG="$PREFIX/etc/fpc.cfg"

# The compiler's configuration: where its units are, and where this machine
# keeps the C library and libgcc that linking against SDL needs. Written here
# rather than by Free Pascal's samplecfg, which needs a tool (fpcmkcfg) from a
# package this does not unpack. The paths are absolute, so it is rewritten
# whenever the checkout has moved.
write_cfg() {
    local multiarch libgcc
    multiarch="$(gcc -print-multiarch 2>/dev/null || true)"
    libgcc="$(dirname "$(gcc -print-libgcc-file-name 2>/dev/null)" 2>/dev/null || true)"
    mkdir -p "$PREFIX/etc"
    {
        echo "# Written by tools/fetch-fpc.sh for $PREFIX"
        echo "-Fu$PREFIX/lib/fpc/\$fpcversion/units/\$fpctarget"
        echo "-Fu$PREFIX/lib/fpc/\$fpcversion/units/\$fpctarget/*"
        echo "-Fu$PREFIX/lib/fpc/\$fpcversion/units/\$fpctarget/rtl"
        if [ -n "$multiarch" ]; then
            echo "-Fl/usr/lib/$multiarch"
            echo "-Fl/lib/$multiarch"
        fi
        if [ -n "$libgcc" ] && [ "$libgcc" != "." ]; then
            echo "-Fl$libgcc"
        fi
    } > "$CFG"
}

# Ready means it builds a program that runs - not merely that the compiler
# prints its version, which it does with no configuration at all.
works() {
    local t out
    t="$(mktemp -d)"
    printf 'program hello; uses SysUtils, IniFiles; begin WriteLn(%s); end.\n' "'ok'" > "$t/hello.pas"
    out="$(PPC_CONFIG_PATH="$PREFIX/etc" "$FPC" -FE"$t" "$t/hello.pas" >/dev/null 2>&1 && "$t/hello" 2>/dev/null || true)"
    rm -rf "$t"
    [ "$out" = "ok" ]
}

# Already fetched: done, once the configuration matches where it now lives.
if [ -x "$FPC" ]; then
    if ! grep -qF "# Written by tools/fetch-fpc.sh for $PREFIX" "$CFG" 2>/dev/null; then
        write_cfg
        works || { say "$FPC is here but does not build a program"; exit 1; }
    fi
    echo "$FPC"
    exit 0
fi

NAME="fpc-$FPC_VERSION.$TARGET.tar"
CACHE="$REPO/.toolchain/downloads"
TARBALL="$CACHE/$NAME"
mkdir -p "$CACHE"

checksum_ok() {
    [ -f "$1" ] && [ "$(sha256sum "$1" | cut -d' ' -f1)" = "$SHA256" ]
}

if ! checksum_ok "$TARBALL"; then
    rm -f "$TARBALL"
    # FPC's own server first: SourceForge was measured at a tenth of its speed.
    for url in \
        "https://downloads.freepascal.org/fpc/dist/$FPC_VERSION/$TARGET/$NAME" \
        "https://downloads.sourceforge.net/project/freepascal/Linux/$FPC_VERSION/$NAME"
    do
        say "downloading $NAME (about 100 MB, once) from ${url%%/fpc/*}${url#*sourceforge.net}"
        if command -v curl >/dev/null 2>&1; then
            curl -fL --retry 3 --progress-bar -o "$TARBALL.part" "$url" || { rm -f "$TARBALL.part"; continue; }
        elif command -v wget >/dev/null 2>&1; then
            wget -q --show-progress -O "$TARBALL.part" "$url" || { rm -f "$TARBALL.part"; continue; }
        else
            say "needs curl or wget to download Free Pascal"
            exit 2
        fi
        mv "$TARBALL.part" "$TARBALL"
        if checksum_ok "$TARBALL"; then
            break
        fi
        say "the download from $url does not match the pinned checksum - discarded"
        rm -f "$TARBALL"
    done
fi

if ! checksum_ok "$TARBALL"; then
    say "could not get an intact $NAME"
    exit 1
fi

say "unpacking into ${PREFIX#$REPO/}"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
rm -rf "$PREFIX"
mkdir -p "$PREFIX"

tar -xf "$TARBALL" -C "$WORK"
tar -xf "$WORK/fpc-$FPC_VERSION.$TARGET/binary.$TARGET.tar" -C "$WORK"
# The compiler, its driver and the runtime; fcl-base, for IniFiles and
# SyncObjs; and x11, whose X and XLib the SDL binding names on Unix for the
# window-manager structures - types only, the game never talks to X. That is
# everything the game's uses clauses reach.
for part in base units-fcl-base units-x11; do
    tar -xzf "$WORK/$part.$TARGET.tar.gz" -C "$PREFIX"
done

# The driver looks for the compiler beside itself. A copy rather than a
# symlink, because this directory may be a Windows folder mounted into a
# container, where symlinks do not survive.
cp "$PREFIX/lib/fpc/$FPC_VERSION/$PPC" "$PREFIX/bin/$PPC"
chmod +x "$PREFIX/bin/"* 2>/dev/null || true

write_cfg
if ! works; then
    say "unpacked, but $FPC does not build a working program"
    exit 1
fi

say "Free Pascal $FPC_VERSION ready"
echo "$FPC"
