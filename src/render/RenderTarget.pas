{ What the game draws onto, and what it draws from.

  WHY THIS EXISTS

  Every routine that drew used to take a `Dest: TCanvas` and read from a
  `TBitmap`, both LCL types, so the renderer could not be changed without
  touching all twelve units that draw. This is the one seam between the game
  and whatever is underneath it: the game asks for a rectangle to be filled or
  an image to be blitted, and the target decides how.

  The only target now is SDLTarget's, which draws with SDL surface blits. The
  LCL one it replaced is in the history, along with the test that ran both
  over the same scenes and required the pixels to be identical; what survives
  of that proof is the pinned checksums in --selftest-render, which were
  recorded from the LCL renderer and still hold.

  THE TWO RECTANGLE BLITS, AND WHY THEY ARE SEPARATE

    BlitRect        copies a source RECTANGLE, background and all
    BlitRectKeyed   the same rectangle, with IMAGE_KEY_COLOR left behind
    DrawImage       a WHOLE image, opaquely
    StretchImage    a whole image scaled into a rectangle

  The split is not tidiness. It is what the original binary distinguished:
  TDDDD_DrawSprite passes its caller's flag word to BltFast as dwTrans, and
  every call site in the game picks whether it wanted a colour key - sprites,
  HUD icons and the dialogue box's icons did, the dialogue frame and the tile
  layer did not. See notes/divergences.md, DIV-017. }

unit RenderTarget;

{$MODE DELPHI}{$H+}

interface

uses
  Classes, SysUtils, GameColors, Types, ctypes, SDL2;

const
  { What the sheets use for "nothing here".

    Every sheet in bmp.qda paints its background pure black and the artwork
    never touches it: the darkest colour in the character sheets is (3,5,17),
    a near-black chosen to stay clear of the key. The bitmap font sheet is
    painted the same way, and the original set this colour on its DirectDraw
    surfaces, which is what made its sprites transparent on the machines it
    was written for. }
  IMAGE_KEY_COLOR = clBlack;

  { The system font the opening narration is drawn in. It lives here rather
    than with the bitmap font because the target is what has to satisfy it,
    and GameFont re-exports it so the check that pins it against the
    original binary keeps working. }
  OUTLINED_FONT_NAME = 'MS Sans Serif';

  { The same font as a file, under the game's data directory, so a port does
    not depend on the host having it installed.

    It is the RASTER font, not a TrueType lookalike. Raw GDI - which is what
    the game draws through - reports TrueType=False for "MS Sans Serif" and
    selects sserife.fon, a hand-tuned bitmap face. GDI+ substitutes the
    TrueType Microsoft Sans Serif for the same name and that is what misled an
    earlier version of this comment; the letterforms differ visibly, most
    obviously in 'a' and 'j'.

    FreeType reads Windows FNT, so SDL_ttf opens this file directly.

    THE SIZE IS A FACE INDEX, NOT A POINT SIZE. A bitmap font carries fixed
    strikes rather than a scalable outline, and TTF_OpenFont ignores its ptsize
    argument for one - it always returns face 0. TTF_OpenFontIndex picks the
    strike. This file holds six:

        face 0   13px cell    'Yes       ' = 39px
        face 1   16px cell    'Yes       ' = 45px    <- the original's strike
        face 2   20px cell    'Yes       ' = 56px
        face 3   24px cell    'Yes       ' = 67px
        face 4   29px cell    'Yes       ' = 84px
        face 5   37px cell    'Yes       ' = 118px

    Face 1 is the one the ORIGINAL BINARY renders with, measured off
    screenshots of it rather than assumed. Two strings pin it independently:

        "Will you save the game?"   original 146x15   face 1 gives 147x15
        "Yes       No"              original  63x12   face 1 gives  64x12

    and no other strike is close on either - face 0 gives 118x13 and 55x11,
    face 2 gives 171x18 and 77x14.

    This reconstruction had been rendering face 0, which is why its text looked
    small beside the original. The save prompt's overlap belongs to face 1 too:
    'Yes       ' is 45 where clearing the hand needs 52, so the original
    overlaps by 6 pixels and so does this. That is the defect being reproduced
    rather than one being introduced. }
  OUTLINED_FONT_FILE   = 'fonts' + PathDelim + 'sserife.fon';
  OUTLINED_FONT_FACE   = 1;

type
  { Something that can be blitted from: a sheet, a glyph, a full-screen
    picture. One SDL surface, in one fixed format, owned by the image. }
  TRenderImage = class
  private
    FSurface: PSDL_Surface;
    FKeyed: Boolean;
    function GetWidth: Integer;
    function GetHeight: Integer;
  public
    { TAKES OWNERSHIP of the surface, and converts it to the renderer's format
      once so that no blit has to. A surface that cannot be converted leaves
      the image empty rather than raising: a sheet that fails to load should
      cost its own picture and not the run. }
    constructor Create(ASurface: PSDL_Surface);
    destructor Destroy; override;

    { The surface to blit from, with the colour key set or cleared to match
      the blit about to happen.

      In SDL the key belongs to the SOURCE SURFACE rather than to the blit, so
      it has to be set beforehand - and setting it throws away SDL's cached
      blit function, so it is only written when it actually changes. Sheets
      really are drawn both ways: sys.bmp carries the HUD icons, which are
      keyed, and the dialogue frame, which is not.

      nil if the image is empty. }
    function SDLSurface(Want: Boolean): PSDL_Surface;

    property Width: Integer read GetWidth;
    property Height: Integer read GetHeight;
  end;

  { Something that can be drawn onto. }
  TRenderTarget = class
  protected
    function GetWidth: Integer; virtual; abstract;
    function GetHeight: Integer; virtual; abstract;
  public
    procedure Fill(const R: TRect; AColor: TColor); virtual; abstract;

    { A source rectangle, copied including whatever is behind the subject. }
    procedure BlitRect(Src: TRenderImage; const SrcRect: TRect;
                       X, Y: Integer); virtual; abstract;

    { The same rectangle, with IMAGE_KEY_COLOR left behind rather than copied.

      This is what the original did: its sprite blit ends in BltFast on a
      DirectDraw surface that carries a source colour key, so a sprite reached
      the screen without the black around it. BlitRect is kept beside it
      because the tile layer is opaque by nature - it IS the background - and
      keying it would cost two blits per tile for no change. }
    procedure BlitRectKeyed(Src: TRenderImage; const SrcRect: TRect;
                            X, Y: Integer); virtual; abstract;

    { A whole image, opaquely. }
    procedure DrawImage(Src: TRenderImage; X, Y: Integer); virtual; abstract;

    { A whole image scaled into a rectangle. The ending slides are the only
      thing the game scales, and they are the reason this exists rather than
      being folded into DrawImage: the scaling filter is a visible choice, and
      the target picks it explicitly. }
    procedure StretchImage(Src: TRenderImage;
                           const DestRect: TRect); virtual; abstract;

    { Text in a SYSTEM font, outlined by drawing it five times.

      The odd one out, and deliberately part of the seam rather than left to
      callers. Everything else the game draws is pixels it already owns; the
      opening narration is the one place that needs a rasteriser, because the
      bitmap font only covers $20..$5F and the narration has lowercase in it. }
    procedure DrawOutlinedText(X, Y: Integer; const S: string;
                               Outline, Fill: TColor;
                               Size: Integer); virtual; abstract;

    property Width: Integer read GetWidth;
    property Height: Integer read GetHeight;
  end;

implementation

{ TRenderImage }

constructor TRenderImage.Create(ASurface: PSDL_Surface);
begin
  inherited Create;
  if ASurface = nil then
    Exit;
  { Once, here, rather than inside every blit. The archive's pictures are
    8-bit paletted and the back buffer is 32-bit, so without this SDL would
    convert on the fly several hundred times a frame. }
  FSurface := SDL_ConvertSurfaceFormat(ASurface, SDL_PIXELFORMAT_ARGB8888, 0);
  SDL_FreeSurface(ASurface);
  if FSurface <> nil then
    { The sheets carry no alpha, so blending them would only cost time. }
    SDL_SetSurfaceBlendMode(FSurface, SDL_BLENDMODE_NONE);
end;

destructor TRenderImage.Destroy;
begin
  if FSurface <> nil then
    SDL_FreeSurface(FSurface);
  inherited Destroy;
end;

function TRenderImage.GetWidth: Integer;
begin
  if FSurface = nil then
    Exit(0);
  Result := FSurface^.w;
end;

function TRenderImage.GetHeight: Integer;
begin
  if FSurface = nil then
    Exit(0);
  Result := FSurface^.h;
end;

function TRenderImage.SDLSurface(Want: Boolean): PSDL_Surface;
var
  Key: LongWord;
begin
  Result := FSurface;
  if (Result = nil) or (Want = FKeyed) then
    Exit;
  FKeyed := Want;
  if Want then
  begin
    Key := LongWord(ColorToRGB(IMAGE_KEY_COLOR));
    SDL_SetColorKey(Result, 1,
      SDL_MapRGB(Result^.format, Byte(Key), Byte(Key shr 8), Byte(Key shr 16)));
  end
  else
    SDL_SetColorKey(Result, 0, 0);
end;

end.
