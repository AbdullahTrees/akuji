# Akuji the Demon

A source port of *Akuji the Demon*, a Japanese doujin action-platformer from
around 2001. The game was written in Borland Delphi and shipped as a Windows
binary; its source was never released. This is that source, rebuilt in Object
Pascal, together with the data the game loads.

It builds with Free Pascal, draws and plays sound through SDL2, and
plays the real game — the same stages, entities, scripts, music and endings.

## Build and run

```sh
make                    # builds bin/akuji (bin/akuji.exe on Windows)
bin/akuji               # plays
```

On Windows run `make` from Git Bash; `tools/build.sh` does the same without
make. Built and tested with Free Pascal 3.2.2 on 64-bit Windows and on
aarch64 Linux (the PortMaster build image, Ubuntu 20.04).

| target | what it does |
|---|---|
| `make` | check what the build needs, then build |
| `make release` | the same, optimised and stripped |
| `make test` | build, then run every self-test |
| `make configure` | only the checks |
| `make clean` | remove what the build produced |
| `make distclean` | also remove the fetched Free Pascal |

### What the build needs

**Free Pascal 3.2.** On Linux there is nothing to install: if no 3.2 compiler
is on PATH, the first `make` downloads the official 3.2.2 release for the
machine's architecture (about 100 MB, once), checks it against a pinned
SHA-256 and unpacks it into `.toolchain/` inside the checkout. Nothing goes
outside the checkout and nothing needs root; `make distclean` removes it.
Distribution packages are passed over on purpose - Ubuntu 20.04 ships 3.0.4.
On Windows, install [Lazarus](https://www.lazarus-ide.org/) (4.8 carries FPC
3.2.2); the build finds the compiler inside it. `FPC=/path/to/fpc make` names
one explicitly.

**SDL2 and SDL2_ttf.** On Windows they are vendored in `third_party/` and
copied beside the binary. On Linux they come from the package manager, which
needs root, so `make` checks for them and prints the line to run rather than
running it:

```sh
sudo apt-get install libsdl2-dev libsdl2-ttf-dev
```

**FluidSynth**, for music only. Loaded at run time (`libfluidsynth.so.3` or
`.so.2`); without it the game builds and runs, silently. On Windows it is
vendored too.

### Release build

```sh
make release
```

3 MB rather than 30 MB. Almost all of the difference is debug information, not
code: the default build keeps symbols because they are what makes a crash
report worth having. The release build passes the same tests.

### Building by hand

`tools/build.sh` is one Free Pascal command; its flags are the ones in
`akuji.lpi`, so opening that in the Lazarus IDE builds the same program.

SDL2_ttf is what draws the opening narration and the dialogue box, out of the
font in `assets/fonts/` rather than one the host happens to have installed.

### Where the data comes from

The binary looks for its data by walking up from its own directory, so it finds
`assets/` with no configuration and no install step. A packaged build works the
same way: put the contents of `assets/` beside the executable.

## Tests

```sh
make test               # or tools/test.sh
```

Twenty self-test modes, linked into the game binary itself rather than into a
separate harness, so they exercise the code the game actually runs. They cover
the archive and audio decoders, the MIDI player, the event-script grammar and
interpreter, stage loading, the camera, the player controller, the entity
dispatcher and every record layout the save format depends on.

Some checks compare against the original 2001 executable. It is not distributed
here and is not needed to build or play; those checks report `SKIP` when it is
absent. Put a copy beside the game data to enable them.

## Languages

English and Japanese ship with the game. Choose with LANGUAGE on the options
screen, or in `assets/system.ini`:

```ini
[language]
lang=ja
```

Japanese is the original Japanese release's own text, in a free pixel font
that keeps kanji legible at the game's 320x240. The menus and the results
screen are still English - they are drawn from an ASCII bitmap font.

Every word the game draws in its outlined font comes from these files and
nowhere else - no text is compiled in. `assets/lang/en.po` is the English and
the base: it is always loaded, and the chosen language is laid over it, so
anything a translation leaves out shows in English. With neither `en.po` nor
the chosen file the game says so and will not start.

### Translating

Translations are gettext PO files in `assets/lang/`, so any PO editor works -
[Poedit](https://poedit.net/), Weblate, Lokalize, or a text editor.

1. Copy `assets/lang/akuji.pot` to `assets/lang/<code>.po` (`fr.po`, `de.po`,
   ...) and set `"Language: <code>\n"` in its header.
2. Fill in the `msgstr` lines. Each entry shows the English, and a comment
   saying where it is used. Anything left empty shows `en.po`'s English, so
   a partial translation is playable.
3. Set `lang=<code>` and play. `make test` checks the file: every dialogue
   line inside its box, every character in the font, the page codes kept.

In the dialogue a line break is a line break, and a box holds three lines.
`\k` waits for a key and starts the next box, `\e` ends the message, `\w` ends
it with the Yes/No prompt. Keep `\e` and `\w` where the English has them, but
use as many boxes as the text needs: a question too long for one box becomes
`...\kWould you like to save? \w`. A box that ends in `\w` holds two lines,
because the prompt takes the third.

`{JUMP}`, `{FIRE}`, `{PAUSE}`, `{UP}`, `{DOWN}`, `{LEFT}` and `{RIGHT}` are
replaced, when the line is shown, by the key bound to that action - drawn
as a keycap icon, or as its name (`R CTRL`) for a key the keycap sheet has
none for - so a sign never names the wrong key:
`Hold down the {FIRE} key`, `{FIRE}キーを押し続けて`,
`Press {LEFT} or {RIGHT} twice`. The directions cannot be rebound yet; the
signs name them the same way so they need nothing when they can. Leave room:
`make test` reports any line that would outgrow its box with a seven-letter
key name.

The default font covers ASCII. A script it lacks needs a font: put a TTF in
`assets/fonts/` and name it in the header, as `ja.po` does -
`X-Akuji-Font: PixelMplus12-Regular.ttf` and `X-Akuji-Font-Size: 12`.
PixelMplus12 also covers Latin-1, so most European languages can simply use it.

When `en.po` changes, `bin/akuji --write-pot assets` rewrites the template
from it and `msgmerge -U <code>.po akuji.pot` brings a translation up to date,
marking changed entries fuzzy.

## Layout

```
akuji.lpi / akuji.lpr     the project and its program block
src/
  components/             the display, input, sound and music components
  media/                  archive, WAV, MIDI and mixer decoding
  render/                 surfaces, sprites, tilemaps, fonts, backgrounds
  gameplay/               entities, player, camera, stages, session state
  events/                 the event-script language and its interpreter
  screens/                title, opening, dialogue, ending, and the main form
tests/                    the self-test modes, plus a pinned save fixture
assets/                   the game's data - see NOTICE.md
tools/                    configure, build and test scripts
Makefile                  the entry point - see Build and run
```

## Portability

The goal is the same outward behaviour on every target Free Pascal supports.
Nothing in the game calls a Windows API any more:

| what | how |
|---|---|
| drawing | SDL surface blits, through one seam - `src/render/RenderTarget.pas` |
| pictures | decoded by SDL from `bmp.qda` |
| text | SDL_ttf, from a font carried in `assets/fonts/` |
| sound | SDL audio, mixed by the game (`src/media/AudioMixer.pas`) |
| music | FluidSynth, with the soundfont in `assets/soundfonts/` |
| the window, keyboard and gamepad | SDL |
| the frame clock | SDL's timer |

The render self-test pins every scene by checksum, and the same numbers hold
from SDL 2.0.10 (the PortMaster image) to 2.32 (vendored on Windows).

## Versioning

The port's version is `APP_VERSION` in `src/Version.pas`, and it is written at
the top of `akuji.log`. It started at **2.0.0** and moves by two rules:

- **patch, +0.0.1, with every commit.** The bump goes in the commit it numbers.
- **minor, +0.1.0, at a milestone**, which is the developer's call; patch goes
  back to 0.

Change it only with the script, which refuses anything but three plain numbers:

    tools/bump-version.sh patch
    tools/bump-version.sh minor
    tools/bump-version.sh           # prints the current version

## Relationship to the reverse-engineering project

This repository is the game. The work of recovering it — the disassembly notes,
the Ghidra database, the differential-testing tooling and the audit ledgers —
lives separately in `akuji-re` and is not needed to build, play or modify
anything here. A shallow clone of this repository is self-contained.

That separation is deliberate. The two have different goals: `akuji-re` answers
"what did the original binary do", and this one answers "does the game run
correctly here". Where those ever disagree, this repository follows the game.

## NOTICE

The code is a reconstruction. The contents of `assets/` are not — they are the
original author's work, redistributed here so the game can be played. See
[NOTICE.md](NOTICE.md) before publishing or redistributing this repository.
