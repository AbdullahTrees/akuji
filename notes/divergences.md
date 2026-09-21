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

The leading space is the same defect at the other end. The hand icon is drawn
OPAQUE, so its whole 16-pixel cell reaches the screen, and
`MB_HAND_ICON_X + MB_ICON_SIZE` is exactly `MB_PROMPT_TEXT_X` - the cell's right
edge finishes where the text starts, so the cursor sits against the Y with no
gap at all. One space, 3 pixels, separates them.

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
