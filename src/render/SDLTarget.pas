{ The render target that draws with SDL.

  WHY IT IS A SURFACE AND NOT A RENDERER

  SDL offers two ways to draw: SDL_Renderer, which needs a window and a video
  subsystem and hands the work to the GPU, and plain surface blits, which are
  software and need neither. This uses surfaces.

  The game is 320x240 and draws a few hundred blits a frame, so there is
  nothing here a GPU is needed for. What matters is that a surface target can
  be dropped in underneath the existing window: the component keeps its LCL
  back buffer, SDL draws into those very pixels, and the one line that puts
  the buffer on screen does not change. No window is created, no video
  subsystem is started, and nothing about input, the message loop or
  fullscreen is touched.

  That leaves ONE place that still knows about the LCL - presentation - and it
  is the place an SDL window replaces when the game is ported.

  WHAT HAS TO MATCH

  This target has to draw the same pixels as TLCLRenderTarget, not merely
  similar ones, because the pinned scenes in --selftest-render were recorded
  from the LCL one. The test runs every scene through both and compares. Two
  places needed care to make that true:

    * the colour key is a property of the SOURCE SURFACE in SDL, not of the
      blit, so TRenderImage.SDLSurface takes the blit's intent and sets the
      flag only when it changes.

    * blend mode. The sheets carry no alpha and are copied, not blended; the
      outlined text carries alpha and must be blended. Getting that backwards
      shows up as text with a black box around it, which is the same defect
      DIV-002 fixed for sprites, so it would be easy to misread. }

unit SDLTarget;

{$MODE DELPHI}{$H+}

interface

uses
  Classes, SysUtils, Graphics, Types, ctypes, SDL2, RenderTarget;

type
  TSDLRenderTarget = class(TRenderTarget)
  private
    FSurface: PSDL_Surface;
    procedure SetSurface(AValue: PSDL_Surface);
  protected
    function GetWidth: Integer; override;
    function GetHeight: Integer; override;
  public
    { The surface is BORROWED. It belongs to whatever owns the back buffer,
      which outlives any target wrapped around it. }
    constructor Create(ASurface: PSDL_Surface);

    procedure Fill(const R: TRect; AColor: TColor); override;
    procedure BlitRect(Src: TRenderImage; const SrcRect: TRect;
                       X, Y: Integer); override;
    procedure BlitRectKeyed(Src: TRenderImage; const SrcRect: TRect;
                            X, Y: Integer); override;
    procedure DrawImage(Src: TRenderImage; X, Y: Integer); override;
    procedure StretchImage(Src: TRenderImage; const DestRect: TRect); override;
    procedure DrawOutlinedText(X, Y: Integer; const S: string;
                               Outline, Fill: TColor; Size: Integer); override;

    { Repointed when the back buffer is rebuilt, so that a resize does not
      need the target itself to be replaced. }
    property Surface: PSDL_Surface read FSurface write SetSurface;
  end;

implementation

uses
  TextRender;

constructor TSDLRenderTarget.Create(ASurface: PSDL_Surface);
begin
  inherited Create;
  FSurface := ASurface;
end;

procedure TSDLRenderTarget.SetSurface(AValue: PSDL_Surface);
begin
  FSurface := AValue;
end;

function TSDLRenderTarget.GetWidth: Integer;
begin
  if FSurface = nil then
    Exit(0);
  Result := FSurface^.w;
end;

function TSDLRenderTarget.GetHeight: Integer;
begin
  if FSurface = nil then
    Exit(0);
  Result := FSurface^.h;
end;

function ToSDLRect(const R: TRect): TSDL_Rect;
begin
  Result.x := R.Left;
  Result.y := R.Top;
  Result.w := R.Right - R.Left;
  Result.h := R.Bottom - R.Top;
end;

procedure TSDLRenderTarget.Fill(const R: TRect; AColor: TColor);
var
  Dst: TSDL_Rect;
  C: LongWord;
begin
  if FSurface = nil then
    Exit;
  { TColor is $00BBGGRR, and ColorToRGB resolves the system colours the game
    names - clBlack and clWhite among them - to that same form. }
  C := LongWord(ColorToRGB(AColor));
  Dst := ToSDLRect(R);
  SDL_FillRect(FSurface, @Dst,
               SDL_MapRGB(FSurface^.format,
                          Byte(C), Byte(C shr 8), Byte(C shr 16)));
end;

{ The two rectangle blits differ only in what they ask the source for. }
procedure BlitFrom(Dest: PSDL_Surface; Src: TRenderImage; const SrcRect: TRect;
                   X, Y: Integer; Keyed: Boolean);
var
  S: PSDL_Surface;
  SrcR, DstR: TSDL_Rect;
begin
  if (Dest = nil) or (Src = nil) then
    Exit;
  S := Src.SDLSurface(Keyed);
  if S = nil then
    Exit;
  SrcR := ToSDLRect(SrcRect);
  DstR.x := X;
  DstR.y := Y;
  { SDL reads w and h from the source rect and writes back what it clipped
    to, so these two are only placeholders. }
  DstR.w := SrcR.w;
  DstR.h := SrcR.h;
  SDL_BlitSurface(S, @SrcR, Dest, @DstR);
end;

procedure TSDLRenderTarget.BlitRect(Src: TRenderImage; const SrcRect: TRect;
  X, Y: Integer);
begin
  BlitFrom(FSurface, Src, SrcRect, X, Y, False);
end;

procedure TSDLRenderTarget.BlitRectKeyed(Src: TRenderImage;
  const SrcRect: TRect; X, Y: Integer);
begin
  BlitFrom(FSurface, Src, SrcRect, X, Y, True);
end;

procedure TSDLRenderTarget.DrawImage(Src: TRenderImage; X, Y: Integer);
begin
  { Opaque, which is what the LCL target does with these: nothing in the game
    sets a key on a whole-image draw any more, and the pictures that go
    through here cover the screen. }
  if Src = nil then
    Exit;
  BlitFrom(FSurface, Src, Rect(0, 0, Src.Width, Src.Height), X, Y, False);
end;

procedure TSDLRenderTarget.StretchImage(Src: TRenderImage;
  const DestRect: TRect);
var
  S: PSDL_Surface;
  DstR: TSDL_Rect;
begin
  if (FSurface = nil) or (Src = nil) then
    Exit;
  S := Src.SDLSurface(False);
  if S = nil then
    Exit;
  DstR := ToSDLRect(DestRect);
  SDL_BlitSurfaceScaled(S, nil, FSurface, @DstR);
end;

procedure TSDLRenderTarget.DrawOutlinedText(X, Y: Integer; const S: string;
  Outline, Fill: TColor; Size: Integer);
var
  Sheet: PSDL_Surface;
  DstR: TSDL_Rect;
begin
  if (FSurface = nil) or (S = '') then
    Exit;

  { Size is ignored for the same reason as in the LCL target: it is 10 POINTS
    and a bitmap face is picked by strike - see OUTLINED_FONT_FACE. }
  Sheet := OutlinedTextSurface(S, Outline, Fill, OUTLINED_FONT_FACE);
  if Sheet = nil then
    Exit;

  { One pixel up and left, because the composed sheet carries its outline
    around the text rather than starting where the text does. }
  DstR.x := X - 1;
  DstR.y := Y - 1;
  DstR.w := Sheet^.w;
  DstR.h := Sheet^.h;
  SDL_BlitSurface(Sheet, nil, FSurface, @DstR);
end;

end.
