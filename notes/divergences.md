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

**How it is held.** `--selftest-render` keeps the five scene checksums and the
scaling checksum, and its present check is now the real present path:
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
