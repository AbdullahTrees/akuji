#!/usr/bin/env bash
# Build Akuji. One command, so a broken build cannot slip past a shell chain.
#
#     tools/build.sh                 build with the lazbuild on PATH
#     LAZBUILD=/path/to/lazbuild tools/build.sh
#
# The binary lands in bin/. It finds assets/ by walking up from its own
# directory, so it runs straight out of the source tree.

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# lazbuild is not on PATH in a default Lazarus install on Windows, so accept an
# override and fall back to the usual locations before giving up.
if [ -n "${LAZBUILD:-}" ]; then
    :
elif command -v lazbuild >/dev/null 2>&1; then
    LAZBUILD="$(command -v lazbuild)"
else
    for candidate in /e/lazarus/lazbuild.exe /c/lazarus/lazbuild.exe \
                     "/c/Program Files/Lazarus/lazbuild.exe" \
                     /usr/bin/lazbuild /usr/local/bin/lazbuild; do
        [ -x "$candidate" ] && LAZBUILD="$candidate" && break
    done
fi

if [ -z "${LAZBUILD:-}" ]; then
    echo "no lazbuild found. Install Lazarus, or set LAZBUILD to its path." >&2
    exit 2
fi

# RELEASE=1 builds optimised, without debug info and with the symbol table
# stripped. That is 3 MB rather than 30 MB, and almost all of the difference is
# debug info rather than code: -g- does more here than -Xs. The default build
# keeps the symbols, because they are what makes a crash report useful.
OPTS=""
if [ "${RELEASE:-0}" != "0" ]; then
    OPTS="-O3 -g- -Xs -CX -XX"
fi

log="$(mktemp)"
trap 'rm -f "$log"' EXIT

if [ -n "$OPTS" ]; then
    set -- --opt="$OPTS"
else
    set --
fi

if ! "$LAZBUILD" "$@" "$REPO/akuji.lpi" > "$log" 2>&1; then
    echo "BUILD FAILED" >&2
    grep -iE "error|fatal" "$log" | head -20 >&2
    exit 1
fi

grep -E "lines compiled" "$log" | tail -1

# Warnings are not fatal, but burying them is how they accumulate.
if grep -qiE "^\S+\([0-9]+,[0-9]+\) Warning" "$log"; then
    echo "--- warnings ---"
    grep -iE "^\S+\([0-9]+,[0-9]+\) Warning" "$log" | head -10
fi

# SDL is loaded by name at run time, so the runtimes have to sit beside the
# binary. Only Windows binaries are vendored; elsewhere the system provides
# them and there is nothing to copy.
case "$(uname -s)" in
    MINGW*|MSYS*|CYGWIN*)
        for dll in "$REPO"/third_party/sdl2/win64/*.dll; do
            [ -e "$dll" ] && cp -u "$dll" "$REPO/bin/"
        done
        ;;
esac

echo "built: $REPO/bin/akuji.exe"
