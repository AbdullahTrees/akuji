#!/bin/bash

XDG_DATA_HOME=${XDG_DATA_HOME:-$HOME/.local/share}

if [ -d "/opt/system/Tools/PortMaster/" ]; then
  controlfolder="/opt/system/Tools/PortMaster"
elif [ -d "/opt/tools/PortMaster/" ]; then
  controlfolder="/opt/tools/PortMaster"
elif [ -d "$XDG_DATA_HOME/PortMaster/" ]; then
  controlfolder="$XDG_DATA_HOME/PortMaster"
else
  controlfolder="/roms/ports/PortMaster"
fi

source $controlfolder/control.txt
[ -f "${controlfolder}/mod_${CFW_NAME}.txt" ] && source "${controlfolder}/mod_${CFW_NAME}.txt"
get_controls

GAMEDIR="/$directory/ports/akuji"
BINARY=akuji.aarch64

cd "$GAMEDIR" || exit 1

> "$GAMEDIR/log.txt" && exec > >(tee "$GAMEDIR/log.txt") 2>&1

export LD_LIBRARY_PATH="$GAMEDIR/libs.${DEVICE_ARCH}:$LD_LIBRARY_PATH"
export SDL_GAMECONTROLLERCONFIG="$sdl_controllerconfig"

# First launch, and every update: unpack the game data. The archive has no
# save, settings or gm.dls, so a player's own files survive it.
ARCHIVE_FILE="gamedata.tar.gz"
if [ -f "$ARCHIVE_FILE" ]; then
  pm_message "Extracting game data, this can take a few minutes..." --title "Please wait"
  if ! gunzip -c "$ARCHIVE_FILE" | tar --no-same-owner -xf -; then
    pm_show_error "Could not extract the game data. Check that there is enough free space, then launch again." --title "Extraction failed"
    exit 1
  fi
  $ESUDO rm -f "$ARCHIVE_FILE"
elif [ ! -f "assets/bmp.qda" ]; then
  pm_show_error "No game data found. Reinstall the port." --title "Game data missing"
  exit 1
fi

$GPTOKEYB2 "akuji" -c "$GAMEDIR/akuji.ini" > /dev/null 2>&1 &

pm_platform_helper "$GAMEDIR/$BINARY"

# Zip extraction may drop the executable bit; put it back.
$ESUDO chmod +x "$GAMEDIR/$BINARY"

./"$BINARY"

pm_finish
