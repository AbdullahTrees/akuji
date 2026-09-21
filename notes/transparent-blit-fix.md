# The transparent blit, and a failed attempt at fixing it

**Status: CLOSED on 2026-09-22. See DIV-002 in notes/divergences.md for what
the fix does; the last section here says how it differs from the attempt that
failed.** An earlier fix was reverted on 2026-09-21 because it made the
picture worse. This is the record of what was known at the time, what was
tried, why it failed, and which explanations had already been ruled out -
kept because the reasoning is what made the second attempt different.

## The symptom

Sprites are drawn with their sheet background: a black rectangle around every
character, item and effect. The rectangles are exactly the sprite's size and
are **not** aligned to the tile grid, which is how they were told apart from
holes in the tile layer - measured from a captured frame, three of them at
32x32 with `x mod 16` of 15, 1 and 1.

It affects entity sprites and the HUD icons alike. Text is unaffected.

The same symptom appears when the **original 2001 binary** runs on Windows 10
or 11, where it is understood to be a driver-level regression in DirectDraw
colour keying. It did not happen on the systems the game was written for
(ME, XP, Vista, 7). Whether the reconstruction's version has the same cause is
NOT established - see "What this is not" below.

## What the original binary did

Worth stating because it settles what the correct picture is, whatever the
cause of the glitch.

`TDDDD_DrawSprite` at `0x00448918` forwards to `FUN_0044880C`, which ends in a
virtual call at vtable offset `0x1C` on a DirectDraw surface:

    (**(code **)(**(int **)(param_1 + 4) + 0x1c))();

Offset `0x1C` in `IDirectDrawSurface` is **`BltFast`**, whose colour-keyed form
(`DDBLTFAST_SRCCOLORKEY`) is the standard transparent sprite blit. The
original's `TileMap_DefineTile` also takes a `Transparent` parameter, so
transparency was first-class in its API.

**The original keyed its sprites.** Transparent sprites are the correct
behaviour to aim at, not a departure from it.

## Where the reconstruction stands

`TSpriteSet.Draw` (`src/render/Sprites.pas`) blits with `TCanvas.CopyRect`,
which takes a source rectangle and **ignores `TBitmap.Transparent` entirely**.
`TDDDD.DrawSprite` looks like it keys and does not - it assigns
`Src.Transparent` and then calls `CopyRect`, which ignores it.

`GameFont` is the one path that works. It cuts each glyph into its **own**
`TBitmap` once, sets `TransparentColor`, and draws with `Canvas.Draw`, which
honours it. `GameFont.pas` carries the comment explaining the difference:

    Draw() honours TBitmap.Transparent, CopyRect does not.

So the knowledge was already in the codebase; it had simply never been applied
to sprites.

## The attempt that was reverted

Commits `9f9f6a3`, `8774812`, `600a888`, reverted back to `7306882`.

A shared helper `BlitKeyed(Dest, Src, SrcRect, X, Y)` in `Surfaces.pas` cut the
source rectangle into **one scratch `TBitmap` reused across all calls**, set
`TransparentColor := clBlack` and `Transparent := True` on it, and drew that
with `Canvas.Draw`. Both `TSpriteSet.Draw` and `TDDDD.DrawSprite` were pointed
at it.

### Why it was believed to work

* the render baseline measured the sprite scene changing 3072 of 3072 covered
  pixels before and 999 of 3072 after
* a rendered scene image showed three sprites over a tilemap with the tiles
  visible around them
* an instrumented run of the real game counted `BlitKeyed = 3599`, exactly
  `TSpriteSet.Draw = 1199` plus `DDDD.DrawSprite = 2400`, and the frame
  captured from that run had no black region of 200 pixels or more

### Why it was wrong

**In motion, parts of the sprite body are erased.** A player screenshot on
stage 1 shows Akuji with sections of the character cut away and replaced by
black, changing as the sprite moves. That is worse than the original defect: a
black box is cosmetic, a hole in the character is corruption.

The shape of it - correct when drawn once, wrong once many different sprites
are drawn in sequence - points hard at **the shared scratch bitmap's mask**.
The suspicion is that the LCL mask is not rebuilt for every blit, so a sprite
is drawn through a mask belonging to a previous one; where that earlier mask
was opaque the new sprite is unkeyed, and where it was transparent the new
sprite is erased.

**This was tested and the test passed, which is itself a finding.** The check
drew a sprite alone, then the same sprite after a different one, and compared
the pixels: 0 differed. So either the contamination needs more than two sprites
in flight, or it depends on size changes between blits, or the mask is rebuilt
and the cause is something else entirely. The order-dependence check as written
does not reproduce it.

## What has already been ruled out

Each of these was measured, not assumed. Re-testing them is wasted effort.

| hypothesis | result |
|---|---|
| the destination bitmap's format differs | drawing the same sprites into a bare `TBitmap` and into `TDDDD.Surface` gives identical results: 999 of 3072 both ways |
| some sheets have a non-black background | every surface slot used by stage 20 reports corner colour `000000` and the same pixel format |
| only stage 1 was ever tested | a probe over every stage found none where the blit was opaque |
| the mask is contaminated by the previous blit | a sprite drawn alone and drawn after a different sprite gave 0 differing pixels |
| entity sprites reach the screen some other way | `DrawAll` and `DrawTop` are the only draw paths in `TSpritePool`, both call `TSpriteSet.Draw`, and counters confirm 1199 calls in a stage |
| the running binary was stale | counters and a captured frame from the same instrumented run confirmed the fix was active |

## Traps hit while investigating, worth not repeating

* **The game sits on the title screen.** It draws through `Title.pas`, so tile
  and sprite counters stay at zero while a dumped frame still looks like a real
  scene - 96% non-black. Every early measurement was of the title screen.
  Getting into a stage needs input driven at the window.
* **A frame dump must run after drawing and must not `Halt`.** A first version
  dumped at the top of `DrawScene` and halted; it captured an empty buffer and
  took the game down with an access violation in a paint handler.
* **Three frames of one character cannot show a mask problem**, because their
  silhouettes are alike. Any future test needs sprites whose shapes differ
  sharply.

## What this is not

It has not been established that the reconstruction's black boxes and the
original binary's Windows 10/11 glitch have the same cause. The reconstruction
does not use DirectDraw at all - it draws through the LCL - so it cannot be
inheriting a DirectDraw driver bug. Our `CopyRect` never keyed anything, which
is sufficient on its own to explain a black box. They may simply be two defects
that look alike.

**Since settled: they are.** The player confirmed the original binary does NOT
show black boxes on Windows XP, so the original's glitch belongs to the modern
driver and ours belongs to `CopyRect`. Fixing ours therefore does not make the
port match the original binary as it behaves today - it makes it match what
the game looked like when it was written. That is why it is a divergence and
not a repair.

## How it was fixed

Commits `4e30a4c`, `9f5fb99`, `91eb183`, `56d6969`.

`TRenderTarget.BlitRectKeyed` does the blit with two raster operations rather
than one call: AND a black-and-white mask of the sheet into the destination to
punch the sprite's silhouette out of it, then OR the sheet in, where its black
background contributes nothing. Both take a source rectangle, which is the
property a colour-keyed `Draw()` does not have and the reason the font has to
cut its glyphs.

Three things were different from the attempt that failed.

**The mask belongs to the image.** `TRenderImage.KeyMask` is built once, the
first time that image is keyed, and lives as long as it does. The failed
attempt cut every blit into ONE scratch bitmap shared by all of them, which is
what let one sprite be drawn through another's mask. A mask that is never
reused for a second image cannot be contaminated by one.

**The test compares colours, not counts.** `--selftest-render` draws twelve
frames from different sheets at different sizes, overlapping each other and
clipped against both screen edges, and checks every pixel against a colour key
applied in software by reading the sheet directly. The failed attempt passed
an order-dependence check, a changed-pixel count and a visual inspection while
cutting pieces out of the character.

**The flag word said which blits to change.** `TDDDD_DrawSprite` passes its
fourth argument straight to `BltFast` as `dwTrans`, so every call site in the
binary states whether it wanted a key: `0x01`/`0x11` with
`DDBLTFAST_SRCCOLORKEY`, `0x00`/`0x10` without. Sprites, HUD icons, the
dialogue box's two icons and the bitmap font are keyed; the dialogue frame and
the game-over screen are not. Nothing had to be guessed at from how it looks.

Tiles are the one place the reading was not followed. `Load_Map` defines every
tile transparent, so the original keyed them - but only one layer is ever
drawn and the buffer is cleared to black first, so keying them would produce
identical pixels for twice the blits.
