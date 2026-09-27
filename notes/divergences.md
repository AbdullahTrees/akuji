# Where this deliberately differs from the original

The reconstruction reproduces the original binary, including its defects, so
that what it does can be checked against what the original did. Every place it
knowingly does something else is written down here, with what was changed and
why - otherwise the difference between a decision and a mistake is lost.

A change belongs here when it alters what the player sees or the game does.
Rewriting the renderer underneath without changing the output does not; it is
not a divergence if the pixels are the same.

Numbers are shared with `akuji-re`'s ledger so that a marker means the same
thing in both. See the section at the end for the ones that came from there.

---

## DIV-016 - three extra spaces in the save prompt

**What the original does.** `MB_PROMPT_TEXT` is `'Yes' + 7 spaces + 'No  '`,
drawn as ONE string at x=112, while the hand cursor is drawn separately at a
FIXED x=148 and is 16 pixels wide. For the word "No" to sit clear of the hand
it has to begin at 164, so everything before it must be at least 52 pixels
wide.

Seven spaces is 45 pixels in the font the game uses, so it is 7 short. The hand
is drawn over the N and the player reads "lo" where it should read "No".

**Why it is a defect rather than a style.** The same layout puts the hand
immediately before "Yes" when Yes is selected, with no overlap. The spacing was
plainly meant to do the same for "No" and does not. It is visible in the
original binary as well as here.

**What this does instead.** Nine spaces rather than seven, and one before "Yes".

The leading space is the same defect at the other end.
`MB_HAND_ICON_X + MB_ICON_SIZE` is exactly `MB_PROMPT_TEXT_X`, so the icon
cell's right edge finishes where the text starts, and the hand fills its cell:
the arrow points right and its widest rows reach column 15 of 16 on the first
animation frame and column 14 on the second. Keying the icon (DIV-017) buys
nothing here for that reason - with or without the black around it, the cursor
sits against the Y. One space, 3 pixels, separates them.

The cursor then sits three pixels from "Yes" and two from "No", which is as
even as it gets: a space is 3 pixels, so the choice before "No" is a gap of 2
or one of 5, and 2 is the nearer match.

**Why nine.** A space is 3 pixels at this strike. Counting the leading one,
eight gives 51 - one short of the 52 needed, leaving the N against the cursor.
Nine gives 54 and clears it.

**Why not move the cursor instead.** `MB_HAND_ICON_X` and
`MB_HAND_ICON_STEP` place the hand for BOTH choices. Moving it to suit "No"
would move it away from "Yes", trading one misalignment for another. The
spacing is the thing that is wrong, so the spacing is what changes.

**How it is held.** `--selftest-render` measures the rendered width of the text
before "No" and fails if it is under 52, and separately checks that something
precedes "Yes" whenever the cursor cell reaches the text origin. Both measure
through the renderer rather than counting characters, because what matters is
the advance and a space is not a fixed width - so a change of font, strike or
string is caught the same way.

**Sites.** `MB_PROMPT_TEXT` in `src/screens/Dialogue.pas`.

---

## DIV-017 - sprites are drawn with a colour key

**What the original does.** It keys them. `TDDDD_DrawSprite` forwards to
`BltFast` on a DirectDraw surface and passes the caller's flag word straight
through as `dwTrans`, and every call site in the binary picks one of four
values:

| flag | meaning | who passes it |
|---|---|---|
| `0x00` | neither | `Overlay_Update` |
| `0x01` | `DDBLTFAST_SRCCOLORKEY` | `SpritePool_DrawBucket`, `HUD_Draw`, `MessageBox_Update` |
| `0x10` | `DDBLTFAST_WAIT` | the dialogue frame, `GameOver_Update` |
| `0x11` | both | the bitmap font, the title and ending panels, `SpritePool_DrawBucket` |

Bit 0 is the colour key and bit 4 is the retry-on-`WASSTILLDRAWING` wait - the
tile loop calls twice, once without the wait and again with it if the first
attempt failed, which is what pairs `0x00` with `0x10` and `0x01` with `0x11`.

So entity sprites and HUD icons were keyed. The reconstruction drew them with
`TCanvas.CopyRect`, which copies the source rectangle whole, and every
character, item and effect arrived with the black of its sheet around it.

**Why it is a defect rather than a style.** The sheets are painted for a key:
their background is pure black and the artwork stays off it - the darkest
colour in the character sheets is (3,5,17). The game has looked right on the
systems it was written for; the black boxes are not in screenshots of the
original running on Windows XP.

**What this does instead.** `TSpriteSet.Draw` and the HUD call
`TRenderTarget.BlitRectKeyed`, which masks the sheet background out.

**Why this is a divergence at all.** Because the original binary on Windows
10 or 11 shows black boxes too. That is a driver-level regression in
DirectDraw colour keying and it is not what the reconstruction is doing
wrong - the reconstruction never keyed anything in the first place, and it
does not use DirectDraw. Two defects that look alike. Fixing ours means the
port no longer matches the original binary as it behaves on a machine bought
today, and matches what the developers drew instead.

**What is deliberately NOT changed.**

* **The dialogue frame.** `0x10`, opaque, and it stays opaque.
* **The tile layer.** Every tile is defined transparent - `Load_Map` passes
  `1` for all of them - so the original keyed tiles as well. Only one layer
  is ever drawn and the buffer is cleared to black before it, so keying them
  would produce identical pixels for twice the blits. A note, not a
  divergence.
* **The full-screen panels.** The title, opening and ending pictures pass
  `0x11`, but they cover the screen over a cleared buffer, so the key has
  nothing to reveal.

**How it is held.** `--selftest-render` draws twelve frames from different
sheets at different sizes, overlapping and clipped against both screen edges,
and compares every pixel against a colour key applied in software by reading
the sheet directly. A previous attempt at this passed every check it had
while cutting pieces out of the character, so the check is the actual colours
and not a count of what changed. The three scene checksums that moved were
re-pinned with it.

**Sites.** `TSpriteSet.Draw` in `src/render/Sprites.pas`,
`TFrm_main.DrawHud` in `src/screens/GmMain.pas`, `BlitRectKeyed` and
`TRenderImage.KeyMask` in `src/render/RenderTarget.pas`.

---

## DIV-018 - WAIT and SOFTWARE VSYNC are gone; SCALING takes their place

**What the original does.** Two rows of the options screen control how a frame
is paced, and `TFrm_main_AppIdle` ends with both:

```c
if (*p_WaitOn == 1) func_0x0044c478(DDDD1);   /* WAIT */
TDDDD_Present(DDDD1);
if (*p_SoftwareVsync == 1) { spin on timeGetTime until 0x10 ms have passed; }
```

`0x0044c478` is seven instructions, and the last two say what WAIT is:

```
6a 00              push 0              ; hEvent = NULL
6a 01              push 1              ; DDWAITVB_BLOCKBEGIN
8b 80 c0 00 00 00  mov  eax,[eax+0C0h] ; the IDirectDraw the component holds
50                 push eax            ; this
8b 00              mov  eax,[eax]      ; vtable
ff 50 58           call [eax+58h]      ; IDirectDraw::WaitForVerticalBlank
c3                 ret
```

So WAIT is the hardware vsync - block until the display's next vertical blank,
then flip - and SOFTWARE VSYNC is not a vsync at all but a frame limiter: spin
until at least 16 ms have passed, which is 62.5 fps rather than 60. They were
alternatives: one paced you to the monitor, the other to a clock.

**Why they are defects here rather than settings.**

*WAIT* cannot do anything. This port has no DirectDraw and no vertical blank to
wait on: it presents through a window. The row set a byte that nothing read.

*SOFTWARE VSYNC* is worse than useless when off. The game has no fixed rate to
uncap - one idle callback is one whole frame, and the loop sets `Done := False`
unconditionally - so turning the limiter off does not let the game render
faster, it makes the game run faster. On a machine from 2001 that was already
true; on one from today it is unplayable.

**What this does instead.** Both rows are gone, pacing is unconditional at the
same 16 ms the original used, and one row that works stands where they were:

    SCALING     1X  2X  3X  4X

**Why scaling, and why whole numbers.** A 320x240 picture stretched to fill an
arbitrary window is scaled by a fraction, so some source pixels get two screen
pixels and some three - on art drawn at this size a one-pixel outline is one
pixel here and two there. The picture is now scaled by the largest whole
multiple that fits, centred, with the four bands around it painted rather than
stretched into. In a window the client area is set to an exact multiple, so
there is nothing left over; fullscreen is where the letterbox appears.

**What the player loses.** Nothing that worked. Anyone who had turned SOFTWARE
VSYNC off was playing a game running as fast as their machine allowed, which
was never the intent - the vblank path was, and it gave 60 fps on the monitors
of the day.

**Where it is stored.** `+0x1E` of system.dat, inside the six bytes the
original neither reads nor writes, as the scale MINUS ONE - so the 0 every
existing file carries reads as 1x, the size the window has always been, and a
load and save stays byte-exact. The two bytes the removed rows used, `+0x18`
and `+0x19`, are left exactly as they are found.

**The frame rate is deliberately still 16 ms**, not 16.667. That is what the
original's limiter did, and matching it keeps every frame-counted timer in the
game running at the speed it was tuned for. It is 62.5 fps, and that is a
separate decision from this one.

**How it is held.** `--selftest-render` checks the scaling as geometry, which
is the part that can be checked without a window: six client areas, including
a 16:9 desktop where the height decides the multiple and one too small to hold
the picture at 1:1, each required to come back a whole multiple and centred.
`--selftest-settings` holds the byte-exact round trip.

**Sites.** `OPT_LABELS` and `AdjustValue` in `src/screens/Title.pas`,
`AppIdle` and `ApplyWindowScale` in `src/screens/GmMain.pas`,
`TDDDD.PresentRect` in `src/components/DDDDComponent.pas`.

---

## DIV-019 - FULL SCREEN switches on the spot, not at the next launch

**What the original does.** `Display_SetFullScreen` is called exactly once, at
`0x00466C78`, from `DDDD1Init` at startup, with `Settings.FullScreenFlag`. The
options row does nothing but flip the byte:

```c
case 1:
  if (p_InputState->AxisX != 0) {
    TDDSD_PlaySound(...);
    *p_FullScreenOn = *p_FullScreenOn ^ 1;
  }
```

So the player toggles FULL SCREEN, sees the word change, and nothing happens
until the game is next started.

**What this does instead.** The row calls back into the form and the switch
happens immediately, which is also what the SCALING row beside it does. A
setting that takes effect next launch is indistinguishable, at the moment it
is used, from one that does nothing - and this screen already had two of
those (DIV-018).

**What it exposed.** The original's windowed branch restores the window border
only when the game is NOT reading from bmp.qda:

```c
if (*p_UseArchive == 0) {
  FUN_0043d62c(DAT_00484fec, 2);    /* BorderStyle := bsSingle */
}
```

That cost it nothing, because coming BACK from fullscreen is a path it never
takes: the one call is at startup, where the border is already what the form
was built with. Taking the path for the first time returned the shipped game -
which does read from bmp.qda - to a window with no title bar and no close
button. The border is now restored unconditionally, and before the client size
is set, because changing it recreates the window.

**Also different.** The original's fullscreen is a display MODE CHANGE, to
320x240 at 16 bits. This one leaves the desktop alone and scales the picture
into it by a whole number, centred, with the rest painted black - on a 2560x1440
desktop that is 6x, measured. Changing the display mode of a modern machine to
320x240 is not something to inflict on anyone, and monitors that accept it are
gone.

**How it is held.** Not by a self-test: a test has no window. It was checked by
running the game, switching both ways at 1x and at 3x, and reading the window
style back from the OS - caption and system menu present, client area exactly
320x240 and 960x720 again afterwards.

**Sites.** `AdjustValue` in `src/screens/Title.pas`, `ApplyFullScreen` and
`SetFullScreen` in `src/screens/GmMain.pas`.

---

## DIV-020 - input is bound by SDL keycode, and the key rows work

**What the original does.** Input comes through DirectInput. The device owns
sixteen buttons, each carrying a primary and an alternate key written by
`Input_SetKeyBinding`, and `AppIdle` polls four of them:

    physical key -> device button 0..15 -> KeyMap -> logical button 0..3

So `KeyMap` does not name a key. It says which DEVICE BUTTON each action
watches, which is what let the same four actions be driven by a keyboard or by
either of two joysticks - `Settings.InputDevice` picks between them. The
options screen polls twelve of those buttons, and when one is hit it gives the
selected row that button and hands the row's old button back to whoever had
it: a swap, so that no two of the three rows end up on one key.

**What this does instead.** The same two stages, named in SDL's terms. An
action carries a primary key, an alternate, and a gamepad button; the keys are
SDL keycodes, which are the same numbers on every platform, and that is the
whole point of moving off `dinput.dll`. The enum says what the buttons do -
JUMP, FIRE, PAUSE, AUX, and the four directions - rather than numbering them.

The four directions are bindings too, though no row shows them. A binding that
is a special case is a binding that gets forgotten.

**The swap is kept and widened.** No key may drive two actions. Binding one
that another action holds trades: the two exchange keys, so neither is left
without one. The original did this across the three rows it could edit;
doing it across all eight is the same rule carried to its conclusion.

**What the player gains.** Any key the game can see, instead of twelve. The
rows are also no longer display-only - see DIV-009, which this retires.

**What the player cannot bind.** A key that currently drives a DIRECTION.
Binding one would trade the arrow away and leave the player on a row they
could no longer move off. The original had the same restriction by
construction: the arrows were not among the twelve buttons it polled.

**What the game can still only see.** The keyboard arrives from the LCL as
Windows virtual keys, so the bindable set is whatever `VKToKeycode` names -
letters, digits, the arrows, the numpad, space, enter, escape, tab, backspace,
shift and control. That function is the only platform-shaped thing left in the
input component, and it goes when the window becomes SDL's.

**The menus are not bound.** They are still driven by the hard-wired virtual
keys of DIV-002, so the arrows move the cursor and Z, space or enter confirm
whatever JUMP is bound to. Retiring DIV-002 is what makes the bindings
authoritative everywhere; until then, rebinding JUMP does not change what
confirms a menu.

**The gamepad.** The original's joystick support was a second DirectInput
device chosen by `Settings.InputDevice`. Here a controller is read IN ADDITION
to the keyboard, always, and `InputDevice` is ignored - the reason the original
made you choose was that it polled one device, and SDL costs nothing to poll
both. Its subsystem starts with no video subsystem and no window at all, which
was measured before it was written, so this works while the window is still
the LCL's.

**Where it is stored.** The same four ints at `+0x08`, holding a tagged SDL
keycode rather than a device button index. The two are told apart by the tag
and NOT by range, because three keycodes - backspace, tab and return - land
inside the original's 0..15. An untagged value in 0..11 is read through the
twelve keys the original's screen could name, so the shipped `0,1,2,3`
migrates to exactly the four defaults and anyone with an existing system.dat
sees nothing change. A file this cannot read leaves the defaults alone.

**How it is held.** `--selftest-input`, headless. Its core check drives all 256
virtual keys through the default bindings and requires the result to equal the
pre-binding table exactly, key for key - the defaults are the old behaviour or
they are a regression. Around it: the twelve legacy indices, the round trip
through the stored form, a corrupt file, the trade rule, the no-duplicate
invariant after every bind, the options screen driven row by row against a
stand-in host, and what the gamepad path can assert with no device attached.
The rest was verified through the real window, by injected key presses held
long enough to span a frame: JUMP bound to V, then X pressed on the same row,
and the saved file came back JUMP=X, FIRE=V. That was done against the LCL
window; injected presses do not reach the SDL one that replaced it (DIV-021),
so re-checking this by hand means pressing the keys.

**Sites.** `src/components/DDIDComponent.pas` entire, `TitleKeyName` and
`TitleBindKey` in `src/screens/GmMain.pas`, the key rows in
`src/screens/Title.pas`, `TGameSettings.KeyMap` in `src/gameplay/GameState.pas`.

---

## DIV-021 - the window is SDL's, and there is no widget set

**What the original does.** It is a Delphi 5 application. `TFrm_main` is a
form, its components are streamed from a form resource, the picture reaches
the screen through DirectDraw, and input arrives through DirectInput and the
window's message loop. Everything about it is Windows.

**What this does instead.** The renderer, the audio, the MIDI and the clock
had already moved to SDL one at a time, each while the LCL window stayed put.
This is the last of it: the window is an `SDL_Window`, the loop is
`SDL_PollEvent` plus the same 16 ms pacing, keys arrive as SDL keycodes, and
presentation is one scaled blit into the window's own surface - so the picture
never leaves SDL. The project does not require the LCL package at all, and the
code section of the binary went from 2023024 bytes to 607936.

**TFrm_main is still called TFrm_main.** So are `FormDestroy`, `FormKeyDown`
and `FormKeyUp`. It is not a form any more and they are not event handlers,
but the original is a form of that name with handlers of those names, and a
reader holding the binary next to this should not have to translate. What
changed is underneath them.

**What the form resource held is now a const block.** `GmMain.lfm` carried the
window caption, the back buffer's size, the 57 sound channels and the fifteen
MIDI names. Those are in `TFrm_main.Create`, named and together, rather than
in a file the game parses at startup. `AkujiReg` and `akuji_components.lpk`
went with it: they existed so the Lazarus designer could resolve the component
classes, and there is no form to design.

**What the player may notice.**

*Nothing about the picture.* The five scene checksums and the scaling checksum
are unchanged - this was held to drawing the same pixels, not similar ones.

*The title bar is the same and fullscreen behaves better.* An SDL window that
was never created borderless still has its border when fullscreen is turned
off, so DIV-019's missing title bar cannot recur: there is nothing to restore
and no archive flag to get wrong.

*Alt-F4 and the close button now quit through the game's own shutdown*, which
is how the settings get written.

**What it exposed.** A double free on every quit, in `TGameSession`: it builds
its own event host, and assigning one leaked that host and left the destructor
freeing the CALLER's, which the caller also freed - on the word of a comment
saying the session did not own it. It never showed, because nothing genuinely
tore a session down; the form's OnDestroy ran at process exit and the result
was discarded. A shell that frees what it builds made it an access violation
on the way out. Both slots now own what they hold.

**What is still shaped by the original.** The menus are still driven by the
hard-wired keys of DIV-002 rather than by the bound buttons - the same keys,
said in SDL's terms - so Z, space and enter still confirm a menu whatever JUMP
is bound to. That is the last Windows-shaped input path and retiring it is a
separate decision, because it changes how the menus feel.

**How it is held.** `--selftest-render` keeps the five scene checksums, and
its present check is now the real present path:
`TDDDD.PresentTo` is the whole of presentation except asking the window for a
surface, so a test can drive it into an offscreen one. 8x4 scaled into 34x18
is 4x at (1,1), and all 612 pixels of the result are required to be either the
right source pixel or black surround - geometry and colour at once.

The second BMP decoder that test compares SDL against used to be the LCL's,
for free. It reads the format itself now, from the specification rather than
from another decoder's behaviour, which makes it stronger evidence than what
it replaces - it shares no code with the thing it checks. It also corrected a
standing misdescription: every one of the 44 entries in bmp.qda is an
uncompressed 24-bit bottom-up BMP, not 8-bit paletted.

`--selftest-session` counts destructors for the ownership rule, which is exact
where looking for a crash is not: a double free does not reliably crash.

What no self-test reaches is the window itself - whether keys arrive, whether
fullscreen switches, whether the picture is where it should be. That was
checked by running the game.

**Sites.** `akuji.lpr`, `TFrm_main` in `src/screens/GmMain.pas`, `Present` and
`PresentTo` in `src/components/DDDDComponent.pas`, `KeyDown`/`KeyUp` in
`src/components/DDIDComponent.pas`, `SDLTarget.pas`, `GameColors.pas`.

---

## DIV-022 - the stray menu panel is painted out of the options background

**This one diverges from the DATA, not from the game.** Every other entry here
changes what the code does; this changes a picture, and it moves the port
closer to the original rather than away from it.

**What the artwork holds.** `title.BMP` has a bordered, slightly darkened
panel around the four menu items. That is original artwork - both Japanese
releases have it - and the main menu is drawn inside it.

`Option.bmp` must not have one: the options screen puts its value column
there, and neither Japanese release's copy carries it. The copy in the English
1.1 translation does. Re-exported with that layer still visible, it put a
rectangle across the values on the options screen - the main menu's panel,
showing on a screen that has no menu.

**How that was established.** Three archives, read directly:

    Option.bmp, column x=302      y=129            y=140
    akuji_ver101_ja (Japanese)    (98, 65, 58)     (98, 65, 58)   flat
    akuji_ver101                  (98, 65, 58)     (98, 65, 58)   flat
    English 1.1 (what we ship)    (137, 94, 90)    (82, 56, 54)   border, then
                                                                  a darker fill

A screenshot of the original reads a flat (98,65,58) down that whole column -
the Japanese pixels exactly, not a tone-shifted version of ours. The
translation touched three of the archive's 44 entries: `title.bmp`,
`option.bmp` and `ed005.bmp`. The other 41 are byte-identical to the Japanese
original.

**That our renderer was faithful was checked first**, because a rectangle on
screen looks like a drawing fault. The running game's client area was captured
and compared against the back buffer it drew: a pixel-exact 3x copy, 36
differing pixels out of 691200 and all of them in the bottom rows the capture
clipped. Rendering the options screen headlessly and diffing against
`Option.bmp` shows nothing drawn but text.

**What was done.** The panel's rectangle - x 229..312, y 128..200 - is
repainted from the Japanese art, pushed through a tone curve fitted to the
surrounding English pixels. Not copied straight in: the English export is
toned differently throughout, about nine levels, so raw Japanese pixels would
leave a lighter rectangle where a darker one used to be. The curve reproduces
untouched art with a median error of 0, so the patch is seamless - the largest
vertical step across the old border drops from 111 to 61, against a natural
99th percentile of 79 in the same columns.

**What was NOT done.** The translated wordmark is the other thing the
translation changed in this image, and it is nowhere near the panel. It stays.
Using the Japanese `Option.bmp` wholesale would have been simpler and would
have taken the wordmark with it, and taking it from `akuji_ver101` would have
swapped in that release's different English wordmark - which would then also
have to be swapped on the title screen, or the logo would change between the
two screens.

**How it is held.** `--selftest-render` counts edges rather than trusting a
checksum, so that a repacked archive or a re-extracted asset is caught as well
as an edit: down each of the 84 columns the border crossed, how many step hard
from one row to the next. With the panel, 84 of 84 at its border row; without
it, the busiest row in the whole band is 15, and those are the character's own
outlines. The threshold is 32. Verified both ways - the old archive fails the
run, the patched one passes.

**Sites.** `Option.bmp` in `assets/bmp.qda`, and the panel check in
`tests/RenderTests.pas`.

---

## DIV-023 - SE VOLUME 0% is silent

**What the original does.** Each effect buffer's volume is set once from the
0..10 setting:

    DirectSoundBuffer.SetVolume((10 - v) * -0x1C2)

DirectSound measures volume in hundredths of a decibel with zero at full, so
each step is 4.5 dB and the bottom step, 0%, is -45 dB. Not silence: every
effect still plays, faintly, and with headphones clearly.

**What this does instead.** 0 is silent. The other ten steps are the
original's exactly. A setting that reads 0% and can still be heard is a
defect, not a property of the curve, and nothing about the curve above it
needed to change to fix it.

**How it is held.** `--selftest-audio` asserts the whole table rather than
logging it: gain 0 at 0, and at every other step the original's attenuation
to the unit. Putting the -45 dB floor back fails the run.

**Sites.** `VolumeToGain` in `src/media/AudioMixer.pas`.

---

## DIV-024 - the music is synthesised here, not by the operating system

**What the original does.** It hands each MIDI track to `kbgm32.dll`, which
passes it to the Windows MIDI synthesiser. That synthesiser plays the notes on
the instruments in `C:\Windows\System32\drivers\gm.dls`, Roland's GS set.

**What this did until now.** The same thing through SDL_mixer's native MIDI:
right on Windows, and nowhere else. It had a worse problem: the only volume
control SDL_mixer has for the Windows synthesiser is `midiOutSetVolume`, which
did nothing audible to the music. Measured from outside the process, it drove
the whole program's Windows volume slider instead, and left it at zero - so
turning the music down could silence the sound effects too.

**What this does instead.** FluidSynth renders the music in software, from
`assets/soundfonts/gm.dls` - the same instrument set the Windows synthesiser
plays - and the result goes out through an SDL audio device of its own at
44100 Hz, the slot SDL_mixer's device used to occupy. The effects mixer is
untouched. Nothing calls into the operating system's MIDI any more, so the
volume is a plain gain, and the music is the same on every platform.

**What might sound different, and what does not.** The instruments are the
same file. What can differ is the synthesiser around them - envelopes, and
effects. FluidSynth adds reverb and chorus by default and the game never had
them: renders with them on were judged by ear to sound noticeably wetter than
the game. They are off unless `system.ini` says `[music] effects=on`.

**When a jingle is over.** FluidSynth's player keeps reporting a track as
playing for about three and a half seconds after its last event - 6.99 s for
the power-up jingle, whose last note ends at 3.45 s - and the power-up panel
waits for the jingle, so it sat through all of that silence, more than twice as
long as the original. A once-through track now counts as finished at its last
event that is not End-of-Track, which is where the Windows synthesiser was done
with it. Looping is unaffected; FluidSynth's loop is seamless. Found in play;
held by `--selftest-music`, which fails if FluidSynth's own end is put back.

**The level.** FluidSynth's default gain is far quieter than the Windows
synthesiser. Matching the Windows synthesiser's measured average would have
needed about 1.1, and at 1.0 eleven of the fourteen tracks clip. 0.5 is the
loudest setting at which none does - end01 is the loudest track - so the music
sits somewhat below the original's level rather than distorting on its peaks.
MUSIC VOLUME takes it down from there.

**The fallback.** `soundfont=gs` selects GeneralUser GS, a free GS-style bank
shipped beside it, and the player falls back to it if `gm.dls` will not load.
Where each bank comes from, and the licence question `gm.dls` raises, is in
NOTICE.md.

**How it is held.** `--selftest-music` renders with no audio device and
measures the output: both banks load, a track makes sound without clipping,
the same input from a fresh synthesiser renders the same output, a
once-through track ends and a looping one does not, a fade out ends in silence
and stops, a fade in is a straight ramp - measured half-way through a 2 s fade
at 0.489 of the unfaded level - effects change the sound, and all 15 tracks
play. What it cannot hold is whether it sounds like the Windows synthesiser;
that was compared by ear.

**Sites.** `src/media/FluidSynth.pas`, `src/media/MusicSynth.pas`,
`src/components/KbgmPlayer.pas`, `[music]` in `assets/system.ini`.

---

## DIV-025 - MUSIC VOLUME

**What the original does.** It has no music volume. The options screen had two
rows for frame pacing, WAIT and SOFTWARE VSYNC, which DIV-018 found could do
nothing here and replaced with one row, SCALING.

**What this does instead.** MUSIC VOLUME takes the other row, below SE VOLUME,
so the screen has the original's ten rows again and GALLERY and EXIT are back
where the original drew them. Same range, same 4.5 dB steps and same
silent-at-zero as SE VOLUME, applied on the spot.

It only became possible with DIV-024. Before it, the music was the Windows
synthesiser's, and the one volume call that reached it did nothing audible.

**Where it is stored.** `+0x1F` of system.dat, the next of the six bytes the
original never touches, as 10 MINUS the volume - so the 0 every existing file
carries means full, the level the music has always played at.

**How it is held.** `--selftest-music` requires volume 5 to scale the music by
exactly SE VOLUME's gain at 5 (0.0750, -22.5 dB) and volume 0 to be silent;
making the volume do nothing fails both. `--selftest-layouts` pins the byte's
offset and `--selftest-settings` the byte-exact round trip.

**Sites.** `OPT_LABELS` and `AdjustValue` in `src/screens/Title.pas`,
`MusicVolume` in `src/gameplay/GameState.pas`, `TitleMusicVolume` in
`src/screens/GmMain.pas`.

## DIV-026 - one game, any language: UTF-8 text and PO translations

**What the original does.** There were two games. The Japanese release
(`akuji ver1.01`) and the English one are separate folders with separate
executables: the English patch retyped the 65 `data/tk*.dat` dialogue files,
replaced the strings compiled into the exe, and swapped the form's font from
MS P Gothic with `SHIFTJIS_CHARSET` to MS Sans Serif - and changed no code;
every coordinate and timing is identical. Text is Shift-JIS bytes, drawn by
GDI in whatever font the form names. Run the Japanese data through the English
build and every byte is read as a Western character, which is the garbage in
the box.

**What this does instead.** One binary, one data folder, a language setting.

* Text is UTF-8 throughout.
* All of it lives in gettext PO files, `assets/lang/<code>.po`; none is
  compiled in, and the English release's `data/tk*.dat` are gone - their
  text is in `en.po`. Each entry is keyed by where the game uses it
  (`tk006:1` is dialogue line 1 of stage 6, the number stage 6's event script
  names) and carries the English beside it.
* `en.po` is the English and the base, always loaded; the language chosen
  with `lang=<code>` under `[language]` in system.ini is laid over it, so an
  entry a translation lacks shows in English, and one neither has shows
  nothing and is logged. With neither file the game shows a message and does
  not start - the one sentence it has that is not in a language file.
  `assets/lang/akuji.pot`, the template, is written by the game from `en.po`
  (`akuji --write-pot`).
* `ja.po` is the Japanese release's own text, converted from Shift-JIS: all 65
  dialogue files and every visible string in its exe (narration, power-up names,
  the Yes/No prompt, the power-up line, the title).
* A language may name its own font in its PO header. Japanese uses
  PixelMplus12 (M+ licence, JIS level 1 and 2 kanji) at 12 pixels: a 13-pixel
  line, the height of the original's MS Gothic at 10 points, and on whole
  pixels at 320x240.

**The reveal rule, restated.** The box uncovered two BYTES per tick - one
full-width Shift-JIS character or two half-width ones - and saw "\n" only as an
aligned pair; the English data was padded so its escapes stay aligned. In
UTF-8 bytes say nothing about width, so the rule is now stated in characters:
a wide character is one unit, narrow characters pair up, "\n" is a unit
wherever it falls. Over every page of the English release's data/tk*.dat
this gave exactly the old units - checked by --selftest-lang against the
two-byte rule, 286 pages, before those files were retired - and the Japanese
data has no misaligned escape, so shipped text reveals as it did. What changes is only what a translator may write: no padding needed. The
panel line is centred by display columns, which is what the byte count
measured.

**Two details that differ.**

*The Japanese prompt gains a leading space.* The original's `はい　　いいえ` was
spaced for a 13-pixel font; at 12 the hand cursor touches both words. One
half-width space puts them 6 and 2 pixels clear - the same fix the English
prompt already carries.

*The menus and results stay English.* They are drawn from a bitmap font that
has only ASCII, and are not in the template yet.

**How it is held.** `--selftest-lang`: the unit rule by hand; the PO reader against a sample with
continuation lines, escapes and fuzzy entries; the template written, read back
and compared with what is committed; and for each language file - no context
`en.po` lacks, `en.po` carrying every non-dialogue entry the game draws, no
brace but a key placeholder (DIV-028), every dialogue code that steers the game kept (the
terminator, and `\w` present exactly when the English has it), every character
in its font, every page inside the box - three lines, two where the Yes/No
prompt takes the third, and a translation may add boxes with `\k` - and every
line within its width with the default keys named (Japanese's widest is 180
of 204 pixels), the Yes/No words clear of the hand. `--selftest-script`
requires text in `en.po` for every dialogue line an event script names.

**Choosing it in the game.** The options screen has a LANGUAGE row, between
MUSIC VOLUME and GALLERY. Left and right step through the files in `lang/`,
English first; the change applies at once and is written back to
`[language]` in system.ini. The row shows each file's `X-Akuji-Menu-Name` -
EN, JP - because the menu font has only capitals, digits and punctuation, and
the value has to fit inside the cursor's brackets. `--selftest-input` drives the row; `--selftest-lang` checks
every menu name is drawable. The row is also what first overflowed the
options screen - see DIV-027.

**Sites.** `src/TextUnits.pas`, `src/Translation.pas`,
`src/screens/LangTemplate.pas`, `tests/LangTests.pas`; the lookups in
`src/events/EventScripts.pas`, `src/screens/Opening.pas`,
`src/screens/Ending.pas`, `src/screens/Dialogue.pas`,
`src/gameplay/PlayerState.pas` and `DDDD1Init` in `src/screens/GmMain.pas`; the
font switch in `src/render/TextRender.pas`.

## DIV-027 - the options screen scrolls, and the key rows have their own page

**What the original does.** One options screen of ten rows at fixed places,
`(index*2 + 7) * 8`, EXIT last at y 200. Three of them - JUMP, FIRE and PAUSE
BUTTON ASSIGN - are the key bindings.

**What this does instead.**

*The list scrolls.* Nine rows fit between the heading and EXIT. When there
are more, the view follows the cursor, moving only when the cursor reaches
its edge; EXIT stays at y 200; a red ^ or V left of the labels marks rows
above or below (the menu font has a caret but no down arrow). With nine rows
or fewer every row is where the original's formula puts it.

*The three ASSIGN rows moved to a CONTROLS page.* The options screen has a
CONTROLS row in their place; confirming it opens a page titled
- CONTROLS - holding the three rows, with the original's labels and layout,
and an EXIT back to CONTROLS. The rows bind exactly as before (DIV-020), with
one guard the move made necessary: the page opens with the cursor on JUMP
while the key that confirmed CONTROLS - Return, Space or Z - is still down,
so no row binds until every key has been let go once. The pause button does
not open the pause menu on that page, for the same reason it does not on the
options screen: it is a key being bound.

The key names are SDL's, and many are longer than the seven glyphs between
the cursor's brackets. A one-letter key still reads as the original's
"Z KEY"; longer names drop KEY and are abbreviated - L and R for left and
right, KP for the keypad, BKSP, PGDN, ESC and the like - and cut at seven.

With LANGUAGE (DIV-026) and without the three rows, the options screen has
nine rows again, so today it does not scroll; GALLERY is one row higher than
the original drew it. The scrolling stays for whatever is added next.

**How it is held.** `--selftest-input`: the scroll rule as a pure function
for 1..24 rows - straight walks down and up, EXIT leaving the view alone, and
500-step random walks that keep the cursor on screen (breaking the upward
case fails 2730 checks); the screen's own Update walked down and back with
the cursor's row always drawn; unscrolled rows at the original's y. And the
CONTROLS page: no options row binds, CONTROLS opens the page on JUMP with
SND_OK, nothing binds while the confirming key is held or on the frame it is
released (opening the page armed fails both), then each key row binds as its
own number with SND_OK, EXIT binds nothing and returns to CONTROLS.

**Sites.** `OptionsScroll`, `OptionRowY`, `ControlRowY`, `ControlsConfirm`
and the TSM_CONTROLS branches in `src/screens/Title.pas`; `TitleKeyHeld` and
the pause check in `src/screens/GmMain.pas`.

## DIV-028 - the signs name the keys the player bound

**What the original does.** The signs' advice is fixed text: "repeatedly
press the jump button", "Hold down the fire button", ジャンプボタン連打,
ファイアボタンを押し続けて. The original could not rebind those keys, so the
text could not be wrong.

**What this does instead.** With the keys rebindable (DIV-020), a line may
carry `{JUMP}`, `{FIRE}`, `{PAUSE}`, `{UP}`, `{DOWN}`, `{LEFT}` or `{RIGHT}`,
replaced when the message opens by the key bound to that action. The key is
looked up as the message opens, so a key rebound a moment ago is the one
named.

It is drawn as a keycap: Kenney's "Input Prompts Pixel" (CC0), light keys,
13-14 pixels tall on the dialogue's 16-pixel line, inline with the text. 84
keys have one - letters, digits, F1-F12, the arrows, punctuation, and the
wide ESC, TAB, SHIFT, CTRL, ALT, HOME, PAGE and the like. A key without one
(the keypad, media keys) is written by the short name the CONTROLS page
shows, `R CTRL`. The keycap travels in the line as one private-use
character, so it reveals as one step and the box width counts its pixels;
a line with no keycap is drawn exactly as before. The same sheet holds the
Xbox, PlayStation, Switch and Steam Deck buttons for when a pad is named.

The signs that name a button now read "the {JUMP} key" and 「{JUMP}キー」, and
the ones that name a direction use the direction's placeholder: "the arrow
key", "the cursor key" and "a direction" (for the dash and the bounce, both
horizontal) became "{LEFT} or {RIGHT}", 【方向キー】 and 【左右キー】 became
【{LEFT}か{RIGHT}キー】, and UP, DOWN, 【上キー】 and 【下キー】 their own. The
directions cannot be rebound yet, so today these read as before in substance
(LEFT, RIGHT, UP, DOWN); they need nothing more when they can. "LOOK UP!" is
advice, not a key, and stays. Six Japanese lines were rewrapped so that even a
seven-letter key name fits. In all, 17 entries in `en.po` and 19 in `ja.po`
carry a placeholder.

**How it is held.** `--selftest-lang` rejects any brace in a translation that
is not one of the three, and measures every dialogue line with the default
keys drawn as keycaps, and names every line that would outgrow its box if
a key had no keycap and a seven-glyph name - none today (Japanese's widest is
192 of 204 pixels either way, English's 200).

**Sites.** `ExpandKeys` and `KEY_PLACEHOLDERS` in `src/Translation.pas`;
`src/render/KeyIcons.pas` and `ComposeWithIcons` in
`src/render/TextRender.pas`;
`TDialogueBox` opening a message in `src/screens/Dialogue.pas`;
`PlaceholderKeyName` in `src/screens/GmMain.pas`; `ShortKeyName` in
`src/screens/Title.pas`.

---

## Numbers 001 to 015

Those belong to the reconstruction and are recorded in `akuji-re`'s own ledger,
which is where each one's evidence lives. Six of them are marked in this
repository's source, so they are summarised here rather than leaving a marker
that resolves to nothing. The numbers are deliberately the same in both
repositories; new entries here start after the highest one there.

**DIV-001 - frame pacing sleeps instead of spinning.** `src/screens/GmMain.pas`.
The original sets `Done := False` unconditionally and spins on `timeGetTime`
until more than 15 ms has passed, pegging a core. This sleeps 1 ms instead.
Neutral for game logic: both run exactly one update per elapsed-time gate and
neither frame-skips, so the sequence of updates is identical.

**DIV-002 - menus are driven from the keyboard in FormKeyDown.**
`src/screens/GmMain.pas`. The original reads movement and buttons from the Joy
component inside the frame loop. This sets the move and confirm flags straight
from raw key codes so the menus can be operated at all. Affecting: input
arrives by a path the original does not have - and since DIV-020 made the
buttons rebindable, it is also why rebinding JUMP does not change what
confirms a menu. Still open. The keys are now SDL keycodes rather than Windows
virtual keys (DIV-021), which changes nothing about what it does.

**DIV-003 - Entity spawn refuses an unknown Kind.** `src/gameplay/Entities.pas`.
For a Kind outside 0..2 the original scans the slot array from uninitialised
registers. Reproducing that is not possible - there is no single behaviour to
copy - so this returns SLOT_NONE. Every call site in the binary passes a
literal 0, 1 or 2.

**DIV-004 - OpeningPictureFor bounds-checks the slide.**
`src/screens/Opening.pas`. The original indexes its picture table unchecked;
this returns -1 outside 1..10. Neutral in practice - the caller clamps first,
so the guard never fires.

**DIV-006 - the entity dispatcher has an else arm.**
`src/gameplay/EntityHandlers.pas`. The original is a jump table, which by
construction has no default. The added arm counts unhandled types so the
self-test can assert that every id the table claims reaches an arm. The
counter is write-only outside the test.

**DIV-009 - the options screen cannot rebind keys. RETIRED.** The three rows
bind, and the swap is kept and widened - see DIV-020. The marker is gone from
`src/screens/Title.pas`; the number stays listed so it does not read as a gap.

**DIV-010 - type 25 clamps EF_VARIANT instead of running off its table.**
`src/gameplay/EntityHandlers.pas`. The original indexes a three-entry sprite
table unchecked and out of range reads the next type's table. This clamps to
0..2. Affecting outside that range and identical inside it; all 160 type-25
records in the 65 shipped stages carry 0, 1 or 2.

**DIV-011 - an index that leaves the sprite data region is clamped.**
`src/gameplay/EntityHandlers.pas`. The sprite tables are laid end to end and
read verbatim from the image, so an overrun inside the region lands on the same
bytes the original's does. Past the end of the region there is no defined
answer to copy, so `SpriteDatum` clamps there and only there.

**DIV-012 - the spawn window reads the layer origin, not the tile component's
scroll.** `src/gameplay/GameSession.pas`. The original mixes two objects and
so spawns against the value the PREVIOUS frame's draw left behind; on the first
frame in a new room that is the last room's. This uses the current frame's
camera.
