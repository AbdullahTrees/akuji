{ A pixel baseline for the renderer.

  WHY THIS EXISTS

  Everything else the game does has a test that can fail. Rendering did not:
  the only check that touched it counted non-black pixels after drawing a map,
  which proves something was painted and nothing about what. That is the same
  gap that let the music ship silent - a test that reports success whatever the
  output looks like.

  It matters now because the renderer is about to be rewritten onto SDL. A
  wrong colour key, a scaling filter, an off-by-one source rectangle or a
  transparent blit that became opaque all produce a game that runs, passes
  every other test, and looks wrong.

  So: draw fixed scenes and checksum the pixels. The numbers below were taken
  from the LCL renderer, which is the one the game shipped with. SDL has to
  reproduce them.

  WHAT EACH SCENE ISOLATES

  Four scenes rather than one, because a single number tells you something
  broke and not what:

    clear      FillRect, and the surface being the size it claims
    tiles      CopyRect - an opaque blit from a sheet, the commonest operation
    sprites    a transparent blit, which is where a colour key goes wrong
    text       glyph blits, the other transparent path, and the one with its
               own key colour

  Each scene also reports how many pixels its draw CHANGED, and a draw that
  changed none fails on its own. Without that a renderer that drew nothing
  could be pinned once and would then agree with itself for ever. }

unit RenderTests;

{$MODE DELPHI}{$H+}

interface

uses
  Classes, SysUtils, Graphics,
  QdaArchive, Surfaces, Sprites, TileMaps, GameFont, Stages, Entities;

function SelfTestRender(Log: TStrings): Integer;

implementation

type
  TScene = record
    Name: string;
    Sum: LongWord;
    Changed: Integer;   { pixels this draw altered, against the scene before }
  end;

type
  TPixels = array of LongWord;

{ Every pixel, in order. Read once per scene rather than per comparison,
  because Canvas.Pixels is a round trip into the widgetset each time. }
procedure ReadSurface(Bmp: TBitmap; out Buf: TPixels);
var
  X, Y: Integer;
begin
  SetLength(Buf, Bmp.Width * Bmp.Height);
  for Y := 0 to Bmp.Height - 1 do
    for X := 0 to Bmp.Width - 1 do
      Buf[Y * Bmp.Width + X] := LongWord(Bmp.Canvas.Pixels[X, Y]);
end;

{ Order-sensitive fold, with the position mixed in.

  Position matters because a plain XOR of colours makes an all-black screen
  checksum to zero whatever its size - which is both indistinguishable from an
  unpinned baseline and unable to tell a 320x240 clear from a 1x1 one. Mixing
  the index in gives every geometry its own value. }
function Checksum(const Buf: TPixels): LongWord;
var
  I: Integer;
begin
  Result := $811C9DC5;
  for I := 0 to High(Buf) do
    Result := ((Result shl 1) or (Result shr 31))
              xor (Buf[I] + LongWord(I) * 2654435761);
end;

{ How many pixels this draw actually altered.

  The count of non-black pixels does not work: text drawn over a tile changes
  the picture without changing how many pixels are lit, so a font that stopped
  rendering would leave it untouched. Differences against the previous scene
  say what each draw call did. }
function CountChanged(const A, B: TPixels): Integer;
var
  I: Integer;
begin
  Result := 0;
  for I := 0 to High(A) do
    if A[I] <> B[I] then
      Inc(Result);
end;

{ The pinned values, recorded from the LCL renderer. A zero here means the
  scene has not been pinned yet: the test then reports what it measured and
  does not fail, so a new scene can be added without inventing a number. }
const
  BASELINE_CLEAR   = $A3804348;
  BASELINE_TILES   = $39A6A29B;
  BASELINE_SPRITES = $A4E5FFD0;
  BASELINE_TEXT    = $477F6671;

function SelfTestRender(Log: TStrings): Integer;
var
  GameDir: string;
  Arch: TQdaArchive;
  Surf: TSurfaceSet;
  Sprite: TSpriteSet;
  Map: TTileMap;
  Font: TGameFont;
  Stages: TStageTable;
  Bmp: TBitmap;
  Scenes: array[0..3] of TScene;
  Expected: array[0..3] of LongWord;
  Prev, Cur: TPixels;
  I, Tileset, MapId: Integer;

  procedure Snap(Index: Integer; const AName: string);
  begin
    ReadSurface(Bmp, Cur);
    Scenes[Index].Name := AName;
    Scenes[Index].Sum := Checksum(Cur);
    if Length(Prev) = Length(Cur) then
      Scenes[Index].Changed := CountChanged(Prev, Cur)
    else
      Scenes[Index].Changed := Length(Cur);
    Prev := Copy(Cur, 0, Length(Cur));
  end;

begin
  Result := 0;
  GameDir := IncludeTrailingPathDelimiter(ParamStr(2));
  Log.Add(Format('game dir: %s', [GameDir]));
  Log.Add('');

  Expected[0] := BASELINE_CLEAR;
  Expected[1] := BASELINE_TILES;
  Expected[2] := BASELINE_SPRITES;
  Expected[3] := BASELINE_TEXT;

  Arch := TQdaArchive.Create(GameDir + 'bmp.qda');
  Surf := TSurfaceSet.Create(Arch);
  Sprite := TSpriteSet.Create;
  Map := TTileMap.Create;
  Stages := TStageTable.Create;
  Bmp := TBitmap.Create;
  Font := nil;
  try
    if Stages.Load(GameDir) <= 0 then
    begin
      Log.Add('FAILED: stage table did not load');
      Exit(1);
    end;

    { Stage 1 throughout: it is the first room of the game, so its map and its
      surface set are the ones a player sees first and the ones most likely to
      be noticed if they break. }
    Surf.LoadSet(GameDir, Stages.SurfaceSet[1]);
    Sprite.LoadSet(GameDir, Stages.SurfaceSet[1]);
    Tileset := Stages.Tileset[1, 0];
    MapId := Stages.Layer[1, 0];
    if not Map.Load(GameDir, MapId) then
    begin
      Log.Add(Format('FAILED: map %.3d did not load', [MapId]));
      Exit(1);
    end;

    Bmp.SetSize(SCREEN_W, SCREEN_H);

    { 1. clear }
    Bmp.Canvas.Brush.Color := clBlack;
    Bmp.Canvas.FillRect(0, 0, SCREEN_W, SCREEN_H);
    Snap(0, 'clear');

    { 2. tiles, at a fixed origin so the source rectangles are pinned too }
    Map.Draw(Bmp.Canvas, Surf, Tileset, 0, 0, SCREEN_W, SCREEN_H);
    Snap(1, 'tiles');

    { 3. sprites over the tiles: the blit has to be transparent, so a sprite
      drawn opaque changes the checksum even where the sprite itself is right }
    if Sprite.Count > 0 then
    begin
      Sprite.Draw(Bmp.Canvas, Surf, 0, 40, 40);
      Sprite.Draw(Bmp.Canvas, Surf, 1 mod Sprite.Count, 96, 64);
      Sprite.Draw(Bmp.Canvas, Surf, 2 mod Sprite.Count, 152, 88);
    end;
    Snap(2, 'sprites');

    { 4. text, which is the other transparent path and has its own key colour }
    if Surf[0] <> nil then
    begin
      Font := TGameFont.Create(Surf[0]);
      Font.TextOut(Bmp.Canvas, 8, 8, 'AKUJI 0123');
      Font.TextOutCentered(Bmp.Canvas, 200, 'THE DEMON');
    end
    else
      Log.Add('note: surface 0 is nil, so the text scene is only the sprites');
    Snap(3, 'text');

    Log.Add('scene      changed   checksum   expected');
    for I := 0 to High(Scenes) do
    begin
      Log.Add(Format('%-9s %8d   %8.8x   %8.8x',
        [Scenes[I].Name, Scenes[I].Changed, Scenes[I].Sum, Expected[I]]));

      if Expected[I] = 0 then
      begin
        Log.Add(Format('  NOT PINNED - put %8.8x in BASELINE_%s',
          [Scenes[I].Sum, UpperCase(Scenes[I].Name)]));
        Continue;
      end;
      if Scenes[I].Sum <> Expected[I] then
      begin
        Log.Add(Format('  FAILED: %s renders differently than the baseline',
          [Scenes[I].Name]));
        Inc(Result);
      end;
    end;

    { Every draw has to have DONE something. Without this a renderer that drew
      nothing at all would still be pinned - once - and then agree with itself
      for ever. }
    for I := 1 to High(Scenes) do
      if Scenes[I].Changed = 0 then
      begin
        Log.Add(Format('FAILED: the %s draw changed no pixels at all',
          [Scenes[I].Name]));
        Inc(Result);
      end;

    if Result = 0 then
      Log.Add('OK');
  finally
    Font.Free;
    Bmp.Free;
    Stages.Free;
    Map.Free;
    Sprite.Free;
    Surf.Free;
    Arch.Free;
  end;
end;

end.
