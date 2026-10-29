## Notes

Thanks to [Buster (E. Hashimoto)](https://ja.wikipedia.org/wiki/%E9%AD%94%E7%8E%8B%E3%81%AE%E3%82%A2%E3%82%AF%E3%82%B8) for creating Akuji the Demon, a compact action-platformer whose one large castle is built around the abilities you win back, and to [D](https://www.romhacking.net/translations/717) for the English translation this port's text comes from.

The music plays through the GeneralUser GS bank. The original Windows `gm.dls` bank is not included, but a player who owns a copy can drop it into `assets/soundfonts/` and choose `gm` on the options screen.

## Controls

| Key | Action |
|--|--|
| D-Pad / Left Stick | Move and menu navigation |
| A | Jump / Confirm |
| X | Fire |
| Start | Pause / Confirm |

## Compile

The source is at https://github.com/AbdullahTrees/akuji. From a clone, `make portmaster` builds this package in an Ubuntu 20.04 aarch64 container: the release binary, the FluidSynth it uses, the game data, and the testing zip in `dist/akuji.zip`. `make windows` and `make linux` build the desktop releases on their own systems.
