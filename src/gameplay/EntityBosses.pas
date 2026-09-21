{ The bosses: multi-phase opponents that pace their behaviour off their own health and the difficulty setting.

  Split out of EntityHandlers, which holds the dispatch and everything
  these share. The handlers themselves are unchanged. }

unit EntityBosses;

{$MODE DELPHI}{$H+}

interface

uses
  SysUtils, Entities, GameState, SoundTable, PlayerState, Player,
  Directions, EntityHandlers;

{ The first boss is a purple lizard that spits short-range red
  projectiles. Six states, three difficulty tables, and a child entity that
  drives the transition this handler cannot make itself. }
procedure EntityUpdate_Type31_Boss_MurasakiLizard(var E: TEntity; AGameState: Integer;
                              World: TEntityWorld);
{ The second boss has six
  states, and its timings scale with its own HP as well as with the
  difficulty; see the T42_ block. }
procedure EntityUpdate_Type42_Boss_TealBlobSlammer(var E: TEntity; AGameState: Integer;
                              World: TEntityWorld);
{ A fire-lion boss that jumps and breathes fire.
  Circle, dive, dive, summon; see the T52_ block. }
procedure EntityUpdate_Type52_Boss_FireLion(var E: TEntity; AGameState: Integer;
                              World: TEntityWorld);
{ A floating magician boss that teleports around the arena,
  throwing an orb as it goes. Hover, blink out, fire, hop, blink in; see the
  T54_ block. }
procedure EntityUpdate_Type54_Boss_FloatingMagician(var E: TEntity; AGameState: Integer;
                              World: TEntityWorld);
{ A miniboss variant of type 31 with
  its own attack. Three of its states are left by a spawned child rather than
  by anything here; see the T73_ block. }
procedure EntityUpdate_Type73_Boss_MidoriLizard(var E: TEntity; AGameState: Integer;
                              World: TEntityWorld);
{ The final boss, the Hero, has six phases,
  each running a six-step script out of two tables; see the T77_ block. }
procedure EntityUpdate_Type77_Boss_Hero(var E: TEntity; AGameState: Integer;
                              World: TEntityWorld);
{ The boss's second body has no behavior: it reads the
  boss's state every frame and writes its own position and sprite. }
procedure EntityUpdate_Type78(var E: TEntity; AGameState: Integer;
                              World: TEntityWorld);

implementation

procedure EntityUpdate_Type31_Boss_MurasakiLizard(var E: TEntity; AGameState: Integer;
                              World: TEntityWorld);
var
  Frame, D, Slot: Integer;
begin
  Frame := E.Raw[EF_FLAG1C];
  if (Frame < 0) or (Frame > T31_HURT_FRAME) then
    Frame := 0;
  E.Raw[EF_ANIM_ID] := T31_SPRITES[Frame];
  D := World.PlayerDifficulty;
  if (D < 0) or (D > 2) then
    D := 0;

  if E.Raw[EF_STATE] = 0 then
  begin
    Inc(E.Raw[EF_HP], T31_HP_BONUS[D]);
    E.Raw[EF_STATE] := 1;
    Dec(E.Raw[EF_POS_X], T31_RISE);
    Dec(E.Raw[EF_POS_Y], T31_DRIFT);
  end;

  { Out of HP: forced onto the hurt frame wherever it is, and this is OUTSIDE
    the dying guard so it keeps happening. }
  if E.Raw[EF_HP] = 0 then
    E.Raw[EF_FLAG1C] := T31_HURT_FRAME;

  if EntityUpdateDying(E, AGameState, World) then
    Exit;

  if E.Raw[EF_STATE] = 1 then
  begin
    { HALF the X component and nothing on Y, so it drifts sideways in a slow
      sine rather than circling. }
    Inc(E.Raw[EF_POS_X], HalfExtent(DirVelX(E.Raw[EF_FACING])));
    E.Raw[EF_FACING] := (E.Raw[EF_FACING] + 1) mod DIR_COUNT;

    Inc(E.Raw[EF_BLOCK_B]);
    if E.Raw[EF_BLOCK_B] > T31_TICKS then
    begin
      E.Raw[EF_BLOCK_B] := 0;
      E.Raw[EF_FLAG1C] := (E.Raw[EF_FLAG1C] + 1) mod T31_FRAMES;
    end;

    { The tougher it is, the LONGER it waits - the wait is proportional to its
      own HP as well as to the difficulty. }
    Inc(E.Raw[EF_CHILD_A]);
    if E.Raw[EF_CHILD_A] > T31_WAIT[D] * E.Raw[EF_HP] + T31_WAIT_BASE then
    begin
      E.Raw[EF_STATE] := 2;
      E.Raw[EF_CHILD_A] := 0;
    end;
  end;

  if E.Raw[EF_STATE] = 2 then
  begin
    E.Raw[EF_STATE] := 3;
    E.Raw[EF_CHILD_A] := 0;
    E.Raw[EF_FLAG1C] := 0;
    Slot := World.Spawn(EKIND_MINOR, T31_MARKER_TYPE,
                        E.Raw[EF_POS_X] - World.Layer.DeltaX - POSITION_BIAS
                          - $400,
                        E.Raw[EF_POS_Y] - World.Layer.DeltaY - POSITION_BIAS
                          + $40);
    World.SetSpawnField(Slot, EF_STATE, 0);
    { The child is told which entity it belongs to, by SLOT. }
    World.SetSpawnField(Slot, EF_OWNER, E.Raw[EF_SLOT]);
  end;

  { State 3 does nothing here. The type-35 child is what advances it to 4. }

  if E.Raw[EF_STATE] = 4 then
  begin
    E.Raw[EF_FLAG1C] := T31_HURT_FRAME;
    Inc(E.Raw[EF_CHILD_A]);
    if E.Raw[EF_CHILD_A] > T31_ATTACK_LEN then
    begin
      E.Raw[EF_CHILD_A] := 0;
      E.Raw[EF_CHILD_B] := 0;
      E.Raw[EF_STATE] := 5;
    end;

    Inc(E.Raw[EF_CHILD_B]);
    if (E.Raw[EF_CHILD_B] mod T31_FIRE_EVERY = 0)
       and (E.Raw[EF_CHILD_A] > T31_RATE[D]) then
    begin
      World.PlaySound(T31_FIRE_SOUND);
      Slot := World.Spawn(EKIND_MINOR, T31_SHOT_TYPE,
                          E.Raw[EF_POS_X] - World.Layer.DeltaX - POSITION_BIAS
                            - $480,
                          E.Raw[EF_POS_Y] - World.Layer.DeltaY - POSITION_BIAS
                            + $80);
      { The shot's heading is block A[1], not the parent's facing. }
      World.SetSpawnField(Slot, EF_FACING, E.Raw[EF_BLOCK_A + 1]);
    end;
  end;

  if E.Raw[EF_STATE] = 5 then
  begin
    E.Raw[EF_STATE] := 6;
    E.Raw[EF_FLAG1C] := 0;
    Slot := World.Spawn(EKIND_MINOR, T31_MARKER_TYPE,
                        E.Raw[EF_POS_X] - World.Layer.DeltaX - POSITION_BIAS
                          - $400,
                        E.Raw[EF_POS_Y] - World.Layer.DeltaY - POSITION_BIAS
                          + $40);
    World.SetSpawnField(Slot, EF_STATE, 1);
    World.SetSpawnField(Slot, EF_OWNER, E.Raw[EF_SLOT]);
  end;
end;
procedure EntityUpdate_Type42_Boss_TealBlobSlammer(var E: TEntity; AGameState: Integer;
                              World: TEntityWorld);
var
  Frame, D, I, N, Slot: Integer;
begin
  Frame := E.Raw[EF_FLAG1C];
  if (Frame < 0) or (Frame > High(T42_SPRITES)) then
    Frame := 0;
  E.Raw[EF_ANIM_ID] := T42_SPRITES[Frame];

  D := World.PlayerDifficulty;
  if (D < 0) or (D > 2) then
    D := 0;

  if E.Raw[EF_STATE] = 0 then
  begin
    Inc(E.Raw[EF_HP], T42_HP_BONUS[D]);
    E.Raw[EF_STATE] := 1;
    Inc(E.Raw[EF_POS_Y], T42_DROP);
    E.Raw[EF_VEL_X] := T42_SPEED;
  end;

  if EntityUpdateDying(E, AGameState, World) then
    Exit;

  { Free-running, and every state reset clears it. }
  Inc(E.Raw[EF_CHILD_B]);

  { States 1 and 5 share the slow four-frame loop. }
  if (E.Raw[EF_STATE] = 1) or (E.Raw[EF_STATE] = 5) then
  begin
    Inc(E.Raw[EF_BLOCK_B]);
    if E.Raw[EF_BLOCK_B] > T42_TICKS then
    begin
      E.Raw[EF_BLOCK_B] := 0;
      E.Raw[EF_FLAG1C] := (E.Raw[EF_FLAG1C] + 1) mod T42_FRAMES;
    end;
  end;

  if E.Raw[EF_STATE] = 1 then
  begin
    if World.TileAtX(E, E.Raw[EF_VEL_X], False) >= World.SolidThreshold then
      E.Raw[EF_VEL_X] := -E.Raw[EF_VEL_X];

    { The bob: one heading step every four frames, and the Y component of that
      heading becomes the vertical velocity. }
    Dec(E.Raw[EF_CHILD_A]);
    if E.Raw[EF_CHILD_A] < 1 then
    begin
      E.Raw[EF_CHILD_A] := T42_BOB_EVERY;
      E.Raw[EF_VEL_Y] := DirVelY(E.Raw[EF_FACING]);
      E.Raw[EF_FACING] := (E.Raw[EF_FACING] + 1) mod DIR_COUNT;
    end;
    Inc(E.Raw[EF_POS_X], E.Raw[EF_VEL_X]);
    Inc(E.Raw[EF_POS_Y], E.Raw[EF_VEL_Y]);

    { Scales with its OWN HP, so a damaged boss patrols for less time. }
    if E.Raw[EF_CHILD_B] > E.Raw[EF_HP] * 10 + T42_PATROL_BASE then
    begin
      World.PlaySound(T42_PATROL_SOUND);
      E.Raw[EF_STATE] := 2;
      E.Raw[EF_BLOCK_B] := 0;
      E.Raw[EF_CHILD_A] := 0;
      E.Raw[EF_CHILD_B] := 0;
      E.Raw[EF_FACING] := 0;
    end;
  end;

  if E.Raw[EF_STATE] = 2 then
  begin
    { A heading step EVERY frame now, so the climb tightens. }
    Dec(E.Raw[EF_CHILD_A]);
    if E.Raw[EF_CHILD_A] < 1 then
    begin
      E.Raw[EF_CHILD_A] := 1;
      E.Raw[EF_FACING] := (E.Raw[EF_FACING] + 1) mod DIR_COUNT;
      E.Raw[EF_VEL_Y] := DirVelY(E.Raw[EF_FACING]);
    end;
    Inc(E.Raw[EF_POS_Y], E.Raw[EF_VEL_Y]);

    Inc(E.Raw[EF_BLOCK_B]);
    if E.Raw[EF_BLOCK_B] > 2 then
    begin
      E.Raw[EF_BLOCK_B] := 0;
      E.Raw[EF_FLAG1C] := (E.Raw[EF_FLAG1C] + 1) mod T42_FRAMES;
    end;

    if E.Raw[EF_CHILD_B] > T42_RISE_LEN[D] then
    begin
      E.Raw[EF_STATE] := 3;
      E.Raw[EF_BLOCK_B] := 0;
      E.Raw[EF_CHILD_A] := 0;
      E.Raw[EF_CHILD_B] := 0;
      E.Raw[EF_VEL_Y] := T42_RISE_VY;
    end;
  end;

  if E.Raw[EF_STATE] = 3 then
  begin
    E.Raw[EF_FLAG1C] := T42_FALL_FRAME;
    Inc(E.Raw[EF_VEL_Y], T42_GRAVITY);
    if E.Raw[EF_VEL_Y] > T42_TERMINAL then
      E.Raw[EF_VEL_Y] := T42_TERMINAL;

    if World.TileAtY(E, E.Raw[EF_VEL_Y], False) >= World.SolidThreshold then
    begin
      World.PlaySound(T42_LAND_SOUND);
      E.Raw[EF_VEL_Y] := World.EdgeDistY(E, E.Raw[EF_VEL_Y]);
      E.Raw[EF_STATE] := 4;
      E.Raw[EF_BLOCK_B] := 0;
      E.Raw[EF_CHILD_A] := 0;
      E.Raw[EF_CHILD_B] := 0;
      E.Raw[EF_FLAG1C] := T42_LAND_FRAME;

      { The fan. Count + 1 shots, each off the shared angle table. }
      N := T42_SHOTS[D];
      if N >= 0 then
        for I := 0 to N do
        begin
          Slot := World.Spawn(EKIND_MINOR, T42_SHOT_TYPE,
                              E.Raw[EF_POS_X] - POSITION_BIAS
                                - World.Layer.DeltaX,
                              E.Raw[EF_POS_Y] - World.Layer.DeltaY
                                - POSITION_BIAS + T42_SHOT_LIFT);
          if I <= High(T42_ANGLES) then
            World.SetSpawnField(Slot, EF_VEL_X,
                                T42_ANGLES[I] shl T42_ANGLE_SHIFT);
        end;
    end;

    Inc(E.Raw[EF_POS_Y], E.Raw[EF_VEL_Y]);
  end;

  if E.Raw[EF_STATE] = 4 then
  begin
    { Re-snaps to the floor every frame it is down. }
    if World.TileAtY(E, E.Raw[EF_VEL_Y], False) >= World.SolidThreshold then
    begin
      World.PlaySound(T42_LAND_SOUND);
      E.Raw[EF_VEL_Y] := World.EdgeDistY(E, E.Raw[EF_VEL_Y]);
    end;

    Inc(E.Raw[EF_BLOCK_B]);
    if E.Raw[EF_BLOCK_B] > T42_TICKS then
    begin
      E.Raw[EF_BLOCK_B] := 0;
      Inc(E.Raw[EF_FLAG1C]);
      if E.Raw[EF_FLAG1C] > T42_LAND_LAST then
        E.Raw[EF_FLAG1C] := T42_LAND_FRAME;
    end;

    if E.Raw[EF_CHILD_B] >
       (E.Raw[EF_HP] div 10) * T42_RECOVER[D] + T42_RECOVER_BASE then
    begin
      E.Raw[EF_STATE] := 3;
      E.Raw[EF_BLOCK_B] := 0;
      E.Raw[EF_CHILD_A] := 0;
      E.Raw[EF_CHILD_B] := 0;
      E.Raw[EF_FLAG1C] := 0;
      E.Raw[EF_VEL_Y] := T42_RETREAT_VY;
      { Every third recovery it retreats instead of attacking again. }
      Inc(E.Raw[EF_SHOTS]);
      if E.Raw[EF_SHOTS] > T42_RECOVERIES then
      begin
        E.Raw[EF_SHOTS] := 0;
        E.Raw[EF_STATE] := 5;
      end;
    end;
  end;

  if E.Raw[EF_STATE] = 5 then
  begin
    Dec(E.Raw[EF_POS_Y], T42_RETREAT_STEP);
    if E.Raw[EF_CHILD_B] > T42_RETREAT_LEN then
    begin
      E.Raw[EF_STATE] := 1;
      E.Raw[EF_BLOCK_B] := 0;
      E.Raw[EF_CHILD_A] := 0;
      E.Raw[EF_CHILD_B] := 0;
      E.Raw[EF_FACING] := 0;
    end;
  end;
end;
procedure EntityUpdate_Type52_Boss_FireLion(var E: TEntity; AGameState: Integer;
                              World: TEntityWorld);
var
  Frame, D, Sign, Slot, PlayerX: Integer;
begin
  Frame := E.Raw[EF_FLAG1C];
  if (Frame < 0) or (Frame > High(T52_SPRITES[0])) then
    Frame := 0;
  { By the SIGN, two ifs and no else, so a stalled one keeps its sprite. }
  if E.Raw[EF_VEL_X] < 0 then
    E.Raw[EF_ANIM_ID] := T52_SPRITES[0][Frame];
  if E.Raw[EF_VEL_X] > 0 then
    E.Raw[EF_ANIM_ID] := T52_SPRITES[1][Frame];

  if EntityUpdateDying(E, AGameState, World) then
    Exit;
  if World.Pool = nil then
    Exit;

  D := World.PlayerDifficulty;
  if (D < 0) or (D > 2) then
    D := 0;
  PlayerX := World.Pool.Field(SLOT_SINGLE_FIRST, EF_POS_X);

  if E.Raw[EF_STATE] = 0 then
  begin
    { Negative on every difficulty - the type table holds the hard figure. }
    Inc(E.Raw[EF_HP], T52_HP[D]);
    E.Raw[EF_STATE] := 1;
    Inc(E.Raw[EF_POS_Y], T52_ENTRY_DROP);
    E.Raw[EF_VEL_X] := T52_ENTRY_VX;
  end;

  if E.Raw[EF_STATE] = 1 then
  begin
    Dec(E.Raw[EF_BLOCK_B]);
    if E.Raw[EF_BLOCK_B] < 1 then
    begin
      E.Raw[EF_BLOCK_B] := T52_TICKS;
      E.Raw[EF_FLAG1C] := (E.Raw[EF_FLAG1C] + 1) mod T52_FRAMES;
    end;

    Inc(E.Raw[EF_CHILD_A]);
    { Paced off its OWN health: the more you have hurt it, the sooner. }
    if (E.Raw[EF_HP] div T52_HP_PACE_DIV) * T52_HP_PACE_MUL + T52_TIMING[D]
       < E.Raw[EF_CHILD_A] then
    begin
      E.Raw[EF_INSET_PCT_Y] := T52_INSET_CIRCLE;
      E.Raw[EF_STATE] := 2;
      E.Raw[EF_BLOCK_B] := 0;
      E.Raw[EF_CHILD_A] := 0;
      Inc(E.Raw[EF_CHILD_B]);
      if E.Raw[EF_CHILD_B] = T52_SUMMON_BEAT then
        World.PlaySound(T52_SND_SUMMON);
      { Only HARD re-aims. }
      if D = 2 then
        E.Raw[EF_VEL_X] := Compare(E.Raw[EF_POS_X], PlayerX) shl 7;
      if E.Raw[EF_VEL_X] = 0 then
        E.Raw[EF_VEL_X] := T52_CHARGE_VX;
    end;
  end;

  if E.Raw[EF_STATE] = 2 then
  begin
    Inc(E.Raw[EF_POS_X], DirVelX(E.Raw[EF_FACING]));
    E.Raw[EF_FACING] := (E.Raw[EF_FACING] + T52_TURN_STEP) mod DIR_COUNT;
    E.Raw[EF_FLAG1C] := T52_CIRCLE_FRAME;

    if E.Raw[EF_CHILD_B] < T52_SUMMON_BEAT then
    begin
      Inc(E.Raw[EF_CHILD_A]);
      if E.Raw[EF_CHILD_A] > T52_CIRCLE_TICKS then
      begin
        E.Raw[EF_INSET_PCT_Y] := T52_INSET_DIVE;
        E.Raw[EF_STATE] := 3;
        E.Raw[EF_BLOCK_B] := 0;
        E.Raw[EF_CHILD_A] := 0;
        E.Raw[EF_VEL_Y] := T52_DIVE_VY;
      end;
    end;

    if E.Raw[EF_CHILD_B] = T52_SUMMON_BEAT then
    begin
      Inc(E.Raw[EF_CHILD_A]);
      if E.Raw[EF_CHILD_A] > T52_TIMING[D] then
      begin
        E.Raw[EF_CHILD_A] := 0;
        Inc(E.Raw[EF_SHOTS]);
        if E.Raw[EF_SHOTS] <= T52_COUNT[D] - 1 then
        begin
          World.PlaySound(T52_SND_SPAWN);
          Sign := Compare(0, E.Raw[EF_VEL_X]);
          Slot := World.Spawn(EKIND_MINOR, T52_MINION_TYPE,
                              Sign * T52_MINION_AHEAD
                                + E.Raw[EF_POS_X] - POSITION_BIAS
                                - World.Layer.DeltaX,
                              E.Raw[EF_POS_Y] - POSITION_BIAS
                                + T52_MINION_BELOW
                                - World.Layer.DeltaY);
          { DirVelX(0) is 32, so the chargers run at 64, 96 or 96. }
          World.SetSpawnField(Slot, EF_VEL_X,
                              Compare(0, E.Raw[EF_VEL_X])
                                * DirVelX(0) * T52_SPEED[D]);
        end;
      end;

      if T52_COUNT[D] <= E.Raw[EF_SHOTS] then
      begin
        E.Raw[EF_STATE] := 1;
        E.Raw[EF_BLOCK_B] := 0;
        E.Raw[EF_CHILD_A] := 0;
        E.Raw[EF_CHILD_B] := 0;
        E.Raw[EF_SHOTS] := 0;
        E.Raw[EF_FLAG1C] := 0;
      end;
    end;
  end;

  if E.Raw[EF_STATE] = 3 then
  begin
    E.Raw[EF_FLAG1C] := T52_DIVE_FRAME;
    if World.TileAtX(E, E.Raw[EF_VEL_X], False) >= World.SolidThreshold then
      E.Raw[EF_VEL_X] := 0;
    Inc(E.Raw[EF_POS_X], E.Raw[EF_VEL_X]);

    Inc(E.Raw[EF_VEL_Y], T52_GRAVITY);
    if E.Raw[EF_VEL_Y] > T52_LAND_VY then
    begin
      World.PlaySound(T52_SND_LAND);
      E.Raw[EF_STATE] := 1;
      E.Raw[EF_BLOCK_B] := 0;
      E.Raw[EF_CHILD_A] := 0;
      E.Raw[EF_FLAG1C] := 0;
      E.Raw[EF_VEL_X] := Compare(E.Raw[EF_POS_X], PlayerX) shl 7;
      if E.Raw[EF_VEL_X] = 0 then
        E.Raw[EF_VEL_X] := T52_CHARGE_VX;
      E.Raw[EF_VEL_Y] := 0;
    end;
    Inc(E.Raw[EF_POS_Y], E.Raw[EF_VEL_Y]);
  end;
end;
procedure EntityUpdate_Type54_Boss_FloatingMagician(var E: TEntity; AGameState: Integer;
                              World: TEntityWorld);
var
  Frame, D, Hop: Integer;
begin
  Frame := E.Raw[EF_FLAG1C];
  if (Frame < 0) or (Frame >= T54_FRAMES) then
    Frame := 0;
  E.Raw[EF_ANIM_ID] := T54_SPRITES[Frame];

  if EntityUpdateDying(E, AGameState, World) then
    Exit;

  D := World.PlayerDifficulty;
  if (D < 0) or (D > 2) then
    D := 0;

  Inc(E.Raw[EF_BLOCK_B]);
  if E.Raw[EF_BLOCK_B] > T54_TICKS then
  begin
    E.Raw[EF_BLOCK_B] := 0;
    E.Raw[EF_FLAG1C] := (E.Raw[EF_FLAG1C] + 1) mod T54_FRAMES;
  end;

  { The heading is an oscillator, not a direction of travel. }
  Inc(E.Raw[EF_POS_Y], DirVelY(E.Raw[EF_FACING]));
  E.Raw[EF_FACING] := (E.Raw[EF_FACING] + 1) mod DIR_COUNT;

  Inc(E.Raw[EF_CHILD_A]);

  if E.Raw[EF_STATE] = 0 then
  begin
    E.Raw[EF_STATE] := 1;
    Inc(E.Raw[EF_HP], T54_HP[D]);
  end;

  if E.Raw[EF_STATE] = 1 then
    { Paced off its OWN health, the same way type 52 is. }
    if (E.Raw[EF_HP] div T54_HP_PACE_DIV) * T54_HP_PACE_MUL + T54_HP_PACE_ADD
       < E.Raw[EF_CHILD_A] then
    begin
      World.PlaySound(T54_SND_BLINK);
      E.Raw[EF_STATE] := 2;
      E.Raw[EF_CHILD_A] := 0;
      E.Raw[EF_DEATH_TIMER] := T54_BLINK;
      E.Raw[EF_TIMER] := T54_BLINK;
    end;

  if (E.Raw[EF_STATE] = 2) and (E.Raw[EF_DEATH_TIMER] = 0) then
  begin
    E.Raw[EF_STATE] := 3;
    E.Raw[EF_CHILD_A] := 0;
    World.Spawn(EKIND_MINOR, T54_SHOT_TYPE,
                E.Raw[EF_POS_X] - POSITION_BIAS - World.Layer.DeltaX,
                E.Raw[EF_POS_Y] - POSITION_BIAS - World.Layer.DeltaY);
  end;

  if E.Raw[EF_STATE] = 3 then
  begin
    E.Raw[EF_DEATH_TIMER] := 1;
    E.Raw[EF_TIMER] := 2;
    if E.Raw[EF_CHILD_A] > T54_HOLD then
    begin
      World.PlaySound(T54_SND_BLINK);
      E.Raw[EF_STATE] := 4;
      E.Raw[EF_CHILD_A] := 0;
      E.Raw[EF_DEATH_TIMER] := T54_BLINK;
      E.Raw[EF_TIMER] := T54_BLINK;

      Hop := E.Raw[EF_CHILD_B];
      if (Hop < 0) or (Hop >= T54_HOPS) then
        Hop := 0;
      Inc(E.Raw[EF_POS_X], T54_HOP[Hop][0] * T54_HOP_SCALE);
      Inc(E.Raw[EF_POS_Y], T54_HOP[Hop][1] * T54_HOP_SCALE);
      Inc(E.Raw[EF_CHILD_B]);
      if E.Raw[EF_CHILD_B] > T54_HOPS - 1 then
        E.Raw[EF_CHILD_B] := 0;
    end;
  end;

  if (E.Raw[EF_STATE] = 4) and (E.Raw[EF_DEATH_TIMER] = 0) then
  begin
    E.Raw[EF_STATE] := 1;
    E.Raw[EF_CHILD_A] := 0;
  end;
end;
procedure EntityUpdate_Type73_Boss_MidoriLizard(var E: TEntity; AGameState: Integer;
                              World: TEntityWorld);
var
  Frame, D, Slot, Hp: Integer;

  function SpawnChild(TypeId, Down: Integer): Integer;
  begin
    Result := World.Spawn(EKIND_MINOR, TypeId,
                          E.Raw[EF_POS_X] - POSITION_BIAS
                            - World.Layer.DeltaX - T73_CHILD_LEFT,
                          E.Raw[EF_POS_Y] - POSITION_BIAS
                            - World.Layer.DeltaY + Down);
    World.SetSpawnField(Result, EF_OWNER, E.Raw[EF_SLOT]);
  end;

begin
  Frame := E.Raw[EF_FLAG1C];
  if (Frame < 0) or (Frame > High(T73_SPRITES)) then
    Frame := 0;
  E.Raw[EF_ANIM_ID] := T73_SPRITES[Frame];

  if E.Raw[EF_STATE] = 0 then
  begin
    E.Raw[EF_STATE] := 1;
    Inc(E.Raw[EF_POS_X], T73_ENTRY_SHIFT);
    Inc(E.Raw[EF_POS_Y], T73_ENTRY_SHIFT);
  end;

  { BEFORE the dying check, so the dead pose shows on the same frame. }
  if E.Raw[EF_HP] = 0 then
    E.Raw[EF_FLAG1C] := T73_DEAD_FRAME;

  if EntityUpdateDying(E, AGameState, World) then
    Exit;

  D := World.PlayerDifficulty;
  if (D < 0) or (D > 2) then
    D := 0;

  if E.Raw[EF_STATE] = 1 then
  begin
    { Half of the heading's X component, and one step a frame - a sway. }
    Inc(E.Raw[EF_POS_X], HalfExtent(DirVelX(E.Raw[EF_FACING])));
    E.Raw[EF_FACING] := (E.Raw[EF_FACING] + 1) mod DIR_COUNT;

    Inc(E.Raw[EF_BLOCK_B]);
    if E.Raw[EF_BLOCK_B] > T73_TICKS then
    begin
      E.Raw[EF_BLOCK_B] := 0;
      E.Raw[EF_FLAG1C] := (E.Raw[EF_FLAG1C] + 1) mod T73_FRAMES;
    end;

    Inc(E.Raw[EF_CHILD_A]);
    Hp := E.Raw[EF_HP] div T73_HP_PACE_DIV;
    { Paced off its own health, like types 52 and 54. }
    if T73_WAIT[D] * Hp + T73_HP_PACE_ADD < E.Raw[EF_CHILD_A] then
    begin
      E.Raw[EF_STATE] := 2;
      E.Raw[EF_CHILD_A] := 0;
    end;
  end;

  if E.Raw[EF_STATE] = 2 then
  begin
    E.Raw[EF_STATE] := 3;
    E.Raw[EF_CHILD_A] := 0;
    E.Raw[EF_FLAG1C] := 0;
    Slot := SpawnChild(T73_CHILD_ONE, T73_CHILD_DOWN_A);
    World.SetSpawnField(Slot, EF_STATE, 0);
  end;

  { State 3 is left by the type 75. }

  if E.Raw[EF_STATE] = 4 then
  begin
    E.Raw[EF_FLAG1C] := T73_DEAD_FRAME;
    Inc(E.Raw[EF_CHILD_A]);
    if T73_CHARGE[D] < E.Raw[EF_CHILD_A] then
    begin
      E.Raw[EF_STATE] := 5;
      E.Raw[EF_CHILD_A] := 0;
      World.PlaySound(T73_SND_CHARGE);
      SpawnChild(T73_CHILD_TWO, T73_CHILD_DOWN_B);
    end;
  end;

  { State 5 is left by the type 74 - see EntityUpdate_Type74. }

  if E.Raw[EF_STATE] = 6 then
  begin
    Inc(E.Raw[EF_CHILD_A]);
    if E.Raw[EF_CHILD_A] > T73_RECOVER then
    begin
      E.Raw[EF_STATE] := 7;
      E.Raw[EF_CHILD_A] := 0;
    end;
  end;

  if E.Raw[EF_STATE] = 7 then
  begin
    E.Raw[EF_STATE] := 8;
    E.Raw[EF_FLAG1C] := 0;
    Slot := SpawnChild(T73_CHILD_THREE, T73_CHILD_DOWN_A);
    World.SetSpawnField(Slot, EF_STATE, 1);
  end;

  { And state 8 is left by the type 35. }
end;
procedure EntityUpdate_Type77_Boss_Hero(var E: TEntity; AGameState: Integer;
                              World: TEntityWorld);
var
  Frame, Dir, Phase, D, Slot, I, N, Act, Speed: Integer;
  PlayerX: Integer;

  function Clamp(V, Hi: Integer): Integer;
  begin
    Result := V;
    if (Result < 0) or (Result > Hi) then
      Result := 0;
  end;

  { Every effect this boss makes is a type 79 carrying its slot. }
  function Part(Variant, DX, DY: Integer): Integer;
  begin
    Result := World.Spawn(EKIND_MINOR, T77_PART_B,
                          E.Raw[EF_POS_X] - POSITION_BIAS
                            - World.Layer.DeltaX + DX,
                          E.Raw[EF_POS_Y] - POSITION_BIAS
                            - World.Layer.DeltaY + DY);
    World.SetSpawnField(Result, EF_OWNER, E.Raw[EF_SLOT]);
    if Variant >= 0 then
      World.SetSpawnField(Result, EF_VARIANT, Variant);
  end;

  procedure BackToIdle;
  begin
    E.Raw[EF_STATE] := 1;
    E.Raw[EF_BLOCK_B] := 0;
    E.Raw[EF_FLAG1C] := 0;
  end;

begin
  Frame := E.Raw[EF_FLAG1C];
  Dir := Ord(E.Raw[EF_VEL_X] > 0);
  Phase := E.Raw[EF_BLOCK_A + 1];

  if Phase < 2 then
    E.Raw[EF_ANIM_ID] := T77_P01_SPRITES[Dir][Clamp(Frame, 9)];
  if Phase = 2 then
    E.Raw[EF_ANIM_ID] := T77_P2_SPRITES[Dir][Clamp(Frame, 13)];
  if Phase = 3 then
    E.Raw[EF_ANIM_ID] := T77_P3_SPRITES[Dir][Clamp(Frame, 12)];
  if Phase = 4 then
    E.Raw[EF_ANIM_ID] := T77_P4_SPRITES[Dir][Clamp(Frame, 5)];
  if Phase = 5 then
    E.Raw[EF_ANIM_ID] := T77_P5_SPRITES[Dir][Clamp(Frame, 7)];
  if Phase = 6 then
    E.Raw[EF_ANIM_ID] := T77_P6_SPRITES[Dir];

  if EntityUpdateDying(E, AGameState, World) then
    Exit;
  if World.Pool = nil then
    Exit;

  D := World.PlayerDifficulty;
  if (D < 0) or (D > 2) then
    D := 0;
  PlayerX := World.Pool.Field(SLOT_SINGLE_FIRST, EF_POS_X);

  { --- the phase gate, before anything else --- }
  if (Phase >= 0) and (Phase < T77_PHASES)
     and (E.Raw[EF_HP] < T77_HP[D][Phase]) then
  begin
    { Phases 0 and 4 pass silently; the other four puff. }
    if (Phase <> 0) and (Phase <> 4) then
    begin
      Slot := World.Spawn(EKIND_MINOR, EMITTER_TYPE,
                          E.Raw[EF_POS_X] - POSITION_BIAS,
                          E.Raw[EF_POS_Y] - POSITION_BIAS - T77_PUFF_LIFT);
      World.SetSpawnField(Slot, EF_BLOCK_A + 1, 8);
      World.SetSpawnField(Slot, EF_BLOCK_A + 2, 2);
      World.SetSpawnField(Slot, EF_BLOCK_A + 3, 1);
      World.SetSpawnField(Slot, EF_BLOCK_A + 4, 2);
    end;
    E.Raw[EF_STATE] := 1;
    E.Raw[EF_BLOCK_B] := 0;
    E.Raw[EF_FLAG1C] := 0;
    Inc(E.Raw[EF_BLOCK_A + 1]);
    E.Raw[EF_CHILD_B] := 0;
    Phase := E.Raw[EF_BLOCK_A + 1];
    if Phase > T77_PHASES - 1 then
    begin
      E.Raw[EF_HP] := 0;
      Exit;
    end;
  end;

  if E.Raw[EF_STATE] = 0 then
  begin
    E.Raw[EF_STATE] := 1;
    E.Raw[EF_VEL_X] := T77_ENTRY_VX;
    Slot := World.Spawn(EKIND_MINOR, T77_PART_A,
                        E.Raw[EF_POS_X] - POSITION_BIAS - World.Layer.DeltaX,
                        E.Raw[EF_POS_Y] - POSITION_BIAS - World.Layer.DeltaY);
    World.SetSpawnField(Slot, EF_OWNER, E.Raw[EF_SLOT]);
    Part(-1, 0, 0);
  end;

  { --- state 1: run the script --- }
  if E.Raw[EF_STATE] = 1 then
  begin
    Inc(E.Raw[EF_BLOCK_B]);
    if E.Raw[EF_BLOCK_B] > T77_IDLE_TICKS then
    begin
      E.Raw[EF_BLOCK_B] := 0;
      E.Raw[EF_FLAG1C] := (E.Raw[EF_FLAG1C] + 1) mod 2;
    end;

    Inc(E.Raw[EF_CHILD_A]);
    N := Clamp(E.Raw[EF_CHILD_B], T77_STEPS - 1);
    if T77_STEP[Clamp(Phase, T77_PHASES - 1)][N] div T77_DIVISOR[D]
       < E.Raw[EF_CHILD_A] then
    begin
      E.Raw[EF_CHILD_A] := 0;
      Act := T77_ACTION[Clamp(Phase, T77_PHASES - 1)][N];

      if Act = T77_ACT_FACE then
      begin
        E.Raw[EF_STATE] := 2;
        E.Raw[EF_BLOCK_B] := 0;
        E.Raw[EF_FLAG1C] := 1;
      end;
      if Act = T77_ACT_DASH then
      begin
        E.Raw[EF_STATE] := 3;
        E.Raw[EF_BLOCK_B] := 0;
        E.Raw[EF_FLAG1C] := 2;
      end;
      if Act = T77_ACT_SLAM then
      begin
        E.Raw[EF_STATE] := 4;
        E.Raw[EF_BLOCK_B] := 0;
        E.Raw[EF_FLAG1C] := 6;
      end;
      if Act = T77_ACT_SHOT then
      begin
        E.Raw[EF_STATE] := 5;
        E.Raw[EF_BLOCK_B] := 0;
        E.Raw[EF_FLAG1C] := 10;
        World.PlaySound(T77_SND_ROAR);
      end;
      if Act = T77_ACT_RECOIL then
      begin
        E.Raw[EF_STATE] := 6;
        E.Raw[EF_BLOCK_B] := 0;
        E.Raw[EF_FLAG1C] := 13;
        E.Raw[EF_VEL_X] := -E.Raw[EF_VEL_X];
      end;
      if Act = T77_ACT_DASH_BACK then
      begin
        { the same state as action 3, entered facing the other way }
        E.Raw[EF_STATE] := 3;
        E.Raw[EF_BLOCK_B] := 0;
        E.Raw[EF_FLAG1C] := 2;
        E.Raw[EF_VEL_X] := -E.Raw[EF_VEL_X];
      end;
      if Act = T77_ACT_POSE then
      begin
        E.Raw[EF_STATE] := 8;
        E.Raw[EF_BLOCK_B] := 0;
        E.Raw[EF_SHOTS] := $1E;
        E.Raw[EF_FLAG1C] := 6;
        World.PlaySound(T77_SND_ROAR);
        Part(5, -$100, -$400);
      end;

      Inc(E.Raw[EF_CHILD_B]);
      if E.Raw[EF_CHILD_B] > T77_STEPS - 1 then
        E.Raw[EF_CHILD_B] := 0;
    end;
  end;

  { --- state 2: face the player and hold --- }
  if E.Raw[EF_STATE] = 2 then
  begin
    { CompareNZ, not Compare - a zero would leave it with no facing. }
    E.Raw[EF_VEL_X] := CompareNZ(E.Raw[EF_POS_X], PlayerX) * T77_TURN_SPEED;
    Inc(E.Raw[EF_BLOCK_B]);
    if E.Raw[EF_BLOCK_B] > T77_TURN_HOLD then
      BackToIdle;
  end;

  { --- states 3 and 7: the dash, trailing as it goes --- }
  if (E.Raw[EF_STATE] = 3) or (E.Raw[EF_STATE] = 7) then
  begin
    Inc(E.Raw[EF_BLOCK_B]);
    { The trail thins as it slows: the interval is 8 - 2 * its speed in
      pixels, so a fast dash drops one almost every frame. }
    Speed := Abs(E.Raw[EF_VEL_X]);
    if Speed < 0 then
      Inc(Speed, 31);
    if (Speed shr POSITION_SHIFT) * -2 + 8 < E.Raw[EF_BLOCK_B] then
    begin
      Part(4, E.Raw[EF_VEL_X] * -4, $100);
      E.Raw[EF_BLOCK_B] := 0;
      Inc(E.Raw[EF_FLAG1C]);
      if E.Raw[EF_FLAG1C] > 5 then
        E.Raw[EF_FLAG1C] := 2;
    end;

    ApproachZero(E.Raw[EF_VEL_X], T77_DASH_FRICTION);
    if World.TileAtX(E, E.Raw[EF_VEL_X], False) >= World.SolidThreshold then
      E.Raw[EF_VEL_X] := -E.Raw[EF_VEL_X];
    Inc(E.Raw[EF_POS_X], E.Raw[EF_VEL_X]);

    if E.Raw[EF_VEL_X] = 0 then
    begin
      BackToIdle;
      { and it comes to rest facing you, at speed 1 }
      E.Raw[EF_VEL_X] := CompareNZ(E.Raw[EF_POS_X], PlayerX);
    end;
  end;

  { --- state 4: the ground slam --- }
  if E.Raw[EF_STATE] = 4 then
  begin
    Inc(E.Raw[EF_BLOCK_B]);
    if T77_SLAM[Clamp(E.Raw[EF_FLAG1C] - 6, 3)] div T77_SLAM_DIV[D]
       < E.Raw[EF_BLOCK_B] then
    begin
      E.Raw[EF_BLOCK_B] := 0;
      Inc(E.Raw[EF_FLAG1C]);

      if (E.Raw[EF_FLAG1C] = 7) or (E.Raw[EF_FLAG1C] = 9) then
        World.PlaySound(T77_SND_SLAM);

      if E.Raw[EF_FLAG1C] = 9 then
      begin
        Part(1, 0, 0);
        N := T77_BURST[D];
        if N >= 0 then
          for I := 0 to N do
          begin
            Slot := World.Spawn(EKIND_MINOR, T77_BURST_TYPE,
                                CompareNZ(0, E.Raw[EF_VEL_X]) * $1000
                                  + E.Raw[EF_POS_X] - POSITION_BIAS
                                  - World.Layer.DeltaX,
                                E.Raw[EF_POS_Y] - POSITION_BIAS
                                  - World.Layer.DeltaY + $200);
            World.SetSpawnField(Slot, EF_VEL_X,
                                T77_BURST_VX[I] shl T77_BURST_SHIFT);
            World.SetSpawnField(Slot, EF_VEL_Y,
                                T77_BURST_VY[I] shl T77_BURST_SHIFT);
          end;
        { The only place in the game that starts the screen shake. }
        ScreenShakeOn := True;
        ScreenShakeTimer := T77_SHAKE_FRAMES;
      end;

      if E.Raw[EF_FLAG1C] = 8 then
        Part(2, 0, 0);

      if E.Raw[EF_FLAG1C] > 9 then
        BackToIdle;
    end;
  end;

  { --- state 5: the lob --- }
  if E.Raw[EF_STATE] = 5 then
  begin
    Inc(E.Raw[EF_BLOCK_B]);
    if T77_SHOT[Clamp(E.Raw[EF_FLAG1C] - 10, 2)] div T77_SHOT_DIV[D]
       < E.Raw[EF_BLOCK_B] then
    begin
      E.Raw[EF_BLOCK_B] := 0;
      if E.Raw[EF_FLAG1C] = $B then
      begin
        World.PlaySound(T77_SND_LOB);
        Part(1, 0, 0);
        Slot := Part(3, CompareNZ(0, E.Raw[EF_VEL_X]) * $800, -$400);
        World.SetSpawnField(Slot, EF_VEL_X,
                            CompareNZ(0, E.Raw[EF_VEL_X]) * $20
                            * T77_LOB_SPEED[D]);
      end;
      Inc(E.Raw[EF_FLAG1C]);
      if E.Raw[EF_FLAG1C] > $C then
        BackToIdle;
    end;
  end;

  { --- state 6: the recoil, action 3's move at twice the friction --- }
  if E.Raw[EF_STATE] = 6 then
  begin
    Inc(E.Raw[EF_BLOCK_B]);
    if E.Raw[EF_BLOCK_B] > 2 then
    begin
      E.Raw[EF_BLOCK_B] := 0;
      Part(4, E.Raw[EF_VEL_X] * -8, $100);
    end;

    ApproachZero(E.Raw[EF_VEL_X], T77_RECOIL_FRICTION);
    if World.TileAtX(E, E.Raw[EF_VEL_X], False) >= World.SolidThreshold then
      E.Raw[EF_VEL_X] := -E.Raw[EF_VEL_X];
    Inc(E.Raw[EF_POS_X], E.Raw[EF_VEL_X]);

    if E.Raw[EF_VEL_X] = 0 then
    begin
      BackToIdle;
      E.Raw[EF_VEL_X] := CompareNZ(E.Raw[EF_POS_X], PlayerX);
    end;
  end;

  { --- state 8: a two-frame hold, and nothing leaves it --- }
  if E.Raw[EF_STATE] = 8 then
  begin
    Inc(E.Raw[EF_BLOCK_B]);
    if E.Raw[EF_BLOCK_B] > T77_HELD_TICKS then
    begin
      E.Raw[EF_BLOCK_B] := 0;
      Inc(E.Raw[EF_FLAG1C]);
      if E.Raw[EF_FLAG1C] > T77_HELD_LAST then
        E.Raw[EF_FLAG1C] := T77_HELD_FIRST;
    end;
  end;
end;
procedure EntityUpdate_Type78(var E: TEntity; AGameState: Integer;
                              World: TEntityWorld);
var
  Owner, Dir, OwnerState, OwnerFrame, F: Integer;

  function Clamp(V, Hi: Integer): Integer;
  begin
    Result := V;
    if (Result < 0) or (Result > Hi) then
      Result := 0;
  end;

begin
  if World.Pool = nil then
    Exit;
  Owner := E.Raw[EF_OWNER];
  Dir := Ord(World.Pool.Field(Owner, EF_VEL_X) > 0);
  OwnerState := World.Pool.Field(Owner, EF_STATE);
  OwnerFrame := World.Pool.Field(Owner, EF_FLAG1C);

  { Slam and lob placement occurs before the dying check; idle placement occurs
    afterward. }
  if OwnerState = 4 then
  begin
    E.Raw[EF_TOUCH_KIND] := 1;
    E.Raw[EF_FLAG1C] := OwnerFrame - 6;
    F := Clamp(E.Raw[EF_FLAG1C], 3);
    E.Raw[EF_POS_X] := T78_SLAM_X[Dir][F] * T78_OFFSET_SCALE
                       + World.Pool.Field(Owner, EF_POS_X);
    E.Raw[EF_POS_Y] := T78_SLAM_Y[F] * T78_OFFSET_SCALE
                       + World.Pool.Field(Owner, EF_POS_Y);
  end;
  if OwnerState = 5 then
  begin
    { Harmless for the whole of the lob - the one safe window. }
    E.Raw[EF_TOUCH_KIND] := 0;
    E.Raw[EF_FLAG1C] := OwnerFrame - 10;
    F := Clamp(E.Raw[EF_FLAG1C], 2);
    E.Raw[EF_POS_X] := T78_LOB_X[Dir][F] * T78_OFFSET_SCALE
                       + World.Pool.Field(Owner, EF_POS_X);
    E.Raw[EF_POS_Y] := T78_LOB_Y[F] * T78_OFFSET_SCALE
                       + World.Pool.Field(Owner, EF_POS_Y);
  end;

  if (OwnerState >= 1) and (OwnerState <= 3) or (OwnerState = 6) then
    E.Raw[EF_ANIM_ID] := T78_IDLE_SPRITES[Dir];
  if OwnerState = 4 then
    E.Raw[EF_ANIM_ID] := T78_SLAM_SPRITES[Dir][Clamp(E.Raw[EF_FLAG1C], 3)];
  if OwnerState = 5 then
    E.Raw[EF_ANIM_ID] := T78_LOB_SPRITES[Dir][Clamp(E.Raw[EF_FLAG1C], 2)];

  if EntityUpdateDying(E, AGameState, World) then
    Exit;

  if (OwnerState >= 1) and (OwnerState <= 3) or (OwnerState = 6) then
  begin
    E.Raw[EF_TOUCH_KIND] := 1;
    E.Raw[EF_POS_X] := T78_IDLE_X[Dir] * T78_OFFSET_SCALE
                       + World.Pool.Field(Owner, EF_POS_X);
    { Frames 0, 3 and 5 sit higher. They belong to two different
      animations, which is why the list is not a range. }
    if (OwnerFrame = 0) or (OwnerFrame = 3) or (OwnerFrame = 5) then
      E.Raw[EF_POS_Y] := World.Pool.Field(Owner, EF_POS_Y) + T78_IDLE_HIGH
    else
      E.Raw[EF_POS_Y] := World.Pool.Field(Owner, EF_POS_Y) + T78_IDLE_LOW;
  end;

  { The boss sheds this half when it reaches its last phase. }
  if World.Pool.Field(Owner, EF_BLOCK_A + 1) = T78_LEAVES_AT_PHASE then
    E.Raw[EF_HP] := 0;
end;

end.
