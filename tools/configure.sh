#!/usr/bin/env bash
# Get what the build needs, and say plainly what is missing.
#
#     tools/configure.sh
#
# Free Pascal is fetched into .toolchain/ if there is none (tools/find-fpc.sh).
# The libraries are only checked, never installed: they come from the system's
# package manager, which needs root and differs between distributions, so the
# script prints the line to run instead of running it.
#
#   SDL2, SDL2_ttf   needed to build - the game links against them
#   FluidSynth       needed only for music; without it the game runs silently
#
# Exits non-zero if anything the build needs is missing.

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

row() { printf '  %-11s %s\n' "$1" "$2"; }

echo "configure:"

{ read -r FPC_BIN; read -r FPC_CFG || true; } < <("$REPO/tools/find-fpc.sh")
if [ -n "${FPC_CFG:-}" ]; then
    export PPC_CONFIG_PATH="$FPC_CFG"
fi
row "fpc" "$("$FPC_BIN" -iV) for $("$FPC_BIN" -iTP)-$("$FPC_BIN" -iTO)  ($FPC_BIN)"

case "$(uname -s)" in
    MINGW*|MSYS*|CYGWIN*)
        # Vendored beside the source and copied next to the binary by the build.
        for dll in SDL2 SDL2_ttf libfluidsynth-3; do
            if ls "$REPO"/third_party/*/win64/"$dll.dll" >/dev/null 2>&1; then
                row "$dll" "vendored"
            else
                row "$dll" "MISSING from third_party/"
                exit 1
            fi
        done
        echo "ready - run tools/build.sh, or make"
        exit 0
        ;;
esac

missing=()
multiarch="$(gcc -print-multiarch 2>/dev/null || true)"

# The unversioned .so that the linker wants is what the -dev package adds.
dev_lib() {
    local name="$1" pc="$2"
    if command -v pkg-config >/dev/null 2>&1 && pkg-config --exists "$pc"; then
        return 0
    fi
    for d in "/usr/lib/$multiarch" /usr/lib /usr/local/lib "/lib/$multiarch"; do
        [ -e "$d/$name" ] && return 0
    done
    return 1
}

if dev_lib libSDL2.so sdl2; then
    row "SDL2" "$(pkg-config --modversion sdl2 2>/dev/null || echo found)"
else
    row "SDL2" "MISSING"; missing+=(libsdl2-dev)
fi
if dev_lib libSDL2_ttf.so SDL2_ttf; then
    row "SDL2_ttf" "$(pkg-config --modversion SDL2_ttf 2>/dev/null || echo found)"
else
    row "SDL2_ttf" "MISSING"; missing+=(libsdl2-ttf-dev)
fi

# Loaded at run time, by either of the two sonames FluidSynth 2 has used.
fluid="$(ldconfig -p 2>/dev/null | grep -oE 'libfluidsynth\.so\.[23]' | sort -r | head -1 || true)"
if [ -n "$fluid" ]; then
    row "FluidSynth" "$fluid"
else
    row "FluidSynth" "not found - the game will build and run, without music"
    row "" "(apt-get install libfluidsynth3, or libfluidsynth2 on older releases)"
fi

if [ "${#missing[@]}" -gt 0 ]; then
    echo
    echo "missing what the build needs. On Debian or Ubuntu:"
    echo "    sudo apt-get install ${missing[*]}"
    exit 1
fi
echo "ready - run make"
