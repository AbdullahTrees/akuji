#!/usr/bin/env bash
# Build Akuji. One command, so a broken build cannot slip past a shell chain.
#
#     tools/build.sh                 build, fetching Free Pascal first if needed
#     RELEASE=1 tools/build.sh       optimised, no debug info, stripped
#     AKUJI_EXE=bin/other.exe tools/build.sh
#     FPC=/path/to/fpc tools/build.sh
#
# Plain Free Pascal, no Lazarus: since the window moved to SDL the game uses
# nothing from the LCL, so lazbuild has nothing to add. The flags below are
# the ones akuji.lpi gives lazbuild - read off its command line - so this and
# the Lazarus IDE build the same program. tools/find-fpc.sh chooses the
# compiler, and on Linux fetches one if there is none.
#
# AKUJI_EXE builds somewhere other than bin/akuji(.exe), as a path relative to
# the repository. Windows locks a running executable, so without it a build
# fails for as long as the game is open - which is exactly when you want to
# build the next one.
#
# The binary lands in bin/. It finds assets/ by walking up from its own
# directory, so it runs straight out of the source tree.

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

WINDOWS=0
case "$(uname -s)" in MINGW*|MSYS*|CYGWIN*) WINDOWS=1 ;; esac

# A Windows fpc.exe wants Windows paths, so every path handed over goes
# through this - and Git Bash must then be told to leave them alone. It reads
# -FuC:/Users/... as a Unix path LIST, "C" and "/Users/...", and rewrites the
# second half to C:/Program Files/Git/Users/..., so every search path arrived
# mangled and the first unit outside the project's own folder was not found.
native() {
    if [ "$WINDOWS" = 1 ]; then cygpath -m "$1"; else echo "$1"; fi
}
if [ "$WINDOWS" = 1 ]; then
    export MSYS2_ARG_CONV_EXCL='*' MSYS_NO_PATHCONV=1
fi

{ read -r FPC_BIN; read -r FPC_CFG || true; } < <("$REPO/tools/find-fpc.sh")
if [ -n "${FPC_CFG:-}" ]; then
    export PPC_CONFIG_PATH="$FPC_CFG"
fi

CPU="$("$FPC_BIN" -iTP)"
OS="$("$FPC_BIN" -iTO)"
LIB="$REPO/lib/$CPU-$OS"

if [ -n "${AKUJI_EXE:-}" ]; then
    EXE="$REPO/$AKUJI_EXE"
elif [ "$WINDOWS" = 1 ]; then
    EXE="$REPO/bin/akuji.exe"
else
    EXE="$REPO/bin/akuji"
fi
mkdir -p "$LIB" "$(dirname "$EXE")"

# akuji.lpi's, as lazbuild passes them: -MObjFPC (each unit says {$MODE
# DELPHI} for itself), C operators, goto, ansistrings, inline, -O1, and debug
# info with line numbers - which is what puts a file and line in a crash.
ARGS=(-MObjFPC -Scghi -O1 -g -gl -l -vewnhibq
      "-Fi$(native "$LIB")" "-FU$(native "$LIB")"
      "-FE$(native "$(dirname "$EXE")")" "-o$(native "$EXE")")
for dir in . src src/components src/events src/gameplay src/media src/render \
           src/screens tests third_party/sdl2-for-pascal; do
    ARGS+=("-Fu$(native "$REPO/$dir")")
done

if [ "$WINDOWS" = 1 ]; then
    ARGS+=(-WG)      # a windowed program, not a console one
else
    # Debian and Ubuntu keep libraries in a per-architecture directory the
    # linker Free Pascal generates does not search on its own; SDL2 is there.
    if command -v gcc >/dev/null 2>&1; then
        multiarch="$(gcc -print-multiarch 2>/dev/null || true)"
        for d in "/usr/lib/$multiarch" "/lib/$multiarch"; do
            [ -n "$multiarch" ] && [ -d "$d" ] && ARGS+=("-Fl$d")
        done
    fi
fi

# RELEASE=1 builds optimised, without debug info and with the symbol table
# stripped. That is 3 MB rather than 30 MB, and almost all of the difference is
# debug info rather than code: -g- does more here than -Xs. The default build
# keeps the symbols, because they are what makes a crash report useful.
if [ "${RELEASE:-0}" != "0" ]; then
    ARGS+=(-O3 -g- -Xs -CX -XX)
fi

log="$(mktemp)"
trap 'rm -f "$log"' EXIT

if ! "$FPC_BIN" "${ARGS[@]}" "$(native "$REPO/akuji.lpr")" > "$log" 2>&1; then
    echo "BUILD FAILED ($FPC_BIN)" >&2
    grep -iE "error|fatal" "$log" | head -20 >&2
    exit 1
fi

grep -E "lines compiled" "$log" | tail -1

# Warnings are not fatal, but burying them is how they accumulate.
if grep -qiE "^\S+\([0-9]+,[0-9]+\) Warning" "$log"; then
    echo "--- warnings ---"
    grep -iE "^\S+\([0-9]+,[0-9]+\) Warning" "$log" | head -10
fi

# SDL and FluidSynth are loaded by name at run time, so on Windows the vendored
# runtimes have to sit beside the binary. Elsewhere the system provides them.
if [ "$WINDOWS" = 1 ]; then
    for dll in "$REPO"/third_party/*/win64/*.dll; do
        [ -e "$dll" ] && cp -u "$dll" "$(dirname "$EXE")/"
    done
fi

echo "built: $EXE"
