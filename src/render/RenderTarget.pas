{ What the game draws onto, and what it draws from.

  WHY THIS EXISTS

  Every routine that draws takes a `Dest: TCanvas` and reads from a `TBitmap`.
  Both are LCL types, so the renderer cannot be changed without touching all
  twelve units that draw. This puts one seam between the game and whatever is
  underneath it: the game asks for a rectangle to be filled or an image to be
  blitted, and the target decides how.

  Nothing uses it yet. It arrives on its own, with a test that it produces the
  same pixels as the canvas calls it replaces, so that the units that move onto
  it afterwards are each a small change against a tree that already works.

  THE TWO BLITS, AND WHY THEY ARE SEPARATE

  This is not a tidy abstraction of one operation; it reproduces an asymmetry
  the LCL has and the game depends on:

    BlitRect   copies a source RECTANGLE, background and all. TCanvas.CopyRect.
    DrawImage  draws a WHOLE image and honours the transparency it carries.
               TCanvas.Draw.

    BlitRectKeyed
               a source RECTANGLE, with the sheet's background treated as
               transparent. Two raster operations rather than one call,
               because the LCL has no such primitive - see below.

  There is no single LCL call that copies a sub-rectangle and honours a colour
  key, which is why the font cuts every glyph into its own bitmap and sprites
  did not. BlitRectKeyed closes that gap without cutting anything: see
  TRenderImage.KeyMask.

  TRenderImage currently wraps a TBitmap and exposes it. That escape hatch is
  what lets units move across one at a time; it is also the thing that has to
  be gone before an SDL target can exist. }

unit RenderTarget;

{$MODE DELPHI}{$H+}

interface

uses
  Classes, SysUtils, Graphics, Types, ctypes, SDL2;

const
  { What the sheets use for "nothing here".

    Every sheet in bmp.qda paints its background pure black and the artwork
    never touches it: the darkest colour in the character sheets is (3,5,17),
    a near-black chosen to stay clear of the key. The bitmap font already
    keys on the same value - GameFont.FONT_KEY_COLOR - and the original set
    this colour on its DirectDraw surfaces, which is what made its sprites
    transparent on the machines it was written for. }
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
    picture. }
  TRenderImage = class
  private
    FBitmap: TBitmap;
    FOwnsBitmap: Boolean;
    FKeyMask: TBitmap;
    FKeyMaskBuilt: Boolean;
    FSDLSurface: PSDL_Surface;
    FSDLBuilt: Boolean;
    FSDLKeyed: Boolean;
    function GetWidth: Integer;
    function GetHeight: Integer;
    function GetKeyMask: TBitmap;
  public
    { AOwns transfers ownership: the surface set keeps its own bitmaps, while a
      glyph cut for one image does not outlive it. }
    constructor Create(ABitmap: TBitmap; AOwns: Boolean = False);
    destructor Destroy; override;

    { The LCL bitmap underneath. Present so units can move across one at a
      time; every remaining use of it is work still to do before the renderer
      can be anything other than the LCL. }
    property Bitmap: TBitmap read FBitmap;

    { This image with every pixel reduced to one of two values: WHITE where
      the image is IMAGE_KEY_COLOR, BLACK everywhere else. It is what makes a
      keyed blit possible from a sub-rectangle:

          dest := (dest AND mask) OR source

      Where the source is background the mask is white, so the destination
      survives the AND and the OR adds black to it - nothing happens. Where
      the source is artwork the mask is black, so the AND clears the
      destination to zero and the OR writes the source pixel exactly. Both
      steps take a source rectangle, which is the property a colour-keyed
      Draw() does not have.

      Built once per image, the first time it is asked for, and held for as
      long as the image lives. That is deliberate: an earlier attempt at keyed
      sprites shared ONE scratch bitmap between every blit and produced sprites
      with pieces of other sprites' silhouettes cut out of them. A mask that
      belongs to the image it describes cannot be contaminated by another
      image, whatever the order of drawing. See notes/transparent-blit-fix.md.

      nil if the image has no bitmap. }
    property KeyMask: TBitmap read GetKeyMask;

    { The same picture as an SDL surface, in one fixed format, built once on
      first use and owned by this image.

      It is here so the renderer underneath can change without the units that
      draw knowing: an SDL target reads this, the LCL target reads the bitmap,
      and both are the same pixels. While both targets exist an image may hold
      both; when the LCL one goes, the bitmap goes with it and this is all
      that is left.

      Want says whether the blit about to happen is keyed. In SDL the key is a
      property of the SOURCE SURFACE, not of the blit, so it has to be set
      beforehand - and setting it throws away SDL's cached blit function, so
      it is only written when it actually changes. Sheets really are drawn
      both ways: sys.bmp carries the HUD icons, which are keyed, and the
      dialogue frame, which is not.

      nil if there is nothing to build from. }
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

    { A whole image, honouring any transparency it carries. }
    procedure DrawImage(Src: TRenderImage; X, Y: Integer); virtual; abstract;

    { A whole image scaled into a rectangle. The ending slides are the only
      thing the game scales, and they are the reason this exists rather than
      being folded into DrawImage: the scaling filter is a visible choice, and
      an SDL target picks it explicitly. }
    procedure StretchImage(Src: TRenderImage;
                           const DestRect: TRect); virtual; abstract;

    { Text in a SYSTEM font, outlined by drawing it five times.

      The odd one out, and deliberately part of the seam rather than left to
      callers. Everything else the game draws is pixels it already owns; the
      opening narration is the one place that asks the platform for glyphs,
      because the bitmap font only covers $20..$5F and the narration has
      lowercase in it. An SDL target has to answer this with SDL_ttf or with a
      prerendered sheet - it is the one primitive with no direct equivalent. }
    procedure DrawOutlinedText(X, Y: Integer; const S: string;
                               Outline, Fill: TColor;
                               Size: Integer); virtual; abstract;

    property Width: Integer read GetWidth;
    property Height: Integer read GetHeight;
  end;

  { The target the game has always had: an LCL canvas. }
  TLCLRenderTarget = class(TRenderTarget)
  private
    FCanvas: TCanvas;
    FWidth: Integer;
    FHeight: Integer;
  protected
    function GetWidth: Integer; override;
    function GetHeight: Integer; override;
  public
    { The canvas is borrowed, not owned - it belongs to the bitmap or form
      behind it, which outlives any target wrapped around it. }
    constructor Create(ACanvas: TCanvas; AWidth, AHeight: Integer);

    procedure Fill(const R: TRect; AColor: TColor); override;
    procedure BlitRect(Src: TRenderImage; const SrcRect: TRect;
                       X, Y: Integer); override;
    procedure BlitRectKeyed(Src: TRenderImage; const SrcRect: TRect;
                            X, Y: Integer); override;
    procedure DrawImage(Src: TRenderImage; X, Y: Integer); override;
    procedure StretchImage(Src: TRenderImage; const DestRect: TRect); override;
    procedure DrawOutlinedText(X, Y: Integer; const S: string;
                               Outline, Fill: TColor; Size: Integer); override;

    property Canvas: TCanvas read FCanvas;
  end;

implementation

uses
  { In the implementation, because TextRender names this unit's font
    constants in turn. Pascal permits the cycle only from here. }
  TextRender, IntfGraphics, FPImage, GraphType;

{ TRenderImage }

constructor TRenderImage.Create(ABitmap: TBitmap; AOwns: Boolean);
begin
  inherited Create;
  FBitmap := ABitmap;
  FOwnsBitmap := AOwns;
end;

destructor TRenderImage.Destroy;
begin
  if FSDLSurface <> nil then
    SDL_FreeSurface(FSDLSurface);
  FKeyMask.Free;
  if FOwnsBitmap then
    FBitmap.Free;
  inherited Destroy;
end;

{ Built through TLazIntfImage rather than Canvas.Pixels because the latter is
  a round trip into the widgetset per pixel, and a sheet is a hundred thousand
  of them. The image is edited in place and loaded back, so the mask ends up
  in exactly the same pixel format as the sheet it describes - which is what
  keeps the two raster operations in step. }
function TRenderImage.GetKeyMask: TBitmap;
var
  Img: TLazIntfImage;
  Key, White, Black: TFPColor;
  C: TFPColor;
  X, Y: Integer;
begin
  Result := FKeyMask;
  if FKeyMaskBuilt or (FBitmap = nil) then
    Exit;

  { Set before the work, not after: a sheet that cannot be read must not be
    retried on every blit for the rest of the run. }
  FKeyMaskBuilt := True;
  if (FBitmap.Width <= 0) or (FBitmap.Height <= 0) then
    Exit;

  Key := TColorToFPColor(ColorToRGB(IMAGE_KEY_COLOR));
  { Opaque white and opaque black. The alpha byte matters: a mask with alpha 0
    would AND the destination's own alpha away, and while nothing reads it
    today, a target that later blends would find the buffer transparent. }
  White := FPColor($FFFF, $FFFF, $FFFF, $FFFF);
  Black := FPColor(0, 0, 0, $FFFF);

  Img := FBitmap.CreateIntfImage;
  try
    for Y := 0 to Img.Height - 1 do
      for X := 0 to Img.Width - 1 do
      begin
        C := Img.Colors[X, Y];
        { Alpha is ignored: the sheets carry none, and where a format leaves
          the byte uninitialised it would otherwise decide the comparison. }
        if (C.red = Key.red) and (C.green = Key.green)
        and (C.blue = Key.blue) then
          Img.Colors[X, Y] := White
        else
          Img.Colors[X, Y] := Black;
      end;
    FKeyMask := TBitmap.Create;
    FKeyMask.LoadFromIntfImage(Img);
  finally
    Img.Free;
  end;
  Result := FKeyMask;
end;

function TRenderImage.GetWidth: Integer;
begin
  if FBitmap = nil then
    Exit(0);
  Result := FBitmap.Width;
end;

function TRenderImage.GetHeight: Integer;
begin
  if FBitmap = nil then
    Exit(0);
  Result := FBitmap.Height;
end;

{ Built by handing SDL the bitmap's own pixels, in whatever layout the
  platform gave them, and letting SDL convert once. The masks come from the
  LCL's description of its own buffer rather than being assumed, because a
  24-bit and a 32-bit bitmap differ and both turn up here.

  The alpha mask is deliberately 0. A 32-bit LCL bitmap has an alpha byte that
  nothing in this game ever writes, so reading it would make sheets vanish by
  accident; 0 tells SDL every pixel is opaque. }
function TRenderImage.SDLSurface(Want: Boolean): PSDL_Surface;
var
  Raw: TRawImage;
  Src: PSDL_Surface;
  Key: LongWord;

  function Mask(Shift, Prec: Byte): cuint32;
  begin
    if Prec = 0 then
      Exit(0);
    Result := ((cuint32(1) shl Prec) - 1) shl Shift;
  end;

begin
  if not FSDLBuilt then
  begin
    { Set first: a bitmap that cannot be read must not be retried per blit. }
    FSDLBuilt := True;
    if (FBitmap <> nil) and (FBitmap.Width > 0) and (FBitmap.Height > 0) then
    begin
      Raw := FBitmap.RawImage;
      Src := SDL_CreateRGBSurfaceFrom(Raw.Data,
               FBitmap.Width, FBitmap.Height,
               Raw.Description.BitsPerPixel, Raw.Description.BytesPerLine,
               Mask(Raw.Description.RedShift, Raw.Description.RedPrec),
               Mask(Raw.Description.GreenShift, Raw.Description.GreenPrec),
               Mask(Raw.Description.BlueShift, Raw.Description.BluePrec),
               0);
      if Src <> nil then
      begin
        { Converting COPIES, which is what makes it safe to let the raw image
          go again: from here the surface owns its own pixels. }
        FSDLSurface := SDL_ConvertSurfaceFormat(Src,
                                                SDL_PIXELFORMAT_ARGB8888, 0);
        SDL_FreeSurface(Src);
      end;
      if FSDLSurface <> nil then
        { The sheets carry no alpha, so blending them would only cost time. }
        SDL_SetSurfaceBlendMode(FSDLSurface, SDL_BLENDMODE_NONE);
    end;
  end;

  Result := FSDLSurface;
  if (Result = nil) or (Want = FSDLKeyed) then
    Exit;
  FSDLKeyed := Want;
  if Want then
  begin
    Key := LongWord(ColorToRGB(IMAGE_KEY_COLOR));
    SDL_SetColorKey(Result, 1,
      SDL_MapRGB(Result^.format, Byte(Key), Byte(Key shr 8), Byte(Key shr 16)));
  end
  else
    SDL_SetColorKey(Result, 0, 0);
end;

{ TLCLRenderTarget }

constructor TLCLRenderTarget.Create(ACanvas: TCanvas; AWidth, AHeight: Integer);
begin
  inherited Create;
  FCanvas := ACanvas;
  FWidth := AWidth;
  FHeight := AHeight;
end;

function TLCLRenderTarget.GetWidth: Integer;
begin
  Result := FWidth;
end;

function TLCLRenderTarget.GetHeight: Integer;
begin
  Result := FHeight;
end;

procedure TLCLRenderTarget.Fill(const R: TRect; AColor: TColor);
begin
  { Brush colour is set per call rather than cached. The callers being replaced
    set it immediately before every FillRect, and a target that remembered it
    would paint a different colour the first time one of them stopped. }
  FCanvas.Brush.Color := AColor;
  FCanvas.FillRect(R);
end;

procedure TLCLRenderTarget.BlitRect(Src: TRenderImage; const SrcRect: TRect;
  X, Y: Integer);
begin
  if (Src = nil) or (Src.Bitmap = nil) then
    Exit;
  FCanvas.CopyRect(
    Rect(X, Y,
         X + (SrcRect.Right - SrcRect.Left),
         Y + (SrcRect.Bottom - SrcRect.Top)),
    Src.Bitmap.Canvas, SrcRect);
end;

procedure TLCLRenderTarget.BlitRectKeyed(Src: TRenderImage;
  const SrcRect: TRect; X, Y: Integer);
var
  Mask: TBitmap;
  Dest: TRect;
  Saved: TCopyMode;
begin
  if (Src = nil) or (Src.Bitmap = nil) then
    Exit;
  Mask := Src.KeyMask;
  if Mask = nil then
  begin
    { No mask could be built. An opaque sprite is wrong, but it is the picture
      the game has drawn all along and it is better than an invisible one. }
    BlitRect(Src, SrcRect, X, Y);
    Exit;
  end;

  Dest := Rect(X, Y,
               X + (SrcRect.Right - SrcRect.Left),
               Y + (SrcRect.Bottom - SrcRect.Top));
  Saved := FCanvas.CopyMode;
  try
    { Punch the silhouette black, then OR the artwork into the hole. The
      source's own background is black and OR leaves the destination alone. }
    FCanvas.CopyMode := cmSrcAnd;
    FCanvas.CopyRect(Dest, Mask.Canvas, SrcRect);
    FCanvas.CopyMode := cmSrcPaint;
    FCanvas.CopyRect(Dest, Src.Bitmap.Canvas, SrcRect);
  finally
    FCanvas.CopyMode := Saved;
  end;
end;

procedure TLCLRenderTarget.DrawImage(Src: TRenderImage; X, Y: Integer);
begin
  if (Src = nil) or (Src.Bitmap = nil) then
    Exit;
  FCanvas.Draw(X, Y, Src.Bitmap);
end;

procedure TLCLRenderTarget.StretchImage(Src: TRenderImage;
  const DestRect: TRect);
begin
  if (Src = nil) or (Src.Bitmap = nil) then
    Exit;
  FCanvas.StretchDraw(DestRect, Src.Bitmap);
end;

procedure TLCLRenderTarget.DrawOutlinedText(X, Y: Integer; const S: string;
  Outline, Fill: TColor; Size: Integer);
var
  Sheet: TBitmap;
begin
  if S = '' then
    Exit;

  { SDL_ttf from the font the game carries, not GDI from whatever the host
    calls "MS Sans Serif". Size is ignored: it is 10 POINTS, and a bitmap face
    is selected by strike rather than sized - see OUTLINED_FONT_FACE. }
  Sheet := OutlinedText(S, Outline, Fill, OUTLINED_FONT_FACE);
  if Sheet <> nil then
  begin
    { The composed sheet carries its outline, so its top-left is one pixel up
      and left of where the text itself begins. }
    FCanvas.Draw(X - 1, Y - 1, Sheet);
    Exit;
  end;

  { No font to render with - fall back to asking the platform, which is what
    the game did before and is better than silence. }
  FCanvas.Font.Name := OUTLINED_FONT_NAME;
  FCanvas.Font.Size := Size;
  FCanvas.Font.Color := Outline;
  FCanvas.Brush.Style := bsClear;
  FCanvas.TextOut(X - 1, Y, S);
  FCanvas.TextOut(X + 1, Y, S);
  FCanvas.TextOut(X, Y - 1, S);
  FCanvas.TextOut(X, Y + 1, S);
  FCanvas.Font.Color := Fill;
  FCanvas.TextOut(X, Y, S);
end;

end.
