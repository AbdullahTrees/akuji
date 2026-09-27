# To do

Decided, not yet done. Each becomes a divergence in `divergences.md` when it
lands.

## Pause the play timer while a message box is open, and stop it at the last orb

The original counts play time in `Player_Update` (`Field11C0` frames,
`ElapsedSec` seconds), before its game-state check, and `Entity_UpdateAll`
calls it for the player every frame in every state. So the clock keeps
running while a sign's message is open (state 0x8C) and through the soul
fanfare and fade after the final orb, until the ending takes over. The port
does the same, deliberately.

Wanted later:

- the clock stops the moment the final orb is collected, where the soul
  pickup starts its fanfare (`TDialogueBox.SoulGet`, phase 0), so the RESULT
  time is the time of collection;
- the clock pauses while a message box is open, so reading signs costs
  nothing.

Both shorten the RESULT time the rank is judged on (Rank S has a time limit),
in the player's favour - record that in the divergence.

## Menus in the language files

NEW GAME, OPTION, CONTROLS, the RESULT screen and the rest are still English
in `src/screens/Title.pas` and `src/screens/Ending.pas`, drawn by the ASCII
bitmap font. Move them into the PO files once that font can draw other
scripts (DIV-026).

## Rebinding the directions

UP, DOWN, LEFT and RIGHT cannot be rebound (`TDDIDEX.BindAction` refuses
them). The signs already name them through `{UP}` `{DOWN}` `{LEFT}` `{RIGHT}`
(DIV-028), so the text needs nothing when they can.
