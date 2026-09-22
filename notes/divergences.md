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
from virtual-key codes so the menus can be operated at all. Affecting: input
arrives by a path the original does not have.

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

**DIV-009 - the options screen cannot rebind keys.** `src/screens/Title.pas`.
The original polls 16 raw buttons and swaps the hit one with the selected row.
This displays the three bindings and cannot change them. Affecting. The way
out is raw button polling in the input layer, which the swap needs.

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
