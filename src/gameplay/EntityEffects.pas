{ Puffs, sparks, explosions, trails, debris and floating messages - things that exist to be looked at and remove themselves. EffectLatch travels with them: it is the shared death-timer arm for types 4 to 7 and nothing else uses it.

  Split out of EntityHandlers, which holds the dispatch and everything
  these share. The handlers themselves are unchanged. }

unit EntityEffects;

{$MODE DELPHI}{$H+}

interface

uses
  SysUtils, Entities, GameState, SoundTable, PlayerState, Player,
  Directions, EntityHandlers;

{ A moving puff whose sprite row is selected by its direction.
  going - and by the SIGN of its velocity, so a puff with no horizontal speed
  at all keeps whatever sprite it had. }
procedure EntityUpdate_Type03(var E: TEntity; AGameState: Integer;
                              World: TEntityWorld);
{ Runs for two frames, then ends. }
procedure EntityUpdate_Type04(var E: TEntity; AGameState: Integer;
                              World: TEntityWorld);
{ An effect attached to another entity: its position is its
  OWNER's plus an offset, and the offset shrinks toward zero along its heading
  every frame, so it retracts into whatever fired it. }
procedure EntityUpdate_Type05(var E: TEntity; AGameState: Integer;
                              World: TEntityWorld);
{ The spark emitted by an explosion. Its sprite row comes from
  block A[1], which EntityUpdate_Type33_Explosion sets when it spawns one. }
procedure EntityUpdate_Type06(var E: TEntity; AGameState: Integer;
                              World: TEntityWorld);
{ Four frames in one of two rows selected by the variant. }
procedure EntityUpdate_Type07(var E: TEntity; AGameState: Integer;
                              World: TEntityWorld);
{ Four-frame puff behavior. See TYPE8_SPRITES above. }
procedure EntityUpdate_Type08(var E: TEntity; AGameState: Integer;
                              World: TEntityWorld);
{ Runs six frames, then ends. }
procedure EntityUpdate_Type10(var E: TEntity; AGameState: Integer;
                              World: TEntityWorld);
{ A continuous four-frame loop whose death timer is kept
  topping back up. }
procedure EntityUpdate_Type11(var E: TEntity; AGameState: Integer);
{ A candle that acts as a switch when shot with Fire
  at it. It owns the two flame entities above it. }
procedure EntityUpdate_Type23_Candle(var E: TEntity; AGameState: Integer;
                              World: TEntityWorld);
{ The rising GET effect left by a collected Mana Stone. Its variant says
  which of the two messages to show, and Entity_TouchPickup sets it. }
procedure EntityUpdate_Type26(var E: TEntity; AGameState: Integer;
                              World: TEntityWorld);
{ Invisible emitter behavior. See EMIT_EVERY above for the block-A
  configuration it runs off. }
procedure EntityUpdate_Type32_Emitter(var E: TEntity; AGameState: Integer;
                                      World: TEntityWorld);
{ Explosion behavior. See BOOM_SPRITES above. }
procedure EntityUpdate_Type33_Explosion(var E: TEntity; AGameState: Integer;
                                        World: TEntityWorld);
{ Static decoration with touch kind 0, so it cannot be
  touched or hurt, and the handler only animates. Two placements in the whole
  game, both unconditional in the final arena. Variant 1 is unreachable - no
  record selects it and nothing spawns type 80. }
procedure EntityUpdate_Type80_Fx_ArenaEmber(var E: TEntity; AGameState: Integer;
                              World: TEntityWorld);

implementation

procedure EffectLatch(var E: TEntity);
begin
  if E.Raw[EF_STATE] = 0 then
  begin
    E.Raw[EF_STATE] := 1;
    E.Raw[EF_DEATH_TIMER] := EFFECT_LATCH_TIMER;
  end;
end;
procedure EntityUpdate_Type03(var E: TEntity; AGameState: Integer;
                              World: TEntityWorld);
var
  Frame: Integer;
begin
  Frame := E.Raw[EF_FLAG1C];
  if (Frame < 0) or (Frame >= T3_FRAMES) then
    Frame := 0;
  { Choose by velocity sign; a stationary puff keeps its current sprite. }
  if E.Raw[EF_VEL_X] < 0 then
    E.Raw[EF_ANIM_ID] := T3_SPRITES[0][Frame];
  if E.Raw[EF_VEL_X] > 0 then
    E.Raw[EF_ANIM_ID] := T3_SPRITES[1][Frame];

  if AGameState <> GS_PLAY then
    Exit;

  Inc(E.Raw[EF_POS_X], E.Raw[EF_VEL_X]);
  Inc(E.Raw[EF_BLOCK_B]);
  if E.Raw[EF_BLOCK_B] > T3_TICKS then
  begin
    E.Raw[EF_BLOCK_B] := 0;
    Inc(E.Raw[EF_FLAG1C]);
  end;
  if E.Raw[EF_FLAG1C] > T3_FRAMES - 1 then
    World.DestroyEntity(E, False);
end;
procedure EntityUpdate_Type04(var E: TEntity; AGameState: Integer;
                              World: TEntityWorld);
var
  Frame: Integer;
begin
  Frame := E.Raw[EF_FLAG1C];
  if (Frame < 0) or (Frame >= T4_FRAMES) then
    Frame := 0;
  E.Raw[EF_ANIM_ID] := T4_SPRITES[Frame];

  if AGameState <> GS_PLAY then
    Exit;

  EffectLatch(E);
  Inc(E.Raw[EF_BLOCK_B]);
  if E.Raw[EF_BLOCK_B] > T4_TICKS then
  begin
    E.Raw[EF_BLOCK_B] := 0;
    Inc(E.Raw[EF_FLAG1C]);
  end;
  if E.Raw[EF_FLAG1C] > T4_FRAMES - 1 then
    World.DestroyEntity(E, False);
end;
procedure EntityUpdate_Type05(var E: TEntity; AGameState: Integer;
                              World: TEntityWorld);
var
  Frame, Owner: Integer;
begin
  Frame := E.Raw[EF_FLAG1C];
  if (Frame < 0) or (Frame >= T5_FRAMES) then
    Frame := 0;
  E.Raw[EF_ANIM_ID] := T5_SPRITES[Frame];

  { Its position is not its own: it is the owner's plus the offset held in the
    velocity fields. Written EVERY frame including outside play, so it stays
    pinned to its owner through a dialogue box. }
  Owner := E.Raw[EF_OWNER];
  if (World.Pool <> nil) and (Owner >= 0) and (Owner < ENTITY_COUNT) then
  begin
    E.Raw[EF_POS_X] := World.Pool.Field(Owner, EF_POS_X) + E.Raw[EF_VEL_X];
    E.Raw[EF_POS_Y] := World.Pool.Field(Owner, EF_POS_Y) + E.Raw[EF_VEL_Y];
  end;

  if AGameState <> GS_PLAY then
    Exit;

  { The offset shrinks along the heading, so it retracts into the owner. }
  Dec(E.Raw[EF_VEL_X], DirVelX(E.Raw[EF_FACING]));
  Dec(E.Raw[EF_VEL_Y], DirVelY(E.Raw[EF_FACING]));

  EffectLatch(E);
  Inc(E.Raw[EF_BLOCK_B]);
  if E.Raw[EF_BLOCK_B] > T5_TICKS then
  begin
    E.Raw[EF_BLOCK_B] := 0;
    Inc(E.Raw[EF_FLAG1C]);
  end;
  if E.Raw[EF_FLAG1C] > T5_FRAMES - 1 then
    World.DestroyEntity(E, False);
end;
procedure EntityUpdate_Type06(var E: TEntity; AGameState: Integer;
                              World: TEntityWorld);
var
  Frame, Row: Integer;
begin
  Frame := E.Raw[EF_FLAG1C];
  if (Frame < 0) or (Frame >= T6_FRAMES) then
    Frame := 0;
  Row := E.Raw[EF_BLOCK_A + 1];
  if (Row < 0) or (Row >= T6_ROWS) then
    Row := 0;
  E.Raw[EF_ANIM_ID] := T6_SPRITES[Row][Frame];

  if AGameState <> GS_PLAY then
    Exit;

  Inc(E.Raw[EF_POS_X], E.Raw[EF_VEL_X]);
  Inc(E.Raw[EF_POS_Y], E.Raw[EF_VEL_Y]);

  EffectLatch(E);
  Inc(E.Raw[EF_BLOCK_B]);
  if E.Raw[EF_BLOCK_B] > T6_TICKS then
  begin
    E.Raw[EF_BLOCK_B] := 0;
    Inc(E.Raw[EF_FLAG1C]);
  end;
  if E.Raw[EF_FLAG1C] > T6_FRAMES - 1 then
    World.DestroyEntity(E, False);
end;
procedure EntityUpdate_Type07(var E: TEntity; AGameState: Integer;
                              World: TEntityWorld);
var
  Frame, Row: Integer;
begin
  Frame := E.Raw[EF_FLAG1C];
  Row := E.Raw[EF_VARIANT];
  { The terminating frame is read from the contiguous table before the entity
    is destroyed, so it can cross into the next row. }
  E.Raw[EF_ANIM_ID] := SpriteDatum(T7_AT + Row * SPRITE_ROW + Frame);

  if AGameState <> GS_PLAY then
    Exit;

  EffectLatch(E);
  Inc(E.Raw[EF_BLOCK_B]);
  if E.Raw[EF_BLOCK_B] > T7_TICKS then
  begin
    E.Raw[EF_BLOCK_B] := 0;
    Inc(E.Raw[EF_FLAG1C]);
  end;
  if E.Raw[EF_FLAG1C] > T7_FRAMES - 1 then
    World.DestroyEntity(E, False);
end;
procedure EntityUpdate_Type08(var E: TEntity; AGameState: Integer;
                              World: TEntityWorld);
var
  Frame: Integer;
begin
  Frame := E.Raw[EF_FLAG1C];
  if (Frame < 0) or (Frame >= TYPE8_FRAMES) then
    Frame := 0;
  E.Raw[EF_ANIM_ID] := TYPE8_SPRITES[Frame];

  if AGameState <> GS_PLAY then
    Exit;

  Inc(E.Raw[EF_BLOCK_B]);
  if E.Raw[EF_BLOCK_B] > TYPE8_TICKS then
  begin
    E.Raw[EF_BLOCK_B] := 0;
    Inc(E.Raw[EF_FLAG1C]);
  end;
  if E.Raw[EF_FLAG1C] > TYPE8_FRAMES - 1 then
    World.DestroyEntity(E, False);
end;
procedure EntityUpdate_Type10(var E: TEntity; AGameState: Integer;
                              World: TEntityWorld);
var
  Frame: Integer;
begin
  Frame := E.Raw[EF_FLAG1C];
  if (Frame < 0) or (Frame >= T10_FRAMES) then
    Frame := 0;
  E.Raw[EF_ANIM_ID] := T10_SPRITES[Frame];

  if AGameState <> GS_PLAY then
    Exit;

  Inc(E.Raw[EF_BLOCK_B]);
  if E.Raw[EF_BLOCK_B] > T10_TICKS then
  begin
    E.Raw[EF_BLOCK_B] := 0;
    Inc(E.Raw[EF_FLAG1C]);
    { Note the destroy is INSIDE the advance here, unlike types 3..7 where it
      is a separate test every frame. Same effect, and kept as written. }
    if E.Raw[EF_FLAG1C] > T10_FRAMES - 1 then
      World.DestroyEntity(E, False);
  end;
end;
procedure EntityUpdate_Type11(var E: TEntity; AGameState: Integer);
var
  Frame: Integer;
begin
  Frame := E.Raw[EF_FLAG1C];
  if (Frame < 0) or (Frame >= T11_FRAMES) then
    Frame := 0;
  E.Raw[EF_ANIM_ID] := T11_SPRITES[Frame];

  if AGameState <> GS_PLAY then
    Exit;

  { Topped back up whenever it reaches zero, so this never actually dies of
    it - Entity_UpdateAll's flicker reads the same field, which is why an
    entity of this type blinks. }
  if E.Raw[EF_DEATH_TIMER] = 0 then
    E.Raw[EF_DEATH_TIMER] := T11_DEATH_TIMER;

  Inc(E.Raw[EF_BLOCK_B]);
  if E.Raw[EF_BLOCK_B] > T11_TICKS then
  begin
    E.Raw[EF_BLOCK_B] := 0;
    { WRAPS. No Entity_Destroy anywhere in this handler. }
    E.Raw[EF_FLAG1C] := (E.Raw[EF_FLAG1C] + 1) mod T11_FRAMES;
  end;
end;
procedure EntityUpdate_Type23_Candle(var E: TEntity; AGameState: Integer;
                              World: TEntityWorld);
var
  Slot: Integer;
begin
  E.Raw[EF_ANIM_ID] := T23_SPRITE;
  if EntityUpdateDying(E, AGameState, World) then
    Exit;

  if E.Raw[EF_STATE] = 1 then
  begin
    { Minus the layer delta: this frame's scroll has already been carried into
      the torch, and a child placed from its position would otherwise take it
      a second time. }
    Slot := World.Spawn(EKIND_MINOR, T23_FLAME_LOW_TYPE,
                        E.Raw[EF_POS_X] - POSITION_BIAS - World.Layer.DeltaX,
                        E.Raw[EF_POS_Y] - POSITION_BIAS - World.Layer.DeltaY
                          - T23_FLAME_LOW_LIFT);
    E.Raw[EF_CHILD_A] := Slot;
    Slot := World.Spawn(EKIND_MINOR, T23_FLAME_HIGH_TYPE,
                        E.Raw[EF_POS_X] - POSITION_BIAS - World.Layer.DeltaX,
                        E.Raw[EF_POS_Y] - POSITION_BIAS - World.Layer.DeltaY
                          - T23_FLAME_HIGH_LIFT);
    E.Raw[EF_CHILD_B] := Slot;
    E.Raw[EF_STATE] := 2;
  end;

  if E.Raw[EF_STATE] = 3 then
  begin
    { Slot 0 is the player and cannot be a child, so it also represents none. }
    if (E.Raw[EF_CHILD_A] <> 0) and (World.Pool <> nil) then
    begin
      World.DestroyEntity(World.Pool.Entity(E.Raw[EF_CHILD_A])^, False);
      E.Raw[EF_CHILD_A] := 0;
    end;
    if (E.Raw[EF_CHILD_B] <> 0) and (World.Pool <> nil) then
    begin
      World.DestroyEntity(World.Pool.Entity(E.Raw[EF_CHILD_B])^, False);
      E.Raw[EF_CHILD_B] := 0;
    end;
    E.Raw[EF_STATE] := 0;
  end;
end;
procedure EntityUpdate_Type26(var E: TEntity; AGameState: Integer;
                              World: TEntityWorld);
var
  Variant: Integer;
begin
  Variant := E.Raw[EF_VARIANT];
  if (Variant < 0) or (Variant >= TYPE26_VARIANTS) then
    Variant := 0;
  E.Raw[EF_ANIM_ID] := TYPE26_SPRITES[Variant];

  if AGameState <> GS_PLAY then
    Exit;

  { Straight up, at a fixed rate - no gravity and no horizontal drift. }
  Dec(E.Raw[EF_POS_Y], TYPE26_LIFT);

  Inc(E.Raw[EF_BLOCK_B]);
  if E.Raw[EF_BLOCK_B] > TYPE26_LIFETIME then
    World.DestroyEntity(E, False);
end;
procedure EntityUpdate_Type32_Emitter(var E: TEntity; AGameState: Integer;
                                      World: TEntityWorld);
var
  Radius, OffX, OffY: Integer;
begin
  if AGameState <> GS_PLAY then
    Exit;

  { The countdown ticks only during play, and the rest happens only on the
    frame it goes below zero. }
  Dec(E.Raw[EMIT_NEXT]);
  if E.Raw[EMIT_NEXT] >= 0 then
    Exit;

  Dec(E.Raw[EMIT_SOUND_NEXT]);
  if E.Raw[EMIT_SOUND_NEXT] < 0 then
  begin
    E.Raw[EMIT_SOUND_NEXT] := E.Raw[EMIT_SOUND_EVERY];
    World.PlaySound(SND_BOM01);
  end;

  { Scatter in PIXELS: plus or minus radius * 8. }
  Radius := E.Raw[EMIT_RADIUS];
  OffX := World.RandomBelow(Radius shl EMIT_RADIUS_SHIFT) - Radius * 8;
  OffY := World.RandomBelow(Radius shl EMIT_RADIUS_SHIFT) - Radius * 8;
  World.Spawn(EKIND_MINOR, EMIT_SPAWN_TYPE,
              E.Raw[EF_POS_X] - POSITION_BIAS + OffX * 32,
              E.Raw[EF_POS_Y] - POSITION_BIAS + OffY * 32);

  E.Raw[EMIT_NEXT] := E.Raw[EMIT_EVERY];
  Inc(E.Raw[EMIT_COUNT]);
  if E.Raw[EMIT_TOTAL] < E.Raw[EMIT_COUNT] then
    World.DestroyEntity(E, True);
end;
procedure EntityUpdate_Type33_Explosion(var E: TEntity; AGameState: Integer;
                                        World: TEntityWorld);
var
  I, Slot, Facing, Frame: Integer;
begin
  Frame := E.Raw[EF_FLAG1C];
  { Clamp malformed frame state before indexing the explosion animation. }
  if (Frame < 0) or (Frame >= BOOM_FRAMES) then
    Frame := 0;
  E.Raw[EF_ANIM_ID] := BOOM_SPRITES[Frame];

  if AGameState <> GS_PLAY then
    Exit;

  if E.Raw[EF_STATE] = 0 then
  begin
    E.Raw[EF_STATE] := 1;
    for I := 1 to BOOM_SPARKS do
    begin
      Slot := World.Spawn(EKIND_MINOR, BOOM_SPARK_TYPE,
                          E.Raw[EF_POS_X] - POSITION_BIAS,
                          E.Raw[EF_POS_Y] - POSITION_BIAS);
      World.SetSpawnField(Slot, EF_BLOCK_A + 1, 0);

      { One heading, both tables - a radial burst. The two speeds are drawn
        separately, so the spread is an ellipse rather than a circle. }
      Facing := World.RandomBelow(DIR_COUNT);
      World.SetSpawnField(Slot, EF_FACING, Facing);
      World.SetSpawnField(Slot, EF_VEL_X,
        (World.RandomBelow(BOOM_SPEED_MAX) + 1) * HalfExtent(DirVelX(Facing)));
      World.SetSpawnField(Slot, EF_VEL_Y,
        (World.RandomBelow(BOOM_SPEED_MAX) + 1) * HalfExtent(DirVelY(Facing)));
    end;
  end;

  Inc(E.Raw[EF_BLOCK_B]);
  if E.Raw[EF_BLOCK_B] > BOOM_TICKS then
  begin
    E.Raw[EF_BLOCK_B] := 0;
    Inc(E.Raw[EF_FLAG1C]);
  end;
  if E.Raw[EF_FLAG1C] > BOOM_FRAMES - 1 then
    World.DestroyEntity(E, False);
end;
procedure EntityUpdate_Type80_Fx_ArenaEmber(var E: TEntity; AGameState: Integer;
                              World: TEntityWorld);
var
  Frame: Integer;
begin
  Frame := E.Raw[EF_FLAG1C];
  if E.Raw[EF_VARIANT] = 0 then
  begin
    if (Frame < 0) or (Frame >= T80_V0_FRAMES) then
      Frame := 0;
    E.Raw[EF_ANIM_ID] := T80_V0_SPRITES[Frame];
  end;
  if E.Raw[EF_VARIANT] = 1 then
  begin
    if (Frame < 0) or (Frame >= T80_V1_FRAMES) then
      Frame := 0;
    E.Raw[EF_ANIM_ID] := T80_V1_SPRITES[Frame];
  end;

  if EntityUpdateDying(E, AGameState, World) then
    Exit;

  { Shared by both variants - and variant 1 adds a second one below, which
    is why it runs at more than twice variant 0's rate. }
  Inc(E.Raw[EF_BLOCK_B]);

  if E.Raw[EF_VARIANT] = 0 then
  begin
    if E.Raw[EF_STATE] = 0 then
      E.Raw[EF_STATE] := 1;
    if E.Raw[EF_BLOCK_B] > T80_V0_TICKS then
    begin
      E.Raw[EF_BLOCK_B] := 0;
      E.Raw[EF_FLAG1C] := (E.Raw[EF_FLAG1C] + 1) mod T80_V0_FRAMES;
    end;
  end;

  if E.Raw[EF_VARIANT] = 1 then
  begin
    if E.Raw[EF_DEATH_TIMER] = 0 then
      E.Raw[EF_DEATH_TIMER] := T80_V1_BLINK;
    Inc(E.Raw[EF_BLOCK_B]);
    if E.Raw[EF_BLOCK_B] > T80_V1_TICKS then
    begin
      E.Raw[EF_BLOCK_B] := 0;
      E.Raw[EF_FLAG1C] := (E.Raw[EF_FLAG1C] + 1) mod T80_V1_FRAMES;
    end;
  end;
end;

end.
