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
  Classes, SysUtils, GameColors, Types, SDL2,
  TestSupport, QdaArchive, Surfaces, Sprites, TileMaps, GameFont, Stages,
  Entities, RenderTarget, SDLTarget, TextRender, Dialogue, DDDDComponent;

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

{ Every pixel, in order, as the $00BBGGRR a TColor is - which is the form the
  baselines were recorded in, back when the renderer was the LCL's. }
procedure ReadSurface(Src: PSDL_Surface; out Buf: TPixels);
var
  X, Y: Integer;
  Row: PByte;
  Pix: PLongWord;
begin
  SetLength(Buf, 0);
  if Src = nil then
    Exit;
  SetLength(Buf, Src^.w * Src^.h);
  for Y := 0 to Src^.h - 1 do
  begin
    Row := PByte(Src^.pixels) + Y * Src^.pitch;
    Pix := PLongWord(Row);
    for X := 0 to Src^.w - 1 do
    begin
      Buf[Y * Src^.w + X] := ((Pix^ and $FF) shl 16) or (Pix^ and $0000FF00)
                             or ((Pix^ shr 16) and $FF);
      Inc(Pix);
    end;
  end;
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
  { Re-pinned when sprites became keyed - DIV-017. The scenes accumulate on
    one surface, so the two that are drawn ON TOP of the sprites moved with
    them; their own draws are unchanged, and the pixel counts they report
    (1071 and 1147) say so. }
  BASELINE_SPRITES = $CC77D640;
  BASELINE_TEXT    = $2FED4FE1;
  { The SYSTEM font path - the opening narration, the ending lines and the
    dialogue box. Pinned separately because it is drawn by the platform
    rather than blitted from a sheet, so it is the one scene an SDL target
    reproduces with a different rasteriser entirely.
    Re-pinned when sserife.fon became Wine's replacement: the advances are
    identical, but the bitmap glyphs are not the ones the old pin was taken
    with, and the draw changes 12 fewer pixels (1135). }
  BASELINE_OUTLINED = $382857A3;

{ Compare one measured checksum against its pinned value. A zero pin means
  the thing has not been pinned yet: it reports what it measured and does not
  fail, so a new one can be added without inventing a number. }
function Pinned(const AName: string; Got, Want: LongWord;
                const AConst: string; Log: TStrings): Integer;
begin
  Result := 0;
  if Want = 0 then
  begin
    Log.Add(Format('  %s is NOT PINNED - put %8.8x in %s',
      [AName, Got, AConst]));
    Exit;
  end;
  if Got <> Want then
  begin
    Log.Add(Format('  FAILED: %s renders differently than the baseline '
      + '(%8.8x, expected %8.8x)', [AName, Got, Want]));
    Result := 1;
  end;
end;

type
  TScaleCase = record
    CW, CH: Integer;   { the client area }
    Want: Integer;     { the whole-number scale it has to choose }
  end;

const
  ScaleCases: array[0..5] of TScaleCase = (
    (CW: 320;  CH: 240;  Want: 1),   { the window at 1x }
    (CW: 640;  CH: 480;  Want: 2),   { at 2x }
    (CW: 1280; CH: 960;  Want: 4),   { at 4x }
    (CW: 1920; CH: 1080; Want: 4),   { fullscreen 16:9 - height decides }
    (CW: 700;  CH: 500;  Want: 2),   { an odd size: 2x, centred, letterboxed }
    (CW: 100;  CH: 100;  Want: 1));  { too small for 1:1, which stays 1:1 }

{ The rectangle the English translation's stray menu panel occupied, and what
  separates a panel edge from the artwork's own. Measured both ways: with the
  panel 84 of these 84 columns step hard across its border row; without it the
  busiest row in the whole band is 15, and those are the character's outlines. }
const
  PANEL_X0 = 229;
  PANEL_X1 = 312;
  PANEL_Y0 = 127;
  PANEL_Y1 = 202;
  PANEL_EDGE = 12;
  PANEL_MAX_COLUMNS = 32;

{ The largest per-channel difference between two $00BBGGRR pixels. }
function ChannelStep(A, B: LongWord): Integer;
var
  I, D: Integer;
begin
  Result := 0;
  for I := 0 to 2 do
  begin
    D := Abs(Integer((A shr (I * 8)) and $FF) - Integer((B shr (I * 8)) and $FF));
    if D > Result then
      Result := D;
  end;
end;

function SelfTestRender(Log: TStrings): Integer;
var
  GameDir: string;
  Arch: TQdaArchive;
  Surf: TSurfaceSet;
  Sprite: TSpriteSet;
  Map: TTileMap;
  Font: TGameFont;
  Stages: TStageTable;
  Screen: PSDL_Surface;
  MapTarget: TSDLRenderTarget;
  Scenes: array[0..4] of TScene;
  Expected: array[0..4] of LongWord;
  Prev, Cur: TPixels;
  I, Tileset, MapId: Integer;
  KeySurf: PSDL_Surface;
  KeyTarget: TSDLRenderTarget;
  KeyRef: TPixels;
  KeyKept, KeyDiff, KeyStep: Integer;
  PresentSurf, DecSurf, DecConv: PSDL_Surface;
  DecBuf: TMemoryStream;
  DecPixels: TDecodedPixels;
  DecW, DecH: Integer;
  PanelBuf: TMemoryStream;
  PanelPixels: TDecodedPixels;
  PanelW, PanelH: Integer;
  PanelIndex, PanelWorst, PanelWorstRow, PanelCount: Integer;
  DecBad, DecChecked, DecEntry: Integer;
  PresentDst: PSDL_Surface;
  PresentArea: TRect;
  PresentBands: Integer;
  PresentGot, PresentWant: LongWord;
  PresentBad: Integer;
  PX, PY: Integer;
  SdlRow: PByte;
  SdlPix: PLongWord;
  ScaleR: TRect;
  ScaleW, ScaleH: Integer;

  procedure Snap(Index: Integer; const AName: string);
  begin
    ReadSurface(Screen, Cur);
    Scenes[Index].Name := AName;
    Scenes[Index].Sum := Checksum(Cur);
    if Length(Prev) = Length(Cur) then
      Scenes[Index].Changed := CountChanged(Prev, Cur)
    else
      Scenes[Index].Changed := Length(Cur);
    Prev := Copy(Cur, 0, Length(Cur));
  end;

  { Every scene, in order, into whatever target is passed.

    The five are cumulative on one surface rather than separate pictures -
    the sprites go over the tiles and the text over the sprites - because
    that is how the game draws and because it means each checksum covers
    everything before it. Snap is only taken on the pass that pins them.

      clear      Fill, and the surface being the size it claims
      tiles      an opaque rectangle blit, the commonest operation
      sprites    a keyed blit, which is where a colour key goes wrong
      text       glyph blits, the other keyed path, with its own key colour
      outlined   the system font, the one thing drawn by a rasteriser }
  procedure DrawScenes(T: TRenderTarget; Snaps: Boolean);
  begin
    T.Fill(Rect(0, 0, SCREEN_W, SCREEN_H), clBlack);
    if Snaps then Snap(0, 'clear');

    { At a fixed origin, so the source rectangles are pinned too. }
    Map.Draw(T, Surf, Tileset, 0, 0, SCREEN_W, SCREEN_H);
    if Snaps then Snap(1, 'tiles');

    if Sprite.Count > 0 then
    begin
      Sprite.Draw(T, Surf, 0, 40, 40);
      Sprite.Draw(T, Surf, 1 mod Sprite.Count, 96, 64);
      Sprite.Draw(T, Surf, 2 mod Sprite.Count, 152, 88);
    end;
    if Snaps then Snap(2, 'sprites');

    if Font <> nil then
    begin
      Font.TextOut(T, 8, 8, 'AKUJI 0123');
      Font.TextOutCentered(T, 200, 'THE DEMON');
    end;
    if Snaps then Snap(3, 'text');

    Game_DrawTextOutlined(8, 100, 'A demon named "Akuji" once',
                          $355B7E, $A3DFFF, OUTLINED_FONT_SIZE, T);
    if Snaps then Snap(4, 'outlined');
  end;

  { Draw one sprite frame through the target's keyed blit, and work out what
    it should have produced by reading the sheet a pixel at a time. The
    renderer and the reference see the same frame, the same position and the
    same clipping rules; anything the two disagree about is the renderer. }
  procedure KeyedSprite(Index, X, Y: Integer);
  var
    Frame: TSpriteFrame;
    Sheet: TRenderImage;
    Pixels: PSDL_Surface;
    SX, SY, DX, DY: Integer;
    C: TColor;
  begin
    Frame := Sprite[Index];
    if Frame.Surface < 0 then
      Exit;
    Sheet := Surf.Images[Frame.Surface];
    if Sheet = nil then
      Exit;
    { The sheet's own pixels, read rather than blitted - which is what makes
      this a reference and not a second copy of the renderer. }
    Pixels := Sheet.SDLSurface(False);

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
        C := SurfacePixel(Pixels, SX, SY);
        if ColorToRGB(C) = ColorToRGB(IMAGE_KEY_COLOR) then
          { The background: whatever is already there stays. }
          Inc(KeyKept)
        else
          KeyRef[DY * SCREEN_W + DX] := LongWord(C);
      end;

    KeyTarget.BlitRectKeyed(Sheet, Frame.Src, X, Y);
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
  Screen := SDL_CreateRGBSurface(0, SCREEN_W, SCREEN_H, 32,
                                 $00FF0000, $0000FF00, $000000FF, 0);
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

    if Screen = nil then
    begin
      Log.Add('FAILED: no SDL surface to draw the scenes into: ' + SDL_GetError);
      Exit(1);
    end;
    MapTarget := TSDLRenderTarget.Create(Screen);
    if Surf.Images[0] <> nil then
      Font := TGameFont.Create(Surf.Images[0])
    else
      Log.Add('note: surface 0 is nil, so the text scene is only the sprites');

    DrawScenes(MapTarget, True);

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

    { The save prompt clearing the hand cursor is checked per language, en.po
      included, by --selftest-lang: the prompt is text from a language file
      now, not a string in the code. }

    { An optional picture of what was just measured. A checksum says two
      renderers disagree; the image says how, which during the SDL rewrite is
      the difference between "something is wrong" and "the glyphs are a
      different size". }
    if ParamCount >= 3 then
    begin
      SDL_SaveBMP(Screen, PAnsiChar(AnsiString(ParamStr(3))));
      Log.Add('wrote ' + ParamStr(3));
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
    KeySurf := SDL_CreateRGBSurface(0, SCREEN_W, SCREEN_H, 32,
                                    $00FF0000, $0000FF00, $000000FF, 0);
    KeyTarget := nil;
    try
      if KeySurf = nil then
      begin
        Log.Add('FAILED: no SDL surface for the keyed blit check');
        Inc(Result);
        Exit(Result);
      end;
      KeyTarget := TSDLRenderTarget.Create(KeySurf);

      { Two backgrounds, neither of them black. A sprite that arrives opaque
        paints its own black over whichever it lands on, and a mask that is
        the wrong way round erases one of them. }
      KeyTarget.Fill(Rect(0, 0, SCREEN_W, SCREEN_H), clNavy);
      KeyTarget.Fill(Rect(0, 0, SCREEN_W, SCREEN_H div 2), clOlive);

      { The reference starts as whatever is actually on the surface rather
        than as the colours just asked for, so the comparison is not also a
        test of how a TColor round-trips. }
      ReadSurface(KeySurf, KeyRef);
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

      ReadSurface(KeySurf, Cur);
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
      if KeySurf <> nil then
        SDL_FreeSurface(KeySurf);
    end;

    { THE PICTURE IS SCALED BY A WHOLE NUMBER AND CENTRED.

      Geometry rather than drawing, which is why it can be checked at all: the
      scaling happens on the way to a window, and a self-test has no window.
      What it must never do is scale by a fraction - that is what gives a
      320-wide picture some source pixels two screen pixels wide and some
      three, which on art this size is plainly visible.

      The cases are the ones that actually occur: an exact window, a window
      the player has been given by a scale setting, a fullscreen desktop that
      is not 4:3, and a client area too small to hold the picture at all. }
    for I := 0 to High(ScaleCases) do
    begin
      ScaleR := TDDDD.PresentRect(SCREEN_W, SCREEN_H,
                                  ScaleCases[I].CW, ScaleCases[I].CH);
      ScaleW := ScaleR.Right - ScaleR.Left;
      ScaleH := ScaleR.Bottom - ScaleR.Top;
      Log.Add(Format('scaling: %4dx%-4d client -> %dx%d at (%d,%d), %dx',
        [ScaleCases[I].CW, ScaleCases[I].CH, ScaleW, ScaleH,
         ScaleR.Left, ScaleR.Top, ScaleW div SCREEN_W]));

      if (ScaleW <> SCREEN_W * ScaleCases[I].Want)
      or (ScaleH <> SCREEN_H * ScaleCases[I].Want) then
      begin
        Log.Add(Format('  FAILED: wanted %dx, got %dx%d',
          [ScaleCases[I].Want, ScaleW, ScaleH]));
        Inc(Result);
      end;
      { Centred, to within the odd pixel an odd difference leaves over. }
      if (Abs((ScaleR.Left * 2 + ScaleW) - ScaleCases[I].CW) > 1)
      or (Abs((ScaleR.Top * 2 + ScaleH) - ScaleCases[I].CH) > 1) then
      begin
        Log.Add('  FAILED: not centred in the client area');
        Inc(Result);
      end;
    end;

    { THE TWO BMP DECODERS HAVE TO AGREE.

      Every picture in bmp.qda is read by SDL, and the pinned scenes cannot
      tell a decoding mistake from a correct decode: the picture and the
      baseline both come from SDL, so a palette read backwards, or the rows
      the wrong way up, would simply become the new normal.

      So a second decoder reads the same entries - TestSupport.DecodeBmp,
      written from the BMP format rather than from any other decoder, which is
      what makes it a witness. It used to be the LCL's decoder, for free;
      the widget set is gone and this is better evidence than what it
      replaces, because it shares no code with the thing it is checking.

      Whole sheets rather than a corner: the first four entries, which are the
      font, the HUD sheet and two character sheets. }
    DecBad := 0;
    DecChecked := 0;
    DecBuf := TMemoryStream.Create;
    try
      for DecEntry := 0 to 3 do
      begin
        if DecEntry >= Arch.Count then
          Break;
        DecBuf.Clear;
        Arch.LoadRaw(DecEntry, DecBuf);
        DecSurf := Arch.LoadSurface(DecEntry);
        if (DecSurf = nil)
           or not DecodeBmp(DecBuf, DecW, DecH, DecPixels) then
        begin
          Log.Add(Format('FAILED: archive entry %d did not load both ways',
            [DecEntry]));
          Inc(Result);
          if DecSurf <> nil then
            SDL_FreeSurface(DecSurf);
          Continue;
        end;
        { Every entry is an uncompressed 24-bit bottom-up BMP - all 44 of
          them, checked - so the SDL side is brought to the same 32-bit form
          the renderer uses before the comparison, which is the conversion
          the renderer would do anyway. }
        DecConv := SDL_ConvertSurfaceFormat(DecSurf, SDL_PIXELFORMAT_ARGB8888, 0);
        SDL_FreeSurface(DecSurf);
        try
          if (DecConv = nil) or (DecConv^.w <> DecW) or (DecConv^.h <> DecH) then
          begin
            Log.Add(Format('FAILED: entry %d is %dx%d read here and a '
              + 'different size to SDL', [DecEntry, DecW, DecH]));
            Inc(Result);
            Continue;
          end;
          for PY := 0 to DecConv^.h - 1 do
          begin
            SdlRow := PByte(DecConv^.pixels) + PY * DecConv^.pitch;
            SdlPix := PLongWord(SdlRow);
            for PX := 0 to DecConv^.w - 1 do
            begin
              Inc(DecChecked);
              if ((SdlPix^ and $FF) shl 16) or (SdlPix^ and $0000FF00)
                 or ((SdlPix^ shr 16) and $FF)
                 <> DecPixels[PY * DecW + PX] then
              begin
                if DecBad = 0 then
                  Log.Add(Format('  first disagreement in entry %d at (%d,%d): '
                    + 'read %.6x, SDL %.8x',
                    [DecEntry, PX, PY, DecPixels[PY * DecW + PX], SdlPix^]));
                Inc(DecBad);
              end;
              Inc(SdlPix);
            end;
          end;
        finally
          if DecConv <> nil then
            SDL_FreeSurface(DecConv);
        end;
      end;
    finally
      DecBuf.Free;
    end;
    Log.Add('');
    Log.Add(Format('bmp decoders: %d pixels compared, %d disagree',
      [DecChecked, DecBad]));
    if DecChecked = 0 then
    begin
      Log.Add('FAILED: no archive entry was decoded, so nothing was compared');
      Inc(Result);
    end;
    if DecBad <> 0 then
    begin
      Log.Add('FAILED: the two decoders do not read the same picture out of '
        + 'bmp.qda');
      Inc(Result);
    end;

    { THE OPTIONS BACKGROUND MUST NOT CARRY THE MAIN MENU'S PANEL.

      title.BMP has a bordered panel around the menu items. That is original
      artwork - both Japanese releases have it - and the menu is drawn inside
      it. Option.bmp must NOT have one: the options screen puts its values
      there, and neither Japanese release's copy carries it.

      The English 1.1 translation's copy did. It was re-exported with that
      layer still showing, so a rectangle sat over the value column, drawn
      faithfully by us because it was in the data. It has been painted out -
      see notes/divergences.md, DIV-022 - and this is what stops it coming
      back through a repacked archive or a re-extracted asset.

      A panel has to have edges, so edges are what this counts: down each
      column the border crossed, how many step hard from one row to the next. }
    PanelBuf := TMemoryStream.Create;
    try
      PanelIndex := Arch.IndexOf('Option.bmp');
      if PanelIndex < 0 then
      begin
        Log.Add('FAILED: bmp.qda has no Option.bmp');
        Inc(Result);
      end
      else
      begin
        Arch.LoadRaw(PanelIndex, PanelBuf);
        if not DecodeBmp(PanelBuf, PanelW, PanelH, PanelPixels)
           or (PanelW < PANEL_X1 + 1) or (PanelH < PANEL_Y1 + 1) then
        begin
          Log.Add('FAILED: Option.bmp did not decode, or is too small');
          Inc(Result);
        end
        else
        begin
          PanelWorst := 0;
          PanelWorstRow := 0;
          for PY := PANEL_Y0 to PANEL_Y1 do
          begin
            PanelCount := 0;
            for PX := PANEL_X0 to PANEL_X1 do
              if ChannelStep(PanelPixels[(PY - 1) * PanelW + PX],
                             PanelPixels[PY * PanelW + PX]) > PANEL_EDGE then
                Inc(PanelCount);
            if PanelCount > PanelWorst then
            begin
              PanelWorst := PanelCount;
              PanelWorstRow := PY;
            end;
          end;
          Log.Add('');
          Log.Add(Format('option background: busiest edge row y=%d, %d of %d '
            + 'columns step (a panel border puts every one of them over)',
            [PanelWorstRow, PanelWorst, PANEL_X1 - PANEL_X0 + 1]));
          if PanelWorst > PANEL_MAX_COLUMNS then
          begin
            Log.Add('FAILED: Option.bmp has a horizontal edge across the value '
              + 'column - the main menu''s panel is back in the options art');
            Inc(Result);
          end;
        end;
      end;
    finally
      PanelBuf.Free;
    end;

    { WHAT THE WINDOW IS SHOWN HAS TO BE WHAT WAS DRAWN.

      Presentation is now one scaled blit into the window's own surface, and
      TDDDD.PresentTo is all of it but the asking for that surface - which is
      why it is a class method taking a destination rather than a window.

      Nothing else in this test crosses that bridge: the scenes above check
      what the renderer puts in the BACK buffer, so a present that swapped red
      and blue, put the picture in the wrong place, or scaled it by the wrong
      number would leave every one of them green and the game unplayable.

      A surface of known colours, chosen to differ in every channel and to be
      asymmetric top to bottom, presented into a destination big enough to
      letterbox: 8x4 into 34x18 is 4x - the height allows 4 and the width
      allows 4 - leaving one column of slack each side and one row top and
      bottom. Every pixel of the result is then accounted for, band or
      picture, which makes this a check of the geometry and the colours at
      once. }
    PresentSurf := SDL_CreateRGBSurface(0, 8, 4, 32,
                                        $00FF0000, $0000FF00, $000000FF, 0);
    PresentDst := SDL_CreateRGBSurface(0, 34, 18, 32,
                                       $00FF0000, $0000FF00, $000000FF, 0);
    if (PresentSurf = nil) or (PresentDst = nil) then
    begin
      Log.Add('FAILED: no SDL surface for the present check: ' + SDL_GetError);
      Inc(Result);
    end
    else
    begin
      try
        for PY := 0 to 3 do
        begin
          SdlRow := PByte(PresentSurf^.pixels) + PY * PresentSurf^.pitch;
          SdlPix := PLongWord(SdlRow);
          for PX := 0 to 7 do
          begin
            { r = 16x, g = 32y + 8, b = 200 - 16x: no two channels alike and
              no symmetry to hide a flip. }
            SdlPix^ := (LongWord(PX * 16) shl 16)
                       or (LongWord(PY * 32 + 8) shl 8)
                       or LongWord(200 - PX * 16);
            Inc(SdlPix);
          end;
        end;

        { Filled with something that is not black first, so that a band left
          unpainted is a failure rather than a coincidence. }
        SDL_FillRect(PresentDst, nil,
                     SDL_MapRGB(PresentDst^.format, 255, 0, 255));

        PresentArea := TDDDD.PresentRect(8, 4, 34, 18);
        Log.Add('');
        Log.Add(Format('present: 8x4 into 34x18 lands at (%d,%d) %dx%d',
          [PresentArea.Left, PresentArea.Top,
           PresentArea.Right - PresentArea.Left,
           PresentArea.Bottom - PresentArea.Top]));
        if (PresentArea.Left <> 1) or (PresentArea.Top <> 1)
           or (PresentArea.Right <> 33) or (PresentArea.Bottom <> 17) then
        begin
          Log.Add('FAILED: 4x centred in 34x18 is (1,1) 32x16');
          Inc(Result);
        end;

        TDDDD.PresentTo(PresentSurf, PresentDst);

        PresentBad := 0;
        PresentBands := 0;
        for PY := 0 to 17 do
          for PX := 0 to 33 do
          begin
            PresentGot := LongWord(SurfacePixel(PresentDst, PX, PY));
            if (PX < PresentArea.Left) or (PX >= PresentArea.Right)
               or (PY < PresentArea.Top) or (PY >= PresentArea.Bottom) then
            begin
              { A band. Black, not the magenta that was there before. }
              Inc(PresentBands);
              PresentWant := 0;
            end
            else
              { Nearest-neighbour at 4x is exact replication, so the source
                pixel is found by dividing rather than by sampling. }
              PresentWant := LongWord(SurfacePixel(PresentSurf,
                                        (PX - PresentArea.Left) div 4,
                                        (PY - PresentArea.Top) div 4));
            if PresentGot <> PresentWant then
            begin
              if PresentBad = 0 then
                Log.Add(Format('  first wrong at (%d,%d): read %.6x, want %.6x',
                  [PX, PY, PresentGot, PresentWant]));
              Inc(PresentBad);
            end;
          end;

        Log.Add(Format('present: %d of %d pixels right, %d of them surround',
          [34 * 18 - PresentBad, 34 * 18, PresentBands]));
        if PresentBad <> 0 then
        begin
          Log.Add('FAILED: what Present shows is not what the game drew');
          Inc(Result);
        end;

        { The back buffer must stay alpha-less. PresentTo blits it into the
          window surface, and a source with an alpha mask would be BLENDED
          against whatever the window had rather than copied over it - which
          is the same defect, arrived at from the other side, that showed the
          outlined text alone over a window full of stale pixels while the
          back buffer behind it was perfect. }
        if PresentSurf^.format^.Amask <> 0 then
        begin
          Log.Add('FAILED: the back buffer now HAS an alpha mask - the '
            + 'present path assumes it does not, and must be revisited');
          Inc(Result);
        end;
      finally
        if PresentDst <> nil then
          SDL_FreeSurface(PresentDst);
        if PresentSurf <> nil then
          SDL_FreeSurface(PresentSurf);
      end;
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
    if Screen <> nil then
      SDL_FreeSurface(Screen);
    Stages.Free;
    Map.Free;
    Sprite.Free;
    Surf.Free;
    Arch.Free;
  end;
end;

end.
