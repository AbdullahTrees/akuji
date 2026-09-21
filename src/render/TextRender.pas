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

  WHY 14 AND NOT 10

  SDL_ttf sizes in pixels per em, not points, and the number that matters is
  the one the game's own layout implies rather than any conversion. At 14 ppem
  SDL_ttf measures 'Yes       ' at exactly 52 pixels, which is what puts "No"
  where the hand expects it. The font's hdmx table - the per-ppem integer
  advances GDI uses - agrees at 52 for the same size.

  WHY THE GLYPHS ARE ANTIALIASED

  TTF_RenderUTF8_Blended. Solid was tried first, on the reasoning that the
  raster font this replaces had hard edges - and it looks wrong beside what the
  game actually draws, which is visibly smooth. The reasoning was sound and the
  premise was not: GDI antialiases its substituted TrueType face, so smooth
  edges are what the game has been showing, and they are what it should keep.

  Blended costs a real alpha channel rather than a colour key, so the sheet is
  composited onto the destination instead of blitted through a key. The five
  passes are blended together in SDL first, the same way five TextOut calls
  accumulate in GDI.

  WHY IT IS CACHED

  A dialogue box redraws its line sixty times a second and the line changes
  when the player presses a key. Rendering five passes through FreeType every
  frame would be wasteful; the strings are few and short, so each rendered
  bitmap is kept until something evicts it. }

unit TextRender;

{$MODE DELPHI}{$H+}

interface

uses
  Classes, SysUtils, Graphics;

{ Where assets/fonts lives. Called once the data directory is known; until it
  is, text renders nothing rather than guessing at a path. }
procedure SetFontDirectory(const ADir: string);

{ True once the font file has been opened successfully. }
function TextRenderReady: Boolean;

{ The string drawn five times - four offsets in Outline, then Fill - as one
  bitmap with a colour key. The caller draws it at (X - 1, Y - 1), because the
  outline extends one pixel above and to the left of where the text itself
  starts.

  Returns nil if there is no font, which is not fatal: the game simply has no
  narration rather than failing to start. The bitmap belongs to the cache and
  must not be freed. }
function OutlinedText(const S: string; Outline, Fill: TColor;
                      Ppem: Integer): TBitmap;

{ How wide the string is, in pixels, at this size. Zero if there is no font. }
function OutlinedTextWidth(const S: string; Ppem: Integer): Integer;

procedure ShutdownTextRender;

implementation

uses
  ctypes, SDL2, SDL2_ttf, RenderTarget, IntfGraphics, FPImage, GraphType;

type
  TCacheEntry = record
    Key: string;
    Bmp: TBitmap;
  end;

var
  FontDir: string = '';
  Font: PTTF_Font = nil;
  FontPpem: Integer = 0;
  Started: Boolean = False;
  Cache: array of TCacheEntry;

procedure SetFontDirectory(const ADir: string);
begin
  FontDir := IncludeTrailingPathDelimiter(ADir);
end;

{ Opens the font at this size, reusing the handle while the size is unchanged.
  Only one size is ever asked for, but the check costs nothing and a second
  caller with a different size would otherwise silently get the first one's. }
function EnsureFont(Ppem: Integer): Boolean;
var
  Path: string;
begin
  if (Font <> nil) and (FontPpem = Ppem) then
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
  Font := TTF_OpenFont(PAnsiChar(AnsiString(Path)), Ppem);
  if Font = nil then
    Exit(False);
  FontPpem := Ppem;
  Result := True;
end;

function TextRenderReady: Boolean;
begin
  Result := Font <> nil;
end;

function OutlinedTextWidth(const S: string; Ppem: Integer): Integer;
var
  W, H: cint;
begin
  Result := 0;
  if not EnsureFont(Ppem) then
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

{ Builds the five-pass surface, then copies it into an LCL bitmap once. }
function Compose(const S: string; Outline, Fill: TColor;
                 Ppem: Integer): TBitmap;
const
  DX: array[0..3] of Integer = (-1,  1,  0,  0);
  DY: array[0..3] of Integer = ( 0,  0, -1,  1);
var
  Text: PSDL_Surface;
  Sheet: PSDL_Surface;
  Img: TLazIntfImage;
  Col: TFPColor;
  Dst: TSDL_Rect;
  I, X, Y, W, H: Integer;
  Pixels: PUInt32;
  Pixel: LongWord;
  Row: PByte;
  TW, TH: cint;
begin
  Result := nil;
  if not EnsureFont(Ppem) then
    Exit;
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
  try
    { Fully transparent, so only what the glyphs cover ends up composited. }
    SDL_FillRect(Sheet, nil, SDL_MapRGBA(Sheet^.format, 0, 0, 0, 0));
    SDL_SetSurfaceBlendMode(Sheet, SDL_BLENDMODE_BLEND);

    for I := 0 to 4 do
    begin
      if I < 4 then
        Text := TTF_RenderUTF8_Blended(Font, PAnsiChar(AnsiString(S)),
                                       ToSDLColor(Outline))
      else
        Text := TTF_RenderUTF8_Blended(Font, PAnsiChar(AnsiString(S)),
                                       ToSDLColor(Fill));
      if Text = nil then
        Continue;
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
      SDL_SetSurfaceBlendMode(Text, SDL_BLENDMODE_BLEND);
      SDL_BlitSurface(Text, nil, Sheet, @Dst);
      SDL_FreeSurface(Text);
    end;

    { Built through TLazIntfImage because a TBitmap's Canvas has no way to
      write an alpha channel, and the alpha is the whole point. }
    Img := TLazIntfImage.Create(W, H, [riqfRGB, riqfAlpha]);
    try
      for Y := 0 to H - 1 do
      begin
        Row := PByte(Sheet^.pixels) + Y * Sheet^.pitch;
        Pixels := PUInt32(Row);
        for X := 0 to W - 1 do
        begin
          Pixel := Pixels^;
          Inc(Pixels);
          Col.red   := ((Pixel shr 16) and $FF) * 257;
          Col.green := ((Pixel shr 8)  and $FF) * 257;
          Col.blue  := ( Pixel         and $FF) * 257;
          Col.alpha := ((Pixel shr 24) and $FF) * 257;
          Img.Colors[X, Y] := Col;
        end;
      end;
      Result := TBitmap.Create;
      Result.PixelFormat := pf32bit;
      Result.LoadFromIntfImage(Img);
    finally
      Img.Free;
    end;
  finally
    SDL_FreeSurface(Sheet);
  end;
end;

function OutlinedText(const S: string; Outline, Fill: TColor;
                      Ppem: Integer): TBitmap;
var
  Key: string;
  I: Integer;
begin
  Key := Format('%d|%.8x|%.8x|%s', [Ppem, Outline, Fill, S]);
  for I := 0 to High(Cache) do
    if Cache[I].Key = Key then
      Exit(Cache[I].Bmp);

  Result := Compose(S, Outline, Fill, Ppem);
  if Result = nil then
    Exit;
  SetLength(Cache, Length(Cache) + 1);
  Cache[High(Cache)].Key := Key;
  Cache[High(Cache)].Bmp := Result;
end;

procedure ShutdownTextRender;
var
  I: Integer;
begin
  for I := 0 to High(Cache) do
    Cache[I].Bmp.Free;
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
