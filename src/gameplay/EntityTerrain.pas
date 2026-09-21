{ Parts of the stage rather than creatures: blocks, platforms, doors, switches and presses the player stands on, rides, opens or breaks.

  Split out of EntityHandlers, which holds the dispatch and everything
  these share. The handlers themselves are unchanged. }

unit EntityTerrain;

{$MODE DELPHI}{$H+}

interface

uses
  SysUtils, Entities, GameState, SoundTable, PlayerState, Player,
  Directions, EntityHandlers;

{ A switch activated by pressing Up against it, usually
  unlocks a door. The only handler that writes to the event table. }
procedure EntityUpdate_Type15_Switch(var E: TEntity; AGameState: Integer;
                              World: TEntityWorld);
{ The winged-horse block is a platform that carries the player
  along its axis. See the T21_ block above for why EF_FACING is a speed here
  and not a heading. }
procedure EntityUpdate_Type21_WingedHorseBlock(var E: TEntity; AGameState: Integer;
                              World: TEntityWorld);
{ A door used to move to the next or previous room. }
procedure EntityUpdate_Type25_Door(var E: TEntity);
{ PoyoPoyo is a bouncing blob that throws the player
  very high. A springboard and a shooter by variant; see the T40_ block,
  whose launch rewrites six fields of the player's entity. }
procedure EntityUpdate_Type40_PoyoPoyo(var E: TEntity; AGameState: Integer;
                              var Inp: TInputState; World: TEntityWorld);
{ NukeNuke is a block that stops being solid once the player has
  stood on it too long. The only reader of EF_RIDDEN. }
procedure EntityUpdate_Type45_Block_NukeNuke(var E: TEntity; AGameState: Integer;
                              World: TEntityWorld);
{ A large spike press that stamps down on a fixed interval: drops
  from the ceiling, sends a wave each way along the floor, rests, and climbs
  back. }
procedure EntityUpdate_Type64_SpikePress(var E: TEntity; AGameState: Integer;
                              World: TEntityWorld);
{ GoroGoro is a ball the player rolls by shooting it, to be dropped
  onto a switch. It slides, and when it finds a hole under it pays out a type
  68 and sets its event's progress flag. }
procedure EntityUpdate_Type69_GoroGoro(var E: TEntity; AGameState: Integer;
                              World: TEntityWorld);
{ Runs eight frames, writes a state into its owner, and ends.
  The only child that dies when its parent's health reaches zero. }
procedure EntityUpdate_Type75(var E: TEntity; AGameState: Integer;
                              World: TEntityWorld);
{ A levitating spike press that tracks left and right: one
  heading step per reload, velocity from that heading, so it crosses and
  comes back over a full turn. }
procedure EntityUpdate_Type76_SpikePress_Lev(var E: TEntity; AGameState: Integer;
                              World: TEntityWorld);

implementation

procedure EntityUpdate_Type15_Switch(var E: TEntity; AGameState: Integer;
                              World: TEntityWorld);
var
  Frame: Integer;
begin
  Frame := E.Raw[EF_FLAG1C];
  if (Frame < 0) or (Frame > 1) then
    Frame := 0;
  E.Raw[EF_ANIM_ID] := T15_SPRITES[Frame];

  if AGameState <> GS_PLAY then
    Exit;

  { Two states in sequence, in two separate ifs - so the frame that sets
    state 2 also runs the state-2 arm. One throw, one frame. }
  if E.Raw[EF_STATE] = 1 then
  begin
    World.PlaySound(T15_SOUND);
    E.Raw[EF_STATE] := 2;
  end;
  if E.Raw[EF_STATE] = 2 then
  begin
    E.Raw[EF_STATE] := 3;
    E.Raw[EF_FLAG1C] := 1;
    World.SetEventOpcode(E.Raw[EF_EVENT_ID], T15_THROWN_OPCODE);
  end;
end;
procedure EntityUpdate_Type21_WingedHorseBlock(var E: TEntity; AGameState: Integer;
                              World: TEntityWorld);
begin
  E.Raw[EF_ANIM_ID] := T21_SPRITE;
  if EntityUpdateDying(E, AGameState, World) then
    Exit;

  Inc(E.Raw[EF_BLOCK_B]);
  { The half-period is block A[1]. Both ParamA kinds 'M' and 'R' write this
    field; shipped type-21 placements use 'M'.

    'M' is also where the speed comes from, and it arrives disguised: the
    letter writes EF_FACING := Arg(2) shl 3, meaning it as a heading in
    eighths of the 64-step turn. Type 21 does not read it as a heading at all,
    it adds it to a coordinate. The placements pass -4, so Facing holds -32,
    which at POSITION_SHIFT 5 is exactly one pixel a frame. }
  if E.Raw[EF_BLOCK_B] > E.Raw[EF_BLOCK_A + 1] then
  begin
    E.Raw[EF_BLOCK_B] := 0;
    E.Raw[EF_FACING] := -E.Raw[EF_FACING];
  end;

  if E.Raw[EF_STATE] = T21_AXIS_VERTICAL then
    Inc(E.Raw[EF_POS_Y], E.Raw[EF_FACING])
  else if E.Raw[EF_STATE] = T21_AXIS_HORIZONTAL then
    Inc(E.Raw[EF_POS_X], E.Raw[EF_FACING]);
end;
procedure EntityUpdate_Type25_Door(var E: TEntity);
var
  Variant: Integer;
begin
  Variant := E.Raw[EF_VARIANT];
  { DIVERGENCE DIV-010: clamp malformed variants instead of crossing tables. }
  { Shipped placements use variants 0..2; clamp malformed runtime data. }
  if (Variant < 0) or (Variant >= ITEM25_VARIANTS) then
    Variant := 0;
  E.Raw[EF_ANIM_ID] := ITEM25_SPRITES[Variant];
end;
procedure EntityUpdate_Type40_PoyoPoyo(var E: TEntity; AGameState: Integer;
                              var Inp: TInputState; World: TEntityWorld);
var
  Frame, Row, D, Slot, Aim: Integer;
  Player: PEntity;
begin
  Frame := E.Raw[EF_FLAG1C];
  if (Frame < 0) or (Frame >= T40_FRAMES) then
    Frame := 0;
  Row := E.Raw[EF_VARIANT];
  if (Row < 0) or (Row >= T40_VARIANTS) then
    Row := 0;
  E.Raw[EF_ANIM_ID] := T40_SPRITES[Row][Frame];

  if E.Raw[EF_STATE] = 0 then
  begin
    E.Raw[EF_STATE] := 1;
    Inc(E.Raw[EF_POS_Y], T40_SETTLE);
    if E.Raw[EF_VARIANT] = T40_SHOOTER_VARIANT then
    begin
      E.Raw[EF_VULN_KIND] := 1;
      E.Raw[EF_CULL_OFFSCREEN] := 0;
    end;
  end;

  if EntityUpdateDying(E, AGameState, World) then
    Exit;

  D := World.PlayerDifficulty;
  if (D < 0) or (D > 2) then
    D := 0;

  if (E.Raw[EF_STATE] = 1) and (E.Raw[EF_VARIANT] = T40_SHOOTER_VARIANT)
     and (not IsOffScreen(E, T40_OFFSCREEN_MARGIN)) and (World.Pool <> nil) then
  begin
    if E.Raw[EF_CHILD_B] > 0 then
      Dec(E.Raw[EF_CHILD_B]);
    if E.Raw[EF_CHILD_B] = 0 then
    begin
      Player := World.Pool.Entity(SLOT_SINGLE_FIRST);
      if EntitiesOverlap(E, Player^, T40_TRIGGER_SCALE_X,
                         T40_TRIGGER_SCALE_Y) then
      begin
        E.Raw[EF_CHILD_B] := T40_COOLDOWN[D];
        Slot := World.Spawn(EKIND_MINOR, T40_SHOT_TYPE,
                            E.Raw[EF_POS_X] - POSITION_BIAS
                              - World.Layer.DeltaX,
                            E.Raw[EF_POS_Y] - World.Layer.DeltaY
                              - POSITION_BIAS + T40_SHOT_LIFT);
        World.SetSpawnField(Slot, EF_OWNER, E.Raw[EF_SLOT]);
        { HP 1 - so this shot never writes back to its parent. }
        World.SetSpawnField(Slot, EF_HP, 1);
        Aim := Compare(E.Raw[EF_POS_X], Player^.Raw[EF_POS_X]) shl T40_AIM_SHIFT;
        if Aim = 0 then
          Aim := T40_AIM_ZERO;
        World.SetSpawnField(Slot, EF_VEL_X, Aim);
      end;
    end;
  end;

  { The launch. Nothing here sets state 2 - the touch handler does. }
  if (E.Raw[EF_STATE] = 2) and (World.Pool <> nil) then
  begin
    E.Raw[EF_STATE] := 3;
    E.Raw[EF_BLOCK_B] := 0;
    E.Raw[EF_CHILD_A] := 0;
    E.Raw[EF_TIMER] := T40_BOUNCE_TIMER;
    E.Raw[EF_FLAG1C] := 0;

    Player := World.Pool.Entity(SLOT_SINGLE_FIRST);
    Player^.Raw[EF_VEL_Y] := T40_LAUNCH_VY;
    { Keeps the SPEED it arrived with, takes the DIRECTION from what is held
      now - so you can turn round on the spring. With no input, untouched. }
    if Inp.AxisX <> 0 then
      Player^.Raw[EF_CHILD_A] := Abs(Player^.Raw[EF_VEL_X]) * Inp.AxisX;
    Player^.Raw[EF_STATE] := 2;
    Player^.Raw[EF_BLOCK_A + 1] := 1;
    Player^.Raw[EF_RIDDEN] := 0;
    Player^.Raw[EF_BLOCK_A + 8] := 1;
    World.PlaySound(T40_LAUNCH_SOUND);
  end;

  if E.Raw[EF_STATE] = 3 then
  begin
    Inc(E.Raw[EF_BLOCK_B]);
    if E.Raw[EF_BLOCK_B] > T40_BOUNCE_TICKS then
    begin
      E.Raw[EF_BLOCK_B] := 0;
      Inc(E.Raw[EF_FLAG1C]);
      if E.Raw[EF_FLAG1C] > T40_BOUNCE_FRAMES - 1 then
      begin
        E.Raw[EF_FLAG1C] := 0;
        Inc(E.Raw[EF_CHILD_A]);
        if E.Raw[EF_CHILD_A] > T40_BOUNCE_CYCLES then
          E.Raw[EF_STATE] := 1;
      end;
    end;
  end;
end;
procedure EntityUpdate_Type45_Block_NukeNuke(var E: TEntity; AGameState: Integer;
                              World: TEntityWorld);
var
  Frame, D: Integer;
begin
  Frame := E.Raw[EF_FLAG1C];
  if (Frame < 0) or (Frame >= T45_FRAMES) then
    Frame := 0;
  E.Raw[EF_ANIM_ID] := T45_SPRITES[Frame];

  if EntityUpdateDying(E, AGameState, World) then
    Exit;

  D := World.PlayerDifficulty;
  if (D < 0) or (D > 2) then
    D := 0;

  { EF_RIDDEN is what Entity_SolidCollideY sets when something stands on a
    solid. This is the only handler that reads it. }
  if (E.Raw[EF_STATE] = 0) and (E.Raw[EF_RIDDEN] = 1) then
    E.Raw[EF_STATE] := 1;

  if E.Raw[EF_STATE] = 1 then
  begin
    Dec(E.Raw[EF_BLOCK_B]);
    if E.Raw[EF_BLOCK_B] < 1 then
    begin
      E.Raw[EF_BLOCK_B] := T45_TICKS;
      Inc(E.Raw[EF_FLAG1C]);
      if E.Raw[EF_FLAG1C] > T45_FRAMES - 1 then
      begin
        E.Raw[EF_FLAG1C] := T45_SHAKE_FIRST;
        Inc(E.Raw[EF_CHILD_A]);
        { A HIGHER difficulty subtracts more, so it breaks SOONER. }
        if E.Raw[EF_CHILD_A] > E.Raw[EF_BLOCK_A + 1] - T45_TOUGH[D] then
        begin
          World.PlaySound(T45_BREAK_SOUND);
          E.Raw[EF_STATE] := 2;
          E.Raw[EF_BLOCK_B] := 0;
          E.Raw[EF_CHILD_A] := 0;
          E.Raw[EF_DEATH_TIMER] := T45_GONE_FRAMES;
          E.Raw[EF_SOLID] := 0;
        end;
      end;
    end;
  end;

  if (E.Raw[EF_STATE] = 2) and (E.Raw[EF_DEATH_TIMER] = 0) then
  begin
    E.Raw[EF_FLAG1C] := 0;
    E.Raw[EF_STATE] := 0;
    E.Raw[EF_SOLID] := 1;
  end;

  { Cleared every frame whatever the state - a one-frame signal the collision
    has to re-set to keep the count going. }
  E.Raw[EF_RIDDEN] := 0;
end;
procedure EntityUpdate_Type64_SpikePress(var E: TEntity; AGameState: Integer;
                              World: TEntityWorld);
var
  Frame, D, Slot, Rise: Integer;
begin
  Frame := E.Raw[EF_FLAG1C];
  if (Frame < 0) or (Frame >= T64_FRAMES) then
    Frame := 0;
  E.Raw[EF_ANIM_ID] := T64_SPRITES[Frame];

  if EntityUpdateDying(E, AGameState, World) then
    Exit;

  D := World.PlayerDifficulty;
  if (D < 0) or (D > 2) then
    D := 0;

  { Outside every state - it flaps at the same rate throughout. }
  Inc(E.Raw[EF_BLOCK_B]);
  if E.Raw[EF_BLOCK_B] > T64_TICKS then
  begin
    E.Raw[EF_BLOCK_B] := 0;
    E.Raw[EF_FLAG1C] := (E.Raw[EF_FLAG1C] + 1) mod T64_FRAMES;
  end;

  if E.Raw[EF_STATE] = 0 then
  begin
    E.Raw[EF_STATE] := 1;
    Inc(E.Raw[EF_POS_X], T64_NUDGE);
  end;

  if E.Raw[EF_STATE] = 1 then
  begin
    Inc(E.Raw[EF_CHILD_A]);
    { Scaled by the variant, so a row of them drops in sequence - and a
      variant of 0 gives a threshold of 0 and drops at once. }
    if E.Raw[EF_CHILD_A] > T64_WAIT[D] * E.Raw[EF_VARIANT] then
    begin
      E.Raw[EF_STATE] := 2;
      E.Raw[EF_CHILD_A] := 0;
      E.Raw[EF_VEL_Y] := 0;
    end;
  end;

  if E.Raw[EF_STATE] = 2 then
  begin
    Inc(E.Raw[EF_VEL_Y], T64_GRAVITY);
    if E.Raw[EF_VEL_Y] > T64_TERMINAL then
      E.Raw[EF_VEL_Y] := T64_TERMINAL;

    if World.TileAtY(E, E.Raw[EF_VEL_Y], False) >= World.SolidThreshold then
    begin
      World.PlaySound(T64_SND_SLAM);
      Slot := World.Spawn(EKIND_MINOR, T64_WAVE_TYPE,
                          E.Raw[EF_POS_X] - POSITION_BIAS - T64_WAVE_OUT,
                          E.Raw[EF_POS_Y] - POSITION_BIAS + T64_WAVE_DROP);
      World.SetSpawnField(Slot, EF_VEL_X, -T64_WAVE_SPEED);
      Slot := World.Spawn(EKIND_MINOR, T64_WAVE_TYPE,
                          E.Raw[EF_POS_X] - POSITION_BIAS + T64_WAVE_OUT,
                          E.Raw[EF_POS_Y] - POSITION_BIAS + T64_WAVE_DROP);
      World.SetSpawnField(Slot, EF_VEL_X, T64_WAVE_SPEED);
      E.Raw[EF_STATE] := 3;
      E.Raw[EF_VEL_Y] := World.EdgeDistY(E, E.Raw[EF_VEL_Y]);
    end;
    Inc(E.Raw[EF_POS_Y], E.Raw[EF_VEL_Y]);
  end;

  if E.Raw[EF_STATE] = 3 then
  begin
    Inc(E.Raw[EF_CHILD_A]);
    if E.Raw[EF_CHILD_A] > T64_REST[D] then
    begin
      E.Raw[EF_CHILD_A] := 0;
      E.Raw[EF_STATE] := 4;
    end;
  end;

  if E.Raw[EF_STATE] = 4 then
  begin
    Rise := T64_RISE[D] * T64_RISE_SCALE;
    E.Raw[EF_VEL_Y] := Rise;
    if World.TileAtY(E, Rise, False) >= World.SolidThreshold then
    begin
      E.Raw[EF_STATE] := 1;
      E.Raw[EF_VEL_Y] := World.EdgeDistY(E, E.Raw[EF_VEL_Y]);
    end;
    Inc(E.Raw[EF_POS_Y], E.Raw[EF_VEL_Y]);
  end;
end;
procedure EntityUpdate_Type69_GoroGoro(var E: TEntity; AGameState: Integer;
                              World: TEntityWorld);
var
  Frame, Slot: Integer;
begin
  Frame := E.Raw[EF_FLAG1C];
  if (Frame < 0) or (Frame >= T69_FRAMES) then
    Frame := 0;
  E.Raw[EF_ANIM_ID] := T69_SPRITES[Frame];

  if EntityUpdateDying(E, AGameState, World) then
    Exit;

  if E.Raw[EF_STATE] = 0 then
    E.Raw[EF_STATE] := 1;

  { It never accelerates itself - something else has to push it. }
  ApproachZero(E.Raw[EF_VEL_X], T69_FRICTION);
  Inc(E.Raw[EF_POS_X], E.Raw[EF_VEL_X]);

  { The absence of a floor, not the presence of a wall. }
  if World.TileAtY(E, T69_FLOOR_PROBE, False) < World.SolidThreshold then
  begin
    Slot := World.Spawn(EKIND_ACTOR, T69_PRIZE_TYPE,
                        E.Raw[EF_POS_X] - POSITION_BIAS,
                        E.Raw[EF_POS_Y] - POSITION_BIAS);
    World.SetSpawnField(Slot, EF_STATE, T69_PRIZE_STATE);
    World.SetSpawnField(Slot, EF_HP, T69_PRIZE_HP);
    { The prize wears this object's own sprite. }
    World.SetSpawnField(Slot, EF_ANIM_ID, E.Raw[EF_ANIM_ID]);
    World.DestroyEntity(E, False);
    { After the destroy, and with no opcode test - see the T69_ block.
      EF_EVENT_ID survives Entity_Destroy, which is why this order works. }
    World.SetProgress(World.EventProgressIndex(E.Raw[EF_EVENT_ID]));
  end;
end;
procedure EntityUpdate_Type75(var E: TEntity; AGameState: Integer;
                              World: TEntityWorld);
var
  Frame: Integer;
begin
  Frame := E.Raw[EF_FLAG1C];
  if (Frame < 0) or (Frame >= T75_FRAMES) then
    Frame := 0;
  { One table, two directions - that is the whole open/close difference. }
  if E.Raw[EF_STATE] = T75_OPENING then
    E.Raw[EF_ANIM_ID] := T75_SPRITES[Frame];
  if E.Raw[EF_STATE] = T75_CLOSING then
    E.Raw[EF_ANIM_ID] := T75_SPRITES[T75_FRAMES - 1 - Frame];

  if EntityUpdateDying(E, AGameState, World) then
    Exit;
  if World.Pool = nil then
    Exit;

  { It dies with its parent. No other child checks this. }
  if World.Pool.Field(E.Raw[EF_OWNER], EF_HP) = 0 then
  begin
    World.DestroyEntity(E, False);
    Exit;
  end;

  Inc(E.Raw[EF_BLOCK_B]);
  if E.Raw[EF_BLOCK_B] > T75_TICKS then
  begin
    E.Raw[EF_BLOCK_B] := 0;
    Inc(E.Raw[EF_FLAG1C]);
    if E.Raw[EF_FLAG1C] > T75_FRAMES - 1 then
    begin
      if E.Raw[EF_STATE] = T75_OPENING then
      begin
        World.PlaySound(T75_SND_OPEN);
        World.Pool.SetField(E.Raw[EF_OWNER], EF_STATE, T75_OWNER_AFTER_OPEN);
      end;
      if E.Raw[EF_STATE] = T75_CLOSING then
        World.Pool.SetField(E.Raw[EF_OWNER], EF_STATE, T75_OWNER_AFTER_CLOSE);
      World.DestroyEntity(E, False);
    end;
  end;
end;
procedure EntityUpdate_Type76_SpikePress_Lev(var E: TEntity; AGameState: Integer;
                              World: TEntityWorld);
var
  Frame, D: Integer;
begin
  Frame := E.Raw[EF_FLAG1C];
  if (Frame < 0) or (Frame >= T76_FRAMES) then
    Frame := 0;
  E.Raw[EF_ANIM_ID] := T76_SPRITES[Frame];

  if EntityUpdateDying(E, AGameState, World) then
    Exit;

  D := World.PlayerDifficulty;
  if (D < 0) or (D > 2) then
    D := 0;

  if E.Raw[EF_STATE] = 0 then
  begin
    E.Raw[EF_STATE] := 1;
    Inc(E.Raw[EF_POS_X], T76_NUDGE);
  end;

  Inc(E.Raw[EF_BLOCK_B]);
  if E.Raw[EF_BLOCK_B] > T76_TICKS then
  begin
    E.Raw[EF_BLOCK_B] := 0;
    E.Raw[EF_FLAG1C] := (E.Raw[EF_FLAG1C] + 1) mod T76_FRAMES;
  end;

  Dec(E.Raw[EF_CHILD_A]);
  if E.Raw[EF_CHILD_A] < 1 then
  begin
    E.Raw[EF_CHILD_A] := T76_PERIOD[D];
    E.Raw[EF_VEL_X] := DirVelX(E.Raw[EF_FACING]) * T76_SPEED[D];
    E.Raw[EF_FACING] := (E.Raw[EF_FACING] + 1) mod DIR_COUNT;
    { On reaching 63, not on the wrap to 0 - see the T76_ block. }
    if E.Raw[EF_FACING] = T76_LAP_AT then
      World.PlaySound(T76_SND_LAP);
  end;

  Inc(E.Raw[EF_POS_X], E.Raw[EF_VEL_X]);
end;

end.
