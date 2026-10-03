{ The on-screen controls for a touch screen: where they sit, which fingers
  press what, and drawing them. Built only with AKUJI_TOUCH - see akuji.inc.

  WHERE

  The game is 4:3 and a phone in landscape is about 20:9, so at a whole-number
  scale there is a black bar either side of the picture - and that is where
  the controls go, so they never cover the game. The d-pad sits in the left
  bar, A (jump) and B (fire) in the right, B down and to the left of A so one
  thumb rolls between them, pause in the top-right corner. Sizes follow the
  screen's height, the one length every landscape screen shares.

  FINGERS

  A finger belongs to whatever it first touched, for as long as it is down:

    * the left half of the screen is the d-pad's, wherever in it the finger
      lands. The direction is the finger's bearing from the d-pad's centre,
      in eight 45-degree sectors, with a small dead zone in the middle - so
      a thumb can slide round the d-pad, onto the diagonals, without lifting,
      and does not have to land on the picture to work;
    * the right half is the face buttons'. The finger presses whichever
      button it is over, with a generous margin, and can roll from one to
      the other;
    * the pause button takes a finger that lands on it.

  What the fingers press is a set of the game's own buttons, added to the
  keyboard's and the pad's by the input component, so the game cannot tell
  a touch from a key. }

unit TouchControls;

{$MODE DELPHI}{$H+}
{$I akuji.inc}

interface

uses
  Types, SDL2, DDIDComponent, TouchArt;

type
  TTouchPart = (tpPad, tpButtons, tpPause);

  TFinger = record
    Id: Int64;
    Part: TTouchPart;
    X, Y: Single;          { in window pixels }
  end;

  TTouchControls = class
  private
    FWinW, FWinH: Integer;
    { Each control's centre and size, in window pixels. }
    FPadX, FPadY, FPadSize: Integer;
    FAX, FAY, FASize: Integer;
    FBX, FBY, FBSize: Integer;
    FPauseX, FPauseY, FPauseSize: Integer;
    FFingers: array of TFinger;
    FPadPictures: array[Byte] of PSDL_Surface;     { by TPadArms }
    FAPictures, FBPictures, FPausePictures: array[Boolean] of PSDL_Surface;
    procedure FreePictures;
    function FingerIndex(Id: Int64): Integer;
    function PadArmsAt(X, Y: Single): TPadArms;
    function ButtonsAt(X, Y: Single): TAkujiButtons;
    function OnPause(X, Y: Single): Boolean;
  public
    destructor Destroy; override;
    { Where everything goes in a window this size; the pictures are drawn
      again only when the sizes change. }
    procedure Layout(WinW, WinH: Integer);
    procedure FingerDown(Id: Int64; X, Y: Single);
    procedure FingerMove(Id: Int64; X, Y: Single);
    procedure FingerUp(Id: Int64);
    { Every button a finger is pressing now. }
    function Pressed: TAkujiButtons;
    procedure Draw(Dst: PSDL_Surface);
  end;

{ How far a finger is from the d-pad centre before it points anywhere, as a
  part of the d-pad's size; and the 8 directions a bearing falls in. Public
  for the self-test. }
const
  PAD_DEAD_ZONE = 0.12;

function PadArmsForBearing(DX, DY, Dead: Single): TPadArms;

implementation

uses
  Math, SysUtils, GameState, DDDDComponent;

const
  { As parts of the screen height. }
  PAD_SIZE = 0.36;
  A_SIZE = 0.23;
  B_SIZE = 0.21;
  PAUSE_SIZE = 0.10;
  MARGIN = 0.04;
  { How far past its edge a face button still takes a finger. }
  BUTTON_REACH = 1.35;

function PadArmsForBearing(DX, DY, Dead: Single): TPadArms;
var
  Sector: Integer;
begin
  Result := [];
  if Hypot(DX, DY) < Dead then
    Exit;
  { Eight sectors, 0 = right, counting clockwise on screen (y grows down). }
  Sector := (Round(ArcTan2(DY, DX) / (Pi / 4)) + 8) mod 8;
  case Sector of
    0: Result := [paRight];
    1: Result := [paRight, paDown];
    2: Result := [paDown];
    3: Result := [paDown, paLeft];
    4: Result := [paLeft];
    5: Result := [paLeft, paUp];
    6: Result := [paUp];
    7: Result := [paUp, paRight];
  end;
end;

function ArmsToButtons(Arms: TPadArms): TAkujiButtons;
begin
  Result := [];
  if paUp in Arms then Include(Result, abUp);
  if paDown in Arms then Include(Result, abDown);
  if paLeft in Arms then Include(Result, abLeft);
  if paRight in Arms then Include(Result, abRight);
end;

destructor TTouchControls.Destroy;
begin
  FreePictures;
  inherited Destroy;
end;

procedure TTouchControls.FreePictures;
var
  I: Integer;
  B: Boolean;
begin
  for I := Low(FPadPictures) to High(FPadPictures) do
    if FPadPictures[I] <> nil then
    begin
      SDL_FreeSurface(FPadPictures[I]);
      FPadPictures[I] := nil;
    end;
  for B := False to True do
  begin
    if FAPictures[B] <> nil then SDL_FreeSurface(FAPictures[B]);
    if FBPictures[B] <> nil then SDL_FreeSurface(FBPictures[B]);
    if FPausePictures[B] <> nil then SDL_FreeSurface(FPausePictures[B]);
    FAPictures[B] := nil;
    FBPictures[B] := nil;
    FPausePictures[B] := nil;
  end;
end;

procedure TTouchControls.Layout(WinW, WinH: Integer);
var
  Picture: TRect;
  Bar, Margin_: Integer;
  B: Boolean;
  Arms: TPadArms;
  ArmA, ArmB: TPadArm;
begin
  if (WinW = FWinW) and (WinH = FWinH) then
    Exit;
  FWinW := WinW;
  FWinH := WinH;
  Picture := TDDDD.PresentRect(SCREEN_W, SCREEN_H, WinW, WinH);
  Bar := Picture.Left;
  Margin_ := Round(MARGIN * WinH);

  FPadSize := Round(PAD_SIZE * WinH);
  FASize := Round(A_SIZE * WinH);
  FBSize := Round(B_SIZE * WinH);
  FPauseSize := Round(PAUSE_SIZE * WinH);
  { Centred in the bars when they are wide enough; against the screen's
    edges, over the picture, when they are not - a 4:3 tablet has no bars. }
  FPadX := Max(Bar div 2, Margin_ + FPadSize div 2);
  FPadY := Round(0.68 * WinH);
  FAX := WinW - Max(Round(Bar * 0.28), Margin_ + FASize div 2);
  FAY := Round(0.59 * WinH);
  FBX := FAX - Round(FASize * 0.95);
  FBY := FAY + Round(FASize * 0.66);
  FPauseX := WinW - Margin_ - FPauseSize div 2;
  FPauseY := Margin_ + FPauseSize div 2;

  FreePictures;
  { The d-pad in each state the fingers can put it in: nothing, an arm, or
    two neighbouring arms. }
  FPadPictures[0] := DrawPad(FPadSize, []);
  for ArmA := Low(TPadArm) to High(TPadArm) do
    for ArmB := ArmA to High(TPadArm) do
    begin
      Arms := [ArmA, ArmB];
      if ((paUp in Arms) and (paDown in Arms)) or
         ((paLeft in Arms) and (paRight in Arms)) then
        Continue;
      if FPadPictures[Byte(Arms)] = nil then
        FPadPictures[Byte(Arms)] := DrawPad(FPadSize, Arms);
    end;
  for B := False to True do
  begin
    FAPictures[B] := DrawFaceButton(FASize, fbA, B);
    FBPictures[B] := DrawFaceButton(FBSize, fbB, B);
    FPausePictures[B] := DrawPauseButton(FPauseSize, B);
  end;
end;

function TTouchControls.FingerIndex(Id: Int64): Integer;
var
  I: Integer;
begin
  for I := 0 to High(FFingers) do
    if FFingers[I].Id = Id then
      Exit(I);
  Result := -1;
end;

function TTouchControls.PadArmsAt(X, Y: Single): TPadArms;
begin
  Result := PadArmsForBearing(X - FPadX, Y - FPadY, PAD_DEAD_ZONE * FPadSize);
end;

function TTouchControls.ButtonsAt(X, Y: Single): TAkujiButtons;
var
  DA, DB: Single;
begin
  Result := [];
  DA := Hypot(X - FAX, Y - FAY) / (FASize / 2);
  DB := Hypot(X - FBX, Y - FBY) / (FBSize / 2);
  { The nearer button, if the finger is within its reach: the two reaches
    overlap between them, and the nearer one wins there. }
  if (DA <= BUTTON_REACH) and (DA <= DB) then
    Include(Result, abJump)
  else if DB <= BUTTON_REACH then
    Include(Result, abFire);
end;

function TTouchControls.OnPause(X, Y: Single): Boolean;
begin
  Result := (Abs(X - FPauseX) <= FPauseSize * 0.7)
            and (Abs(Y - FPauseY) <= FPauseSize * 0.7);
end;

procedure TTouchControls.FingerDown(Id: Int64; X, Y: Single);
var
  I: Integer;
begin
  I := FingerIndex(Id);
  if I < 0 then
  begin
    I := Length(FFingers);
    SetLength(FFingers, I + 1);
  end;
  FFingers[I].Id := Id;
  FFingers[I].X := X;
  FFingers[I].Y := Y;
  if OnPause(X, Y) then
    FFingers[I].Part := tpPause
  else if X < FWinW / 2 then
    FFingers[I].Part := tpPad
  else
    FFingers[I].Part := tpButtons;
end;

procedure TTouchControls.FingerMove(Id: Int64; X, Y: Single);
var
  I: Integer;
begin
  I := FingerIndex(Id);
  if I < 0 then
    Exit;
  FFingers[I].X := X;
  FFingers[I].Y := Y;
end;

procedure TTouchControls.FingerUp(Id: Int64);
var
  I: Integer;
begin
  I := FingerIndex(Id);
  if I < 0 then
    Exit;
  FFingers[I] := FFingers[High(FFingers)];
  SetLength(FFingers, Length(FFingers) - 1);
end;

function TTouchControls.Pressed: TAkujiButtons;
var
  F: TFinger;
begin
  Result := [];
  for F in FFingers do
    case F.Part of
      tpPad: Result := Result + ArmsToButtons(PadArmsAt(F.X, F.Y));
      tpButtons: Result := Result + ButtonsAt(F.X, F.Y);
      tpPause: if OnPause(F.X, F.Y) then Include(Result, abPause);
    end;
end;

procedure TTouchControls.Draw(Dst: PSDL_Surface);
var
  Down: TAkujiButtons;
  Arms: TPadArms;

  procedure Put(Pic: PSDL_Surface; CX, CY: Integer);
  var
    R: TSDL_Rect;
  begin
    if Pic = nil then
      Exit;
    R.x := CX - Pic^.w div 2;
    R.y := CY - Pic^.h div 2;
    R.w := Pic^.w;
    R.h := Pic^.h;
    SDL_BlitSurface(Pic, nil, Dst, @R);
  end;

begin
  if Dst = nil then
    Exit;
  Layout(Dst^.w, Dst^.h);
  Down := Pressed;
  Arms := [];
  if abUp in Down then Include(Arms, paUp);
  if abDown in Down then Include(Arms, paDown);
  if abLeft in Down then Include(Arms, paLeft);
  if abRight in Down then Include(Arms, paRight);
  { Opposite arms at once - two fingers - has no picture; the d-pad then
    shows nothing pressed rather than vanishing. }
  if FPadPictures[Byte(Arms)] = nil then
    Arms := [];
  Put(FPadPictures[Byte(Arms)], FPadX, FPadY);
  Put(FAPictures[abJump in Down], FAX, FAY);
  Put(FBPictures[abFire in Down], FBX, FBY);
  Put(FPausePictures[abPause in Down], FPauseX, FPauseY);
end;

end.
