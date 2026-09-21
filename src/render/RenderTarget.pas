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

  There is no LCL call that does both, which is why the font cuts every glyph
  into its own bitmap and sprites do not. That asymmetry is also the open
  defect in notes/transparent-blit-fix.md, so the split is kept visible here
  rather than smoothed over - a target that silently keyed everything would
  change what the game looks like, and that is not this step's job.

  TRenderImage currently wraps a TBitmap and exposes it. That escape hatch is
  what lets units move across one at a time; it is also the thing that has to
  be gone before an SDL target can exist. }

unit RenderTarget;

{$MODE DELPHI}{$H+}

interface

uses
  Classes, SysUtils, Graphics, Types;

const
  { The system font the opening narration is drawn in. It lives here rather
    than with the bitmap font because the target is what has to satisfy it,
    and GameFont re-exports it so the check that pins it against the
    original binary keeps working. }
  OUTLINED_FONT_NAME = 'MS Sans Serif';

type
  { Something that can be blitted from: a sheet, a glyph, a full-screen
    picture. }
  TRenderImage = class
  private
    FBitmap: TBitmap;
    FOwnsBitmap: Boolean;
    function GetWidth: Integer;
    function GetHeight: Integer;
  public
    { AOwns transfers ownership: the surface set keeps its own bitmaps, while a
      glyph cut for one image does not outlive it. }
    constructor Create(ABitmap: TBitmap; AOwns: Boolean = False);
    destructor Destroy; override;

    { The LCL bitmap underneath. Present so units can move across one at a
      time; every remaining use of it is work still to do before the renderer
      can be anything other than the LCL. }
    property Bitmap: TBitmap read FBitmap;

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
    procedure DrawImage(Src: TRenderImage; X, Y: Integer); override;
    procedure StretchImage(Src: TRenderImage; const DestRect: TRect); override;
    procedure DrawOutlinedText(X, Y: Integer; const S: string;
                               Outline, Fill: TColor; Size: Integer); override;

    property Canvas: TCanvas read FCanvas;
  end;

implementation

{ TRenderImage }

constructor TRenderImage.Create(ABitmap: TBitmap; AOwns: Boolean);
begin
  inherited Create;
  FBitmap := ABitmap;
  FOwnsBitmap := AOwns;
end;

destructor TRenderImage.Destroy;
begin
  if FOwnsBitmap then
    FBitmap.Free;
  inherited Destroy;
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
begin
  if S = '' then
    Exit;
  FCanvas.Font.Name := OUTLINED_FONT_NAME;
  FCanvas.Font.Size := Size;
  FCanvas.Font.Color := Outline;
  FCanvas.Brush.Style := bsClear;
  { Four offset copies make the outline, then the fill over them. }
  FCanvas.TextOut(X - 1, Y, S);
  FCanvas.TextOut(X + 1, Y, S);
  FCanvas.TextOut(X, Y - 1, S);
  FCanvas.TextOut(X, Y + 1, S);
  FCanvas.Font.Color := Fill;
  FCanvas.TextOut(X, Y, S);
end;

end.
