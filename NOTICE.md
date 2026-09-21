# Notice on origin and redistribution

Two different things live in this repository and they do not have the same
status. Read this before making the repository public.

## The code

`src/`, `tests/`, `tools/` and the project files are a reconstruction. They were
written by reading the original binary's behaviour and reimplementing it in
Object Pascal; no original source was available, because it was never released.

**No licence has been chosen yet.** Until one is, the usual default applies and
nobody has been granted permission to copy or modify this. Picking a licence is
an open decision, and it interacts with the next section.

## The data

`assets/` is the original author's work, unmodified:

| | |
|---|---|
| `bmp.qda` | the sprite and picture archive |
| `map/` | 65 stage tilemaps |
| `data/` | entity placements, event scripts and message text |
| `midi/` | the music |
| `wav/` | the sound effects |
| `system.ini` | display and input settings |

These came from the English-translated release of the game. They are
redistributed here so that a clone is playable without hunting for a copy of a
25-year-old doujin release, which is a real preservation concern — but
redistributing them is not something the reconstruction's authors can license,
because the copyright is not theirs.

**This is the open question to settle before publishing.** The options, roughly:

- **Ship the data, as now.** A clone just works. It redistributes someone
  else's copyrighted work, which they have not agreed to.
- **Ship no data.** The repository holds only the reconstruction, and the
  player supplies their own copy of the game. Legally clean; a worse experience,
  and it makes the build untestable for anyone without the release.
- **Ship the data and seek permission.** The best outcome if the author or the
  translation's publisher can be reached and agrees.

Nothing here decides that. It is recorded so the decision is made deliberately
rather than by default when the repository is pushed.

## The font

`assets/fonts/micross.ttf` is Microsoft Sans Serif, copied from a Windows
installation.

It is here because the game asks for "MS Sans Serif" and Windows substitutes
this file for it, so it is the font the opening narration, the ending lines and
the dialogue box have always actually been drawn in. A port to Linux or macOS
has no such font and would silently render something else, which is why a local
copy travels with the game rather than being looked up by name.

**Its licence does not permit redistribution.** Microsoft's font EULA allows
use on a licensed Windows machine, not shipping the file inside someone else's
project. This is the same open question as the game data above and it is
recorded for the same reason - so it is settled deliberately rather than by
default when the repository is pushed. The options are much the same:

- **Ship it, as now.** Every platform renders identically to Windows.
- **Ship nothing and look the font up by name.** Legally clean, and the text
  looks different on any machine without it, which is every machine that is not
  Windows.
- **Ship a metrically similar open font** such as Liberation Sans. Legally
  clean, redistributable, and visibly not the same glyphs.
- **Pre-render the glyphs into a sheet**, the way the game already stores its
  own bitmap font. Pixel-exact everywhere, no font file at run time, and it
  sidesteps redistributing a font program - though the glyph shapes are still
  Microsoft's design.

## What is deliberately absent

The original `akuji.exe` is **not** distributed here. It is not needed to build
or play, and the self-tests that read it skip cleanly without it. It belongs to
the reverse-engineering project, not to this one.

`d3drm.dll` and `kbgm32.dll` shipped with the original release and are **not**
needed either: this build reimplements the display and music components in
Pascal and loads no third-party DLL. Nothing from Microsoft is redistributed.

## The shipped save file

`assets/data/save.dat` is the save that came with the release, and **the game
overwrites it whenever you save at a statue.** That is not a bug; it is where
the game keeps its save. But it means a playtest quietly modifies a tracked
file, and one such overwrite has already destroyed a shipped copy once.

The tests do not use it. They use `tests/fixtures/save.dat`, which is a separate
pinned copy for exactly this reason — see `tests/fixtures/README.md`.
