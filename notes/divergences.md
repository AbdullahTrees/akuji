# Where this deliberately differs from the original

The reconstruction reproduces the original binary, including its defects, so
that what it does can be checked against what the original did. Every place it
knowingly does something else is written down here, with what was changed and
why - otherwise the difference between a decision and a mistake is lost.

A change belongs here when it alters what the player sees or the game does.
Rewriting the renderer underneath without changing the output does not; it is
not a divergence if the pixels are the same.

---

## DIV-001 - three extra spaces in the save prompt

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
animation frame and column 14 on the second. Keying the icon (DIV-002) buys
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

## DIV-002 - sprites are drawn with a colour key

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
