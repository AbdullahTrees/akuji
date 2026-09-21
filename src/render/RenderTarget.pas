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

end.
