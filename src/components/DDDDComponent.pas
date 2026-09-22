{ The display component the main form draws through. It owns the back buffer
  and handles clearing, drawing, presentation and fades.

  THE BACK BUFFER IS AN SDL SURFACE, and so is the window's. Present scales
  one into the other and asks SDL to show it. There is no bitmap, no canvas
  and no conversion in between any more - the picture never leaves SDL. }

unit DDDDComponent;

{$MODE DELPHI}{$H+}

interface

uses
  Classes, SysUtils, Types, SDL2, RenderTarget, SDLTarget, GameColors;

const
  { 0x78 and the step every caller writes to self+0x10 before starting one.
    120 at 4 a frame is thirty frames. }
  FADE_FULL = $78;
  { Callers may override the step for different fade speeds. }
  FADE_STEP = 4;
  { 0x78 / 4 = 30 steps to cover, plus the one that pushes the level
    strictly outside and ends the fade. }
  FADE_TICKS = FADE_FULL div FADE_STEP + 1;

type
  TDDDDDebugOptionItem = (ddoHaltOnError);
  TDDDDDebugOption = set of TDDDDDebugOptionItem;

  { The game does not enable the component's 3D path. }
  TD3DOptionItem = (d3doReserved);
  TD3DOptions = set of TD3DOptionItem;

  TDDDD = class(TComponent)
  private
    FDebugOption: TDDDDDebugOption;
    FInitialScreenWidth: Integer;
    FInitialScreenHeight: Integer;
    FBackColor: TColor;
    FDisableScreenSaver: Boolean;
    FUse3D: Boolean;
    FD3DOptions: TD3DOptions;
    FVsyncAtWindowed: Boolean;
    FOnInit: TNotifyEvent;
    FBack: PSDL_Surface;
    FTarget: TSDLRenderTarget;
    FWindow: PSDL_Window;
    { Fade state offsets retained for layout verification. }
    FFadeLevel: Integer;      { +0x08 }
    FFadeStep: Integer;       { +0x10, written by the caller before a fade }
    FFadeMode: Integer;       { +0x04 }
    FFadeOut: Boolean;        { +0x0C }
    FFadeBusy: Boolean;       { +0x0D }
    function GetTarget: TRenderTarget;
    procedure ReleaseBuffers;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    { Called once the form is up. Fires OnInit. }
    procedure Initialize;

    procedure Clear;
    procedure Present;

    { The window the picture is shown in. The shell owns it and outlives
      this; nothing is drawn until it is set. }
    property Window: PSDL_Window read FWindow write FWindow;

    { All of presentation except asking the window for its surface: the
      picture scaled by a whole number and centred, and the four bands around
      it painted. A class method because that is the part a test can drive -
      it needs a destination surface, not a window. }
    class procedure PresentTo(Src, Dst: PSDL_Surface);

    { Where the back buffer lands inside a client area of this size: the
      largest whole multiple of it that fits, centred.

      Exposed because it is geometry rather than drawing, and a test can
      check geometry without a window. }
    class function PresentRect(BufW, BufH, ClientW, ClientH: Integer): TRect;

    { Fade-in counts from black to clear; fade-out counts from clear to black.
      Stage changes wait for FadeBusy to clear before loading the destination. }
    procedure StartFade(Mode: Integer; FadeOut: Boolean);
    { Applied by Present; exposed for tests. }
    procedure ApplyFade;
    procedure TickFade;
    function FadeBusy: Boolean;
    { How far the fade level moves per frame. }
    property FadeStep: Integer read FFadeStep write FFadeStep;

    { 0 = clear, FADE_FULL = black. What a real fader would draw. }
    property FadeLevel: Integer read FFadeLevel;

    { Everything the game draws goes through here. }
    property Target: TRenderTarget read GetTarget;
  published
    property DebugOption: TDDDDDebugOption read FDebugOption write FDebugOption;
    property InitialScreenWidth: Integer read FInitialScreenWidth write FInitialScreenWidth;
    property InitialScreenHeight: Integer read FInitialScreenHeight write FInitialScreenHeight;
    property BackColor: TColor read FBackColor write FBackColor;
    property DisableScreenSaver: Boolean read FDisableScreenSaver write FDisableScreenSaver;
    property Use3D: Boolean read FUse3D write FUse3D;
    property D3DOptions: TD3DOptions read FD3DOptions write FD3DOptions;
    property VsyncAtWindowed: Boolean read FVsyncAtWindowed write FVsyncAtWindowed;
    property OnInit: TNotifyEvent read FOnInit write FOnInit;
  end;

implementation

constructor TDDDD.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FInitialScreenWidth := 320;
  FInitialScreenHeight := 240;
  FBackColor := 0;
  { Callers may replace this; ordinary transitions use the default step. }
  FFadeStep := FADE_STEP;
end;

destructor TDDDD.Destroy;
begin
  ReleaseBuffers;
  inherited Destroy;
end;

procedure TDDDD.ReleaseBuffers;
begin
  FreeAndNil(FTarget);
  if FBack <> nil then
  begin
    SDL_FreeSurface(FBack);
    FBack := nil;
  end;
end;

{ nil until Initialize has run. A bare component - which is what the fade
  self-test drives - has no buffer and nothing to draw on. }
function TDDDD.GetTarget: TRenderTarget;
begin
  Result := FTarget;
end;

procedure TDDDD.Initialize;
begin
  { Property values arrive from the .lfm before this runs. }
  ReleaseBuffers;
  FBack := SDL_CreateRGBSurface(0, FInitialScreenWidth, FInitialScreenHeight,
                                32, $00FF0000, $0000FF00, $000000FF, 0);
  if FBack <> nil then
  begin
    FTarget := TSDLRenderTarget.Create(FBack);
    Clear;
  end;
  if Assigned(FOnInit) then
    FOnInit(Self);
end;

procedure TDDDD.StartFade(Mode: Integer; FadeOut: Boolean);
begin
  FFadeLevel := 0;
  FFadeMode := Mode;
  FFadeOut := FadeOut;
  FFadeBusy := True;
  { The one asymmetry: a fade IN starts full and runs down. }
  if (Mode = 0) and (not FadeOut) then
    FFadeLevel := FADE_FULL;
end;

procedure TDDDD.TickFade;
begin
  { Draw before advancing so the terminal fade frame remains visible while
    clients are still waiting for FadeBusy to clear. }
  if not FFadeBusy then
    Exit;
  if FFadeMode <> 0 then
    Exit;
  ApplyFade;
  { Strict bounds keep the fade busy through its endpoint; it finishes after
    the counter steps outside the visible range. }
  if FFadeOut then
  begin
    Inc(FFadeLevel, FFadeStep);
    if FFadeLevel > FADE_FULL then
      FFadeBusy := False;
  end
  else
  begin
    Dec(FFadeLevel, FFadeStep);
    if FFadeLevel < 0 then
      FFadeBusy := False;
  end;
end;

function TDDDD.FadeBusy: Boolean;
begin
  Result := FFadeBusy;
end;

procedure TDDDD.Clear;
begin
  if FTarget = nil then
    Exit;
  FTarget.Fill(Rect(0, 0, FTarget.Width, FTarget.Height), FBackColor);
end;

{ The fade is a box wipe: four black rectangles close in from the edges.

      Rect(0,   0,   level,       240)          the left band
      Rect(320, 0,   320 - level, 240)          the right band
      Rect(0,   0,   320,         level)        the top band
      Rect(0,   240, 320,         240 - level)  the bottom band

  At level 120 the vertical bands meet and cover the 240-pixel display. }
procedure TDDDD.ApplyFade;
var
  Level, Width, Height: Integer;
begin
  { TickFade owns the state guards; this routine only paints the current level. }
  { Nothing to paint on until there is a buffer - the fade self-test drives a
    bare component with no screen behind it. }
  if FTarget = nil then
    Exit;
  Level := FFadeLevel;
  if Level <= 0 then
    Exit;
  Width := FTarget.Width;
  Height := FTarget.Height;
  FTarget.Fill(Rect(0, 0, Level, Height), clBlack);              { left }
  FTarget.Fill(Rect(Width - Level, 0, Width, Height), clBlack);  { right }
  FTarget.Fill(Rect(0, 0, Width, Level), clBlack);               { top }
  FTarget.Fill(Rect(0, Height - Level, Width, Height), clBlack); { bottom }
end;

{ WHOLE NUMBERS ONLY.

  A 320x240 picture stretched to fill an arbitrary window is scaled by a
  fraction, which gives some source pixels two screen pixels and some three.
  On art drawn at this size that is plainly visible - a one-pixel outline
  becomes one pixel here and two there. So the picture is scaled by the
  largest whole multiple that fits and centred, and whatever is left over
  around it is painted rather than stretched into.

  In a window the client area is set to an exact multiple, so there is
  nothing left over. Fullscreen is where the letterbox appears. }
class function TDDDD.PresentRect(BufW, BufH, ClientW, ClientH: Integer): TRect;
var
  Scale, W, H: Integer;
begin
  Result := Rect(0, 0, 0, 0);
  if (BufW <= 0) or (BufH <= 0) or (ClientW <= 0) or (ClientH <= 0) then
    Exit;

  Scale := ClientW div BufW;
  if ClientH div BufH < Scale then
    Scale := ClientH div BufH;
  { A client area too small for even 1:1 still gets 1:1, clipped by the
    window. Shrinking by a fraction would reintroduce exactly the unevenness
    this exists to avoid. }
  if Scale < 1 then
    Scale := 1;

  W := BufW * Scale;
  H := BufH * Scale;
  Result := Bounds((ClientW - W) div 2, (ClientH - H) div 2, W, H);
end;

class procedure TDDDD.PresentTo(Src, Dst: PSDL_Surface);
var
  R: TRect;
  Picture: TSDL_Rect;
  Black: LongWord;

  { The surround, in the four bands around the picture. Painted rather than
    left alone, because what is there otherwise is whatever the desktop or
    the previous window size left behind. Each band is empty in a window,
    where the client area is an exact multiple. }
  procedure Band(L, T, Rt, B: Integer);
  var
    Area: TSDL_Rect;
  begin
    if (Rt <= L) or (B <= T) then
      Exit;
    Area.x := L; Area.y := T; Area.w := Rt - L; Area.h := B - T;
    SDL_FillRect(Dst, @Area, Black);
  end;

begin
  if (Src = nil) or (Dst = nil) then
    Exit;
  Black := SDL_MapRGB(Dst^.format, 0, 0, 0);
  R := PresentRect(Src^.w, Src^.h, Dst^.w, Dst^.h);

  Band(0, 0, R.Left, Dst^.h);
  Band(R.Right, 0, Dst^.w, Dst^.h);
  Band(R.Left, 0, R.Right, R.Top);
  Band(R.Left, R.Bottom, R.Right, Dst^.h);

  { Nearest-neighbour, which at a whole-number scale is exact pixel
    replication - every source pixel becomes the same square of screen
    pixels, which is the whole reason the scale is a whole number.
    SDL_BlitSurfaceScaled writes back through the rectangle it is given, so
    this one is built fresh rather than kept. }
  Picture.x := R.Left;
  Picture.y := R.Top;
  Picture.w := R.Right - R.Left;
  Picture.h := R.Bottom - R.Top;
  SDL_BlitSurfaceScaled(Src, nil, Dst, @Picture);
end;

procedure TDDDD.Present;
var
  Surf: PSDL_Surface;
begin
  if (FBack = nil) or (FWindow = nil) then
    Exit;
  { Asked for every frame rather than kept: SDL invalidates the window
    surface whenever the window is resized, and going to or coming back from
    fullscreen is a resize. }
  Surf := SDL_GetWindowSurface(FWindow);
  if Surf = nil then
    Exit;
  PresentTo(FBack, Surf);
  SDL_UpdateWindowSurface(FWindow);
end;

end.
