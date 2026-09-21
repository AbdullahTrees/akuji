{ The ordinary enemies: walkers, chasers, jumpers and shooters placed around a stage in numbers rather than as set pieces.

  Split out of EntityHandlers, which holds the dispatch and everything
  these share. The handlers themselves are unchanged. }

unit EntityMonsters;

{$MODE DELPHI}{$H+}

interface

uses
  SysUtils, Entities, GameState, SoundTable, PlayerState, Player,
  Directions, EntityHandlers;

{ A circling particle that advances one direction step per frame and moves by
  the full X component and HALF the Y, which is what makes the path an ellipse
  rather than a circle. It never destroys itself - it leaves the screen. }
procedure EntityUpdate_Type09(var E: TEntity; AGameState: Integer);
{ The same loop one tick slower, without the timer. }
procedure EntityUpdate_Type12(var E: TEntity; AGameState: Integer);
{ Both handlers are inert. The switch has an arm for
  these two types and the arm does nothing, which is not the same as types 0,
  18 and 20, which have no arm at all. Written out so the difference survives
  in code rather than only in HANDLER_ADDR. }
procedure EntityUpdate_Type17(var E: TEntity);
procedure EntityUpdate_Type19(var E: TEntity);
{ A stationary spike ball with a single sprite.
  sprite, plus the Entity_UpdateDying call whose result it discards. }
procedure EntityUpdate_Type22_SpikeBall(var E: TEntity; AGameState: Integer;
                              World: TEntityWorld);
{ Runs four frames and is inert unless its variant is 0. }
procedure EntityUpdate_Type28(var E: TEntity; AGameState: Integer;
                              World: TEntityWorld);
{ A green one-eyed monster whose idle animates faster when the
  player is close. }
procedure EntityUpdate_Type29_Mon_MidoriMonster(var E: TEntity; AGameState: Integer;
                              World: TEntityWorld);
{ An Akuji-like entity whose
  the sprite says so and nothing in the code does. A patroller that gets
  meaner on hard; see the T30_ block. }
procedure EntityUpdate_Type30_Akuji(var E: TEntity; AGameState: Integer;
                              World: TEntityWorld);
{ Type 31's shot uses double speed and difficulty-keyed animation. }
procedure EntityUpdate_Type34(var E: TEntity; AGameState: Integer;
                              World: TEntityWorld);
{ Type 31's telegraph puts its owner into the
  attack state. See the T35_ block. }
procedure EntityUpdate_Type35(var E: TEntity; AGameState: Integer;
                              World: TEntityWorld);
{ A stationary cat that fires on a fixed interval. Waits only
  while on screen, then fires a type 39. }
procedure EntityUpdate_Type38_Mon_AkuNeko(var E: TEntity; AGameState: Integer;
                              World: TEntityWorld);
{ A green jumping cricket. See the T41_ block. }
procedure EntityUpdate_Type41_Mon_TondaCricket(var E: TEntity; AGameState: Integer;
                              World: TEntityWorld);
{ GashiGashi is a block broken by shooting it with Fire+, not
  armour worn by anything. Its VARIANT selects which of the four
  vulnerability kinds it has, which is what makes Fire+ the one shot that
  works; see the T43_ block. }
procedure EntityUpdate_Type43_GashiGashi(var E: TEntity; AGameState: Integer;
                              World: TEntityWorld);
{ A purple bat that sleeps until the player comes close, then
  homes on them. }
procedure EntityUpdate_Type46_Mon_Bat(var E: TEntity; AGameState: Integer;
                              World: TEntityWorld);
{ A pink squid that lobs spiky bouncing balls on a fixed
  interval: wait, wind up, throw two shots, rest, repeat. }
procedure EntityUpdate_Type47_Mon_PinkSquid(var E: TEntity; AGameState: Integer;
                              World: TEntityWorld);
{ A red water creature that leaps when the
  player nears. A diver - hover, drop, climb, rest; see the T49_ block. }
procedure EntityUpdate_Type49_Mon_Water(var E: TEntity; AGameState: Integer;
                              World: TEntityWorld);
{ An armored turtle, vulnerable only while open and
  firing. Patrols, opens to fire, closes, and changes its own vulnerability
  while open; see the T50_ block. }
procedure EntityUpdate_Type50_Mon_Turtle(var E: TEntity; AGameState: Integer;
                              World: TEntityWorld);
{ A blue spherical ghost that passes through terrain and follows the
  player and hurts on contact. The simplest chaser - steer, move, repeat, for
  ever. }
procedure EntityUpdate_Type51_Mon_Ghost(var E: TEntity; AGameState: Integer;
                              World: TEntityWorld);
{ Winds up, then charges in its facing direction. }
procedure EntityUpdate_Type53(var E: TEntity; AGameState: Integer;
                              World: TEntityWorld);
{ A red mushroom that swells as the player nears and bursts,
  throwing a projectile. See the T56_ block. }
procedure EntityUpdate_Type56_Mon_AkaiKinoko(var E: TEntity; AGameState: Integer;
                              World: TEntityWorld);
{ Four unrelated entities share this handler, selected by
  EF_VARIANT. See the T57_ block. }
procedure EntityUpdate_Type57(var E: TEntity; AGameState: Integer;
                              World: TEntityWorld);
{ A fake Mana Stone that resembles the collectible,
  and is a crab. Sleeps until touched, then wobbles on the spot. }
procedure EntityUpdate_Type58_Mon_NiseMana(var E: TEntity; AGameState: Integer;
                              World: TEntityWorld);
{ The red eye rises out of lava when the player comes
  near and travels toward where they are. Wakes, rises, aims once at the
  apex, then flies. }
procedure EntityUpdate_Type59_Mon_RedEye(var E: TEntity; AGameState: Integer;
                              World: TEntityWorld);
{ A golem that loses its head and accelerates when attacked. A
  walker that turns at walls AND at ledges, and enrages when its health drops
  below 11; see the T60_ block. }
procedure EntityUpdate_Type60_Mon_Golem(var E: TEntity; AGameState: Integer;
                              World: TEntityWorld);
{ HenaHena is afraid of the player and runs away.
  Catching it is the only way to kill it, which needs the Cloud dash: it
  zeroes its own EF_HP on a 1x1 overlap with the player, in both states. See
  the T61_ block, and note the acceleration really is away from the player. }
procedure EntityUpdate_Type61_Mon_HenaHena(var E: TEntity; AGameState: Integer;
                              World: TEntityWorld);
{ A shield-bearing royal penguin whose weak side is
  whichever way the shield is not: it recomputes its own vulnerability every
  frame from which way it is heading relative to the player. }
procedure EntityUpdate_Type62_Mon_PenguinHeishi(var E: TEntity; AGameState: Integer;
                              World: TEntityWorld);
{ An armored penguin that stops to throw a knife. Walks, fires
  one type-57 skimmer, then turns round; see the T63_ block. }
procedure EntityUpdate_Type63_Mon_PenguinKnife(var E: TEntity; AGameState: Integer;
                              World: TEntityWorld);
{ DorDor vanishes when attacked and can only be hurt in the
  moment after it reappears. It reads the input directly - nothing happens
  until the player presses ATTACK while standing in its box. See T65_. }
procedure EntityUpdate_Type65_Mon_DorDor(var E: TEntity; AGameState: Integer;
                              var Inp: TInputState; World: TEntityWorld);
{ A giant environmental ball that damages on
  contact and does nothing else. An anchor and the satellite that orbits it,
  one handler and two variants; see the T66_ block for what EF_FACING means
  here. }
procedure EntityUpdate_Type66_GiantBall(var E: TEntity; AGameState: Integer;
                              World: TEntityWorld);
{ A turtle that lays bombs and runs from them. Walks, lays a
  type-57 egg, then bolts away from it and coasts to a halt; see the T67_
  block. }
procedure EntityUpdate_Type67_Mon_TurtleBomb(var E: TEntity; AGameState: Integer;
                              World: TEntityWorld);
{ The hatched riser resizes its own hitbox frame by
  frame, and falls and drops loot once something has caught it. }
procedure EntityUpdate_Type68(var E: TEntity; AGameState: Integer;
                              World: TEntityWorld);
{ The angry switch is activated by
  throw it is to drop a GoroGoro on top, which kills it: it has exactly 100
  hp and any wound at all is fatal, which is what makes the ball the one
  thing that works. Variant 1 walks, variant 0 stands; see the T70_ block. }
procedure EntityUpdate_Type70_AngrySwitch(var E: TEntity; AGameState: Integer;
                              World: TEntityWorld);
{ A cat that deflects anything thrown at it except during the
  brief pause when it stops. Walks invulnerable, curls up vulnerable,
  repeats; see the T71_ block, and note the walk timer only runs while it is
  on screen. }
procedure EntityUpdate_Type71_BouncyCat(var E: TEntity; AGameState: Integer;
                              World: TEntityWorld);
{ A faller, a heading-based flyer, and the
  trail the flyer drops. See the T72_ block. }
procedure EntityUpdate_Type72(var E: TEntity; AGameState: Integer;
                              World: TEntityWorld);
{ Type 73's charge-up and fan of shots. The
  charge-up is what writes state 6 back into its parent. }
procedure EntityUpdate_Type74(var E: TEntity; AGameState: Integer;
                              World: TEntityWorld);
{ Handles everything type 77 emits. Variant 5 frees the boss
  from state 8, after throwing three flyers. See the T79_ block. }
procedure EntityUpdate_Type79(var E: TEntity; AGameState: Integer;
                              World: TEntityWorld);

implementation

procedure EntityUpdate_Type09(var E: TEntity; AGameState: Integer);
begin
  E.Raw[EF_ANIM_ID] := T9_SPRITE;

  { One of only two handlers that also run in GS_PLAY_ALT. }
  if (AGameState <> GS_PLAY) and (AGameState <> GS_PLAY_ALT) then
    Exit;

  { Full X, HALF Y - so the path is an ellipse, not a circle. }
  Inc(E.Raw[EF_POS_X], DirVelX(E.Raw[EF_FACING]));
  Inc(E.Raw[EF_POS_Y], HalfExtent(DirVelY(E.Raw[EF_FACING])));

  E.Raw[EF_FACING] := (E.Raw[EF_FACING] + 1) mod DIR_COUNT;
end;
procedure EntityUpdate_Type12(var E: TEntity; AGameState: Integer);
var
  Frame: Integer;
begin
  Frame := E.Raw[EF_FLAG1C];
  if (Frame < 0) or (Frame >= T12_FRAMES) then
    Frame := 0;
  E.Raw[EF_ANIM_ID] := T12_SPRITES[Frame];

  if AGameState <> GS_PLAY then
    Exit;

  Inc(E.Raw[EF_BLOCK_B]);
  if E.Raw[EF_BLOCK_B] > T12_TICKS then
  begin
    E.Raw[EF_BLOCK_B] := 0;
    E.Raw[EF_FLAG1C] := (E.Raw[EF_FLAG1C] + 1) mod T12_FRAMES;
  end;
end;
procedure EntityUpdate_Type17(var E: TEntity);
begin
end;
procedure EntityUpdate_Type19(var E: TEntity);
begin
end;
procedure EntityUpdate_Type22_SpikeBall(var E: TEntity; AGameState: Integer;
                              World: TEntityWorld);
begin
  E.Raw[EF_ANIM_ID] := TYPE22_SPRITE;
  { Death handling may update the entity; its Boolean result is irrelevant here. }
  EntityUpdateDying(E, AGameState, World);
end;
procedure EntityUpdate_Type28(var E: TEntity; AGameState: Integer;
                              World: TEntityWorld);
var
  Frame: Integer;
begin
  { Everything, including the sprite, is inside the variant test. A variant
    other than 0 makes this entity completely inert. }
  if E.Raw[EF_VARIANT] <> 0 then
    Exit;

  Frame := E.Raw[EF_FLAG1C];
  if (Frame < 0) or (Frame >= T28_FRAMES) then
    Frame := 0;
  E.Raw[EF_ANIM_ID] := T28_SPRITES[Frame];

  if AGameState <> GS_PLAY then
    Exit;

  if E.Raw[EF_DEATH_TIMER] = 0 then
    E.Raw[EF_DEATH_TIMER] := T28_DEATH_TIMER;

  Inc(E.Raw[EF_BLOCK_B]);
  if E.Raw[EF_BLOCK_B] > T28_TICKS then
  begin
    E.Raw[EF_BLOCK_B] := 0;
    Inc(E.Raw[EF_FLAG1C]);
    if E.Raw[EF_FLAG1C] > T28_FRAMES - 1 then
      World.DestroyEntity(E, False);
  end;
end;
procedure EntityUpdate_Type29_Mon_MidoriMonster(var E: TEntity; AGameState: Integer;
                              World: TEntityWorld);
var
  Frame, Ticks: Integer;
begin
  Frame := E.Raw[EF_FLAG1C];
  if (Frame < 0) or (Frame >= T29_FRAMES) then
    Frame := 0;
  E.Raw[EF_ANIM_ID] := T29_SPRITES[Frame];

  { Settles two pixels on its first frame, and this happens whatever the game
    state is - it is outside the guard below. }
  if E.Raw[EF_STATE] = 0 then
  begin
    E.Raw[EF_STATE] := 1;
    Inc(E.Raw[EF_POS_Y], T29_SETTLE);
  end;

  if EntityUpdateDying(E, AGameState, World) then
    Exit;

  Ticks := T29_TICKS_IDLE;
  if (World.Pool <> nil)
     and EntitiesOverlap(E, World.Pool.Entity(SLOT_SINGLE_FIRST)^,
                         T29_NEAR_SCALE_X, T29_NEAR_SCALE_Y) then
    Ticks := T29_TICKS_CLOSE;

  Inc(E.Raw[EF_BLOCK_B]);
  if E.Raw[EF_BLOCK_B] > Ticks then
  begin
    E.Raw[EF_BLOCK_B] := 0;
    E.Raw[EF_FLAG1C] := (E.Raw[EF_FLAG1C] + 1) mod T29_FRAMES;
  end;
end;

{ The one-shot latch types 4..7 share: mark it done and arm the death timer.
  Written once here because it is literally the same three lines in each. }
procedure EntityUpdate_Type30_Akuji(var E: TEntity; AGameState: Integer;
                              World: TEntityWorld);
var
  Frame: Integer;
begin
  Frame := E.Raw[EF_FLAG1C];
  if (Frame < 0) or (Frame >= T30_FRAMES) then
    Frame := 0;
  { By the SIGN of the speed, two ifs and no else - a stationary one keeps
    whatever sprite it had. }
  if E.Raw[EF_FACING] < 0 then
    E.Raw[EF_ANIM_ID] := T30_SPRITES[0][Frame];
  if E.Raw[EF_FACING] > 0 then
    E.Raw[EF_ANIM_ID] := T30_SPRITES[1][Frame];

  if E.Raw[EF_STATE] = 0 then
  begin
    E.Raw[EF_STATE] := 1;
    Inc(E.Raw[EF_POS_Y], T30_SETTLE);
    { HARD ONLY: twice the speed and half the turn period, so four times the
      ground between turns. This is the whole of its difficulty scaling and it
      happens once, on the first frame. }
    if World.PlayerDifficulty = T30_HARD then
    begin
      E.Raw[EF_FACING] := E.Raw[EF_FACING] * 2;
      E.Raw[EF_BLOCK_A + 1] := HalfExtent(E.Raw[EF_BLOCK_A + 1]);
    end;
  end;

  if EntityUpdateDying(E, AGameState, World) then
    Exit;

  Inc(E.Raw[EF_BLOCK_B]);
  if E.Raw[EF_BLOCK_B] > T30_TICKS then
  begin
    E.Raw[EF_BLOCK_B] := 0;
    E.Raw[EF_FLAG1C] := (E.Raw[EF_FLAG1C] + 1) mod T30_FRAMES;
  end;

  { A SECOND counter, in EF_CHILD_A, for the turn - the frame counter above is
    already using EF_BLOCK_B. }
  Inc(E.Raw[EF_CHILD_A]);
  if E.Raw[EF_CHILD_A] > E.Raw[EF_BLOCK_A + 1] then
  begin
    E.Raw[EF_CHILD_A] := 0;
    E.Raw[EF_FACING] := -E.Raw[EF_FACING];
  end;

  Inc(E.Raw[EF_POS_X], E.Raw[EF_FACING]);
end;
procedure EntityUpdate_Type34(var E: TEntity; AGameState: Integer;
                              World: TEntityWorld);
var
  Frame, D, Rate: Integer;
begin
  Frame := E.Raw[EF_FLAG1C];
  if (Frame < 0) or (Frame >= T34_FRAMES) then
    Frame := 0;
  E.Raw[EF_ANIM_ID] := T34_SPRITES[Frame];

  if EntityUpdateDying(E, AGameState, World) then
    Exit;

  Inc(E.Raw[EF_POS_X], DirVelX(E.Raw[EF_FACING]) * T34_SPEED);
  Inc(E.Raw[EF_POS_Y], DirVelY(E.Raw[EF_FACING]) * T34_SPEED);

  D := World.PlayerDifficulty;
  if (D < 0) or (D > 2) then
    D := 0;
  Rate := T34_RATE[D];

  { A modulo test rather than a countdown - the counter is never reset, so the
    frames land on multiples of the rate. }
  Inc(E.Raw[EF_BLOCK_B]);
  if (Rate <> 0) and (E.Raw[EF_BLOCK_B] mod Rate = 0) then
  begin
    Inc(E.Raw[EF_FLAG1C]);
    if E.Raw[EF_FLAG1C] > T34_FRAMES - 1 then
      World.DestroyEntity(E, False);
  end;
end;
procedure EntityUpdate_Type35(var E: TEntity; AGameState: Integer;
                              World: TEntityWorld);
var
  Frame, Owner, Aim: Integer;
begin
  Frame := E.Raw[EF_FLAG1C];
  if (Frame < 0) or (Frame >= T35_FRAMES) then
    Frame := 0;
  { The same table both ways round: forwards while winding up, backwards while
    winding down. }
  if E.Raw[EF_STATE] = T35_MODE_WIND_UP then
    E.Raw[EF_ANIM_ID] := T35_SPRITES[Frame];
  if E.Raw[EF_STATE] = T35_MODE_WIND_DOWN then
    E.Raw[EF_ANIM_ID] := T35_SPRITES[T35_FRAMES - 1 - Frame];

  if EntityUpdateDying(E, AGameState, World) then
    Exit;

  Owner := E.Raw[EF_OWNER];
  if World.Pool = nil then
    Exit;

  { An owner with no HP left takes its telegraph with it. }
  if World.Pool.Field(Owner, EF_HP) = 0 then
  begin
    World.DestroyEntity(E, False);
    Exit;
  end;

  Inc(E.Raw[EF_BLOCK_B]);
  if E.Raw[EF_BLOCK_B] <= T35_TICKS then
    Exit;

  E.Raw[EF_BLOCK_B] := 0;
  Inc(E.Raw[EF_FLAG1C]);
  if E.Raw[EF_FLAG1C] <= T35_FRAMES - 1 then
    Exit;

  if E.Raw[EF_STATE] = T35_MODE_WIND_UP then
  begin
    World.PlaySound(T35_SOUND);
    World.Pool.SetField(Owner, EF_STATE, T35_OWNER_ATTACK);
    { The aim, taken ONCE here rather than tracked - which is why the shots
      that follow all leave along one heading however the player moves. }
    Aim := AngleBetween(World.Pool.Field(Owner, EF_POS_X),
                        World.Pool.Field(Owner, EF_POS_Y),
                        World.Pool.Field(SLOT_SINGLE_FIRST, EF_POS_X),
                        World.Pool.Field(SLOT_SINGLE_FIRST, EF_POS_Y));
    World.Pool.SetField(Owner, EF_BLOCK_A + 1, Aim);
  end;
  if E.Raw[EF_STATE] = T35_MODE_WIND_DOWN then
    World.Pool.SetField(Owner, EF_STATE, T35_OWNER_IDLE);

  World.DestroyEntity(E, False);
end;
procedure EntityUpdate_Type38_Mon_AkuNeko(var E: TEntity; AGameState: Integer;
                              World: TEntityWorld);
var
  Frame, Row, D, Slot: Integer;
begin
  Frame := E.Raw[EF_FLAG1C];
  Row := E.Raw[EF_VARIANT];
  { Sprite row and frame are intentionally read through the contiguous table. }
  E.Raw[EF_ANIM_ID] := SpriteDatum(T38_AT + Row * SPRITE_ROW + Frame);

  if E.Raw[EF_STATE] = 0 then
  begin
    E.Raw[EF_STATE] := 1;
    Inc(E.Raw[EF_POS_Y], T38_SETTLE);
    { The variant is both the sprite row and the direction. }
    E.Raw[EF_FACING] := E.Raw[EF_VARIANT] shl T38_FACING_SHIFT;
  end;

  if EntityUpdateDying(E, AGameState, World) then
    Exit;
  if AGameState <> GS_PLAY then
    Exit;

  D := World.PlayerDifficulty;
  if (D < 0) or (D > 2) then
    D := 0;

  if E.Raw[EF_STATE] = 1 then
  begin
    { OFF SCREEN, NO COUNTDOWN. A turret you cannot see never fires. }
    if not IsOffScreen(E, T38_OFFSCREEN_MARGIN) then
    begin
      Inc(E.Raw[EF_CHILD_A]);
      if E.Raw[EF_CHILD_A] > T38_WAIT[D] then
      begin
        E.Raw[EF_BLOCK_B] := 0;
        E.Raw[EF_CHILD_A] := 0;
        E.Raw[EF_STATE] := 2;
        E.Raw[EF_FLAG1C] := 0;
      end;
    end;
  end;

  if E.Raw[EF_STATE] = 2 then
  begin
    Inc(E.Raw[EF_BLOCK_B]);
    if E.Raw[EF_BLOCK_B] > T38_TICKS then
    begin
      E.Raw[EF_BLOCK_B] := 0;
      Inc(E.Raw[EF_FLAG1C]);
    end;
    if E.Raw[EF_FLAG1C] > T38_FRAMES - 1 then
    begin
      E.Raw[EF_BLOCK_B] := 0;
      E.Raw[EF_STATE] := 3;
      E.Raw[EF_FLAG1C] := T38_FRAMES - 1;
    end;
  end;

  if E.Raw[EF_STATE] = 3 then
  begin
    Inc(E.Raw[EF_CHILD_A]);
    if E.Raw[EF_CHILD_A] > T38_FIRE_DELAY then
    begin
      Slot := World.Spawn(EKIND_MINOR, T38_SHOT_TYPE,
                          E.Raw[EF_POS_X] - POSITION_BIAS - World.Layer.DeltaX
                            + DirVelX(E.Raw[EF_FACING]) * T38_SHOT_AHEAD,
                          E.Raw[EF_POS_Y] - World.Layer.DeltaY - POSITION_BIAS
                            - T38_SHOT_LIFT);
      World.SetSpawnField(Slot, EF_OWNER, E.Raw[EF_SLOT]);
      { The shot's velocity is one direction step, and the speed multiplier is
        applied at the far end by type 39 itself. }
      World.SetSpawnField(Slot, EF_VEL_X, DirVelX(E.Raw[EF_FACING]));
      E.Raw[EF_CHILD_A] := 0;
      E.Raw[EF_STATE] := 4;
    end;
  end;

  { State 4 is a hold. Type 39 is what leaves it. }

  if E.Raw[EF_STATE] = 5 then
  begin
    Inc(E.Raw[EF_BLOCK_B]);
    if E.Raw[EF_BLOCK_B] > T38_TICKS then
    begin
      E.Raw[EF_BLOCK_B] := 0;
      Dec(E.Raw[EF_FLAG1C]);
    end;
    if E.Raw[EF_FLAG1C] < 1 then
    begin
      E.Raw[EF_BLOCK_B] := 0;
      E.Raw[EF_STATE] := 1;
    end;
  end;
end;
procedure EntityUpdate_Type41_Mon_TondaCricket(var E: TEntity; AGameState: Integer;
                              World: TEntityWorld);
var
  Frame, D: Integer;
begin
  Frame := E.Raw[EF_FLAG1C];
  if (Frame < 0) or (Frame > High(T41_SPRITES)) then
    Frame := 0;
  E.Raw[EF_ANIM_ID] := T41_SPRITES[Frame];

  if E.Raw[EF_STATE] = 0 then
  begin
    E.Raw[EF_STATE] := 1;
    Inc(E.Raw[EF_POS_Y], T41_SETTLE);
    if World.PlayerDifficulty = T41_HARD then
      E.Raw[EF_FACING] := E.Raw[EF_FACING] * 2;
  end;

  if EntityUpdateDying(E, AGameState, World) then
    Exit;

  D := World.PlayerDifficulty;
  if (D < 0) or (D > 2) then
    D := 0;

  { Off screen it does not even count - frozen mid-crouch, not hopping in
    place. Same gate type 38 uses. }
  if (E.Raw[EF_STATE] = 1) and (not IsOffScreen(E, T41_OFFSCREEN_MARGIN)) then
  begin
    Inc(E.Raw[EF_BLOCK_B]);
    if E.Raw[EF_BLOCK_B] > T41_TICKS then
    begin
      E.Raw[EF_BLOCK_B] := 0;
      E.Raw[EF_FLAG1C] := (E.Raw[EF_FLAG1C] + 1) mod T41_FRAMES;
    end;

    Inc(E.Raw[EF_CHILD_A]);
    if E.Raw[EF_CHILD_A] > T41_WAIT[D] then
    begin
      World.PlaySound(T41_JUMP_SOUND);
      E.Raw[EF_STATE] := 2;
      E.Raw[EF_BLOCK_B] := 0;
      E.Raw[EF_CHILD_A] := 0;
      E.Raw[EF_FLAG1C] := T41_CROUCH_FRAME;
      E.Raw[EF_VEL_Y] := T41_JUMP_VY;
    end;
  end;

  if E.Raw[EF_STATE] = 2 then
  begin
    Inc(E.Raw[EF_BLOCK_B]);
    if E.Raw[EF_BLOCK_B] > T41_CROUCH_TICKS then
    begin
      E.Raw[EF_STATE] := 3;
      E.Raw[EF_BLOCK_B] := 0;
      E.Raw[EF_FLAG1C] := T41_AIR_FRAME;
    end;
  end;

  if E.Raw[EF_STATE] = 3 then
  begin
    Inc(E.Raw[EF_POS_X], E.Raw[EF_FACING]);
    Inc(E.Raw[EF_VEL_Y], T41_GRAVITY);
    if E.Raw[EF_VEL_Y] > T41_TERMINAL then
      E.Raw[EF_VEL_Y] := T41_TERMINAL;

    if World.TileAtY(E, E.Raw[EF_VEL_Y], False) >= World.SolidThreshold then
    begin
      E.Raw[EF_VEL_Y] := World.EdgeDistY(E, E.Raw[EF_VEL_Y]);
      E.Raw[EF_STATE] := 1;
      E.Raw[EF_BLOCK_B] := 0;
      E.Raw[EF_CHILD_A] := 0;
      E.Raw[EF_FLAG1C] := 0;
      { Turns round after block A[1] landings. }
      Inc(E.Raw[EF_CHILD_B]);
      if E.Raw[EF_CHILD_B] > E.Raw[EF_BLOCK_A + 1] then
      begin
        E.Raw[EF_CHILD_B] := 0;
        E.Raw[EF_FACING] := -E.Raw[EF_FACING];
      end;
    end;

    Inc(E.Raw[EF_POS_Y], E.Raw[EF_VEL_Y]);
  end;
end;
procedure EntityUpdate_Type43_GashiGashi(var E: TEntity; AGameState: Integer;
                              World: TEntityWorld);
var
  Variant: Integer;
begin
  Variant := E.Raw[EF_VARIANT];
  if (Variant < 0) or (Variant >= T43_VARIANTS) then
    Variant := 0;
  E.Raw[EF_ANIM_ID] := T43_SPRITES[Variant];

  { Every frame, not once - so nothing can leave it armoured differently. }
  E.Raw[EF_VULN_KIND] := E.Raw[EF_VARIANT] + T43_VULN_BASE;

  { The result is discarded: this type has nothing to do while dying. }
  EntityUpdateDying(E, AGameState, World);
end;
procedure EntityUpdate_Type46_Mon_Bat(var E: TEntity; AGameState: Integer;
                              World: TEntityWorld);
var
  Frame, D, Dist: Integer;
begin
  Frame := E.Raw[EF_FLAG1C];
  if (Frame < 0) or (Frame > High(T46_SPRITES)) then
    Frame := 0;
  E.Raw[EF_ANIM_ID] := T46_SPRITES[Frame];

  if E.Raw[EF_STATE] = 0 then
  begin
    E.Raw[EF_STATE] := 1;
    Dec(E.Raw[EF_POS_Y], T46_RISE);
    { So a room full of these does not move in lockstep. }
    E.Raw[EF_FACING] := World.RandomBelow(DIR_COUNT);
  end;

  if EntityUpdateDying(E, AGameState, World) then
    Exit;
  if World.Pool = nil then
    Exit;

  D := World.PlayerDifficulty;
  if (D < 0) or (D > 2) then
    D := 0;

  if E.Raw[EF_STATE] = 1 then
  begin
    E.Raw[EF_FLAG1C] := T46_SLEEP_FRAME;
    { Horizontal pixel distance; Easy has the longest wake range. }
    Dist := Abs(OriginPixel(E.Raw[EF_POS_X]
                - World.Pool.Field(SLOT_SINGLE_FIRST, EF_POS_X)));
    if Dist < T46_RANGE[D] then
    begin
      World.PlaySound(T46_WAKE_SOUND);
      E.Raw[EF_FLAG1C] := 0;
      E.Raw[EF_STATE] := 2;
    end;
  end;

  if E.Raw[EF_STATE] = 2 then
  begin
    { Steer turns one step toward the player and rewrites the velocity from
      the direction table; this then halves it and scales by difficulty. }
    World.Pool.Steer(E.Raw[EF_SLOT], T46_TURN_TIMER, T46_TURN[D]);
    E.Raw[EF_VEL_X] := T46_SPEED[D] * HalfExtent(E.Raw[EF_VEL_X]);
    E.Raw[EF_VEL_Y] := T46_SPEED[D] * HalfExtent(E.Raw[EF_VEL_Y]);

    { Clamped on both axes, so it slides along walls instead of entering. }
    if World.TileAtX(E, E.Raw[EF_VEL_X], False) >= World.SolidThreshold then
      E.Raw[EF_VEL_X] := World.EdgeDistX(E, E.Raw[EF_VEL_X]);
    if World.TileAtY(E, E.Raw[EF_VEL_Y], False) >= World.SolidThreshold then
      E.Raw[EF_VEL_Y] := World.EdgeDistY(E, E.Raw[EF_VEL_Y]);

    Inc(E.Raw[EF_POS_X], E.Raw[EF_VEL_X]);
    Inc(E.Raw[EF_POS_Y], E.Raw[EF_VEL_Y]);

    Inc(E.Raw[EF_BLOCK_B]);
    if E.Raw[EF_BLOCK_B] > T46_TICKS then
    begin
      E.Raw[EF_BLOCK_B] := 0;
      E.Raw[EF_FLAG1C] := (E.Raw[EF_FLAG1C] + 1) mod T46_FRAMES;
    end;
  end;
end;
procedure EntityUpdate_Type47_Mon_PinkSquid(var E: TEntity; AGameState: Integer;
                              World: TEntityWorld);
var
  Frame, D, I, Slot: Integer;
begin
  Frame := E.Raw[EF_FLAG1C];
  if (Frame < 0) or (Frame > High(T47_SPRITES)) then
    Frame := 0;
  E.Raw[EF_ANIM_ID] := T47_SPRITES[Frame];

  if EntityUpdateDying(E, AGameState, World) then
    Exit;

  D := World.PlayerDifficulty;
  if (D < 0) or (D > 2) then
    D := 0;

  if E.Raw[EF_STATE] = 0 then
    E.Raw[EF_STATE] := 1;

  { The idle and the rest share one two-frame loop. }
  if (E.Raw[EF_STATE] = 1) or (E.Raw[EF_STATE] = 3) then
  begin
    Inc(E.Raw[EF_BLOCK_B]);
    if E.Raw[EF_BLOCK_B] > T47_TICKS then
    begin
      E.Raw[EF_BLOCK_B] := 0;
      E.Raw[EF_FLAG1C] := (E.Raw[EF_FLAG1C] + 1) mod T47_FRAMES;
    end;
  end;

  if E.Raw[EF_STATE] = 1 then
  begin
    Inc(E.Raw[EF_CHILD_A]);
    if E.Raw[EF_CHILD_A] > T47_WAIT[D] then
    begin
      E.Raw[EF_STATE] := 2;
      E.Raw[EF_BLOCK_B] := 0;
      E.Raw[EF_CHILD_A] := 0;
      E.Raw[EF_FLAG1C] := T47_WIND_FIRST;
    end;
  end;

  { The wind-up only advances while visible. }
  if (E.Raw[EF_STATE] = 2) and (not IsOffScreen(E, T47_OFFSCREEN_MARGIN)) then
  begin
    Inc(E.Raw[EF_BLOCK_B]);
    if E.Raw[EF_BLOCK_B] > T47_TICKS then
    begin
      E.Raw[EF_BLOCK_B] := 0;
      Inc(E.Raw[EF_FLAG1C]);
      if E.Raw[EF_FLAG1C] > T47_WIND_LAST then
      begin
        for I := 0 to High(T47_ANGLES) do
        begin
          Slot := World.Spawn(EKIND_MINOR, T47_SHOT_TYPE,
                              E.Raw[EF_POS_X] - POSITION_BIAS
                                - World.Layer.DeltaX,
                              E.Raw[EF_POS_Y] - World.Layer.DeltaY
                                - POSITION_BIAS - T47_SHOT_LIFT);
          World.SetSpawnField(Slot, EF_VEL_X,
                              T47_ANGLES[I] shl T47_ANGLE_SHIFT);
          World.SetSpawnField(Slot, EF_VEL_Y, T47_SHOT_VY);
        end;
        World.PlaySound(T47_FIRE_SOUND);
        E.Raw[EF_STATE] := 3;
        E.Raw[EF_BLOCK_B] := 0;
      end;
    end;
  end;

  if E.Raw[EF_STATE] = 3 then
  begin
    Inc(E.Raw[EF_CHILD_A]);
    if E.Raw[EF_CHILD_A] > T47_REST[D] then
    begin
      E.Raw[EF_STATE] := 1;
      E.Raw[EF_CHILD_A] := 0;
    end;
  end;
end;
procedure EntityUpdate_Type49_Mon_Water(var E: TEntity; AGameState: Integer;
                              World: TEntityWorld);
var
  Frame, D, Step, Dist: Integer;
begin
  Frame := E.Raw[EF_FLAG1C];
  if (Frame < 0) or (Frame > High(T49_SPRITES)) then
    Frame := 0;
  E.Raw[EF_ANIM_ID] := T49_SPRITES[Frame];

  if EntityUpdateDying(E, AGameState, World) then
    Exit;
  if World.Pool = nil then
    Exit;

  D := World.PlayerDifficulty;
  if (D < 0) or (D > 2) then
    D := 0;

  if E.Raw[EF_STATE] = 0 then
    E.Raw[EF_STATE] := 1;

  { Hovering and resting share the flap and the bob. }
  if (E.Raw[EF_STATE] = 1) or (E.Raw[EF_STATE] = 3) then
  begin
    Dec(E.Raw[EF_BLOCK_B]);
    if E.Raw[EF_BLOCK_B] < 1 then
    begin
      E.Raw[EF_BLOCK_B] := T49_TICKS;
      E.Raw[EF_FLAG1C] := (E.Raw[EF_FLAG1C] + 1) mod T49_FRAMES;
    end;

    E.Raw[EF_FACING] := (E.Raw[EF_FACING] + 1) mod DIR_COUNT;
    { Use signed division for one quarter of the heading's Y component. }
    Inc(E.Raw[EF_POS_Y],
        DirVelY(E.Raw[EF_FACING]) div (1 shl T49_BOB_SHIFT));
  end;

  if E.Raw[EF_STATE] = 1 then
  begin
    Dist := Abs(E.Raw[EF_POS_X]
                - World.Pool.Field(SLOT_SINGLE_FIRST, EF_POS_X));
    if Dist < 0 then
      Inc(Dist, 31);
    if (Dist shr POSITION_SHIFT) < T49_RANGE[D] then
    begin
      World.SpawnDebris(E, 0);
      E.Raw[EF_STATE] := 2;
      E.Raw[EF_BLOCK_A + 1] := 0;
      E.Raw[EF_CHILD_B] := 0;
      { Only above easy does it aim - on easy it drops straight down. }
      if D > 0 then
        E.Raw[EF_VEL_X] :=
          Compare(E.Raw[EF_POS_X],
                  World.Pool.Field(SLOT_SINGLE_FIRST, EF_POS_X))
          shl T49_AIM_SHIFT;
      E.Raw[EF_VEL_Y] := T49_DIVE_VY;
    end;
  end;

  if E.Raw[EF_STATE] = 2 then
  begin
    { A sign test, not a state: rising shows one frame and falling another. }
    E.Raw[EF_FLAG1C] := T49_RISING_FRAME;
    if E.Raw[EF_VEL_Y] > 0 then
      E.Raw[EF_FLAG1C] := T49_FALLING_FRAME;

    Inc(E.Raw[EF_VEL_Y], T49_GRAVITY);
    if E.Raw[EF_VEL_Y] > T49_DIVE_END then
    begin
      World.SpawnDebris(E, 0);
      E.Raw[EF_BLOCK_B] := 0;
      E.Raw[EF_STATE] := 3;
      E.Raw[EF_VEL_Y] := 0;
    end;

    Inc(E.Raw[EF_POS_X], E.Raw[EF_VEL_X]);
    Inc(E.Raw[EF_POS_Y], E.Raw[EF_VEL_Y]);
  end;

  if E.Raw[EF_STATE] = 3 then
  begin
    Inc(E.Raw[EF_CHILD_A]);
    if E.Raw[EF_CHILD_A] > T49_REST[D] then
    begin
      E.Raw[EF_STATE] := 1;
      E.Raw[EF_CHILD_A] := 0;
    end;
  end;
end;
procedure EntityUpdate_Type50_Mon_Turtle(var E: TEntity; AGameState: Integer;
                              World: TEntityWorld);
var
  Frame, D, Slot: Integer;
begin
  Frame := E.Raw[EF_FLAG1C];
  if (Frame < 0) or (Frame > High(T50_SPRITES)) then
    Frame := 0;
  E.Raw[EF_ANIM_ID] := T50_SPRITES[Frame];

  if EntityUpdateDying(E, AGameState, World) then
    Exit;

  D := World.PlayerDifficulty;
  if (D < 0) or (D > 2) then
    D := 0;

  if E.Raw[EF_STATE] = 0 then
  begin
    E.Raw[EF_STATE] := 1;
    { The only handler that weakens ITSELF on easy. }
    if D = 0 then
      Inc(E.Raw[EF_HP], T50_EASY_HP_PENALTY);
  end;

  if E.Raw[EF_STATE] = 1 then
  begin
    Dec(E.Raw[EF_BLOCK_B]);
    if E.Raw[EF_BLOCK_B] < 1 then
    begin
      E.Raw[EF_BLOCK_B] := T50_TICKS;
      E.Raw[EF_FLAG1C] := (E.Raw[EF_FLAG1C] + 1) mod T50_FRAMES;
    end;

    Inc(E.Raw[EF_CHILD_A]);
    if E.Raw[EF_CHILD_A] > E.Raw[EF_BLOCK_A + 1] then
    begin
      E.Raw[EF_CHILD_A] := 0;
      E.Raw[EF_FACING] := -E.Raw[EF_FACING];
    end;
    Inc(E.Raw[EF_POS_X], E.Raw[EF_FACING]);

    Inc(E.Raw[EF_CHILD_B]);
    if E.Raw[EF_CHILD_B] > T50_PATROL[D] then
    begin
      E.Raw[EF_STATE] := 2;
      E.Raw[EF_FLAG1C] := T50_OPEN_FIRST;
      E.Raw[EF_BLOCK_B] := 0;
      E.Raw[EF_CHILD_B] := 0;
      E.Raw[EF_SHOTS] := 0;
    end;
  end;

  if (E.Raw[EF_STATE] = 2) and (not IsOffScreen(E, T50_OFFSCREEN_MARGIN)) then
  begin
    Inc(E.Raw[EF_BLOCK_B]);
    if E.Raw[EF_BLOCK_B] > T50_TICKS then
    begin
      E.Raw[EF_BLOCK_B] := 0;
      Inc(E.Raw[EF_FLAG1C]);
      if E.Raw[EF_FLAG1C] > T50_OPEN_LAST then
      begin
        E.Raw[EF_FLAG1C] := T50_OPEN_LAST;
        E.Raw[EF_STATE] := 3;
        { Open, and hurtable differently while it is. }
        E.Raw[EF_VULN_KIND] := T50_VULN_OPEN;
        Slot := World.Spawn(EKIND_MINOR, T50_SHOT_TYPE,
                            E.Raw[EF_POS_X] - POSITION_BIAS
                              - World.Layer.DeltaX,
                            E.Raw[EF_POS_Y] - POSITION_BIAS
                              - World.Layer.DeltaY);
        World.SetSpawnField(Slot, EF_OWNER, E.Raw[EF_SLOT]);
        World.SetSpawnField(Slot, EF_VEL_X,
                            E.Raw[EF_FACING] * T50_SHOT_SPEED);
      end;
    end;
  end;

  { State 3 is a hold - the type-39 shot moves it to 5. }

  if E.Raw[EF_STATE] = 5 then
  begin
    Inc(E.Raw[EF_CHILD_B]);
    if E.Raw[EF_CHILD_B] > T50_HOLD[D] then
    begin
      E.Raw[EF_STATE] := 6;
      E.Raw[EF_BLOCK_B] := 0;
      E.Raw[EF_CHILD_B] := 0;
      E.Raw[EF_VULN_KIND] := T50_VULN_CLOSING;
    end;
  end;

  if E.Raw[EF_STATE] = 6 then
  begin
    Inc(E.Raw[EF_BLOCK_B]);
    if E.Raw[EF_BLOCK_B] > T50_TICKS then
    begin
      E.Raw[EF_BLOCK_B] := 0;
      Dec(E.Raw[EF_FLAG1C]);
      if E.Raw[EF_FLAG1C] < T50_OPEN_FIRST then
      begin
        E.Raw[EF_FLAG1C] := 0;
        E.Raw[EF_STATE] := 1;
        E.Raw[EF_BLOCK_B] := 0;
      end;
    end;
  end;
end;
procedure EntityUpdate_Type51_Mon_Ghost(var E: TEntity; AGameState: Integer;
                              World: TEntityWorld);
var
  Frame: Integer;
begin
  Frame := E.Raw[EF_FLAG1C];
  if (Frame < 0) or (Frame >= T51_FRAMES) then
    Frame := 0;
  E.Raw[EF_ANIM_ID] := T51_SPRITES[Frame];

  { Topped back up whenever it reaches zero, so it blinks continuously - the
    same thing types 11 and 28 do with this field. }
  if E.Raw[EF_DEATH_TIMER] = 0 then
    E.Raw[EF_DEATH_TIMER] := T51_DEATH_TIMER;

  if EntityUpdateDying(E, AGameState, World) then
    Exit;

  Inc(E.Raw[EF_BLOCK_B]);
  if E.Raw[EF_BLOCK_B] > T51_TICKS then
  begin
    E.Raw[EF_BLOCK_B] := 0;
    E.Raw[EF_FLAG1C] := (E.Raw[EF_FLAG1C] + 1) mod T51_FRAMES;
  end;

  if World.Pool <> nil then
    World.Pool.Steer(E.Raw[EF_SLOT], T51_TURN_TIMER, T51_TURN_RELOAD);
  Inc(E.Raw[EF_POS_X], E.Raw[EF_VEL_X]);
  Inc(E.Raw[EF_POS_Y], E.Raw[EF_VEL_Y]);
end;
procedure EntityUpdate_Type53(var E: TEntity; AGameState: Integer;
                              World: TEntityWorld);
var
  Frame: Integer;
begin
  Frame := E.Raw[EF_FLAG1C];
  if (Frame < 0) or (Frame >= T53_ROW) then
    Frame := 0;
  { By the SIGN, two ifs and no else - a stationary one keeps its sprite. }
  if E.Raw[EF_VEL_X] < 0 then
    E.Raw[EF_ANIM_ID] := T53_SPRITES[0][Frame];
  if E.Raw[EF_VEL_X] > 0 then
    E.Raw[EF_ANIM_ID] := T53_SPRITES[1][Frame];

  if EntityUpdateDying(E, AGameState, World) then
    Exit;

  if E.Raw[EF_STATE] = 0 then
  begin
    Inc(E.Raw[EF_BLOCK_B]);
    if E.Raw[EF_BLOCK_B] > T53_TICKS then
    begin
      E.Raw[EF_BLOCK_B] := 0;
      Inc(E.Raw[EF_FLAG1C]);
      if E.Raw[EF_FLAG1C] > T53_WIND_LAST then
      begin
        World.PlaySound(T53_CHARGE_SOUND);
        E.Raw[EF_STATE] := 1;
        E.Raw[EF_FLAG1C] := T53_RUN_FIRST;
      end;
    end;
  end;

  if E.Raw[EF_STATE] = 1 then
  begin
    Inc(E.Raw[EF_POS_X], E.Raw[EF_VEL_X]);
    Inc(E.Raw[EF_BLOCK_B]);
    if E.Raw[EF_BLOCK_B] > T53_TICKS then
    begin
      E.Raw[EF_BLOCK_B] := 0;
      Inc(E.Raw[EF_FLAG1C]);
      if E.Raw[EF_FLAG1C] > T53_RUN_LAST then
        E.Raw[EF_FLAG1C] := T53_RUN_FIRST;
    end;
  end;
end;
procedure EntityUpdate_Type56_Mon_AkaiKinoko(var E: TEntity; AGameState: Integer;
                              World: TEntityWorld);
var
  Frame, D, Aim, I, N, Slot: Integer;
  Player: PEntity;
begin
  Frame := E.Raw[EF_FLAG1C];
  if (Frame < 0) or (Frame >= T56_FRAMES) then
    Frame := 0;
  E.Raw[EF_ANIM_ID] := T56_SPRITES[Frame];

  if EntityUpdateDying(E, AGameState, World) then
    Exit;
  if World.Pool = nil then
    Exit;

  D := World.PlayerDifficulty;
  if (D < 0) or (D > 2) then
    D := 0;
  Player := World.Pool.Entity(SLOT_SINGLE_FIRST);

  { EF_TIMER is the fuse and Entity_UpdateAll counts it down. }
  if E.Raw[EF_TIMER] = 0 then
    E.Raw[EF_STATE] := 0;

  if (E.Raw[EF_STATE] = 0) and (E.Raw[EF_TIMER] <> 0) then
  begin
    E.Raw[EF_STATE] := 1;
    Inc(E.Raw[EF_FLAG1C]);
    if E.Raw[EF_FLAG1C] > T56_FRAMES - 1 then
    begin
      E.Raw[EF_FLAG1C] := T56_FRAMES - 1;
      E.Raw[EF_HP] := 0;

      { Aim, then SKEW it - harder settings lead the shot. }
      Aim := AngleBetween(E.Raw[EF_POS_X], E.Raw[EF_POS_Y],
                          Player^.Raw[EF_POS_X], Player^.Raw[EF_POS_Y]);
      Inc(Aim, T56_SKEW[D]);
      if Aim < 0 then
        Inc(Aim, DIR_COUNT);

      N := T56_COUNT[D];
      if N >= 0 then
        for I := 0 to N do
        begin
          Slot := World.Spawn(EKIND_MINOR, T56_SHOT_TYPE,
                              E.Raw[EF_POS_X] - POSITION_BIAS,
                              E.Raw[EF_POS_Y] - POSITION_BIAS);
          World.SetSpawnField(Slot, EF_VARIANT, 0);
          World.SetSpawnField(Slot, EF_VEL_X, T56_SPEED[D] * DirVelX(Aim));
          World.SetSpawnField(Slot, EF_VEL_Y, T56_SPEED[D] * DirVelY(Aim));
          { The shots are hurtable themselves. }
          World.SetSpawnField(Slot, EF_VULN_KIND, 1);

          { `next := aim + 4; if next > 63 then next := aim - 60`, which is
            (aim + 4) mod 64 for every aim in range - see the T56_ block. }
          if Aim + T56_FAN_STEP > DIR_COUNT - 1 then
            Aim := Aim - T56_FAN_WRAP
          else
            Inc(Aim, T56_FAN_STEP);
        end;
    end;
  end;

  if EntitiesOverlap(E, Player^, T56_TRIGGER_SCALE_X, T56_TRIGGER_SCALE_Y)
     and (E.Raw[EF_TIMER] = 0) then
    E.Raw[EF_TIMER] := T56_FUSE;
end;
procedure EntityUpdate_Type57(var E: TEntity; AGameState: Integer;
                              World: TEntityWorld);
var
  Frame, D, I, Slot, Facing: Integer;
begin
  Frame := E.Raw[EF_FLAG1C];

  { --- the sprite, four different ways --- }
  if E.Raw[EF_VARIANT] = 0 then
  begin
    if (Frame < 0) or (Frame >= T57_V0_FRAMES) then
      Frame := 0;
    E.Raw[EF_ANIM_ID] := T57_V0_SPRITES[Frame];
  end;
  if E.Raw[EF_VARIANT] = 1 then
  begin
    if (Frame < 0) or (Frame >= T57_V1_FRAMES) then
      Frame := 0;
    if E.Raw[EF_STATE] = 0 then
    begin
      { The same table as two rows, by the sign - two ifs and no else. }
      if E.Raw[EF_VEL_X] > 0 then
        E.Raw[EF_ANIM_ID] := T57_V1_SPRITES[0];
      if E.Raw[EF_VEL_X] < 0 then
        E.Raw[EF_ANIM_ID] := T57_V1_SPRITES[T57_V1_ROW];
    end
    else
      E.Raw[EF_ANIM_ID] := T57_V1_SPRITES[Frame];
  end;
  if E.Raw[EF_VARIANT] = 2 then
  begin
    if (Frame < 0) or (Frame >= T57_V2_FRAMES) then
      Frame := 0;
    E.Raw[EF_ANIM_ID] := T57_V2_SPRITES[Frame];
  end;
  if E.Raw[EF_VARIANT] = 3 then
  begin
    if (Frame < 0) or (Frame >= T57_V3_FRAMES) then
      Frame := 0;
    E.Raw[EF_ANIM_ID] := T57_V3_SPRITES[Frame];
  end;

  if EntityUpdateDying(E, AGameState, World) then
    Exit;

  D := World.PlayerDifficulty;
  if (D < 0) or (D > 2) then
    D := 0;

  { --- variant 0: type 56's shot --- }
  if E.Raw[EF_VARIANT] = 0 then
  begin
    Inc(E.Raw[EF_POS_X], E.Raw[EF_VEL_X]);
    Inc(E.Raw[EF_POS_Y], E.Raw[EF_VEL_Y]);
    Inc(E.Raw[EF_BLOCK_B]);
    if E.Raw[EF_BLOCK_B] > T57_V0_TICKS then
    begin
      E.Raw[EF_BLOCK_B] := 0;
      E.Raw[EF_FLAG1C] := (E.Raw[EF_FLAG1C] + 1) mod T57_V0_FRAMES;
    end;
  end;

  { --- variant 1: skims, then falls when it meets a wall --- }
  if E.Raw[EF_VARIANT] = 1 then
  begin
    if E.Raw[EF_STATE] = 0 then
    begin
      Inc(E.Raw[EF_POS_X], E.Raw[EF_VEL_X]);
      if World.TileAtX(E, E.Raw[EF_VEL_X], False) >= World.SolidThreshold then
      begin
        World.PlaySound(T57_V1_SND_HIT);
        E.Raw[EF_STATE] := 1;
        E.Raw[EF_VEL_Y] := T57_V1_HOP;
      end;
    end;

    if E.Raw[EF_STATE] = 1 then
    begin
      Inc(E.Raw[EF_VEL_Y], T57_V1_GRAVITY);
      if E.Raw[EF_VEL_Y] > T57_V1_TERMINAL then
        E.Raw[EF_VEL_Y] := T57_V1_TERMINAL;
      Inc(E.Raw[EF_POS_Y], E.Raw[EF_VEL_Y]);
      Inc(E.Raw[EF_BLOCK_B]);
      if E.Raw[EF_BLOCK_B] > T57_V1_TICKS then
      begin
        E.Raw[EF_BLOCK_B] := 0;
        E.Raw[EF_FLAG1C] := (E.Raw[EF_FLAG1C] + 1) mod T57_V1_FRAMES;
      end;
    end;
  end;

  { --- variant 2: the homing fireball, type 55's state 0 rebuilt --- }
  if E.Raw[EF_VARIANT] = 2 then
  begin
    Inc(E.Raw[EF_BLOCK_B]);
    if E.Raw[EF_BLOCK_B] > T57_V2_TICKS then
    begin
      E.Raw[EF_BLOCK_B] := 0;
      E.Raw[EF_FLAG1C] := (E.Raw[EF_FLAG1C] + 1) mod T57_V2_FRAMES;
      if E.Raw[EF_FLAG1C] = 0 then
        World.PlaySound(T57_V2_SND_LOOP);
    end;

    Inc(E.Raw[EF_SHOTS]);
    if E.Raw[EF_SHOTS] < T57_V2_HOMING_UNTIL then
    begin
      if World.Pool <> nil then
        World.Pool.Steer(E.Raw[EF_SLOT], T57_V2_TURN_TIMER,
                         T57_V2_TURN_RELOAD);
      E.Raw[EF_VEL_X] := (D + 1) * E.Raw[EF_VEL_X];
      E.Raw[EF_VEL_Y] := (D + 1) * E.Raw[EF_VEL_Y];
    end;

    Inc(E.Raw[EF_POS_X], E.Raw[EF_VEL_X]);
    Inc(E.Raw[EF_POS_Y], E.Raw[EF_VEL_Y]);

    Inc(E.Raw[EF_BLOCK_B + 4]);
    if E.Raw[EF_BLOCK_B + 4] mod T57_V2_TRAIL_EVERY = 0 then
      World.Spawn(EKIND_MINOR, T57_V2_TRAIL_TYPE,
                  E.Raw[EF_POS_X] - POSITION_BIAS,
                  E.Raw[EF_POS_Y] - POSITION_BIAS);

    if E.Raw[EF_BLOCK_B + 4] > T57_V2_LIFETIME then
    begin
      Slot := World.Spawn(EKIND_MINOR, T57_V2_END_TYPE,
                          E.Raw[EF_POS_X] - POSITION_BIAS,
                          E.Raw[EF_POS_Y] - POSITION_BIAS);
      World.SetSpawnField(Slot, EF_VARIANT, T57_V2_END_VARIANT);
      World.DestroyEntity(E, False);
      Exit;
    end;
  end;

  { --- variant 3: the egg --- }
  if E.Raw[EF_VARIANT] = 3 then
  begin
    if E.Raw[EF_STATE] = 0 then
    begin
      E.Raw[EF_BLOCK_B] := 0;
      Inc(E.Raw[EF_CHILD_A]);
      { Shrinking hops - the sixth has no lift at all. }
      E.Raw[EF_VEL_Y] := (T57_V3_HOPS - E.Raw[EF_CHILD_A]) * T57_V3_HOP_UNIT;
      if E.Raw[EF_CHILD_A] < T57_V3_HOPS then
        E.Raw[EF_STATE] := 1
      else
        E.Raw[EF_STATE] := 2;
    end;

    if E.Raw[EF_STATE] = 1 then
    begin
      Inc(E.Raw[EF_BLOCK_B]);
      if E.Raw[EF_BLOCK_B] > T57_V3_TICKS then
      begin
        E.Raw[EF_BLOCK_B] := 0;
        E.Raw[EF_FLAG1C] := (E.Raw[EF_FLAG1C] + 1) mod T57_V3_ROCK_FRAMES;
      end;

      { Last frame's reversal, collected now that the flush landing is done. }
      if E.Raw[EF_PARKED_VEL] <> 0 then
      begin
        E.Raw[EF_VEL_X] := E.Raw[EF_PARKED_VEL];
        E.Raw[EF_PARKED_VEL] := 0;
      end;

      if World.TileAtX(E, E.Raw[EF_VEL_X], False) >= World.SolidThreshold then
      begin
        E.Raw[EF_PARKED_VEL] := -E.Raw[EF_VEL_X];
        E.Raw[EF_VEL_X] := World.EdgeDistX(E, E.Raw[EF_VEL_X]);
      end;
      Inc(E.Raw[EF_POS_X], E.Raw[EF_VEL_X]);

      Inc(E.Raw[EF_VEL_Y], T57_V3_GRAVITY);
      if E.Raw[EF_VEL_Y] > T57_V3_TERMINAL then
        E.Raw[EF_VEL_Y] := T57_V3_TERMINAL;
      if World.TileAtY(E, E.Raw[EF_VEL_Y], False) >= World.SolidThreshold then
      begin
        World.PlaySound(T57_V3_SND_LAND);
        E.Raw[EF_VEL_Y] := World.EdgeDistY(E, E.Raw[EF_VEL_Y]);
        E.Raw[EF_STATE] := 0;
        E.Raw[EF_FLAG1C] := 0;
      end;
      Inc(E.Raw[EF_POS_Y], E.Raw[EF_VEL_Y]);
    end;

    if E.Raw[EF_STATE] = 2 then
    begin
      Inc(E.Raw[EF_BLOCK_B]);
      if E.Raw[EF_BLOCK_B] > T57_V3_TICKS then
      begin
        E.Raw[EF_BLOCK_B] := 0;
        Inc(E.Raw[EF_FLAG1C]);
        if E.Raw[EF_FLAG1C] > T57_V3_FRAMES - 1 then
        begin
          E.Raw[EF_FLAG1C] := 0;
          Inc(E.Raw[EF_CHILD_A]);
        end;

        if T57_V3_HATCH[D] < E.Raw[EF_CHILD_A] then
        begin
          for I := 1 to T57_V3_BURST do
          begin
            Slot := World.Spawn(EKIND_MINOR, T57_V3_BURST_TYPE,
                                E.Raw[EF_POS_X] - POSITION_BIAS,
                                E.Raw[EF_POS_Y] - POSITION_BIAS);
            World.SetSpawnField(Slot, EF_BLOCK_A + 1, 0);
            Facing := World.RandomBelow(DIR_COUNT);
            World.SetSpawnField(Slot, EF_FACING, Facing);
            World.SetSpawnField(Slot, EF_VEL_X,
              (World.RandomBelow(T57_V3_SPEED_SPREAD) + T57_V3_SPEED_BASE)
              * HalfExtent(DirVelX(Facing)));
            World.SetSpawnField(Slot, EF_VEL_Y,
              (World.RandomBelow(T57_V3_SPEED_SPREAD) + T57_V3_SPEED_BASE)
              * HalfExtent(DirVelY(Facing)));
          end;
          World.PlaySound(T57_V3_SND_HATCH);

          { An ACTOR, not a minor - and in state 3, which is the state
            Entity_UpdateAll touch-tests twice. }
          Slot := World.Spawn(EKIND_ACTOR, T57_V3_HATCHLING,
                              E.Raw[EF_POS_X] - POSITION_BIAS,
                              E.Raw[EF_POS_Y] - POSITION_BIAS);
          World.SetSpawnField(Slot, EF_STATE, T57_V3_HATCHLING_STATE);
          World.SetSpawnField(Slot, EF_HP, T57_V3_HATCHLING_HP);
          World.SetSpawnField(Slot, EF_TYPEF_0C, 1);
          World.SetSpawnField(Slot, EF_DEPTH, T57_V3_HATCHLING_DEPTH);
          World.DestroyEntity(E, False);
        end;
      end;
    end;
  end;
end;
procedure EntityUpdate_Type58_Mon_NiseMana(var E: TEntity; AGameState: Integer;
                              World: TEntityWorld);
var
  Frame: Integer;
begin
  Frame := E.Raw[EF_FLAG1C];
  if (Frame < 0) or (Frame > High(T58_SPRITES)) then
    Frame := 0;
  E.Raw[EF_ANIM_ID] := T58_SPRITES[Frame];

  { BEFORE the dying check, not after - so one killed on its first frame
    still takes the drop. }
  if E.Raw[EF_STATE] = 0 then
  begin
    E.Raw[EF_STATE] := 1;
    E.Raw[EF_FLAG1C] := T58_SLEEP_FRAME;
    Inc(E.Raw[EF_POS_Y], T58_SETTLE);
  end;

  if EntityUpdateDying(E, AGameState, World) then
    Exit;
  if World.Pool = nil then
    Exit;

  if EntitiesOverlap(E, World.Pool.Entity(SLOT_SINGLE_FIRST)^,
                     T58_TRIGGER_SCALE, T58_TRIGGER_SCALE)
     and (E.Raw[EF_STATE] = 1) then
  begin
    World.PlaySound(T58_SND_WAKE);
    E.Raw[EF_STATE] := 2;
    E.Raw[EF_FLAG1C] := 0;
    Inc(E.Raw[EF_POS_Y], T58_RISE);
  end;

  if E.Raw[EF_STATE] = 2 then
  begin
    { A full turn sums to zero, so this wobbles rather than travels. }
    Inc(E.Raw[EF_POS_X], DirVelX(E.Raw[EF_FACING]));
    E.Raw[EF_FACING] := (E.Raw[EF_FACING] + 1) mod DIR_COUNT;

    Inc(E.Raw[EF_BLOCK_B]);
    if E.Raw[EF_BLOCK_B] > T58_TICKS then
    begin
      E.Raw[EF_BLOCK_B] := 0;
      E.Raw[EF_FLAG1C] := (E.Raw[EF_FLAG1C] + 1) mod T58_FRAMES;
    end;
  end;
end;
procedure EntityUpdate_Type59_Mon_RedEye(var E: TEntity; AGameState: Integer;
                              World: TEntityWorld);
var
  Frame, D, Dist: Integer;
begin
  Frame := E.Raw[EF_FLAG1C];
  if (Frame < 0) or (Frame > High(T59_SPRITES)) then
    Frame := 0;
  E.Raw[EF_ANIM_ID] := T59_SPRITES[Frame];

  if EntityUpdateDying(E, AGameState, World) then
    Exit;
  if World.Pool = nil then
    Exit;

  D := World.PlayerDifficulty;
  if (D < 0) or (D > 2) then
    D := 0;

  if E.Raw[EF_STATE] = 0 then
    E.Raw[EF_STATE] := 1;

  if E.Raw[EF_STATE] = 1 then
  begin
    Dist := Abs(E.Raw[EF_POS_X]
                - World.Pool.Field(SLOT_SINGLE_FIRST, EF_POS_X));
    if Dist < 0 then
      Inc(Dist, 31);
    { A bare 0x50 - the only proximity test that is not difficulty-keyed. }
    if (Dist shr POSITION_SHIFT) < T59_WAKE_RANGE then
    begin
      E.Raw[EF_STATE] := 2;
      World.SpawnDebris(E, 0);
      E.Raw[EF_VEL_Y] := T59_RISE_VY;
    end;
  end;

  if E.Raw[EF_STATE] = 2 then
  begin
    E.Raw[EF_FLAG1C] := T59_RISE_FRAME;
    Inc(E.Raw[EF_VEL_Y], T59_GRAVITY);
    Inc(E.Raw[EF_POS_Y], E.Raw[EF_VEL_Y]);
    { Leaves at the APEX - when the velocity turns positive - not on a timer. }
    if E.Raw[EF_VEL_Y] > 0 then
    begin
      E.Raw[EF_STATE] := 3;
      E.Raw[EF_BLOCK_B] := 0;
      E.Raw[EF_FLAG1C] := T59_HANG_FRAME;
      E.Raw[EF_VEL_Y] := 0;
    end;
  end;

  if E.Raw[EF_STATE] = 3 then
  begin
    Inc(E.Raw[EF_BLOCK_B]);
    if E.Raw[EF_BLOCK_B] > T59_HANG_TICKS then
    begin
      E.Raw[EF_STATE] := 4;
      E.Raw[EF_BLOCK_B] := 0;
      E.Raw[EF_FLAG1C] := T59_HANG_FRAME;
      { ONCE, here, and never again - it cannot correct after this. }
      E.Raw[EF_FACING] :=
        AngleBetween(E.Raw[EF_POS_X], E.Raw[EF_POS_Y],
                     World.Pool.Field(SLOT_SINGLE_FIRST, EF_POS_X),
                     World.Pool.Field(SLOT_SINGLE_FIRST, EF_POS_Y));
    end;
  end;

  if E.Raw[EF_STATE] = 4 then
  begin
    Inc(E.Raw[EF_BLOCK_B]);
    if E.Raw[EF_BLOCK_B] > T59_FLY_TICKS then
    begin
      E.Raw[EF_BLOCK_B] := 0;
      Inc(E.Raw[EF_FLAG1C]);
      if E.Raw[EF_FLAG1C] > T59_FLY_LAST then
        E.Raw[EF_FLAG1C] := T59_FLY_FIRST;
    end;
    Inc(E.Raw[EF_POS_X], DirVelX(E.Raw[EF_FACING]) * T59_SPEED[D]);
    Inc(E.Raw[EF_POS_Y], DirVelY(E.Raw[EF_FACING]) * T59_SPEED[D]);
  end;
end;
procedure EntityUpdate_Type60_Mon_Golem(var E: TEntity; AGameState: Integer;
                              World: TEntityWorld);
var
  Frame, D, Slot, PlayerX: Integer;
begin
  Frame := E.Raw[EF_VARIANT] + E.Raw[EF_FLAG1C];
  if (Frame < 0) or (Frame > High(T60_SPRITES[0])) then
    Frame := 0;
  { By the SIGN, two ifs and no else. }
  if E.Raw[EF_VEL_X] < 0 then
    E.Raw[EF_ANIM_ID] := T60_SPRITES[0][Frame];
  if E.Raw[EF_VEL_X] > 0 then
    E.Raw[EF_ANIM_ID] := T60_SPRITES[1][Frame];

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
    E.Raw[EF_STATE] := 1;
    Inc(E.Raw[EF_POS_Y], T60_SETTLE);
    E.Raw[EF_VEL_X] := T60_SPEED[D] shl T60_SPEED_SHIFT;
  end;

  if E.Raw[EF_STATE] = 1 then
  begin
    Inc(E.Raw[EF_CHILD_A]);
    if E.Raw[EF_CHILD_A] > T60_TURN[D] then
    begin
      E.Raw[EF_CHILD_A] := 0;
      E.Raw[EF_VEL_X] := Compare(E.Raw[EF_POS_X], PlayerX)
                         * (1 shl T60_SPEED_SHIFT) * T60_SPEED[D];
      if E.Raw[EF_VEL_X] = 0 then
        E.Raw[EF_VEL_X] := T60_SPEED[D] shl T60_SPEED_SHIFT;
    end;
  end;

  if (E.Raw[EF_HP] < T60_RAGE_BELOW) and (E.Raw[EF_STATE] = 1) then
  begin
    E.Raw[EF_STATE] := 2;
    { A write, not a clamp - 10 becomes 3 and 1 becomes 3. }
    E.Raw[EF_HP] := T60_RAGE_HP;
    E.Raw[EF_VARIANT] := T60_RAGE_VARIANT;
    E.Raw[EF_VEL_X] := Compare(E.Raw[EF_POS_X], PlayerX)
                       * (1 shl T60_SPEED_SHIFT) * T60_RAGE[D];
    if E.Raw[EF_VEL_X] = 0 then
      E.Raw[EF_VEL_X] := T60_RAGE[D] shl T60_SPEED_SHIFT;

    { The small death's emitter, with its four parameters, used as a puff. }
    Slot := World.Spawn(EKIND_MINOR, EMITTER_TYPE,
                        E.Raw[EF_POS_X] - POSITION_BIAS,
                        E.Raw[EF_POS_Y] - POSITION_BIAS - T60_PUFF_LIFT);
    World.SetSpawnField(Slot, EF_BLOCK_A + 1, 8);
    World.SetSpawnField(Slot, EF_BLOCK_A + 2, 2);
    World.SetSpawnField(Slot, EF_BLOCK_A + 3, 1);
    World.SetSpawnField(Slot, EF_BLOCK_A + 4, 2);
  end;

  Dec(E.Raw[EF_BLOCK_B]);
  if E.Raw[EF_BLOCK_B] < 1 then
  begin
    { 12 frames while calm, 6 once enraged. }
    E.Raw[EF_BLOCK_B] := (E.Raw[EF_STATE] - 1) * T60_ANIM_STEP + T60_ANIM_BASE;
    E.Raw[EF_FLAG1C] := (E.Raw[EF_FLAG1C] + 1) mod T60_FRAMES;
  end;

  { A wall ahead, or no floor one tile down - either turns it round. }
  if (World.TileAtX(E, E.Raw[EF_VEL_X], False) >= World.SolidThreshold)
     or (World.TileAtX(E, E.Raw[EF_VEL_X], False, T60_LEDGE_PROBE)
         < World.SolidThreshold) then
    E.Raw[EF_VEL_X] := -E.Raw[EF_VEL_X];
  Inc(E.Raw[EF_POS_X], E.Raw[EF_VEL_X]);
end;
procedure EntityUpdate_Type61_Mon_HenaHena(var E: TEntity; AGameState: Integer;
                              World: TEntityWorld);
var
  Frame, D, Cap: Integer;
  Player: PEntity;
begin
  Frame := E.Raw[EF_FLAG1C];
  if (Frame < 0) or (Frame > High(T61_SPRITES)) then
    Frame := 0;
  E.Raw[EF_ANIM_ID] := T61_SPRITES[Frame];

  if EntityUpdateDying(E, AGameState, World) then
    Exit;
  if World.Pool = nil then
    Exit;

  D := World.PlayerDifficulty;
  if (D < 0) or (D > 2) then
    D := 0;
  Player := World.Pool.Entity(SLOT_SINGLE_FIRST);

  if E.Raw[EF_STATE] = 0 then
    E.Raw[EF_STATE] := 1;

  if E.Raw[EF_STATE] = 1 then
  begin
    Inc(E.Raw[EF_BLOCK_B]);
    if E.Raw[EF_BLOCK_B] > T61_TICKS then
    begin
      E.Raw[EF_BLOCK_B] := 0;
      E.Raw[EF_FLAG1C] := (E.Raw[EF_FLAG1C] + 1) mod T61_FRAMES;
    end;

    { A quarter turn a frame: 32, 0, -32, 0 - it sways. }
    Inc(E.Raw[EF_POS_X], DirVelX(E.Raw[EF_FACING]));
    E.Raw[EF_FACING] := (E.Raw[EF_FACING] + T61_IDLE_TURN) mod DIR_COUNT;

    if EntitiesOverlap(E, Player^, T61_WAKE_X, T61_WAKE_Y) then
    begin
      World.PlaySound(T61_SND_SQUEAK);
      E.Raw[EF_STATE] := 2;
      E.Raw[EF_BLOCK_B] := 0;
      E.Raw[EF_VEL_X] := 0;
      E.Raw[EF_FLAG1C] := T61_RUN_FIRST;
    end;
  end;

  if E.Raw[EF_STATE] = 2 then
  begin
    { Compare(player, self), not Compare(self, player) - this accelerates
      AWAY. Every other chaser has the arguments the other way round. }
    Inc(E.Raw[EF_VEL_X],
        Compare(Player^.Raw[EF_POS_X], E.Raw[EF_POS_X]) * T61_ACCEL);
    Cap := T61_SPEED[D] * T61_SPEED_SCALE;
    if E.Raw[EF_VEL_X] > Cap then
      E.Raw[EF_VEL_X] := Cap;
    if E.Raw[EF_VEL_X] < -Cap then
      E.Raw[EF_VEL_X] := -Cap;

    if World.TileAtX(E, E.Raw[EF_VEL_X], False) >= World.SolidThreshold then
      E.Raw[EF_VEL_X] := World.EdgeDistX(E, E.Raw[EF_VEL_X]);
    Inc(E.Raw[EF_POS_X], E.Raw[EF_VEL_X]);

    Inc(E.Raw[EF_VEL_Y], T61_GRAVITY);
    if E.Raw[EF_VEL_Y] > T61_TERMINAL then
      E.Raw[EF_VEL_Y] := T61_TERMINAL;
    if World.TileAtY(E, E.Raw[EF_VEL_Y], False) >= World.SolidThreshold then
      E.Raw[EF_VEL_Y] := World.EdgeDistY(E, E.Raw[EF_VEL_Y]);
    Inc(E.Raw[EF_POS_Y], E.Raw[EF_VEL_Y]);

    Inc(E.Raw[EF_BLOCK_B]);
    if E.Raw[EF_BLOCK_B] > T61_RUN_TICKS then
    begin
      E.Raw[EF_BLOCK_B] := 0;
      Inc(E.Raw[EF_FLAG1C]);
      if E.Raw[EF_FLAG1C] > T61_RUN_LAST then
        E.Raw[EF_FLAG1C] := T61_RUN_FIRST;
    end;

    Inc(E.Raw[EF_CHILD_A]);
    if E.Raw[EF_CHILD_A] > T61_SQUEAK_EVERY then
    begin
      E.Raw[EF_CHILD_A] := 0;
      World.PlaySound(T61_SND_SQUEAK);
    end;
  end;

  { In BOTH states, and last: catching it is what kills it. }
  if EntitiesOverlap(E, Player^, T61_TOUCH_SCALE, T61_TOUCH_SCALE) then
    E.Raw[EF_HP] := 0;
end;
procedure EntityUpdate_Type62_Mon_PenguinHeishi(var E: TEntity; AGameState: Integer;
                              World: TEntityWorld);
var
  Frame, D, PlayerX: Integer;
begin
  Frame := E.Raw[EF_FLAG1C];
  if (Frame < 0) or (Frame >= T62_FRAMES) then
    Frame := 0;
  if E.Raw[EF_VEL_X] < 0 then
    E.Raw[EF_ANIM_ID] := T62_SPRITES[0][Frame];
  if E.Raw[EF_VEL_X] > 0 then
    E.Raw[EF_ANIM_ID] := T62_SPRITES[1][Frame];

  if EntityUpdateDying(E, AGameState, World) then
    Exit;
  if World.Pool = nil then
    Exit;

  D := World.PlayerDifficulty;
  if (D < 0) or (D > 2) then
    D := 0;
  PlayerX := World.Pool.Field(SLOT_SINGLE_FIRST, EF_POS_X);

  { Recomputed from the geometry every frame - 2 while closing on you. }
  E.Raw[EF_VULN_KIND] := T62_VULN_AWAY;
  if ((PlayerX < E.Raw[EF_POS_X]) and (E.Raw[EF_VEL_X] < 0))
     or ((E.Raw[EF_POS_X] < PlayerX) and (E.Raw[EF_VEL_X] > 0)) then
    E.Raw[EF_VULN_KIND] := T62_VULN_TOWARDS;

  if E.Raw[EF_STATE] = 0 then
  begin
    E.Raw[EF_STATE] := 1;
    E.Raw[EF_VEL_X] := Compare(E.Raw[EF_POS_X], PlayerX);
    if E.Raw[EF_VEL_X] = 0 then
      E.Raw[EF_VEL_X] := 1;
    E.Raw[EF_VEL_X] := T62_SPEED[D] * E.Raw[EF_VEL_X] * T62_SPEED_SCALE;
    { Compare(vel, 0) is -sign(vel), so the rank offset goes BACKWARDS. }
    Inc(E.Raw[EF_POS_X],
        Compare(E.Raw[EF_VEL_X], 0) * T62_RANK_STEP * E.Raw[EF_VARIANT]);
  end;

  Dec(E.Raw[EF_BLOCK_B]);
  if E.Raw[EF_BLOCK_B] < 1 then
  begin
    E.Raw[EF_BLOCK_B] := T62_TICKS;
    E.Raw[EF_FLAG1C] := (E.Raw[EF_FLAG1C] + 1) mod T62_FRAMES;
  end;

  { A wall ahead, or no floor one tile down - type 60's probe pair. }
  if (World.TileAtX(E, E.Raw[EF_VEL_X], False) >= World.SolidThreshold)
     or (World.TileAtX(E, E.Raw[EF_VEL_X], False, T62_LEDGE_PROBE)
         < World.SolidThreshold) then
    E.Raw[EF_VEL_X] := -E.Raw[EF_VEL_X];

  { Frozen while EF_CHILD_A runs down. Nothing here ever sets it. }
  if E.Raw[EF_CHILD_A] = 0 then
    Inc(E.Raw[EF_POS_X], E.Raw[EF_VEL_X])
  else
    Dec(E.Raw[EF_CHILD_A]);
end;
procedure EntityUpdate_Type63_Mon_PenguinKnife(var E: TEntity; AGameState: Integer;
                              World: TEntityWorld);
var
  Frame, D, Slot, PlayerX: Integer;
  Player: PEntity;
begin
  Frame := E.Raw[EF_FLAG1C];
  if (Frame < 0) or (Frame > High(T63_SPRITES[0])) then
    Frame := 0;
  if E.Raw[EF_VEL_X] < 0 then
    E.Raw[EF_ANIM_ID] := T63_SPRITES[0][Frame];
  if E.Raw[EF_VEL_X] > 0 then
    E.Raw[EF_ANIM_ID] := T63_SPRITES[1][Frame];

  if EntityUpdateDying(E, AGameState, World) then
    Exit;
  if World.Pool = nil then
    Exit;

  D := World.PlayerDifficulty;
  if (D < 0) or (D > 2) then
    D := 0;
  Player := World.Pool.Entity(SLOT_SINGLE_FIRST);
  PlayerX := Player^.Raw[EF_POS_X];

  if E.Raw[EF_STATE] = 0 then
  begin
    E.Raw[EF_STATE] := 1;
    E.Raw[EF_VEL_X] := T63_WALK_SPEED;
  end;

  if E.Raw[EF_STATE] = 1 then
  begin
    Dec(E.Raw[EF_BLOCK_B]);
    if E.Raw[EF_BLOCK_B] < 1 then
    begin
      E.Raw[EF_BLOCK_B] := T63_TICKS;
      E.Raw[EF_FLAG1C] := (E.Raw[EF_FLAG1C] + 1) mod T63_FRAMES;
    end;

    if (World.TileAtX(E, E.Raw[EF_VEL_X], False) >= World.SolidThreshold)
       or (World.TileAtX(E, E.Raw[EF_VEL_X], False, T63_LEDGE_PROBE)
           < World.SolidThreshold) then
      E.Raw[EF_VEL_X] := -E.Raw[EF_VEL_X];
    Inc(E.Raw[EF_POS_X], E.Raw[EF_VEL_X]);

    if E.Raw[EF_CHILD_A] > 0 then
      Dec(E.Raw[EF_CHILD_A]);

    { Off cooldown, in range, AND already heading your way. }
    if (E.Raw[EF_CHILD_A] = 0)
       and EntitiesOverlap(E, Player^, T63_WAKE_X, T63_WAKE_Y)
       and (((PlayerX < E.Raw[EF_POS_X]) and (E.Raw[EF_VEL_X] < 0))
            or ((E.Raw[EF_POS_X] < PlayerX) and (E.Raw[EF_VEL_X] > 0))) then
    begin
      E.Raw[EF_STATE] := 2;
      E.Raw[EF_BLOCK_B] := 0;
      E.Raw[EF_CHILD_A] := 0;
      E.Raw[EF_FLAG1C] := T63_AIM_FRAME;
    end;
  end;

  if E.Raw[EF_STATE] = 2 then
  begin
    Inc(E.Raw[EF_CHILD_A]);
    { An equality, not a threshold - so exactly one shot. }
    if T63_FIRE_AT[D] = E.Raw[EF_CHILD_A] then
    begin
      World.PlaySound(T63_SND_FIRE);
      Slot := World.Spawn(EKIND_MINOR, T63_SHOT_TYPE,
                          E.Raw[EF_POS_X] - POSITION_BIAS
                            + E.Raw[EF_VEL_X] * T63_SHOT_AHEAD,
                          E.Raw[EF_POS_Y] - POSITION_BIAS + T63_SHOT_DROP);
      World.SetSpawnField(Slot, EF_VARIANT, T63_SHOT_VARIANT);
      World.SetSpawnField(Slot, EF_VEL_X, T63_SHOT_SPD[D] * E.Raw[EF_VEL_X]);
      E.Raw[EF_FLAG1C] := T63_FIRE_FRAME;
    end;

    if T63_RECOVER[D] < E.Raw[EF_CHILD_A] then
    begin
      E.Raw[EF_STATE] := 1;
      E.Raw[EF_CHILD_A] := T63_COOLDOWN[D];
      E.Raw[EF_FLAG1C] := 0;
      { And it always walks back the way it came. }
      E.Raw[EF_VEL_X] := -E.Raw[EF_VEL_X];
    end;
  end;
end;
procedure EntityUpdate_Type65_Mon_DorDor(var E: TEntity; AGameState: Integer;
                              var Inp: TInputState; World: TEntityWorld);
var
  Frame, D, Slot, Hop, Shot, PlayerX: Integer;
  Player: PEntity;
begin
  Frame := E.Raw[EF_FLAG1C];
  if (Frame < 0) or (Frame >= T65_FRAMES) then
    Frame := 0;
  E.Raw[EF_ANIM_ID] := T65_SPRITES[Frame];

  if EntityUpdateDying(E, AGameState, World) then
    Exit;
  if World.Pool = nil then
    Exit;

  D := World.PlayerDifficulty;
  if (D < 0) or (D > 2) then
    D := 0;
  Player := World.Pool.Entity(SLOT_SINGLE_FIRST);
  PlayerX := Player^.Raw[EF_POS_X];

  if E.Raw[EF_STATE] = 0 then
  begin
    { Above easy it gives ITSELF hp. Types 50, 52 and 54 take it away. }
    if D <> 0 then
      Inc(E.Raw[EF_HP], T65_HARD_HP_BONUS);
    E.Raw[EF_STATE] := 1;
    E.Raw[EF_CHILD_B] := E.Raw[EF_VARIANT];
  end;

  if E.Raw[EF_STATE] = 1 then
  begin
    E.Raw[EF_VEL_X] := Compare(E.Raw[EF_POS_X], PlayerX) shl T65_AIM_SHIFT;
    { The rising edge of ATTACK, inside a 10x2 box. Nothing else starts it. }
    if EntitiesOverlap(E, Player^, T65_WAKE_X, T65_WAKE_Y)
       and Inp.Button[T65_ATTACK_BUTTON]
       and (not Inp.ButtonLatch[T65_ATTACK_BUTTON]) then
    begin
      World.PlaySound(T65_SND_BLINK);
      E.Raw[EF_STATE] := 2;
      E.Raw[EF_DEATH_TIMER] := T65_BLINK;
      E.Raw[EF_TIMER] := T65_BLINK;
    end;
  end;

  if (E.Raw[EF_STATE] = 2) and (E.Raw[EF_DEATH_TIMER] = 0) then
  begin
    E.Raw[EF_STATE] := 3;
    E.Raw[EF_CHILD_A] := 0;
    Slot := World.Spawn(EKIND_MINOR, T65_SHOT_TYPE,
                        E.Raw[EF_POS_X] - POSITION_BIAS,
                        E.Raw[EF_POS_Y] - POSITION_BIAS);
    World.SetSpawnField(Slot, EF_VARIANT, T65_SHOT_VARIANT);
    Shot := Compare(E.Raw[EF_POS_X], PlayerX) * T65_SHOT_SPEED;
    if Shot = 0 then
      Shot := T65_SHOT_SPEED;
    World.SetSpawnField(Slot, EF_VEL_X, Shot);
    { Only this boss writes these two on its shot. }
    World.SetSpawnField(Slot, EF_VULN_KIND, T65_SHOT_VULN);
    World.SetSpawnField(Slot, EF_HIT_SOUND, T65_SHOT_HIT_SOUND);
  end;

  if E.Raw[EF_STATE] = 3 then
  begin
    E.Raw[EF_DEATH_TIMER] := 1;
    E.Raw[EF_TIMER] := 2;
    Inc(E.Raw[EF_CHILD_A]);
    if E.Raw[EF_CHILD_A] > T65_HOLD then
    begin
      World.PlaySound(T65_SND_BLINK);
      E.Raw[EF_STATE] := 4;
      E.Raw[EF_CHILD_A] := 0;
      Hop := E.Raw[EF_CHILD_B];
      if (Hop < 0) or (Hop >= T65_HOPS) then
        Hop := 0;
      Inc(E.Raw[EF_POS_X], T65_HOP[Hop] * T65_HOP_SCALE);
      E.Raw[EF_CHILD_B] := (E.Raw[EF_CHILD_B] + 1) mod T65_HOPS;
      E.Raw[EF_DEATH_TIMER] := T65_BLINK;
      E.Raw[EF_TIMER] := T65_BLINK;
    end;
  end;

  if (E.Raw[EF_STATE] = 4) and (E.Raw[EF_DEATH_TIMER] = 0) then
  begin
    E.Raw[EF_STATE] := 5;
    E.Raw[EF_CHILD_A] := 0;
  end;

  if E.Raw[EF_STATE] = 5 then
  begin
    Inc(E.Raw[EF_CHILD_A]);
    if E.Raw[EF_CHILD_A] > T65_HOLD then
    begin
      E.Raw[EF_STATE] := 1;
      E.Raw[EF_CHILD_A] := 0;
    end;
  end;

  { The bob, in every state. }
  Inc(E.Raw[EF_SHOTS]);
  if E.Raw[EF_SHOTS] > T65_BOB_TICKS then
  begin
    E.Raw[EF_SHOTS] := 0;
    E.Raw[EF_FACING] := (E.Raw[EF_FACING] + 1) mod DIR_COUNT;
  end;
  E.Raw[EF_VEL_Y] := HalfExtent(DirVelY(E.Raw[EF_FACING]));
  Inc(E.Raw[EF_POS_Y], E.Raw[EF_VEL_Y]);

  Inc(E.Raw[EF_BLOCK_B]);
  if E.Raw[EF_BLOCK_B] > T65_TICKS then
  begin
    E.Raw[EF_BLOCK_B] := 0;
    E.Raw[EF_FLAG1C] := (E.Raw[EF_FLAG1C] + 1) mod T65_FRAMES;
  end;
end;
procedure EntityUpdate_Type66_GiantBall(var E: TEntity; AGameState: Integer;
                              World: TEntityWorld);
var
  Frame, Slot, Period: Integer;
begin
  Frame := E.Raw[EF_FLAG1C];
  if E.Raw[EF_VARIANT] = T66_ANCHOR then
  begin
    if (Frame < 0) or (Frame >= T66_V0_FRAMES) then
      Frame := 0;
    E.Raw[EF_ANIM_ID] := T66_V0_SPRITES[Frame];
  end;
  if E.Raw[EF_VARIANT] = T66_SATELLITE then
  begin
    if (Frame < 0) or (Frame >= T66_V1_FRAMES) then
      Frame := 0;
    E.Raw[EF_ANIM_ID] := T66_V1_SPRITES[Frame];
  end;

  if EntityUpdateDying(E, AGameState, World) then
    Exit;

  { A placement parameter, not a timer - see the T66_ block. }
  Period := E.Raw[EF_BLOCK_A + 1];

  if E.Raw[EF_VARIANT] = T66_ANCHOR then
  begin
    if E.Raw[EF_STATE] = 0 then
    begin
      E.Raw[EF_STATE] := 1;
      E.Raw[EF_TYPEF_0C] := 0;
      E.Raw[EF_VULN_KIND] := 0;
      E.Raw[EF_DEPTH] := T66_ANCHOR_DEPTH;
      Slot := World.Spawn(EKIND_MINOR, T66_SELF_TYPE,
                          E.Raw[EF_POS_X] - POSITION_BIAS
                            - World.Layer.DeltaX,
                          E.Raw[EF_POS_Y] - POSITION_BIAS
                            + E.Raw[EF_FACING] * Period * T66_LIFT_UNIT
                            - World.Layer.DeltaY);
      World.SetSpawnField(Slot, EF_VARIANT, T66_SATELLITE);
      World.SetSpawnField(Slot, EF_FACING, E.Raw[EF_FACING]);
      World.SetSpawnField(Slot, EF_BLOCK_A + 1, Period);
    end;

    Inc(E.Raw[EF_BLOCK_B]);
    if Period < E.Raw[EF_BLOCK_B] then
    begin
      E.Raw[EF_BLOCK_B] := 0;
      { `< 1`, where the satellite below asks `< 0`. }
      if Compare(E.Raw[EF_FACING], 0) < 1 then
        Inc(E.Raw[EF_FLAG1C])
      else
        Dec(E.Raw[EF_FLAG1C]);
      if E.Raw[EF_FLAG1C] > T66_V0_FRAMES - 1 then
        E.Raw[EF_FLAG1C] := 0;
      if E.Raw[EF_FLAG1C] < 0 then
        E.Raw[EF_FLAG1C] := T66_V0_FRAMES - 1;
    end;
  end;

  if E.Raw[EF_VARIANT] = T66_SATELLITE then
  begin
    Inc(E.Raw[EF_BLOCK_B]);
    if E.Raw[EF_BLOCK_B] > T66_V1_TICKS then
    begin
      E.Raw[EF_BLOCK_B] := 0;
      E.Raw[EF_FLAG1C] := (E.Raw[EF_FLAG1C] + 1) mod T66_V1_FRAMES;
    end;

    Dec(E.Raw[EF_CHILD_A]);
    if E.Raw[EF_CHILD_A] < 1 then
    begin
      E.Raw[EF_CHILD_A] := Period;
      { The MAGNITUDE of EF_FACING is a speed, not a heading. }
      E.Raw[EF_VEL_X] := Abs(E.Raw[EF_FACING])
                         * HalfExtent(DirVelX(E.Raw[EF_CHILD_B]));
      E.Raw[EF_VEL_Y] := Abs(E.Raw[EF_FACING])
                         * HalfExtent(DirVelY(E.Raw[EF_CHILD_B]));
      { And its SIGN is which way round the orbit goes. }
      if Compare(E.Raw[EF_FACING], 0) < 0 then
        Dec(E.Raw[EF_CHILD_B])
      else
        Inc(E.Raw[EF_CHILD_B]);
      if E.Raw[EF_CHILD_B] > DIR_COUNT - 1 then
      begin
        E.Raw[EF_CHILD_B] := 0;
        World.PlaySound(T66_SND_LAP);
      end;
      if E.Raw[EF_CHILD_B] < 0 then
      begin
        E.Raw[EF_CHILD_B] := DIR_COUNT - 1;
        World.PlaySound(T66_SND_LAP);
      end;
    end;

    Inc(E.Raw[EF_POS_X], E.Raw[EF_VEL_X]);
    Inc(E.Raw[EF_POS_Y], E.Raw[EF_VEL_Y]);
  end;
end;
procedure EntityUpdate_Type67_Mon_TurtleBomb(var E: TEntity; AGameState: Integer;
                              World: TEntityWorld);
var
  Frame, D, Slot, PlayerX: Integer;
  Player: PEntity;
begin
  Frame := E.Raw[EF_FLAG1C];
  if (Frame < 0) or (Frame > High(T67_SPRITES)) then
    Frame := 0;
  E.Raw[EF_ANIM_ID] := T67_SPRITES[Frame];

  if EntityUpdateDying(E, AGameState, World) then
    Exit;
  if World.Pool = nil then
    Exit;

  D := World.PlayerDifficulty;
  if (D < 0) or (D > 2) then
    D := 0;
  Player := World.Pool.Entity(SLOT_SINGLE_FIRST);
  PlayerX := Player^.Raw[EF_POS_X];

  if E.Raw[EF_STATE] = 0 then
  begin
    E.Raw[EF_STATE] := 1;
    E.Raw[EF_VEL_X] := Compare(E.Raw[EF_POS_X], PlayerX);
    if E.Raw[EF_VEL_X] = 0 then
      E.Raw[EF_VEL_X] := 1;
    E.Raw[EF_VEL_X] := E.Raw[EF_VEL_X] shl T67_WALK_SHIFT;
  end;

  { Only the two moving states tick the walk cycle. }
  if (E.Raw[EF_STATE] = 1) or (E.Raw[EF_STATE] = 3) then
  begin
    Dec(E.Raw[EF_BLOCK_B]);
    if E.Raw[EF_BLOCK_B] < 1 then
    begin
      E.Raw[EF_BLOCK_B] := T67_TICKS;
      E.Raw[EF_FLAG1C] := (E.Raw[EF_FLAG1C] + 1) mod T67_FRAMES;
    end;
  end;

  if E.Raw[EF_STATE] = 1 then
  begin
    if (World.TileAtX(E, E.Raw[EF_VEL_X], False) >= World.SolidThreshold)
       or (World.TileAtX(E, E.Raw[EF_VEL_X], False, T67_LEDGE_PROBE)
           < World.SolidThreshold) then
      E.Raw[EF_VEL_X] := -E.Raw[EF_VEL_X];
    Inc(E.Raw[EF_POS_X], E.Raw[EF_VEL_X]);
    Dec(E.Raw[EF_CHILD_A]);

    if (((PlayerX < E.Raw[EF_POS_X]) and (E.Raw[EF_VEL_X] < 0))
        or ((E.Raw[EF_POS_X] < PlayerX) and (E.Raw[EF_VEL_X] > 0)))
       and EntitiesOverlap(E, Player^, T67_RANGE[D], T67_WAKE_Y)
       and (E.Raw[EF_CHILD_A] < 1) then
    begin
      E.Raw[EF_STATE] := 2;
      E.Raw[EF_BLOCK_B] := 0;
      E.Raw[EF_CHILD_A] := 0;
      E.Raw[EF_FLAG1C] := 0;
    end;
  end;

  if E.Raw[EF_STATE] = 2 then
  begin
    Inc(E.Raw[EF_CHILD_A]);
    if E.Raw[EF_CHILD_A] = T67_LAY_AT then
    begin
      World.PlaySound(T67_SND_LAY);
      Slot := World.Spawn(EKIND_MINOR, T67_EGG_TYPE,
                          E.Raw[EF_POS_X] - POSITION_BIAS
                            - World.Layer.DeltaX,
                          E.Raw[EF_POS_Y] - POSITION_BIAS - T67_EGG_LIFT
                            - World.Layer.DeltaY);
      World.SetSpawnField(Slot, EF_VARIANT, T67_EGG_VARIANT);
      World.SetSpawnField(Slot, EF_VEL_X, E.Raw[EF_VEL_X] * 2);
      World.SetSpawnField(Slot, EF_VEL_Y, T67_EGG_VY);
      World.SetSpawnField(Slot, EF_VULN_KIND, 0);
      E.Raw[EF_FLAG1C] := T67_LAY_FRAME;
    end;

    if E.Raw[EF_CHILD_A] > T67_LAY_END then
    begin
      E.Raw[EF_STATE] := 3;
      E.Raw[EF_BLOCK_B] := 0;
      E.Raw[EF_CHILD_A] := 0;
      E.Raw[EF_FLAG1C] := 0;
      { AWAY - Compare's arguments the other way round, and a bigger shift. }
      E.Raw[EF_VEL_X] := Compare(PlayerX, E.Raw[EF_POS_X]);
      if E.Raw[EF_VEL_X] = 0 then
        E.Raw[EF_VEL_X] := 1;
      E.Raw[EF_VEL_X] := E.Raw[EF_VEL_X] shl T67_BOLT_SHIFT;
    end;
  end;

  if E.Raw[EF_STATE] = 3 then
  begin
    ApproachZero(E.Raw[EF_VEL_X], T67_FRICTION);
    if (World.TileAtX(E, E.Raw[EF_VEL_X], False) >= World.SolidThreshold)
       or (World.TileAtX(E, E.Raw[EF_VEL_X], False, T67_LEDGE_PROBE)
           < World.SolidThreshold) then
      E.Raw[EF_VEL_X] := -E.Raw[EF_VEL_X];
    Inc(E.Raw[EF_POS_X], E.Raw[EF_VEL_X]);

    if E.Raw[EF_VEL_X] = 0 then
    begin
      E.Raw[EF_STATE] := 1;
      E.Raw[EF_CHILD_A] := T67_COOLDOWN[D];
      E.Raw[EF_VEL_X] := Compare(E.Raw[EF_POS_X], PlayerX);
      if E.Raw[EF_VEL_X] = 0 then
        E.Raw[EF_VEL_X] := 1;
      E.Raw[EF_VEL_X] := E.Raw[EF_VEL_X] shl T67_WALK_SHIFT;
    end;
  end;
end;
procedure EntityUpdate_Type68(var E: TEntity; AGameState: Integer;
                              World: TEntityWorld);
var
  Frame: Integer;
begin
  { Only state 3 writes a sprite - a caught one keeps the frame it had. }
  if E.Raw[EF_STATE] = T68_RISING_STATE then
  begin
    Frame := E.Raw[EF_FLAG1C];
    if (Frame < 0) or (Frame >= T68_FRAMES) then
      Frame := 0;
    E.Raw[EF_ANIM_ID] := T68_SPRITES[Frame];
  end;

  if EntityUpdateDying(E, AGameState, World) then
    Exit;

  if E.Raw[EF_STATE] = T68_RISING_STATE then
  begin
    Inc(E.Raw[EF_POS_Y], T68_RISE);
    Inc(E.Raw[EF_BLOCK_B]);
    if E.Raw[EF_BLOCK_B] > T68_TICKS then
    begin
      E.Raw[EF_BLOCK_B] := 0;
      Inc(E.Raw[EF_FLAG1C]);
      if E.Raw[EF_FLAG1C] > T68_FRAMES - 1 then
      begin
        World.DestroyEntity(E, False);
        Exit;
      end;
    end;

    { Both insets from the same entry, one per frame. }
    Frame := E.Raw[EF_FLAG1C];
    if (Frame < 0) or (Frame >= T68_FRAMES) then
      Frame := 0;
    E.Raw[EF_INSET_PCT_X] := T68_INSET[Frame];
    E.Raw[EF_INSET_PCT_Y] := T68_INSET[Frame];
  end;

  if E.Raw[EF_STATE] = T68_CAUGHT_STATE then
  begin
    Inc(E.Raw[EF_VEL_Y], T68_GRAVITY);
    if E.Raw[EF_VEL_Y] > T68_TERMINAL then
      E.Raw[EF_VEL_Y] := T68_TERMINAL;
    if World.TileAtY(E, E.Raw[EF_VEL_Y], False) >= World.SolidThreshold then
    begin
      E.Raw[EF_VEL_Y] := World.EdgeDistY(E, E.Raw[EF_VEL_Y]);
      Inc(E.Raw[EF_POS_Y], E.Raw[EF_VEL_Y]);
      { WITH loot - the only destroy in any handler here that passes True. }
      World.DestroyEntity(E, True);
      Exit;
    end;
    Inc(E.Raw[EF_POS_Y], E.Raw[EF_VEL_Y]);
  end;
end;
procedure EntityUpdate_Type70_AngrySwitch(var E: TEntity; AGameState: Integer;
                              World: TEntityWorld);
var
  Frame: Integer;
begin
  Frame := E.Raw[EF_FLAG1C];
  if (Frame < 0) or (Frame > High(T70_V0_SPRITES)) then
    Frame := 0;
  if E.Raw[EF_VARIANT] = 0 then
    E.Raw[EF_ANIM_ID] := T70_V0_SPRITES[Frame];
  if E.Raw[EF_VARIANT] = T70_WALKER then
    E.Raw[EF_ANIM_ID] := T70_V1_SPRITES[Frame];

  if EntityUpdateDying(E, AGameState, World) then
    Exit;

  if E.Raw[EF_STATE] = 0 then
  begin
    E.Raw[EF_STATE] := 1;
    E.Raw[EF_VEL_X] := T70_WALK_SPEED;
  end;

  if E.Raw[EF_STATE] = 1 then
  begin
    Inc(E.Raw[EF_BLOCK_B]);
    if E.Raw[EF_BLOCK_B] > T70_TICKS then
    begin
      E.Raw[EF_BLOCK_B] := 0;
      E.Raw[EF_FLAG1C] := (E.Raw[EF_FLAG1C] + 1) mod T70_FRAMES;
    end;

    { The one line the two variants differ by. }
    if E.Raw[EF_VARIANT] = T70_WALKER then
    begin
      if (World.TileAtX(E, E.Raw[EF_VEL_X], False) >= World.SolidThreshold)
         or (World.TileAtX(E, E.Raw[EF_VEL_X], False, T70_LEDGE_PROBE)
             < World.SolidThreshold) then
        E.Raw[EF_VEL_X] := -E.Raw[EF_VEL_X];
      Inc(E.Raw[EF_POS_X], E.Raw[EF_VEL_X]);
    end;

    { Not a threshold and not zero - ANY value other than 100. }
    if E.Raw[EF_HP] <> T70_FULL_HP then
    begin
      E.Raw[EF_BLOCK_B] := 0;
      E.Raw[EF_STATE] := 2;
    end;
  end;

  if E.Raw[EF_STATE] = 2 then
  begin
    E.Raw[EF_FLAG1C] := T70_WOUND_FRAME;
    Inc(E.Raw[EF_BLOCK_B]);
    if E.Raw[EF_BLOCK_B] > T70_DYING_FOR then
      E.Raw[EF_HP] := 0;
  end;
end;
procedure EntityUpdate_Type71_BouncyCat(var E: TEntity; AGameState: Integer;
                              World: TEntityWorld);
var
  Frame, D, PlayerX: Integer;

  procedure AimAndGo;
  begin
    E.Raw[EF_VEL_X] := Compare(E.Raw[EF_POS_X], PlayerX);
    if E.Raw[EF_VEL_X] = 0 then
      E.Raw[EF_VEL_X] := 1;
    E.Raw[EF_VEL_X] := E.Raw[EF_VEL_X] shl T71_SPEED_SHIFT;
  end;

begin
  Frame := E.Raw[EF_FLAG1C];
  if (Frame < 0) or (Frame >= T71_ROW) then
    Frame := 0;
  if E.Raw[EF_VEL_X] < 0 then
    E.Raw[EF_ANIM_ID] := T71_SPRITES[0][Frame];
  if E.Raw[EF_VEL_X] > 0 then
    E.Raw[EF_ANIM_ID] := T71_SPRITES[1][Frame];

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
    E.Raw[EF_STATE] := 1;
    AimAndGo;
    if D = 0 then
      Inc(E.Raw[EF_HP], T71_EASY_HP_PENALTY);
  end;

  if E.Raw[EF_STATE] = 1 then
  begin
    E.Raw[EF_VULN_KIND] := T71_VULN_WALKING;

    Dec(E.Raw[EF_BLOCK_B]);
    if E.Raw[EF_BLOCK_B] < 1 then
    begin
      E.Raw[EF_BLOCK_B] := T71_WALK_TICKS;
      E.Raw[EF_FLAG1C] := (E.Raw[EF_FLAG1C] + 1) mod T71_WALK_FRAMES;
    end;

    if (World.TileAtX(E, E.Raw[EF_VEL_X], False) >= World.SolidThreshold)
       or (World.TileAtX(E, E.Raw[EF_VEL_X], False, T71_LEDGE_PROBE)
           < World.SolidThreshold) then
      E.Raw[EF_VEL_X] := -E.Raw[EF_VEL_X];
    Inc(E.Raw[EF_POS_X], E.Raw[EF_VEL_X]);

    { Only while it can be seen - off screen it walks for ever. }
    if not IsOffScreen(E, T71_OFFSCREEN_MARGIN) then
      Inc(E.Raw[EF_CHILD_A]);

    if T71_WALK[D] < E.Raw[EF_CHILD_A] then
    begin
      E.Raw[EF_STATE] := 2;
      E.Raw[EF_BLOCK_B] := 0;
      E.Raw[EF_CHILD_A] := 0;
      E.Raw[EF_FLAG1C] := T71_CURL_FIRST;
      World.PlaySound(T71_SND_CURL);
      E.Raw[EF_DEATH_TIMER] := T71_STUN;
    end;
  end;

  if E.Raw[EF_STATE] = 2 then
  begin
    E.Raw[EF_VULN_KIND] := T71_VULN_RESTING;

    Inc(E.Raw[EF_BLOCK_B]);
    if E.Raw[EF_BLOCK_B] > T71_CURL_TICKS then
    begin
      E.Raw[EF_BLOCK_B] := 0;
      Inc(E.Raw[EF_FLAG1C]);
      if E.Raw[EF_FLAG1C] > T71_CURL_LAST then
      begin
        E.Raw[EF_FLAG1C] := T71_CURL_FIRST;
        { Counting completed LOOPS, which is what the rest table measures. }
        Inc(E.Raw[EF_CHILD_A]);
      end;
    end;

    if T71_REST[D] < E.Raw[EF_CHILD_A] then
    begin
      E.Raw[EF_STATE] := 1;
      E.Raw[EF_BLOCK_B] := 0;
      E.Raw[EF_CHILD_A] := 0;
      E.Raw[EF_FLAG1C] := 0;
      AimAndGo;
      World.PlaySound(T71_SND_CURL);
      E.Raw[EF_DEATH_TIMER] := T71_STUN;
    end;
  end;
end;
procedure EntityUpdate_Type72(var E: TEntity; AGameState: Integer;
                              World: TEntityWorld);
var
  Frame, D, Slot, Dir: Integer;
begin
  Frame := E.Raw[EF_FLAG1C];
  if E.Raw[EF_VARIANT] = 0 then
  begin
    if (Frame < 0) or (Frame >= T72_V0_FRAMES) then
      Frame := 0;
    E.Raw[EF_ANIM_ID] := T72_V0_SPRITES[Frame];
  end;
  if E.Raw[EF_VARIANT] = 1 then
  begin
    { Select by heading rather than frame, rounding toward zero. }
    Dir := E.Raw[EF_FACING];
    if Dir < 0 then
      Inc(Dir, (1 shl T72_DIR_SHIFT) - 1);
    Dir := Dir shr T72_DIR_SHIFT;
    if (Dir < 0) or (Dir >= T72_V1_DIRS) then
      Dir := 0;
    E.Raw[EF_ANIM_ID] := T72_V1_SPRITES[Dir];
  end;
  if E.Raw[EF_VARIANT] = 2 then
  begin
    if (Frame < 0) or (Frame >= T72_V2_FRAMES) then
      Frame := 0;
    E.Raw[EF_ANIM_ID] := T72_V2_SPRITES[Frame];
  end;

  if EntityUpdateDying(E, AGameState, World) then
    Exit;

  D := World.PlayerDifficulty;
  if (D < 0) or (D > 2) then
    D := 0;

  if E.Raw[EF_VARIANT] = 0 then
  begin
    Inc(E.Raw[EF_BLOCK_B]);
    if E.Raw[EF_BLOCK_B] > T72_V0_TICKS then
    begin
      E.Raw[EF_BLOCK_B] := 0;
      E.Raw[EF_FLAG1C] := (E.Raw[EF_FLAG1C] + 1) mod T72_V0_FRAMES;
    end;

    if E.Raw[EF_STATE] = 0 then
    begin
      E.Raw[EF_STATE] := 1;
      E.Raw[EF_FIELD_C0] := 1;
      E.Raw[EF_CLASS] := T72_FALLER_CLASS;
      E.Raw[EF_VULN_KIND] := T72_FALLER_VULN;
    end;

    if E.Raw[EF_STATE] = 1 then
    begin
      Inc(E.Raw[EF_POS_X], E.Raw[EF_VEL_X]);
      Inc(E.Raw[EF_VEL_Y], T72_GRAVITY);
      if E.Raw[EF_VEL_Y] > T72_TERMINAL then
        E.Raw[EF_VEL_Y] := T72_TERMINAL;
      Inc(E.Raw[EF_POS_Y], E.Raw[EF_VEL_Y]);
    end;
  end;

  if E.Raw[EF_VARIANT] = 1 then
  begin
    E.Raw[EF_DEPTH] := T72_FLYER_DEPTH;
    { It moves by its heading and never writes EF_VEL_X or EF_VEL_Y. }
    Inc(E.Raw[EF_POS_X], DirVelX(E.Raw[EF_FACING]) * T72_SPEED[D]);
    Inc(E.Raw[EF_POS_Y], DirVelY(E.Raw[EF_FACING]) * T72_SPEED[D]);

    Inc(E.Raw[EF_CHILD_A]);
    if E.Raw[EF_CHILD_A] > T72_FLYER_LIFE then
    begin
      World.DestroyEntity(E, False);
      Exit;
    end;

    Inc(E.Raw[EF_CHILD_B]);
    if T72_TRAIL[D] < E.Raw[EF_CHILD_B] then
    begin
      E.Raw[EF_CHILD_B] := 0;
      Slot := World.Spawn(EKIND_MINOR, T72_SELF_TYPE,
                          E.Raw[EF_POS_X] - POSITION_BIAS
                            - World.Layer.DeltaX,
                          E.Raw[EF_POS_Y] - POSITION_BIAS
                            - World.Layer.DeltaY);
      World.SetSpawnField(Slot, EF_OWNER, E.Raw[EF_SLOT]);
      World.SetSpawnField(Slot, EF_VARIANT, T72_TRAIL_VARIANT);
      { The flyer's OWN velocity fields, which it never updates - so this is
        whatever it was spawned with, not where it is going. }
      World.SetSpawnField(Slot, EF_VEL_X, E.Raw[EF_VEL_X]);
      World.SetSpawnField(Slot, EF_VEL_Y, E.Raw[EF_VEL_Y]);
    end;
  end;

  if E.Raw[EF_VARIANT] = 2 then
  begin
    E.Raw[EF_DEPTH] := T72_TRAIL_DEPTH;
    { Scenery, not a second hazard. }
    E.Raw[EF_TOUCH_KIND] := 0;
    if E.Raw[EF_DEATH_TIMER] = 0 then
      E.Raw[EF_DEATH_TIMER] := T72_TRAIL_BLINK;

    Inc(E.Raw[EF_POS_X], E.Raw[EF_VEL_X]);
    Inc(E.Raw[EF_POS_Y], E.Raw[EF_VEL_Y]);

    Inc(E.Raw[EF_BLOCK_B]);
    if E.Raw[EF_BLOCK_B] > T72_V2_TICKS then
    begin
      E.Raw[EF_BLOCK_B] := 0;
      Inc(E.Raw[EF_FLAG1C]);
      if E.Raw[EF_FLAG1C] > T72_V2_FRAMES - 1 then
        World.DestroyEntity(E, False);
    end;
  end;
end;
procedure EntityUpdate_Type74(var E: TEntity; AGameState: Integer;
                              World: TEntityWorld);
var
  Frame, D, Aim, I, N, Slot: Integer;
begin
  Frame := E.Raw[EF_FLAG1C];
  if E.Raw[EF_VARIANT] = 0 then
  begin
    if (Frame < 0) or (Frame >= T74_V0_FRAMES) then
      Frame := 0;
    E.Raw[EF_ANIM_ID] := T74_V0_SPRITES[Frame];
  end;
  if E.Raw[EF_VARIANT] = 1 then
  begin
    if (Frame < 0) or (Frame >= T74_V1_FRAMES) then
      Frame := 0;
    E.Raw[EF_ANIM_ID] := T74_V1_SPRITES[Frame];
  end;

  if EntityUpdateDying(E, AGameState, World) then
    Exit;
  if World.Pool = nil then
    Exit;

  D := World.PlayerDifficulty;
  if (D < 0) or (D > 2) then
    D := 0;

  if E.Raw[EF_VARIANT] = 0 then
  begin
    Inc(E.Raw[EF_BLOCK_B]);
    if E.Raw[EF_BLOCK_B] > T74_V0_TICKS then
    begin
      E.Raw[EF_BLOCK_B] := 0;
      Inc(E.Raw[EF_FLAG1C]);
      if E.Raw[EF_FLAG1C] > T74_V0_FRAMES - 1 then
      begin
        { Type 56's fan, rebuilt with type 56's numbers. }
        Aim := AngleBetween(E.Raw[EF_POS_X], E.Raw[EF_POS_Y],
                            World.Pool.Field(SLOT_SINGLE_FIRST, EF_POS_X),
                            World.Pool.Field(SLOT_SINGLE_FIRST, EF_POS_Y));
        Inc(Aim, T74_SKEW[D]);
        if Aim < 0 then
          Inc(Aim, DIR_COUNT);

        N := T74_COUNT[D];
        if N >= 0 then
          for I := 0 to N do
          begin
            Slot := World.Spawn(EKIND_MINOR, T74_SELF_TYPE,
                                E.Raw[EF_POS_X] - POSITION_BIAS
                                  - World.Layer.DeltaX,
                                E.Raw[EF_POS_Y] - POSITION_BIAS
                                  - World.Layer.DeltaY);
            World.SetSpawnField(Slot, EF_VARIANT, T74_SHOT_VARIANT);
            World.SetSpawnField(Slot, EF_VEL_X,
                                T74_SPEED[D] * DirVelX(Aim));
            World.SetSpawnField(Slot, EF_VEL_Y,
                                T74_SPEED[D] * DirVelY(Aim));
            if Aim + T74_FAN_STEP > DIR_COUNT - 1 then
              Aim := Aim - T74_FAN_WRAP
            else
              Inc(Aim, T74_FAN_STEP);
          end;

        { The write that lets type 73 leave state 5. }
        World.Pool.SetField(E.Raw[EF_OWNER], EF_STATE, T74_OWNER_STATE);
        World.DestroyEntity(E, False);
        Exit;
      end;
    end;
  end;

  if E.Raw[EF_VARIANT] = 1 then
  begin
    Inc(E.Raw[EF_BLOCK_B]);
    if E.Raw[EF_BLOCK_B] > T74_V1_TICKS then
    begin
      E.Raw[EF_BLOCK_B] := 0;
      E.Raw[EF_FLAG1C] := (E.Raw[EF_FLAG1C] + 1) mod T74_V1_FRAMES;
    end;
    Inc(E.Raw[EF_POS_X], E.Raw[EF_VEL_X]);
    Inc(E.Raw[EF_POS_Y], E.Raw[EF_VEL_Y]);
  end;
end;
procedure EntityUpdate_Type79(var E: TEntity; AGameState: Integer;
                              World: TEntityWorld);
var
  Owner, Dir, Frame, Slot, OwnerFrame: Integer;

  function Clamp(V, Hi: Integer): Integer;
  begin
    Result := V;
    if (Result < 0) or (Result > Hi) then
      Result := 0;
  end;

begin
  if EntityUpdateDying(E, AGameState, World) then
    Exit;
  if World.Pool = nil then
    Exit;

  Owner := E.Raw[EF_OWNER];
  { Everything it emits dies with it. }
  if World.Pool.Field(Owner, EF_HP) = 0 then
    E.Raw[EF_HP] := 0;
  Dir := Ord(World.Pool.Field(Owner, EF_VEL_X) > 0);
  Frame := E.Raw[EF_FLAG1C];

  if E.Raw[EF_VARIANT] = 0 then
    E.Raw[EF_ANIM_ID] := T79_V0_SPRITES[Dir];
  if E.Raw[EF_VARIANT] = 1 then
    E.Raw[EF_ANIM_ID] := T79_V1_SPRITES[Dir];
  if E.Raw[EF_VARIANT] = 2 then
    E.Raw[EF_ANIM_ID] := T79_V2_SPRITES[Dir];
  if (E.Raw[EF_VARIANT] = 3) and (E.Raw[EF_VEL_X] > 0) then
    E.Raw[EF_ANIM_ID] := T79_V3_SPRITES[0][Clamp(Frame, 1)];
  if (E.Raw[EF_VARIANT] = 3) and (E.Raw[EF_VEL_X] < 0) then
    E.Raw[EF_ANIM_ID] := T79_V3_SPRITES[1][Clamp(Frame, 1)];
  if E.Raw[EF_VARIANT] = 4 then
    E.Raw[EF_ANIM_ID] := T79_V4_SPRITES[Clamp(Frame, T79_V4_FRAMES - 1)];
  if E.Raw[EF_VARIANT] = 5 then
    E.Raw[EF_ANIM_ID] := T79_V5_SPRITES[Clamp(Frame, T79_SUMMON_LAST)];

  if E.Raw[EF_VARIANT] = 0 then
  begin
    E.Raw[EF_POS_X] := T79_V0_X[Dir] * T78_OFFSET_SCALE
                       + World.Pool.Field(Owner, EF_POS_X);
    OwnerFrame := World.Pool.Field(Owner, EF_FLAG1C);
    if (OwnerFrame = 1) or (OwnerFrame = 2) or (OwnerFrame = 4) then
      E.Raw[EF_POS_Y] := World.Pool.Field(Owner, EF_POS_Y) + T79_V0_HIGH
    else
      E.Raw[EF_POS_Y] := World.Pool.Field(Owner, EF_POS_Y) + T79_V0_LOW;
    { and this piece goes four phases before type 78 does }
    if World.Pool.Field(Owner, EF_BLOCK_A + 1) = T79_V0_LEAVES_AT_PHASE then
      E.Raw[EF_HP] := 0;
  end;

  if E.Raw[EF_VARIANT] = 1 then
  begin
    E.Raw[EF_TOUCH_KIND] := 0;
    if E.Raw[EF_DEATH_TIMER] = 0 then
      E.Raw[EF_DEATH_TIMER] := 2;
    E.Raw[EF_POS_X] := T79_V1_X[Dir] * T78_OFFSET_SCALE
                       + World.Pool.Field(Owner, EF_POS_X);
    E.Raw[EF_POS_Y] := T79_V1_Y[0] * T78_OFFSET_SCALE
                       + World.Pool.Field(Owner, EF_POS_Y);
    Inc(E.Raw[EF_BLOCK_B]);
    if E.Raw[EF_BLOCK_B] > T79_V1_LIFE then
    begin
      World.DestroyEntity(E, False);
      Exit;
    end;
  end;

  if E.Raw[EF_VARIANT] = 2 then
  begin
    E.Raw[EF_TOUCH_KIND] := 0;
    if E.Raw[EF_DEATH_TIMER] = 0 then
      E.Raw[EF_DEATH_TIMER] := 2;
    E.Raw[EF_POS_X] := T79_V2_X[Dir] * T78_OFFSET_SCALE
                       + World.Pool.Field(Owner, EF_POS_X);
    E.Raw[EF_POS_Y] := T79_V2_Y[0] * T78_OFFSET_SCALE
                       + World.Pool.Field(Owner, EF_POS_Y);
    Inc(E.Raw[EF_BLOCK_B]);
    if E.Raw[EF_BLOCK_B] > T79_V2_LIFE then
    begin
      World.DestroyEntity(E, False);
      Exit;
    end;
  end;

  if E.Raw[EF_VARIANT] = 3 then
  begin
    Inc(E.Raw[EF_CHILD_A]);
    if E.Raw[EF_CHILD_A] > T79_LOB_SND_EVERY then
    begin
      E.Raw[EF_CHILD_A] := 0;
      World.PlaySound(T79_SND_LOB);
    end;

    if World.TileAtX(E, E.Raw[EF_VEL_X], False) >= World.SolidThreshold then
    begin
      E.Raw[EF_VEL_X] := 0;
      E.Raw[EF_DEATH_TIMER] := T79_LOB_FUSE;
    end;
    Inc(E.Raw[EF_POS_X], E.Raw[EF_VEL_X]);

    Inc(E.Raw[EF_BLOCK_B]);
    if E.Raw[EF_BLOCK_B] > 2 then
    begin
      E.Raw[EF_BLOCK_B] := 0;
      E.Raw[EF_FLAG1C] := (E.Raw[EF_FLAG1C] + 1) mod 2;
    end;

    Inc(E.Raw[EF_CHILD_B]);
    if (E.Raw[EF_CHILD_B] > T79_LOB_LIFE) and (E.Raw[EF_DEATH_TIMER] = 0) then
      E.Raw[EF_DEATH_TIMER] := T79_LOB_FUSE;
    { At ONE, not zero: Entity_UpdateAll ticks the timer after this runs. }
    if E.Raw[EF_DEATH_TIMER] = 1 then
    begin
      World.DestroyEntity(E, False);
      Exit;
    end;
  end;

  if E.Raw[EF_VARIANT] = 4 then
  begin
    E.Raw[EF_TOUCH_KIND] := 0;
    E.Raw[EF_VULN_KIND] := 0;
    Inc(E.Raw[EF_BLOCK_B]);
    if E.Raw[EF_BLOCK_B] > 2 then
    begin
      E.Raw[EF_BLOCK_B] := 0;
      Inc(E.Raw[EF_FLAG1C]);
      if E.Raw[EF_FLAG1C] > T79_V4_FRAMES - 1 then
      begin
        World.DestroyEntity(E, False);
        Exit;
      end;
    end;
  end;

  if E.Raw[EF_VARIANT] = 5 then
  begin
    E.Raw[EF_TOUCH_KIND] := 0;

    if E.Raw[EF_STATE] = 0 then
    begin
      Inc(E.Raw[EF_BLOCK_B]);
      if E.Raw[EF_BLOCK_B] > 2 then
      begin
        E.Raw[EF_BLOCK_B] := 0;
        E.Raw[EF_FLAG1C] := (E.Raw[EF_FLAG1C] + 1) mod 2;
      end;
      Inc(E.Raw[EF_CHILD_A]);
      if E.Raw[EF_CHILD_A] > T79_SUMMON_WAIT then
      begin
        E.Raw[EF_STATE] := 1;
        E.Raw[EF_CHILD_A] := 0;
        E.Raw[EF_FLAG1C] := 0;
      end;
    end;

    if E.Raw[EF_STATE] = 1 then
    begin
      Inc(E.Raw[EF_BLOCK_B]);
      if E.Raw[EF_BLOCK_B] > 2 then
      begin
        E.Raw[EF_BLOCK_B] := 0;
        Inc(E.Raw[EF_FLAG1C]);
        if E.Raw[EF_FLAG1C] > T79_SUMMON_LAST then
        begin
          Inc(E.Raw[EF_CHILD_B]);
          if E.Raw[EF_CHILD_B] < T79_SUMMONS then
          begin
            E.Raw[EF_STATE] := 0;
            E.Raw[EF_FLAG1C] := 0;
            Slot := World.Spawn(EKIND_MINOR, T79_FLYER_TYPE,
                                E.Raw[EF_POS_X] - POSITION_BIAS
                                  - World.Layer.DeltaX,
                                E.Raw[EF_POS_Y] - POSITION_BIAS
                                  - World.Layer.DeltaY);
            World.SetSpawnField(Slot, EF_OWNER, E.Raw[EF_SLOT]);
            World.SetSpawnField(Slot, EF_VARIANT, T79_FLYER_VARIANT);
            World.SetSpawnField(Slot, EF_FACING,
              AngleBetween(E.Raw[EF_POS_X], E.Raw[EF_POS_Y],
                           World.Pool.Field(SLOT_SINGLE_FIRST, EF_POS_X),
                           World.Pool.Field(SLOT_SINGLE_FIRST, EF_POS_Y)));
            World.PlaySound(T79_SND_SUMMON);
          end
          else
          begin
            { The fourth pass hands the boss back its idle state. }
            World.Pool.SetField(Owner, EF_STATE, 1);
            World.Pool.SetField(Owner, EF_BLOCK_B, 0);
            World.Pool.SetField(Owner, EF_FLAG1C, 0);
            World.DestroyEntity(E, False);
          end;
        end;
      end;
    end;
  end;
end;

end.
