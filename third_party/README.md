# third_party

Vendored rather than fetched at build time, so that a shallow clone builds with
no network and no package manager. Each entry records where it came from and
what it is under.

## sdl2-for-pascal

Pascal header translations for SDL2 and its satellite libraries.

| | |
|---|---|
| upstream | https://github.com/PascalGameDevelopment/SDL2-for-Pascal |
| revision | a48b83efbfa7c13ce548905ebdc954eb6c8384be |
| licence | MPL-2.0 or zlib, at your option - both texts are in the directory |

Only the header translations are used: `sdl2.pas` and `sdl2_mixer.pas`, with
the `.inc` files they include. Nothing here is modified.

## sdl2

The SDL2 and SDL2_mixer runtime libraries for 64-bit Windows.

| | |
|---|---|
| SDL2 | 2.32.10, from https://github.com/libsdl-org/SDL/releases |
| SDL2_mixer | 2.8.2, from https://github.com/libsdl-org/SDL_mixer/releases |
| SDL2_ttf | 2.24.0, from https://github.com/libsdl-org/SDL_ttf/releases |
| licence | zlib - see README-SDL.txt |

`tools/build.sh` copies these next to the built binary.

**This SDL2_mixer build plays MIDI through the Windows MIDI Mapper.** Its
import table names `WINMM.dll`, so the native-MIDI backend is compiled in, and
MIDI reaches the same synthesiser the game has always used. That matters
because it means the music does not change timbre on Windows when the player
moves from the winmm code to SDL_mixer.

It is also the reason no soundfont ships here. Other platforms have no native
MIDI backend, and SDL_mixer falls back to Timidity or FluidSynth, which need a
patch set or an `.sf2` and will not sound the same. That is an open decision
recorded in NOTICE.md, not something this directory settles.

Only Windows binaries are vendored. On Linux and macOS SDL2 and SDL2_mixer come
from the system package manager, which is how those platforms expect to get
them.
