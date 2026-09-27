{ The outlined narration font, rendered by SDL_ttf.

  WHY NOT THE PLATFORM'S OWN TEXT

  The game asks GDI for "MS Sans Serif" at 10 points and draws each string five
  times - four one-pixel offsets in the outline colour, then the fill over
  them. That worked when "MS Sans Serif" meant the raster font it was written
  against. Windows has since substituted the TrueType Microsoft Sans Serif for
  that name, whose advances are narrower, and the game's fixed layout has no
  way to notice.

  The save prompt shows it plainly. It draws ONE string, 'Yes       No  ', at
  x=112, and puts the hand cursor at a FIXED x=148 with a 16 pixel icon. For
  "No" to sit clear of the hand, 'Yes       ' has to be 52 pixels wide. The
  substituted font gives 39, so "No" begins at 151, underneath the hand, and
  the player sees "lo". The same undersizing leaves the opening narration
  sitting high in its band.

  The original binary has this defect too, on a modern Windows - it is the
  font substitution, not the reconstruction. Rendering the text ourselves from
  a font we carry is what makes it stop depending on the host at all, and the
  same change is what lets the game draw text on a platform that has no GDI.

  WHICH STRIKE

  A bitmap font has fixed strikes rather than a scalable outline, so the size
  is a FACE INDEX. TTF_OpenFont ignores its ptsize for such a face and always
  hands back face 0; TTF_OpenFontIndex picks. The file holds six, and the game
  renders with the first, so that is the one used here - the text looks exactly
  as it does today rather than merely similar.

  The save prompt's overlap travels with that choice, which is why the render
  test reports the prompt width rather than asserting it.

  HOW THE OUTLINE IS MADE

  Four stamps at one-pixel offsets, then the fill - exactly what the game does.
  FreeType's stroker needs outlines and a bitmap face has none, so the
  technique the game already uses is both the only one available and the
  faithful one.

  Rendered Solid, because a bitmap strike has nothing to antialias. Blended
  would wrap the same hard pixels in an alpha channel and change nothing but
  the cost.

  WHY IT IS CACHED

  A dialogue box redraws its line sixty times a second and the line changes
  when the player presses a key. Rendering five passes through FreeType every
  frame would be wasteful; the strings are few and short, so each rendered
  bitmap is kept until something evicts it.

  ANOTHER LANGUAGE'S FONT

  The default face is Latin only. A translation names its own font in its
  PO header (see Translation), and that font then draws everything this
  unit draws, at the pixel size it gives, instead of the strike the face
  index picks. The Japanese one is PixelMplus12: a TrueType font drawn on a
  12-pixel grid, so rendered Solid at 12 it lands on whole pixels as a
  bitmap strike would. The original used MS Gothic at 10 points, a 13-pixel
  line, which this matches.

  KEYCAPS

  A key a sign names can arrive as a keycap icon rather than as its name -
  one private-use character per icon, see KeyIcons. A string with one is
  composed in runs: the text between icons with the same five passes, each
  icon copied from the keycap sheet, left to right. An icon is taller than
  the text it sits in, so the sheet may carry a pad above the text; the
  target draws the sheet that much higher, and the text lands where it
  always did. A string without an icon is composed exactly as before. }

unit TextRender;

{$MODE DELPHI}{$H+}

interface

uses
  Classes, SysUtils, GameColors, SDL2;

{ Where assets/fonts lives. Called once the data directory is known; until it
  is, text renders nothing rather than guessing at a path. }
procedure SetFontDirectory(const ADir: string);

{ True once the font file has been opened successfully. }
function TextRenderReady: Boolean;

{ The string drawn five times - four offsets in Outline, then Fill - as one
  surface with an alpha channel. The caller draws it at (X - 1, Y - 1),
  because the outline extends one pixel above and to the left of where the
  text itself starts.

  Returns nil if there is no font, which is not fatal: the game simply has no
  narration rather than failing to start. The surface belongs to the cache and
  must not be freed. }
function OutlinedTextSurface(const S: string; Outline, Fill: TColor;
                             Face: Integer; out TopPad: Integer): PSDL_Surface;

{ How wide the string is, in pixels, at this size. Zero if there is no font. }
function OutlinedTextWidth(const S: string; Face: Integer): Integer;

{ Whether the font this face draws with right now has a glyph for the
  character - for the translation checks. }
function OutlinedFontHasGlyph(CodePoint: Cardinal; Face: Integer): Boolean;

procedure ShutdownTextRender;

implementation

uses
  ctypes, SDL2_ttf, RenderTarget, Translation, TextUnits, KeyIcons;

type
  TCacheEntry = record
    Key: string;
    Surface: PSDL_Surface;
    TopPad: Integer;
  end;

  { A string cut at its icons: each run is text, or one icon. }
  TRun = record
    Text: string;
    Icon: Integer;      { -1 for a text run }
  end;

var
  FontDir: string = '';
  Font: PTTF_Font = nil;
  FontKey: string = '';
  Started: Boolean = False;
  Cache: array of TCacheEntry;
  IconSheet: PSDL_Surface = nil;
  IconSheetTried: Boolean = False;

{ Keycap helpers, defined beside Compose. }
function HasIcon(const S: string): Boolean; forward;
function RunsOf(const S: string): TArray<TRun>; forward;
function RunWidth(const R: TRun): Integer; forward;

procedure SetFontDirectory(const ADir: string);
begin
  FontDir := IncludeTrailingPathDelimiter(ADir);
end;

{ The language's font file, under assets/fonts/. }
function LanguageFontPath: string;
begin
  Result := FontDir + 'fonts' + PathDelim + LanguageFontFile;
end;

var
  { Whether the language's font file exists, asked once per file rather
    than on every draw - this runs several times a frame. }
  CheckedFontPath: string = '';
  CheckedFontExists: Boolean = False;

{ Which font this face means right now: the language's, if it names one
  that exists, otherwise the default file's strike. }
function WantedFont(Face: Integer): string;
var
  Path: string;
begin
  if (FontDir <> '') and (LanguageFontFile <> '') then
  begin
    Path := LanguageFontPath;
    if Path <> CheckedFontPath then
    begin
      CheckedFontPath := Path;
      CheckedFontExists := FileExists(Path);
    end;
    if CheckedFontExists then
      Exit('lang|' + LanguageFontFile + '|' + IntToStr(LanguageFontSize));
  end;
  Result := 'face|' + IntToStr(Face);
end;

{ Opens the font at this size, reusing the handle while the size is unchanged.
  Only one size is ever asked for, but the check costs nothing and a second
  caller with a different size would otherwise silently get the first one's. }
function EnsureFont(Face: Integer): Boolean;
var
  Path, Key: string;
  Size: Integer;
begin
  Key := WantedFont(Face);
  if (Font <> nil) and (FontKey = Key) then
    Exit(True);
  if FontDir = '' then
    Exit(False);

  if not Started then
  begin
    if TTF_Init <> 0 then
      Exit(False);
    Started := True;
  end;

  if Font <> nil then
  begin
    TTF_CloseFont(Font);
    Font := nil;
  end;
  if Copy(Key, 1, 5) = 'lang|' then
  begin
    Size := LanguageFontSize;
    if Size <= 0 then
      Size := 12;
    Font := TTF_OpenFont(PAnsiChar(AnsiString(LanguageFontPath)), Size);
  end
  else
  begin
    Path := FontDir + OUTLINED_FONT_FILE;
    if not FileExists(Path) then
      Exit(False);
    { The ptsize argument is ignored for a bitmap face; the index is what
      picks the strike. The 12 is a placeholder and means nothing. }
    Font := TTF_OpenFontIndex(PAnsiChar(AnsiString(Path)), 12, Face);
  end;
  if Font = nil then
    Exit(False);
  FontKey := Key;
  Result := True;
end;

function OutlinedFontHasGlyph(CodePoint: Cardinal; Face: Integer): Boolean;
begin
  Result := EnsureFont(Face) and (CodePoint <= $FFFF)
            and (TTF_GlyphIsProvided(Font, Word(CodePoint)) <> 0);
end;

function TextRenderReady: Boolean;
begin
  Result := Font <> nil;
end;

function OutlinedTextWidth(const S: string; Face: Integer): Integer;
var
  W, H: cint;
  R: TRun;
begin
  Result := 0;
  if not EnsureFont(Face) then
    Exit;
  if HasIcon(S) then
  begin
    for R in RunsOf(S) do
      Inc(Result, RunWidth(R));
    Exit;
  end;
  if TTF_SizeUTF8(Font, PAnsiChar(AnsiString(S)), @W, @H) = 0 then
    Result := W;
end;

function ToSDLColor(C: TColor): TSDL_Color;
begin
  { TColor is $00BBGGRR. }
  Result.r := Byte(C);
  Result.g := Byte(C shr 8);
  Result.b := Byte(C shr 16);
  Result.a := 255;
end;

{ Whether S carries a keycap. Cheap enough to ask of every string drawn: an
  icon is the three-byte sequence EE 80 xx, so a string without $EE has none. }
function HasIcon(const S: string): Boolean;
var
  I, Len: Integer;
begin
  Result := False;
  if Pos(#$EE, S) = 0 then
    Exit;
  I := 1;
  while I <= Length(S) do
  begin
    if KeyIconOfCodePoint(Utf8CodePoint(S, I, Len)) >= 0 then
      Exit(True);
    Inc(I, Len);
  end;
end;

function RunsOf(const S: string): TArray<TRun>;
var
  I, Len, Icon, N: Integer;
  Text: string;

  procedure Add(const T: string; Ic: Integer);
  begin
    SetLength(Result, N + 1);
    Result[N].Text := T;
    Result[N].Icon := Ic;
    Inc(N);
  end;

begin
  N := 0;
  SetLength(Result, 0);
  Text := '';
  I := 1;
  while I <= Length(S) do
  begin
    Icon := KeyIconOfCodePoint(Utf8CodePoint(S, I, Len));
    if Icon >= 0 then
    begin
      if Text <> '' then
        Add(Text, -1);
      Text := '';
      Add('', Icon);
    end
    else
      Text := Text + Copy(S, I, Len);
    Inc(I, Len);
  end;
  if Text <> '' then
    Add(Text, -1);
end;

{ The keycap sheet, loaded the first time a keycap is drawn. Copied rather
  than blended, like the glyphs - a blended 8-bit keyed surface copies
  nothing under SDL 2.0.10. }
function EnsureIconSheet: Boolean;
begin
  if not IconSheetTried then
  begin
    IconSheetTried := True;
    IconSheet := SDL_LoadBMP(PAnsiChar(AnsiString(FontDir + 'fonts' + PathDelim
                                                  + KEY_ICON_SHEET)));
    if IconSheet <> nil then
    begin
      SDL_SetColorKey(IconSheet, 1, SDL_MapRGB(IconSheet^.format, 255, 0, 255));
      SDL_SetSurfaceBlendMode(IconSheet, SDL_BLENDMODE_NONE);
    end;
  end;
  Result := IconSheet <> nil;
end;

{ How wide a run is: the text's advance, or the icon's rectangle. }
function RunWidth(const R: TRun): Integer;
var
  W, H: cint;
begin
  if R.Icon >= 0 then
    Exit(KEY_ICONS[R.Icon].W);
  Result := 0;
  if TTF_SizeUTF8(Font, PAnsiChar(AnsiString(R.Text)), @W, @H) = 0 then
    Result := W;
end;

{ The five passes, as one surface with an alpha channel. }
function Compose(const S: string; Outline, Fill: TColor;
                 Face: Integer): PSDL_Surface;
const
  DX: array[0..3] of Integer = (-1, 1, 0, 0);
  DY: array[0..3] of Integer = ( 0, 0,-1, 1);
var
  I: Integer;
  Text: PSDL_Surface;
  Sheet: PSDL_Surface;
  Dst: TSDL_Rect;
  W, H: Integer;
  TW, TH: cint;
begin
  Result := nil;
  if not EnsureFont(Face) then
    Exit;
  { Measured on the UNSTROKED face. The ring makes the rendered glyphs wider,
    but the advance the layout depends on is the plain one. }
  if TTF_SizeUTF8(Font, PAnsiChar(AnsiString(S)), @TW, @TH) <> 0 then
    Exit;
  if (TW <= 0) or (TH <= 0) then
    Exit;

  { One pixel of outline on every side. }
  W := TW + 2;
  H := TH + 2;

  { With an ALPHA mask - the last argument. Without it the surface has no
    alpha channel to blend into and every glyph arrives opaque. }
  Sheet := SDL_CreateRGBSurface(0, W, H, 32,
                                $00FF0000, $0000FF00, $000000FF, $FF000000);
  if Sheet = nil then
    Exit;
  Result := Sheet;
  begin
    { Fully transparent, so only what the glyphs cover ends up composited. }
    SDL_FillRect(Sheet, nil, SDL_MapRGBA(Sheet^.format, 0, 0, 0, 0));
    SDL_SetSurfaceBlendMode(Sheet, SDL_BLENDMODE_BLEND);

    { The game's own five passes: four one-pixel offsets in the outline
      colour, then the fill over them. }
    for I := 0 to 4 do
    begin
      if I < 4 then
        Text := TTF_RenderUTF8_Solid(Font, PAnsiChar(AnsiString(S)),
                                     ToSDLColor(Outline))
      else
        Text := TTF_RenderUTF8_Solid(Font, PAnsiChar(AnsiString(S)),
                                     ToSDLColor(Fill));
      if Text = nil then
        Continue;
      { A plain copy: the colour key already drops the background, and the
        glyph pixels are opaque. Blending an 8-bit keyed surface onto ARGB
        copies nothing at all under SDL 2.0.10, the PortMaster image's. }
      SDL_SetSurfaceBlendMode(Text, SDL_BLENDMODE_NONE);
      if I < 4 then
      begin
        Dst.x := 1 + DX[I];
        Dst.y := 1 + DY[I];
      end
      else
      begin
        Dst.x := 1;
        Dst.y := 1;
      end;
      Dst.w := Text^.w;
      Dst.h := Text^.h;
      SDL_BlitSurface(Text, nil, Sheet, @Dst);
      SDL_FreeSurface(Text);
    end;
  end;
end;

{ The cache slot for this string, composing it if this is the first ask.
  -1 if there is no font or nothing to draw. }
function ComposeWithIcons(const S: string; Outline, Fill: TColor;
                          Face: Integer; out TopPad: Integer): PSDL_Surface;
  forward;

function Slot(const S: string; Outline, Fill: TColor; Face: Integer): Integer;
var
  Key: string;
  Sheet: PSDL_Surface;
  I, Pad: Integer;
begin
  Key := Format('%s|%.8x|%.8x|%s', [WantedFont(Face), Outline, Fill, S]);
  for I := 0 to High(Cache) do
    if Cache[I].Key = Key then
      Exit(I);

  Pad := 0;
  if HasIcon(S) then
    Sheet := ComposeWithIcons(S, Outline, Fill, Face, Pad)
  else
    Sheet := Compose(S, Outline, Fill, Face);
  if Sheet = nil then
    Exit(-1);
  SetLength(Cache, Length(Cache) + 1);
  Result := High(Cache);
  Cache[Result].Key := Key;
  Cache[Result].Surface := Sheet;
  Cache[Result].TopPad := Pad;
end;

{ The runs laid out left to right: each text run gets the five passes at its
  own x, each icon is copied from the sheet, centred on the text's height. }
function ComposeWithIcons(const S: string; Outline, Fill: TColor;
                          Face: Integer; out TopPad: Integer): PSDL_Surface;
const
  DX: array[0..3] of Integer = (-1, 1, 0, 0);
  DY: array[0..3] of Integer = ( 0, 0,-1, 1);
var
  Runs: TArray<TRun>;
  R: TRun;
  I, X, TW, TH, IconTop, W, H: Integer;
  Text, Sheet: PSDL_Surface;
  Src, Dst: TSDL_Rect;
begin
  Result := nil;
  TopPad := 0;
  if not EnsureFont(Face) then
    Exit;
  EnsureIconSheet;
  Runs := RunsOf(S);
  TW := 0;
  for R in Runs do
    Inc(TW, RunWidth(R));
  TH := TTF_FontHeight(Font);
  if (TW <= 0) or (TH <= 0) then
    Exit;

  { The text starts one pixel in, for the outline; the icons are centred on
    its height, and whatever of them rises above the sheet becomes pad. }
  IconTop := 1 + (TH - KEY_ICON_H) div 2;
  if IconTop < 0 then
    TopPad := -IconTop;
  W := TW + 2;
  H := TopPad + TH + 2;
  if IconTop + TopPad + KEY_ICON_H > H then
    H := IconTop + TopPad + KEY_ICON_H;

  Sheet := SDL_CreateRGBSurface(0, W, H, 32,
                                $00FF0000, $0000FF00, $000000FF, $FF000000);
  if Sheet = nil then
    Exit;
  Result := Sheet;
  SDL_FillRect(Sheet, nil, SDL_MapRGBA(Sheet^.format, 0, 0, 0, 0));
  SDL_SetSurfaceBlendMode(Sheet, SDL_BLENDMODE_BLEND);

  X := 1;
  for R in Runs do
  begin
    if R.Icon >= 0 then
    begin
      if IconSheet <> nil then
      begin
        Src.x := KEY_ICONS[R.Icon].X;
        Src.y := KEY_ICONS[R.Icon].Y;
        Src.w := KEY_ICONS[R.Icon].W;
        Src.h := KEY_ICON_H;
        Dst.x := X;
        Dst.y := IconTop + TopPad;
        Dst.w := Src.w;
        Dst.h := Src.h;
        SDL_BlitSurface(IconSheet, @Src, Sheet, @Dst);
      end;
    end
    else
      for I := 0 to 4 do
      begin
        if I < 4 then
          Text := TTF_RenderUTF8_Solid(Font, PAnsiChar(AnsiString(R.Text)),
                                       ToSDLColor(Outline))
        else
          Text := TTF_RenderUTF8_Solid(Font, PAnsiChar(AnsiString(R.Text)),
                                       ToSDLColor(Fill));
        if Text = nil then
          Continue;
        SDL_SetSurfaceBlendMode(Text, SDL_BLENDMODE_NONE);
        Dst.x := X;
        Dst.y := 1 + TopPad;
        if I < 4 then
        begin
          Inc(Dst.x, DX[I]);
          Inc(Dst.y, DY[I]);
        end;
        Dst.w := Text^.w;
        Dst.h := Text^.h;
        SDL_BlitSurface(Text, nil, Sheet, @Dst);
        SDL_FreeSurface(Text);
      end;
    Inc(X, RunWidth(R));
  end;
end;

function OutlinedTextSurface(const S: string; Outline, Fill: TColor;
                             Face: Integer; out TopPad: Integer): PSDL_Surface;
var
  I: Integer;
begin
  TopPad := 0;
  I := Slot(S, Outline, Fill, Face);
  if I < 0 then
    Exit(nil);
  Result := Cache[I].Surface;
  TopPad := Cache[I].TopPad;
end;

procedure ShutdownTextRender;
var
  I: Integer;
begin
  for I := 0 to High(Cache) do
    if Cache[I].Surface <> nil then
      SDL_FreeSurface(Cache[I].Surface);
  SetLength(Cache, 0);
  if IconSheet <> nil then
    SDL_FreeSurface(IconSheet);
  IconSheet := nil;
  IconSheetTried := False;
  if Font <> nil then
  begin
    TTF_CloseFont(Font);
    Font := nil;
  end;
  if Started then
  begin
    TTF_Quit;
    Started := False;
  end;
end;

finalization
  ShutdownTextRender;

end.
