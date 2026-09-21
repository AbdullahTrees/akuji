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
  QdaArchive, Surfaces, Sprites, TileMaps, GameFont, Stages, Entities,
  RenderTarget, TextRender, Dialogue;

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
  { The SYSTEM font path - the opening narration, the ending lines and the
    dialogue box. Pinned separately because it is drawn by the platform
    rather than blitted from a sheet, so it is the one scene an SDL target
    reproduces with a different rasteriser entirely. }
  BASELINE_OUTLINED = $5D477D70;

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
  Scenes: array[0..4] of TScene;
  Expected: array[0..4] of LongWord;
  Prev, Cur: TPixels;
  I, Tileset, MapId, TargetDiff, PromptW, PromptNeed: Integer;
  DirectBmp, TargetBmp, Glyph: TBitmap;
  Target, MapTarget: TLCLRenderTarget;
  SheetImage, GlyphImage: TRenderImage;
  KeyBmp: TBitmap;
  KeyTarget: TLCLRenderTarget;
  KeyRef: TPixels;
  KeyKept, KeyDiff, KeyStep: Integer;

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

  { Draw one sprite frame through the target's keyed blit, and work out what
    it should have produced by reading the sheet a pixel at a time. The
    renderer and the reference see the same frame, the same position and the
    same clipping rules; anything the two disagree about is the renderer. }
  procedure KeyedSprite(Index, X, Y: Integer);
  var
    Frame: TSpriteFrame;
    Sheet: TBitmap;
    SX, SY, DX, DY: Integer;
    C: TColor;
  begin
    Frame := Sprite[Index];
    if Frame.Surface < 0 then
      Exit;
    Sheet := Surf[Frame.Surface];
    if Sheet = nil then
      Exit;

    for SY := Frame.Src.Top to Frame.Src.Bottom - 1 do
      for SX := Frame.Src.Left to Frame.Src.Right - 1 do
      begin
        if (SX < 0) or (SY < 0)
        or (SX >= Sheet.Width) or (SY >= Sheet.Height) then
          Continue;
        DX := X + (SX - Frame.Src.Left);
        DY := Y + (SY - Frame.Src.Top);
        if (DX < 0) or (DY < 0) or (DX >= SCREEN_W) or (DY >= SCREEN_H) then
          Continue;
        C := Sheet.Canvas.Pixels[SX, SY];
        if ColorToRGB(C) = ColorToRGB(IMAGE_KEY_COLOR) then
          { The background: whatever is already there stays. }
          Inc(KeyKept)
        else
          KeyRef[DY * SCREEN_W + DX] := LongWord(C);
      end;

    KeyTarget.BlitRectKeyed(Surf.Images[Frame.Surface], Frame.Src, X, Y);
  end;

begin
  Result := 0;
  GameDir := IncludeTrailingPathDelimiter(ParamStr(2));
  SetFontDirectory(GameDir);
  Log.Add(Format('game dir: %s', [GameDir]));
  Log.Add('');

  Expected[0] := BASELINE_CLEAR;
  Expected[1] := BASELINE_TILES;
  Expected[2] := BASELINE_SPRITES;
  Expected[3] := BASELINE_TEXT;
  Expected[4] := BASELINE_OUTLINED;

  Arch := TQdaArchive.Create(GameDir + 'bmp.qda');
  Surf := TSurfaceSet.Create(Arch);
  Sprite := TSpriteSet.Create;
  Map := TTileMap.Create;
  Stages := TStageTable.Create;
  Bmp := TBitmap.Create;
  Font := nil;
  MapTarget := nil;
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
    MapTarget := TLCLRenderTarget.Create(Bmp.Canvas, SCREEN_W, SCREEN_H);
    Map.Draw(MapTarget, Surf, Tileset, 0, 0, SCREEN_W, SCREEN_H);
    Snap(1, 'tiles');

    { 3. sprites over the tiles: the blit has to be transparent, so a sprite
      drawn opaque changes the checksum even where the sprite itself is right }
    if Sprite.Count > 0 then
    begin
      Sprite.Draw(MapTarget, Surf, 0, 40, 40);
      Sprite.Draw(MapTarget, Surf, 1 mod Sprite.Count, 96, 64);
      Sprite.Draw(MapTarget, Surf, 2 mod Sprite.Count, 152, 88);
    end;
    Snap(2, 'sprites');

    { 4. text, which is the other transparent path and has its own key colour }
    if Surf[0] <> nil then
    begin
      Font := TGameFont.Create(Surf[0]);
      Font.TextOut(MapTarget, 8, 8, 'AKUJI 0123');
      Font.TextOutCentered(MapTarget, 200, 'THE DEMON');
    end
    else
      Log.Add('note: surface 0 is nil, so the text scene is only the sprites');
    Snap(3, 'text');

    { The vendored font has to be in the clone. Nothing reads it yet - the LCL
      target still asks the system for the name - but a port does, and a file
      that goes missing would first be noticed as wrong-looking narration
      rather than as an error. }
    if not FileExists(GameDir + OUTLINED_FONT_FILE) then
    begin
      Log.Add('FAILED: no ' + OUTLINED_FONT_FILE + ' under the game data - '
        + 'see the font section of NOTICE.md');
      Inc(Result);
    end;

    { THE SAVE PROMPT HAS TO CLEAR THE HAND.

      The prompt is one string drawn at x=112, with the hand cursor at a FIXED
      x=148 and 16 pixels wide, so the word "No" has to begin at 164 or later.
      That makes everything before it at least 52 pixels.

      The original leaves seven spaces there, which at its own font is 45, so
      the hand covers the N and the player reads "lo". MB_PROMPT_TEXT carries
      three more - a declared divergence, see notes/divergences.md - and this
      is what keeps it correct: change the font, the strike or the string and
      the check says so.

      Measured through the renderer rather than by counting characters, because
      what matters is the rendered advance and a space is not a fixed width. }
    PromptW := OutlinedTextWidth(Copy(MB_PROMPT_TEXT, 1,
                                      Pos('No', MB_PROMPT_TEXT) - 1),
                                 OUTLINED_FONT_FACE);
    PromptNeed := (MB_HAND_ICON_X + MB_HAND_ICON_STEP + MB_ICON_SIZE)
                  - MB_PROMPT_TEXT_X;
    Log.Add(Format('save prompt: text before "No" is %d px, clearing the hand '
      + 'needs %d - a gap of %d', [PromptW, PromptNeed, PromptW - PromptNeed]));
    if PromptW < PromptNeed then
    begin
      Log.Add(Format('FAILED: the hand cursor covers the word No by %d px',
        [PromptNeed - PromptW]));
      Inc(Result);
    end;

    { And the cursor must not touch "Yes" either. Its icon is drawn opaque, so
      the full 16-pixel cell lands on the screen and its right edge finishes
      exactly where the text begins - MB_HAND_ICON_X + MB_ICON_SIZE is
      MB_PROMPT_TEXT_X. Whatever precedes "Yes" in the string is the only gap
      there is. }
    PromptW := OutlinedTextWidth(Copy(MB_PROMPT_TEXT, 1,
                                      Pos('Yes', MB_PROMPT_TEXT) - 1),
                                 OUTLINED_FONT_FACE);
    Log.Add(Format('save prompt: a gap of %d px before "Yes"', [PromptW]));
    if (MB_HAND_ICON_X + MB_ICON_SIZE >= MB_PROMPT_TEXT_X) and (PromptW < 1) then
    begin
      Log.Add('FAILED: the hand cursor touches the word Yes');
      Inc(Result);
    end;

    { 5. the outlined system font, with the opening's own colours }
    Game_DrawTextOutlined(8, 100, 'A demon named "Akuji" once',
                          $355B7E, $A3DFFF, OUTLINED_FONT_SIZE, MapTarget);
    Snap(4, 'outlined');

    { An optional picture of what was just measured. A checksum says two
      renderers disagree; the image says how, which during the SDL rewrite is
      the difference between "something is wrong" and "the glyphs are a
      different size". }
    if ParamCount >= 3 then
    begin
      Bmp.SaveToFile(ParamStr(3));
      Log.Add('wrote ' + ParamStr(3));
    end;

    { THE RENDER TARGET DRAWS THE SAME PIXELS AS THE CANVAS IT REPLACES.

      Job B moves every drawing routine off TCanvas and onto TRenderTarget.
      That is only safe if the target's three primitives are exactly the calls
      they stand in for, so both sequences are run here and the results have to
      be identical - not close, identical.

      The primitives are checked against the call each one replaces:

        Fill       <- Brush.Color := c; FillRect(r)
        BlitRect   <- CopyRect(dest, src.Canvas, srcRect)
        DrawImage  <- Draw(x, y, bitmap)   and so honours its transparency

      A glyph is used for DrawImage because it is the only image in the game
      that carries transparency, which is the part most easily got wrong. }
    DirectBmp := TBitmap.Create;
    TargetBmp := TBitmap.Create;
    Glyph := TBitmap.Create;
    Target := nil;
    SheetImage := nil;
    GlyphImage := nil;
    try
      DirectBmp.SetSize(SCREEN_W, SCREEN_H);
      TargetBmp.SetSize(SCREEN_W, SCREEN_H);

      { A transparent image, cut the way the font cuts a glyph. }
      Glyph.SetSize(32, 32);
      if Surf[0] <> nil then
        Glyph.Canvas.CopyRect(Rect(0, 0, 32, 32), Surf[0].Canvas,
                              Rect(0, 0, 32, 32));
      Glyph.TransparentColor := clBlack;
      Glyph.Transparent := True;

      { --- the canvas calls, made directly --- }
      DirectBmp.Canvas.Brush.Color := clNavy;
      DirectBmp.Canvas.FillRect(Rect(0, 0, SCREEN_W, SCREEN_H));
      DirectBmp.Canvas.Brush.Color := clMaroon;
      DirectBmp.Canvas.FillRect(Rect(20, 20, 140, 90));
      if Surf[Tileset] <> nil then
        DirectBmp.Canvas.CopyRect(Rect(64, 100, 64 + 48, 100 + 48),
                                  Surf[Tileset].Canvas, Rect(0, 0, 48, 48));
      DirectBmp.Canvas.Draw(160, 120, Glyph);

      { --- the same, through the target --- }
      Target := TLCLRenderTarget.Create(TargetBmp.Canvas, SCREEN_W, SCREEN_H);
      GlyphImage := TRenderImage.Create(Glyph);
      Target.Fill(Rect(0, 0, SCREEN_W, SCREEN_H), clNavy);
      Target.Fill(Rect(20, 20, 140, 90), clMaroon);
      if Surf[Tileset] <> nil then
      begin
        SheetImage := TRenderImage.Create(Surf[Tileset]);
        Target.BlitRect(SheetImage, Rect(0, 0, 48, 48), 64, 100);
      end;
      Target.DrawImage(GlyphImage, 160, 120);

      ReadSurface(DirectBmp, Prev);
      ReadSurface(TargetBmp, Cur);
      TargetDiff := CountChanged(Prev, Cur);
      Log.Add('');
      Log.Add(Format('render target vs raw canvas: %d pixels differ of %d',
        [TargetDiff, Length(Prev)]));
      if TargetDiff <> 0 then
      begin
        Log.Add('FAILED: TLCLRenderTarget does not reproduce the canvas calls '
          + 'it replaces');
        Inc(Result);
      end;
      { And it has to have drawn something, or two blank surfaces would agree. }
      if Checksum(Cur) = Checksum(Prev) then
        if Prev[0] = 0 then
        begin
          Log.Add('FAILED: neither sequence drew anything');
          Inc(Result);
        end;
    finally
      SheetImage.Free;
      GlyphImage.Free;
      Target.Free;
      Glyph.Free;
      TargetBmp.Free;
      DirectBmp.Free;
    end;

    { A KEYED BLIT PUTS THE SPRITE DOWN AND LEAVES THE SHEET BEHIND.

      This is the check that a checksum cannot make. A checksum says the
      picture changed; it cannot say whether the change was right, and the
      last attempt at keyed sprites passed every check there was while
      cutting pieces out of the character - so this one computes what the
      screen SHOULD hold, pixel by pixel, straight from the sheet, and
      compares. Not a count of what changed: the actual colours.

      The scene is built to break the thing that went wrong last time. A
      shared mask shows up as one sprite wearing another's silhouette, so
      the frames are taken from across the whole table rather than from one
      animation - different sheets, different sizes, different shapes - they
      overlap each other, and two of them hang off the edge of the screen
      where the blit has to clip. Three frames of one character would all
      have looked alike and told us nothing. }
    KeyBmp := TBitmap.Create;
    KeyTarget := nil;
    try
      KeyBmp.SetSize(SCREEN_W, SCREEN_H);
      KeyTarget := TLCLRenderTarget.Create(KeyBmp.Canvas, SCREEN_W, SCREEN_H);

      { Two backgrounds, neither of them black. A sprite that arrives opaque
        paints its own black over whichever it lands on, and a mask that is
        the wrong way round erases one of them. }
      KeyTarget.Fill(Rect(0, 0, SCREEN_W, SCREEN_H), clNavy);
      KeyTarget.Fill(Rect(0, 0, SCREEN_W, SCREEN_H div 2), clOlive);

      { The reference starts as whatever is actually on the surface rather
        than as the colours just asked for, so the comparison is not also a
        test of how TColor round-trips through a bitmap. }
      ReadSurface(KeyBmp, KeyRef);
      KeyKept := 0;

      if Sprite.Count > 0 then
      begin
        KeyStep := Sprite.Count div 8;
        if KeyStep < 1 then
          KeyStep := 1;
        for I := 0 to 7 do
          KeyedSprite((I * KeyStep) mod Sprite.Count,
                      12 + (I mod 4) * 72, 16 + (I div 4) * 84);
        { Deliberately on top of what is already there. }
        KeyedSprite(0, 20, 24);
        KeyedSprite((3 * KeyStep) mod Sprite.Count, 26, 30);
        { And over the edges, where the blit clips. }
        KeyedSprite((5 * KeyStep) mod Sprite.Count, -9, -7);
        KeyedSprite((2 * KeyStep) mod Sprite.Count, SCREEN_W - 13,
                    SCREEN_H - 11);
      end;

      ReadSurface(KeyBmp, Cur);
      KeyDiff := CountChanged(KeyRef, Cur);
      Log.Add('');
      Log.Add(Format('keyed blit: %d pixels differ from a software colour '
        + 'key, %d background pixels left showing', [KeyDiff, KeyKept]));
      if KeyDiff <> 0 then
      begin
        Log.Add('FAILED: the keyed blit does not draw what a colour key '
          + 'would - the sprites are wrong, not merely different');
        Inc(Result);
      end;
      { If the frames chosen had no background in them the comparison above
        would hold for an opaque blit too, and prove nothing. }
      if KeyKept = 0 then
      begin
        Log.Add('FAILED: no sheet background fell inside the scene, so the '
          + 'keyed blit was never actually asked to leave anything behind');
        Inc(Result);
      end;
    finally
      KeyTarget.Free;
      KeyBmp.Free;
    end;

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
    MapTarget.Free;
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
