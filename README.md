# Akuji the Demon

A source port of *Akuji the Demon*, a Japanese doujin action-platformer from
around 2001. The game was written in Borland Delphi and shipped as a Windows
binary; its source was never released. This is that source, rebuilt in Object
Pascal, together with the data the game loads.

It builds with [Lazarus](https://www.lazarus-ide.org/) and Free Pascal and
plays the real game — the same stages, entities, scripts, music and endings.

## Build and run

You need Lazarus with Free Pascal. Then:

```sh
tools/build.sh          # builds bin/akuji.exe
bin/akuji.exe           # plays
```

Or open `akuji.lpi` in the Lazarus IDE and build from there.

The binary looks for its data by walking up from its own directory, so it finds
`assets/` with no configuration and no install step. A packaged build works too:
put the contents of `assets/` beside the executable.

To open `src/screens/GmMain.lfm` in the form designer you must first install
`akuji_components.lpk`, which registers the four component classes the form
uses. Building from the command line does not need it.

## Tests

```sh
tools/test.sh
```

Fifteen self-test modes, linked into the game binary itself rather than into a
separate harness, so they exercise the code the game actually runs. They cover
the archive and audio decoders, the MIDI player, the event-script grammar and
interpreter, stage loading, the camera, the player controller, the entity
dispatcher and every record layout the save format depends on.

Some checks compare against the original 2001 executable. It is not distributed
here and is not needed to build or play; those checks report `SKIP` when it is
absent. Put a copy beside the game data to enable them.

## Layout

```
akuji.lpi / akuji.lpr     the project and its program block
akuji_components.lpk      design-time package, for the form designer only
src/
  components/             the display, input, sound and music components
  media/                  archive, WAV, MIDI and mixer decoding
  render/                 surfaces, sprites, tilemaps, fonts, backgrounds
  gameplay/               entities, player, camera, stages, session state
  events/                 the event-script language and its interpreter
  screens/                title, opening, dialogue, ending, and the main form
tests/                    the self-test modes, plus a pinned save fixture
assets/                   the game's data - see NOTICE.md
tools/                    build and test scripts
```

## Portability

The goal is the same outward behaviour on every target Free Pascal supports.
The game logic, the decoders and the renderer are already portable: they are
plain Object Pascal over the LCL.

Three units are not, and they are the whole of the remaining work:

| unit | why |
|---|---|
| `src/media/AudioOut.pas` | `waveOut*` via `MMSystem` |
| `src/media/MidiOut.pas` | `midiOut*` via `MMSystem` |
| `src/MsClock.pas` | `timeGetTime` via `MMSystem` |

Each is a small surface behind an interface the rest of the code already uses,
so a backend per platform is the shape of the fix rather than a rewrite.

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
