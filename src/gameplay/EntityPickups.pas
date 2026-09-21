{ Things the player collects: ability orbs, mana stones, dropped items, the boss key, save points and readable signs.

  Split out of EntityHandlers, which holds the dispatch and everything
  these share. The handlers themselves are unchanged. }

unit EntityPickups;

{$MODE DELPHI}{$H+}

interface

uses
  SysUtils, Entities, GameState, SoundTable, PlayerState, Player,
  Directions, EntityHandlers;

{ The Mana Stone collectible counted by the HUD.

  An animated pickup: four frames on a five-frame cycle, and a one-shot settle
  downward the first time it updates.

  It animates ONLY while GameState is GS_PLAY, so items freeze during an event
  script or a pause rather than continuing behind the dialogue box. It does not
  call Entity_UpdateDying and has no touch handling of its own - what happens
  when the player walks into it is decided by EF_TOUCH_KIND from the type table,
  in Entity_PlayerTouch. }
procedure EntityUpdate_Type14_ManaStone(var E: TEntity; AGameState: Integer);
{ A sign whose text is read through interaction. Two
  instructions of substance, and no game-state guard at all. }
procedure EntityUpdate_Type16_InfoSign(var E: TEntity);
{ The power orb carries one of Akuji's nine abilities: Dash,
  Fire, Bat and the rest - and which one is its placement variant. World is
  needed only for the heartbeat, which only variant 8 has. }
procedure EntityUpdate_Type24_PowerOrb(var E: TEntity; AGameState: Integer;
                              World: TEntityWorld);
{ The Akuji statue is a save point that opens a confirmation prompt. }
procedure EntityUpdate_Type27_AkujiStatue(var E: TEntity; AGameState: Integer);
{ Falling item behavior. See DROP_SPRITES above. }
procedure EntityUpdate_Type36_FallingItem(var E: TEntity; AGameState: Integer;
                                          World: TEntityWorld);
{ The boss key drops when a boss dies, opens the door, and
  restores health. Drops, lands, and lies there animating. }
procedure EntityUpdate_Type37_BossKey(var E: TEntity; AGameState: Integer;
                              World: TEntityWorld);

implementation

procedure EntityUpdate_Type14_ManaStone(var E: TEntity; AGameState: Integer);
var
  Variant, Frame: Integer;
begin
  Variant := E.Raw[EF_VARIANT];
  Frame := E.Raw[EF_FLAG1C];
  { Shipped variants are 0 and 1. The frame counter is always kept in range. }
  E.Raw[EF_ANIM_ID] := SpriteDatum(MANA_AT + Variant * SPRITE_ROW + Frame);

  if E.Raw[EF_STATE] = 0 then
  begin
    E.Raw[EF_STATE] := 1;
    E.Raw[EF_POS_Y] := E.Raw[EF_POS_Y] + MANA_SETTLE_DROP;
  end;

  if AGameState <> GS_PLAY then
    Exit;

  Inc(E.Raw[EF_BLOCK_B]);
  if E.Raw[EF_BLOCK_B] > MANA_FRAME_TICKS then
  begin
    E.Raw[EF_BLOCK_B] := 0;
    E.Raw[EF_FLAG1C] := (E.Raw[EF_FLAG1C] + 1) mod MANA_FRAMES;
  end;
end;

{ Entity activity is encoded in the low byte of EF_ALIVE. }
procedure EntityUpdate_Type16_InfoSign(var E: TEntity);
begin
  E.Raw[EF_ANIM_ID] := SIGN_SPRITE;
end;
procedure EntityUpdate_Type24_PowerOrb(var E: TEntity; AGameState: Integer;
                              World: TEntityWorld);
var
  Variant, Frame: Integer;
begin
  Variant := E.Raw[EF_VARIANT];
  Frame   := E.Raw[EF_FLAG1C];
  { Clamp invalid runtime data before indexing sprite tables. }
  if (Variant < 0) or (Variant >= ITEM24_VARIANTS) then
    Variant := 0;
  if (Frame < 0) or (Frame >= ITEM24_BEAT_FRAMES) then
    Frame := 0;

  if E.Raw[EF_VARIANT] <> ITEM24_BEAT_VARIANT then
    E.Raw[EF_ANIM_ID] := ITEM24_SPRITES[Variant]
  else
    E.Raw[EF_ANIM_ID] := ITEM24_BEAT_SPRITES[Frame];

  if AGameState <> GS_PLAY then
    Exit;

  { The bob. EF_FACING is a phase here, not a heading: one step of 64 per frame
    through the direction table's Y column is one full sine period. }
  Inc(E.Raw[EF_POS_Y], DirVelY(WrapDir(E.Raw[EF_FACING])));
  { Signed modulo keeps the phase within the direction table. }
  E.Raw[EF_FACING] := (E.Raw[EF_FACING] + 1) mod DIR_COUNT;

  if E.Raw[EF_VARIANT] <> ITEM24_BEAT_VARIANT then
    Exit;

  { The frame counter is compared against ZERO, so it resets on the very frame
    it is incremented and the two frames alternate every frame. The counter is
    vestigial rather than a speed control, producing a flicker. }
  Inc(E.Raw[EF_BLOCK_B]);
  if E.Raw[EF_BLOCK_B] > 0 then
  begin
    E.Raw[EF_BLOCK_B] := 0;
    E.Raw[EF_FLAG1C] := (E.Raw[EF_FLAG1C] + 1) mod ITEM24_BEAT_FRAMES;
  end;

  Inc(E.Raw[EF_BLOCK_B + 1]);
  if E.Raw[EF_BLOCK_B + 1] > ITEM24_BEAT_TICKS then
  begin
    E.Raw[EF_BLOCK_B + 1] := 0;
    World.PlaySound(SND_KODOU);
  end;
end;
procedure EntityUpdate_Type27_AkujiStatue(var E: TEntity; AGameState: Integer);
var
  Frame: Integer;
begin
  Frame := E.Raw[EF_FLAG1C];
  if (Frame < 0) or (Frame >= SAVE_POINT_FRAMES) then
    Frame := 0;
  E.Raw[EF_ANIM_ID] := SAVE_POINT_SPRITES[Frame];

  if AGameState <> GS_PLAY then
    Exit;

  Inc(E.Raw[EF_BLOCK_B]);
  if E.Raw[EF_BLOCK_B] > SAVE_POINT_TICKS then
  begin
    E.Raw[EF_BLOCK_B] := 0;
    E.Raw[EF_FLAG1C] := (E.Raw[EF_FLAG1C] + 1) mod SAVE_POINT_FRAMES;
  end;
end;
procedure EntityUpdate_Type36_FallingItem(var E: TEntity; AGameState: Integer;
                                          World: TEntityWorld);
var
  Frame: Integer;
begin
  Frame := E.Raw[EF_FLAG1C];
  if (Frame < 0) or (Frame >= DROP_SPRITE_COUNT) then
    Frame := 0;
  E.Raw[EF_ANIM_ID] := DROP_SPRITES[Frame];

  if AGameState <> GS_PLAY then
    Exit;

  { Gravity only while still in the air. }
  if E.Raw[EF_STATE] = 0 then
  begin
    Inc(E.Raw[EF_VEL_Y], GRAVITY);
    if E.Raw[EF_VEL_Y] > TERMINAL_VELOCITY then
      E.Raw[EF_VEL_Y] := TERMINAL_VELOCITY;
  end;

  { The collision query and the move happen either way, landed or not. }
  if (World.TileAtY(E, E.Raw[EF_VEL_Y], False) >= World.SolidThreshold)
     and (E.Raw[EF_VEL_Y] > 0) then
  begin
    E.Raw[EF_VEL_Y] := World.EdgeDistY(E, E.Raw[EF_VEL_Y]);
    E.Raw[EF_STATE] := 1;
  end;

  Inc(E.Raw[EF_POS_Y], E.Raw[EF_VEL_Y]);
end;
procedure EntityUpdate_Type37_BossKey(var E: TEntity; AGameState: Integer;
                              World: TEntityWorld);
var
  Frame: Integer;
begin
  Frame := E.Raw[EF_FLAG1C];
  if (Frame < 0) or (Frame >= T37_FRAMES) then
    Frame := 0;
  E.Raw[EF_ANIM_ID] := T37_SPRITES[Frame];

  { Arrival, and it happens whatever the game state is. }
  if E.Raw[EF_STATE] = 0 then
  begin
    World.Spawn(EKIND_MINOR, T37_PUFF_TYPE,
                E.Raw[EF_POS_X] - POSITION_BIAS,
                E.Raw[EF_POS_Y] - POSITION_BIAS);
    E.Raw[EF_STATE] := 1;
    Inc(E.Raw[EF_POS_Y], T37_DROP);
    E.Raw[EF_TIMER] := T37_TIMERS;
    E.Raw[EF_DEATH_TIMER] := T37_TIMERS;
  end;

  if AGameState <> GS_PLAY then
    Exit;

  if E.Raw[EF_STATE] = 1 then
  begin
    Inc(E.Raw[EF_VEL_Y], T37_GRAVITY);
    if E.Raw[EF_VEL_Y] > T37_TERMINAL then
      E.Raw[EF_VEL_Y] := T37_TERMINAL;

    if World.TileAtY(E, E.Raw[EF_VEL_Y], False) >= World.SolidThreshold then
    begin
      World.PlaySound(T37_LAND_SOUND);
      E.Raw[EF_VEL_Y] := World.EdgeDistY(E, E.Raw[EF_VEL_Y]);
      E.Raw[EF_STATE] := 2;
    end;
    Inc(E.Raw[EF_POS_Y], E.Raw[EF_VEL_Y]);
  end;

  Inc(E.Raw[EF_BLOCK_B]);
  if E.Raw[EF_BLOCK_B] > T37_TICKS then
  begin
    E.Raw[EF_BLOCK_B] := 0;
    E.Raw[EF_FLAG1C] := (E.Raw[EF_FLAG1C] + 1) mod T37_FRAMES;
  end;
end;

end.
