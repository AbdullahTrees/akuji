{ Shots, bombs, eggs and thrown objects in flight, whoever fired them.

  Split out of EntityHandlers, which holds the dispatch and everything
  these share. The handlers themselves are unchanged. }

unit EntityProjectiles;

{$MODE DELPHI}{$H+}

interface

uses
  SysUtils, Entities, GameState, SoundTable, PlayerState, Player,
  Directions, EntityHandlers;

{ Player projectile behavior. See the T2_ block above. }
procedure EntityUpdate_Type02(var E: TEntity; AGameState: Integer;
                              World: TEntityWorld);
{ Debris behavior with four states. See the T13_ block above. }
procedure EntityUpdate_Type13(var E: TEntity; AGameState: Integer;
                              World: TEntityWorld);
{ Type 38's shot charges, then flies. }
procedure EntityUpdate_Type39(var E: TEntity; AGameState: Integer;
                              World: TEntityWorld);
{ Type 42's shot is thrown up, pulled down, and culled off screen. }
procedure EntityUpdate_Type44(var E: TEntity; AGameState: Integer;
                              World: TEntityWorld);
{ Type 47's shot bounces four times, each lower than the last. }
procedure EntityUpdate_Type48(var E: TEntity; AGameState: Integer;
                              World: TEntityWorld);
{ The magician boss's fireball in state 0 and its trail in state 1. }
procedure EntityUpdate_Type55(var E: TEntity; AGameState: Integer;
                              World: TEntityWorld);

implementation

procedure EntityUpdate_Type02(var E: TEntity; AGameState: Integer;
                              World: TEntityWorld);
var
  Frame, Row, I, Slot, Facing, SparkRow: Integer;
begin
  Frame := E.Raw[EF_FLAG1C];
  Row := E.Raw[EF_STATE];
  { Select the state row and facing half from the contiguous sprite table. A
    zero horizontal velocity leaves the previous sprite unchanged. }
  if E.Raw[EF_VEL_X] > 0 then
    E.Raw[EF_ANIM_ID] := SpriteDatum(T2_AT + Row * SPRITE_ROW + Frame);
  if E.Raw[EF_VEL_X] < 0 then
    E.Raw[EF_ANIM_ID] :=
      SpriteDatum(T2_AT + Row * SPRITE_ROW + Frame + T2_FRAMES);

  if AGameState <> GS_PLAY then
    Exit;

  Inc(E.Raw[EF_BLOCK_B]);
  if E.Raw[EF_BLOCK_B] > T2_TICKS then
  begin
    E.Raw[EF_BLOCK_B] := 0;
    Inc(E.Raw[EF_FLAG1C]);
    if E.Raw[EF_FLAG1C] > T2_FRAMES - 1 then
      E.Raw[EF_FLAG1C] := 0;
  end;

  SparkRow := 0;
  if E.Raw[EF_STATE] = T2_CHARGE_STATE then
  begin
    SparkRow := 1;
    { Accelerates along whatever direction it already has - Compare(0, v) is
      the sign, so this never reverses a shot. }
    Inc(E.Raw[EF_VEL_X], Compare(0, E.Raw[EF_VEL_X]) * T2_CHARGE_ACCEL);
    Inc(E.Raw[EF_CHILD_A]);
    if E.Raw[EF_CHILD_A] > T2_TRAIL_EVERY then
    begin
      E.Raw[EF_CHILD_A] := 0;
      World.Spawn(EKIND_MINOR, T2_TRAIL_TYPE,
                  E.Raw[EF_POS_X] - POSITION_BIAS,
                  E.Raw[EF_POS_Y] - POSITION_BIAS - T2_TRAIL_LIFT);
    end;
  end;

  if World.TileAtX(E, E.Raw[EF_VEL_X], False) < World.SolidThreshold then
  begin
    Inc(E.Raw[EF_POS_X], E.Raw[EF_VEL_X]);
    { The lifetime is a countdown, and running out is the quiet end. }
    Dec(E.Raw[EF_CHILD_B]);
    if E.Raw[EF_CHILD_B] < 0 then
    begin
      World.Spawn(EKIND_MINOR, T2_TRAIL_TYPE,
                  E.Raw[EF_POS_X] - POSITION_BIAS,
                  E.Raw[EF_POS_Y] - POSITION_BIAS - T2_TRAIL_LIFT);
      World.DestroyEntity(E, False);
    end;
  end
  else
  begin
    { A wall. Six sparks, each with its own heading and its own two speeds. }
    for I := 1 to T2_SPARKS do
    begin
      Slot := World.Spawn(EKIND_MINOR, T2_SPARK_TYPE,
                          E.Raw[EF_POS_X] - POSITION_BIAS,
                          E.Raw[EF_POS_Y] - POSITION_BIAS);
      { Block A[1] is type 6's sprite ROW, so a charged impact throws a
        different-coloured burst. }
      World.SetSpawnField(Slot, EF_BLOCK_A + 1, SparkRow);
      Facing := World.RandomBelow(DIR_COUNT);
      World.SetSpawnField(Slot, EF_FACING, Facing);
      World.SetSpawnField(Slot, EF_VEL_X,
        (World.RandomBelow(T2_SPARK_SPEED_MAX) + 1) * HalfExtent(DirVelX(Facing)));
      World.SetSpawnField(Slot, EF_VEL_Y,
        (World.RandomBelow(T2_SPARK_SPEED_MAX) + 1) * HalfExtent(DirVelY(Facing)));
    end;
    World.DestroyEntity(E, False);
  end;
end;
procedure EntityUpdate_Type13(var E: TEntity; AGameState: Integer;
                              World: TEntityWorld);
var
  Frame: Integer;
begin
  Frame := E.Raw[EF_FLAG1C];

  { The sprite, by state. Four independent ifs, and two of them also test the
    stage's terrain - so a state-1 shard in any terrain but 3 or 4 gets no
    write at all and keeps whatever it had. }
  if E.Raw[EF_STATE] = T13_STATE_SPLASH then
    if (Frame >= 0) and (Frame < T13_SPLASH_FRAMES) then
      E.Raw[EF_ANIM_ID] := T13_SPLASH_SPRITES[Frame];
  if (E.Raw[EF_STATE] = T13_STATE_SHARD)
     and (World.TerrainId = T13_TERRAIN_SHARD3) then
    if (Frame >= 0) and (Frame < T13_SHARD_FRAMES) then
      E.Raw[EF_ANIM_ID] := T13_SHARD3_SPRITES[Frame];
  if (E.Raw[EF_STATE] = T13_STATE_SHARD)
     and (World.TerrainId = T13_TERRAIN_SHARD4) then
    if (Frame >= 0) and (Frame < T13_SHARD_FRAMES) then
      E.Raw[EF_ANIM_ID] := T13_SHARD4_SPRITES[Frame];
  if E.Raw[EF_STATE] = 2 then
    E.Raw[EF_ANIM_ID] := T13_STATE2_SPRITE;
  if E.Raw[EF_STATE] = 3 then
    E.Raw[EF_ANIM_ID] := T13_STATE3_SPRITE;

  if (AGameState <> GS_PLAY) and (AGameState <> GS_PLAY_ALT) then
    Exit;

  if E.Raw[EF_STATE] = T13_STATE_SPLASH then
  begin
    { A pull that grows by one a frame, with no cap, and the X step comes off
      the direction table rather than a velocity. }
    Inc(E.Raw[EF_VEL_Y]);
    Inc(E.Raw[EF_POS_X], DirVelX(E.Raw[EF_FACING]));
    Inc(E.Raw[EF_POS_Y], E.Raw[EF_VEL_Y]);
    Inc(E.Raw[EF_BLOCK_B]);
    if E.Raw[EF_BLOCK_B] > T13_SPLASH_TICKS then
    begin
      E.Raw[EF_BLOCK_B] := 0;
      Inc(E.Raw[EF_FLAG1C]);
      if E.Raw[EF_FLAG1C] > T13_SPLASH_FRAMES - 1 then
      begin
        World.DestroyEntity(E, False);
        Exit;
      end;
    end;
  end;

  if E.Raw[EF_STATE] = T13_STATE_SHARD then
  begin
    Inc(E.Raw[EF_VEL_Y], T13_GRAVITY);
    if E.Raw[EF_VEL_Y] > T13_TERMINAL then
      E.Raw[EF_VEL_Y] := T13_TERMINAL;
    { This state intentionally applies vertical velocity twice per frame. }
    Inc(E.Raw[EF_POS_Y], E.Raw[EF_VEL_Y]);
    Inc(E.Raw[EF_POS_X], E.Raw[EF_VEL_X]);
    Inc(E.Raw[EF_POS_Y], E.Raw[EF_VEL_Y]);
    Inc(E.Raw[EF_BLOCK_B]);
    if E.Raw[EF_BLOCK_B] > T13_SHARD_TICKS then
    begin
      E.Raw[EF_BLOCK_B] := 0;
      Inc(E.Raw[EF_FLAG1C]);
      if E.Raw[EF_FLAG1C] > T13_SHARD_FRAMES - 1 then
      begin
        World.DestroyEntity(E, False);
        Exit;
      end;
    end;
  end;

  { States 2 and 3 share continuous motion without animation or expiry. }
  if (E.Raw[EF_STATE] = 2) or (E.Raw[EF_STATE] = 3) then
  begin
    Inc(E.Raw[EF_VEL_Y], T13_GRAVITY);
    if E.Raw[EF_VEL_Y] > T13_TERMINAL then
      E.Raw[EF_VEL_Y] := T13_TERMINAL;
    Inc(E.Raw[EF_POS_Y], E.Raw[EF_VEL_Y]);
    Inc(E.Raw[EF_POS_X], E.Raw[EF_VEL_X]);
    Inc(E.Raw[EF_POS_Y], E.Raw[EF_VEL_Y]);
  end;
end;
procedure EntityUpdate_Type39(var E: TEntity; AGameState: Integer;
                              World: TEntityWorld);
var
  Frame, D, Slot: Integer;
begin
  Frame := E.Raw[EF_FLAG1C];
  if (Frame < 0) or (Frame >= T39_FRAMES) then
    Frame := 0;
  E.Raw[EF_ANIM_ID] := T39_SPRITES[Frame];

  if EntityUpdateDying(E, AGameState, World) then
    Exit;

  D := World.PlayerDifficulty;
  if (D < 0) or (D > 2) then
    D := 0;

  if E.Raw[EF_STATE] = 0 then
  begin
    Inc(E.Raw[EF_BLOCK_B]);
    if E.Raw[EF_BLOCK_B] > T39_WIND[D] then
    begin
      E.Raw[EF_BLOCK_B] := 0;
      Inc(E.Raw[EF_FLAG1C]);
      if E.Raw[EF_FLAG1C] > T39_CHARGE_FRAMES - 1 then
      begin
        { ONLY a shot with no HP releases its parent. One with HP left leaves
          the turret stuck in state 4. }
        if (E.Raw[EF_HP] = 0) and (World.Pool <> nil) then
          World.Pool.SetField(E.Raw[EF_OWNER], EF_STATE, T39_OWNER_WIND_DOWN);
        E.Raw[EF_STATE] := 1;
        World.PlaySound(T39_LAUNCH_SOUND);
      end;
    end;
  end;

  if E.Raw[EF_STATE] = 1 then
  begin
    Inc(E.Raw[EF_BLOCK_B]);
    Inc(E.Raw[EF_CHILD_A]);
    if E.Raw[EF_BLOCK_B] > T39_FLIGHT_TICKS then
    begin
      E.Raw[EF_BLOCK_B] := 0;
      Inc(E.Raw[EF_FLAG1C]);
      if E.Raw[EF_FLAG1C] > T39_FRAMES - 1 then
        E.Raw[EF_FLAG1C] := T39_FLIGHT_FIRST;
    end;

    Inc(E.Raw[EF_POS_X], T39_SPEED[D] * E.Raw[EF_VEL_X]);
    Inc(E.Raw[EF_POS_Y], T39_SPEED[D] * E.Raw[EF_VEL_Y]);

    if (World.TileAtX(E, E.Raw[EF_VEL_X], False) >= World.SolidThreshold)
       or (E.Raw[EF_CHILD_A] > T39_RANGE) then
    begin
      Slot := World.Spawn(EKIND_MINOR, T39_PUFF_TYPE,
                          E.Raw[EF_POS_X] - POSITION_BIAS,
                          E.Raw[EF_POS_Y] - POSITION_BIAS);
      World.SetSpawnField(Slot, EF_VARIANT, T39_PUFF_VARIANT);
      World.DestroyEntity(E, False);
    end;
  end;
end;
procedure EntityUpdate_Type44(var E: TEntity; AGameState: Integer;
                              World: TEntityWorld);
var
  Frame: Integer;
begin
  Frame := E.Raw[EF_FLAG1C];
  if (Frame < 0) or (Frame >= T44_FRAMES) then
    Frame := 0;
  E.Raw[EF_ANIM_ID] := T44_SPRITES[Frame];

  if EntityUpdateDying(E, AGameState, World) then
    Exit;

  Inc(E.Raw[EF_BLOCK_B]);
  if E.Raw[EF_BLOCK_B] > T44_TICKS then
  begin
    E.Raw[EF_BLOCK_B] := 0;
    E.Raw[EF_FLAG1C] := (E.Raw[EF_FLAG1C] + 1) mod T44_FRAMES;
  end;

  if E.Raw[EF_STATE] = 0 then
  begin
    E.Raw[EF_STATE] := 1;
    E.Raw[EF_VEL_Y] := T44_LAUNCH_VY;
  end;

  if E.Raw[EF_STATE] = 1 then
  begin
    Inc(E.Raw[EF_POS_X], E.Raw[EF_VEL_X]);
    Inc(E.Raw[EF_VEL_Y], T44_GRAVITY);
    if E.Raw[EF_VEL_Y] > T44_TERMINAL then
      E.Raw[EF_VEL_Y] := T44_TERMINAL;
    Inc(E.Raw[EF_POS_Y], E.Raw[EF_VEL_Y]);
  end;
end;
procedure EntityUpdate_Type48(var E: TEntity; AGameState: Integer;
                              World: TEntityWorld);
var
  Frame: Integer;
begin
  Frame := E.Raw[EF_FLAG1C];
  if (Frame < 0) or (Frame >= T48_FRAMES) then
    Frame := 0;
  E.Raw[EF_ANIM_ID] := T48_SPRITES[Frame];

  if EntityUpdateDying(E, AGameState, World) then
    Exit;

  if E.Raw[EF_STATE] = 0 then
  begin
    E.Raw[EF_STATE] := 1;
    E.Raw[EF_CHILD_A] := T48_BOUNCES;
  end;

  { A one-shot handoff slot. Nothing in the shipped game writes it - see the
    T48_ block - but the read is real, so it is here. }
  if E.Raw[T48_HANDOFF] <> 0 then
  begin
    E.Raw[EF_VEL_X] := E.Raw[T48_HANDOFF];
    E.Raw[T48_HANDOFF] := 0;
  end;

  Inc(E.Raw[EF_BLOCK_B]);
  if E.Raw[EF_BLOCK_B] > T48_TICKS then
  begin
    E.Raw[EF_BLOCK_B] := 0;
    E.Raw[EF_FLAG1C] := (E.Raw[EF_FLAG1C] + 1) mod T48_FRAMES;
  end;

  if World.TileAtX(E, E.Raw[EF_VEL_X], False) >= World.SolidThreshold then
    E.Raw[EF_VEL_X] := World.EdgeDistX(E, E.Raw[EF_VEL_X]);
  Inc(E.Raw[EF_POS_X], E.Raw[EF_VEL_X]);

  Inc(E.Raw[EF_VEL_Y], T48_GRAVITY);
  if E.Raw[EF_VEL_Y] > T48_TERMINAL then
    E.Raw[EF_VEL_Y] := T48_TERMINAL;

  if World.TileAtY(E, E.Raw[EF_VEL_Y], False) >= World.SolidThreshold then
  begin
    World.PlaySound(T48_BOUNCE_SOUND);
    Dec(E.Raw[EF_CHILD_A]);
    { On the second-to-last bounce. Entity_UpdateAll flickers the sprite on
      this field's parity, so what this really does is start it blinking. }
    if E.Raw[EF_CHILD_A] = 1 then
      E.Raw[EF_DEATH_TIMER] := T48_BLINK_TIMER;
    E.Raw[EF_VEL_Y] := World.EdgeDistY(E, E.Raw[EF_VEL_Y]);
    E.Raw[EF_STATE] := 2;
  end;

  Inc(E.Raw[EF_POS_Y], E.Raw[EF_VEL_Y]);

  if E.Raw[EF_STATE] = 2 then
  begin
    E.Raw[EF_STATE] := 1;
    { Each rebound is shorter than the last, and this is the only decay. }
    E.Raw[EF_VEL_Y] := (E.Raw[EF_CHILD_A] + 1) * T48_REBOUND_STEP;
  end;

  if E.Raw[EF_CHILD_A] = 0 then
    World.DestroyEntity(E, False);
end;
procedure EntityUpdate_Type55(var E: TEntity; AGameState: Integer;
                              World: TEntityWorld);
var
  Frame, D, Slot, JitterY, JitterX: Integer;
begin
  Frame := E.Raw[EF_FLAG1C];
  if E.Raw[EF_STATE] = 0 then
  begin
    if (Frame < 0) or (Frame >= T55_FLY_FRAMES) then
      Frame := 0;
    E.Raw[EF_ANIM_ID] := T55_FLY_SPRITES[Frame];
  end;
  if E.Raw[EF_STATE] = 1 then
  begin
    if (Frame < 0) or (Frame >= T55_TRAIL_FRAMES) then
      Frame := 0;
    E.Raw[EF_ANIM_ID] := T55_TRAIL_SPRITES[Frame];
  end;

  if EntityUpdateDying(E, AGameState, World) then
    Exit;

  D := World.PlayerDifficulty;
  if (D < 0) or (D > 2) then
    D := 0;

  if E.Raw[EF_STATE] = 0 then
  begin
    Inc(E.Raw[EF_BLOCK_B]);
    if E.Raw[EF_BLOCK_B] > T55_FLY_TICKS then
    begin
      E.Raw[EF_BLOCK_B] := 0;
      E.Raw[EF_FLAG1C] := (E.Raw[EF_FLAG1C] + 1) mod T55_FLY_FRAMES;
      if E.Raw[EF_FLAG1C] = 0 then
        World.PlaySound(T55_SND_LOOP);
    end;

    Inc(E.Raw[EF_SHOTS]);
    if E.Raw[EF_SHOTS] < T55_HOMING_UNTIL then
    begin
      if World.Pool <> nil then
        World.Pool.Steer(E.Raw[EF_SLOT], T55_TURN_TIMER, T55_TURN_RELOAD);
      { Times one on easy, and compounding above it. As written. }
      E.Raw[EF_VEL_X] := (D + 1) * E.Raw[EF_VEL_X];
      E.Raw[EF_VEL_Y] := (D + 1) * E.Raw[EF_VEL_Y];
    end;

    { A second counter of the same thing, one frame longer. }
    Inc(E.Raw[EF_BLOCK_B + 4]);
    if E.Raw[EF_BLOCK_B + 4] > T55_LIFETIME then
    begin
      World.DestroyEntity(E, False);
      Exit;
    end;

    Inc(E.Raw[EF_POS_X], E.Raw[EF_VEL_X]);
    Inc(E.Raw[EF_POS_Y], E.Raw[EF_VEL_Y]);

    Inc(E.Raw[EF_CHILD_B]);
    if E.Raw[EF_CHILD_B] > T55_TRAIL_EVERY then
    begin
      E.Raw[EF_CHILD_B] := 0;
      { Draw Y jitter before X to preserve random-sequence behavior. }
      JitterY := World.RandomBelow(T55_TRAIL_SPREAD) - T55_TRAIL_CENTRE;
      JitterX := World.RandomBelow(T55_TRAIL_SPREAD) - T55_TRAIL_CENTRE;
      Slot := World.Spawn(EKIND_MINOR, T55_SELF_TYPE,
                          JitterX * T55_TRAIL_SCALE
                            + E.Raw[EF_POS_X] - POSITION_BIAS,
                          JitterY * T55_TRAIL_SCALE
                            + E.Raw[EF_POS_Y] - POSITION_BIAS);
      World.SetSpawnField(Slot, EF_STATE, 1);
    end;
  end;

  if E.Raw[EF_STATE] = 1 then
  begin
    E.Raw[EF_DEPTH] := T55_TRAIL_DEPTH;
    E.Raw[EF_TIMER] := T55_TRAIL_TIMER;
    if E.Raw[EF_DEATH_TIMER] = 0 then
      E.Raw[EF_DEATH_TIMER] := T55_TRAIL_BLINK;

    Inc(E.Raw[EF_BLOCK_B]);
    if E.Raw[EF_BLOCK_B] > T55_TRAIL_TICKS then
    begin
      E.Raw[EF_BLOCK_B] := 0;
      Inc(E.Raw[EF_FLAG1C]);
      if E.Raw[EF_FLAG1C] > T55_TRAIL_FRAMES - 1 then
        World.DestroyEntity(E, False);
    end;
  end;
end;

end.
