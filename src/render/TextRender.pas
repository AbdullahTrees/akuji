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
  bitmap is kept until something evicts it. }

unit TextRender;

{$MODE DELPHI}{$H+}

interface

uses
  { Graphics for TColor, which is how the game says what colour it means. }
  Classes, SysUtils, Graphics, SDL2;

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
                             Face: Integer): PSDL_Surface;

{ How wide the string is, in pixels, at this size. Zero if there is no font. }
function OutlinedTextWidth(const S: string; Face: Integer): Integer;

procedure ShutdownTextRender;

implementation

uses
  ctypes, SDL2_ttf, RenderTarget;

type
  TCacheEntry = record
    Key: string;
    Surface: PSDL_Surface;
  end;

var
  FontDir: string = '';
  Font: PTTF_Font = nil;
  FontFace: Integer = -1;
  Started: Boolean = False;
  Cache: array of TCacheEntry;

procedure SetFontDirectory(const ADir: string);
begin
  FontDir := IncludeTrailingPathDelimiter(ADir);
end;

{ Opens the font at this size, reusing the handle while the size is unchanged.
  Only one size is ever asked for, but the check costs nothing and a second
  caller with a different size would otherwise silently get the first one's. }
function EnsureFont(Face: Integer): Boolean;
var
  Path: string;
begin
  if (Font <> nil) and (FontFace = Face) then
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
  Path := FontDir + OUTLINED_FONT_FILE;
  if not FileExists(Path) then
    Exit(False);
  { The ptsize argument is ignored for a bitmap face; the index is what picks
    the strike. The 12 is a placeholder and means nothing. }
  Font := TTF_OpenFontIndex(PAnsiChar(AnsiString(Path)), 12, Face);
  if Font = nil then
    Exit(False);
  FontFace := Face;
  Result := True;
end;

function TextRenderReady: Boolean;
begin
  Result := Font <> nil;
end;

function OutlinedTextWidth(const S: string; Face: Integer): Integer;
var
  W, H: cint;
begin
  Result := 0;
  if not EnsureFont(Face) then
    Exit;
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
      SDL_SetSurfaceBlendMode(Text, SDL_BLENDMODE_BLEND);
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
function Slot(const S: string; Outline, Fill: TColor; Face: Integer): Integer;
var
  Key: string;
  Sheet: PSDL_Surface;
  I: Integer;
begin
  Key := Format('%d|%.8x|%.8x|%s', [Face, Outline, Fill, S]);
  for I := 0 to High(Cache) do
    if Cache[I].Key = Key then
      Exit(I);

  Sheet := Compose(S, Outline, Fill, Face);
  if Sheet = nil then
    Exit(-1);
  SetLength(Cache, Length(Cache) + 1);
  Result := High(Cache);
  Cache[Result].Key := Key;
  Cache[Result].Surface := Sheet;
end;

function OutlinedTextSurface(const S: string; Outline, Fill: TColor;
                             Face: Integer): PSDL_Surface;
var
  I: Integer;
begin
  I := Slot(S, Outline, Fill, Face);
  if I < 0 then
    Exit(nil);
  Result := Cache[I].Surface;
end;

procedure ShutdownTextRender;
var
  I: Integer;
begin
  for I := 0 to High(Cache) do
    if Cache[I].Surface <> nil then
      SDL_FreeSurface(Cache[I].Surface);
  SetLength(Cache, 0);
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
