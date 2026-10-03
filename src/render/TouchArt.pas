{ The on-screen touch controls' pictures, drawn from shapes rather than
  loaded: a d-pad, the A and B face buttons, and a pause button, in every
  state, at whatever size the screen wants - so they are as sharp on a phone
  as on a tablet, and nothing ships but this code.

  HOW

  Every shape is a signed distance function: how far a point is from the
  shape's edge, negative inside. A pixel takes the colour in proportion to
  how much of it the edge leaves inside - clamp(0.5 - distance) - which
  smooths every edge by exactly one pixel at any size. A picture is layers
  of such shapes painted over each other. The colours are Kenney's input
  prompts', the ones the keycaps use.

  THE LOOK

  A dark rim, a lighter ring inside it all the way round, the face. Pressed,
  the face darkens evenly inside a darker ring of the same width: nothing
  shifts or casts a one-sided shadow, so a press reads the same from every
  side. Two d-pad arms pressed - a diagonal - darken together with the
  centre between them, one L-shaped press. }

unit TouchArt;

{$MODE DELPHI}{$H+}
{$I akuji.inc}

interface

uses
  SDL2;

type
  TPadArm = (paUp, paDown, paLeft, paRight);
  TPadArms = set of TPadArm;
  TFaceButton = (fbA, fbB);

{ Each returns a new ARGB surface, Size pixels square, that the caller owns
  and blends over the screen. }
function DrawPad(Size: Integer; Pressed: TPadArms): PSDL_Surface;
function DrawFaceButton(Size: Integer; Button: TFaceButton;
                        Pressed: Boolean): PSDL_Surface;
function DrawPauseButton(Size: Integer; Pressed: Boolean): PSDL_Surface;

implementation

uses
  Math;

type
  TRGB = record
    R, G, B: Single;
  end;

  TShapeKind = (skBox, skCircle, skStroke, skTriangle, skArc);

  { One shape. Box: centre (X1, Y1), half sizes (X2, Y2), corner radius R.
    Circle: centre (X1, Y1), radius R. Stroke: from (X1, Y1) to (X2, Y2),
    width W, round ends. Triangle: corners (X1, Y1), (X2, Y2), (X3, Y3).
    Arc: the right half of a circle at (X1, Y1), radius R, stroked W wide. }
  TShape = record
    Kind: TShapeKind;
    X1, Y1, X2, Y2, X3, Y3, R, W: Single;
  end;

  TCanvas = record
    Size: Integer;
    { Premultiplied colour and coverage, one per pixel. }
    PR, PG, PB, PA: array of Single;
    procedure Init(ASize: Integer);
    procedure Paint(const Shapes: array of TShape; const Colour: TRGB);
    function ToSurface(Opacity: Single): PSDL_Surface;
  end;

const
  OPACITY = 0.9;

function RGB(R, G, B: Byte): TRGB;
begin
  Result.R := R / 255;
  Result.G := G / 255;
  Result.B := B / 255;
end;

function Box(CX, CY, HW, HH, Radius: Single): TShape;
begin
  Result := Default(TShape);
  Result.Kind := skBox;
  Result.X1 := CX; Result.Y1 := CY; Result.X2 := HW; Result.Y2 := HH;
  Result.R := Radius;
end;

{ A box given by its corners, as the prototype drew them. }
function BoxLTRB(L, T, R, B, Radius: Single): TShape;
begin
  Result := Box((L + R) / 2, (T + B) / 2, (R - L) / 2, (B - T) / 2, Radius);
end;

function Circle(CX, CY, Radius: Single): TShape;
begin
  Result := Default(TShape);
  Result.Kind := skCircle;
  Result.X1 := CX; Result.Y1 := CY; Result.R := Radius;
end;

function Stroke(AX, AY, BX, BY, Width: Single): TShape;
begin
  Result := Default(TShape);
  Result.Kind := skStroke;
  Result.X1 := AX; Result.Y1 := AY; Result.X2 := BX; Result.Y2 := BY;
  Result.W := Width;
end;

function Triangle(AX, AY, BX, BY, CX, CY: Single): TShape;
begin
  Result := Default(TShape);
  Result.Kind := skTriangle;
  Result.X1 := AX; Result.Y1 := AY; Result.X2 := BX; Result.Y2 := BY;
  Result.X3 := CX; Result.Y3 := CY;
end;

function RightArc(CX, CY, Radius, Width: Single): TShape;
begin
  Result := Default(TShape);
  Result.Kind := skArc;
  Result.X1 := CX; Result.Y1 := CY; Result.R := Radius; Result.W := Width;
end;

{ --- distances ------------------------------------------------------------ }

function SegmentDistance(PX, PY, AX, AY, BX, BY: Single): Single;
var
  DX, DY, T, L2: Single;
begin
  DX := BX - AX;
  DY := BY - AY;
  L2 := DX * DX + DY * DY;
  if L2 = 0 then
    T := 0
  else
    T := EnsureRange(((PX - AX) * DX + (PY - AY) * DY) / L2, 0, 1);
  Result := Hypot(PX - (AX + T * DX), PY - (AY + T * DY));
end;

{ How far P is outside the line from A to B, for a corner order whose
  inside is on the right; negative inside. }
function EdgeDistance(PX, PY, AX, AY, BX, BY: Single): Single;
var
  DX, DY, L: Single;
begin
  DX := BX - AX;
  DY := BY - AY;
  L := Hypot(DX, DY);
  if L = 0 then
    Exit(-1e9);
  Result := ((PX - AX) * DY - (PY - AY) * DX) / L;
end;

function Distance(const S: TShape; PX, PY: Single): Single;
var
  QX, QY, Area: Single;
begin
  case S.Kind of
    skBox:
      begin
        QX := Abs(PX - S.X1) - (S.X2 - S.R);
        QY := Abs(PY - S.Y1) - (S.Y2 - S.R);
        Result := Hypot(Max(QX, 0), Max(QY, 0)) + Min(Max(QX, QY), 0) - S.R;
      end;
    skCircle:
      Result := Hypot(PX - S.X1, PY - S.Y1) - S.R;
    skStroke:
      Result := SegmentDistance(PX, PY, S.X1, S.Y1, S.X2, S.Y2) - S.W / 2;
    skTriangle:
      begin
        { Inside is to the right of every edge when the corners turn
          clockwise on screen; take them the other way round otherwise. }
        Area := (S.X2 - S.X1) * (S.Y3 - S.Y1) - (S.Y2 - S.Y1) * (S.X3 - S.X1);
        if Area > 0 then
          Result := Max(Max(EdgeDistance(PX, PY, S.X1, S.Y1, S.X2, S.Y2),
                            EdgeDistance(PX, PY, S.X2, S.Y2, S.X3, S.Y3)),
                        EdgeDistance(PX, PY, S.X3, S.Y3, S.X1, S.Y1))
        else
          Result := Max(Max(EdgeDistance(PX, PY, S.X1, S.Y1, S.X3, S.Y3),
                            EdgeDistance(PX, PY, S.X3, S.Y3, S.X2, S.Y2)),
                        EdgeDistance(PX, PY, S.X2, S.Y2, S.X1, S.Y1));
      end;
    skArc:
      if PX >= S.X1 then
        Result := Abs(Hypot(PX - S.X1, PY - S.Y1) - S.R) - S.W / 2
      else
        Result := Min(Hypot(PX - S.X1, PY - (S.Y1 - S.R)),
                      Hypot(PX - S.X1, PY - (S.Y1 + S.R))) - S.W / 2;
  else
    Result := 1e9;
  end;
end;

{ --- the canvas ----------------------------------------------------------- }

procedure TCanvas.Init(ASize: Integer);
begin
  Size := ASize;
  SetLength(PR, Size * Size);
  SetLength(PG, Size * Size);
  SetLength(PB, Size * Size);
  SetLength(PA, Size * Size);
  FillChar(PR[0], Length(PR) * SizeOf(Single), 0);
  FillChar(PG[0], Length(PG) * SizeOf(Single), 0);
  FillChar(PB[0], Length(PB) * SizeOf(Single), 0);
  FillChar(PA[0], Length(PA) * SizeOf(Single), 0);
end;

{ The shapes as one, painted over what is there. }
procedure TCanvas.Paint(const Shapes: array of TShape; const Colour: TRGB);
var
  X, Y, I, K: Integer;
  D, Cov, PX, PY: Single;
begin
  for Y := 0 to Size - 1 do
  begin
    PY := Y + 0.5;
    for X := 0 to Size - 1 do
    begin
      PX := X + 0.5;
      D := 1e9;
      for K := Low(Shapes) to High(Shapes) do
        D := Min(D, Distance(Shapes[K], PX, PY));
      Cov := EnsureRange(0.5 - D, 0, 1);
      if Cov <= 0 then
        Continue;
      I := Y * Size + X;
      PR[I] := Colour.R * Cov + PR[I] * (1 - Cov);
      PG[I] := Colour.G * Cov + PG[I] * (1 - Cov);
      PB[I] := Colour.B * Cov + PB[I] * (1 - Cov);
      PA[I] := Cov + PA[I] * (1 - Cov);
    end;
  end;
end;

function TCanvas.ToSurface(Opacity: Single): PSDL_Surface;
var
  X, Y, I: Integer;
  Row: PLongWord;
  A: Single;
begin
  Result := SDL_CreateRGBSurface(0, Size, Size, 32, $00FF0000, $0000FF00,
                                 $000000FF, $FF000000);
  if Result = nil then
    Exit;
  for Y := 0 to Size - 1 do
  begin
    Row := PLongWord(PByte(Result^.pixels) + Y * Result^.pitch);
    for X := 0 to Size - 1 do
    begin
      I := Y * Size + X;
      A := PA[I];
      if A <= 0 then
        Row[X] := 0
      else
        Row[X] := (LongWord(Round(A * Opacity * 255)) shl 24)
                  or (LongWord(Round(EnsureRange(PR[I] / A, 0, 1) * 255)) shl 16)
                  or (LongWord(Round(EnsureRange(PG[I] / A, 0, 1) * 255)) shl 8)
                  or LongWord(Round(EnsureRange(PB[I] / A, 0, 1) * 255));
    end;
  end;
  SDL_SetSurfaceBlendMode(Result, SDL_BLENDMODE_BLEND);
end;

{ --- the colours ---------------------------------------------------------- }

var
  OUTLINE, FACE, BEVEL, SHADE, SHADE_RING, WHITE: TRGB;
  BUTTON_FACE, BUTTON_BEVEL, BUTTON_PRESS, BUTTON_RING: array[TFaceButton] of TRGB;

procedure InitColours;
begin
  OUTLINE := RGB(67, 74, 95);
  FACE := RGB(220, 225, 231);
  BEVEL := RGB(241, 244, 247);
  SHADE := RGB(149, 154, 177);
  SHADE_RING := RGB(120, 128, 154);
  WHITE := RGB(255, 255, 255);
  BUTTON_FACE[fbA] := RGB(182, 213, 60);
  BUTTON_BEVEL[fbA] := RGB(207, 243, 67);
  BUTTON_PRESS[fbA] := RGB(136, 171, 20);
  BUTTON_RING[fbA] := RGB(108, 140, 10);
  BUTTON_FACE[fbB] := RGB(252, 104, 59);
  BUTTON_BEVEL[fbB] := RGB(255, 152, 121);
  BUTTON_PRESS[fbB] := RGB(220, 52, 57);
  BUTTON_RING[fbB] := RGB(180, 36, 44);
end;

{ --- the pictures --------------------------------------------------------- }

function DrawPad(Size: Integer; Pressed: TPadArms): PSDL_Surface;
var
  Cv: TCanvas;
  S, C, Arm, Half, Rim, Bev, Inner, Through, T, AX, AY: Single;
  A: TPadArm;
  Regions: array[TPadArm] of array[0..3] of Single;
  Colour: TRGB;

  procedure Cross(ArmLen, HalfW, Radius: Single; const Colour: TRGB);
  begin
    Cv.Paint([Box(C, C, ArmLen, HalfW, Radius), Box(C, C, HalfW, ArmLen, Radius)],
             Colour);
  end;

const
  DIR_X: array[TPadArm] of Integer = (0, 0, -1, 1);
  DIR_Y: array[TPadArm] of Integer = (-1, 1, 0, 0);
begin
  Cv.Init(Size);
  S := Size;
  C := S / 2;
  Arm := S * 0.48;
  Half := S * 0.17;
  Rim := S * 0.035;
  Bev := S * 0.022;
  Cross(Arm, Half, S * 0.06, OUTLINE);
  Cross(Arm - Rim, Half - Rim, S * 0.045, BEVEL);
  Cross(Arm - Rim - Bev, Half - Rim - Bev, S * 0.035, FACE);

  { A pressed arm, inset from the outline the same on every side. Alone, it
    runs from its tip to the edge of the centre square and the centre stays
    as it is; two arms - a diagonal - each run through the centre, so the
    pair darkens as one L. }
  Inner := Half - Rim;
  if (Pressed = [paUp]) or (Pressed = [paDown]) or (Pressed = [paLeft])
     or (Pressed = [paRight]) then
    Through := -Inner
  else
    Through := Inner;
  Regions[paUp][0] := C - Inner;  Regions[paUp][1] := C - Arm + Rim;
  Regions[paUp][2] := C + Inner;  Regions[paUp][3] := C + Through;
  Regions[paDown][0] := C - Inner; Regions[paDown][1] := C - Through;
  Regions[paDown][2] := C + Inner; Regions[paDown][3] := C + Arm - Rim;
  Regions[paLeft][0] := C - Arm + Rim; Regions[paLeft][1] := C - Inner;
  Regions[paLeft][2] := C + Through;   Regions[paLeft][3] := C + Inner;
  Regions[paRight][0] := C - Through;   Regions[paRight][1] := C - Inner;
  Regions[paRight][2] := C + Arm - Rim; Regions[paRight][3] := C + Inner;
  for A := Low(TPadArm) to High(TPadArm) do
    if A in Pressed then
      Cv.Paint([BoxLTRB(Regions[A][0], Regions[A][1], Regions[A][2],
                        Regions[A][3], S * 0.04)], SHADE_RING);
  for A := Low(TPadArm) to High(TPadArm) do
    if A in Pressed then
      Cv.Paint([BoxLTRB(Regions[A][0] + Bev, Regions[A][1] + Bev,
                        Regions[A][2] - Bev, Regions[A][3] - Bev, S * 0.03)],
               SHADE);

  { The centre dimple belongs to no arm: darker only when a diagonal has
    darkened the centre around it. }
  if (Pressed = []) or (Through < 0) then
    Cv.Paint([Circle(C, C, S * 0.065)], SHADE)
  else
    Cv.Paint([Circle(C, C, S * 0.065)], SHADE_RING);

  { An arrow in each arm, white on a pressed one. }
  T := S * 0.075;
  for A := Low(TPadArm) to High(TPadArm) do
  begin
    AX := C + DIR_X[A] * Arm * 0.66;
    AY := C + DIR_Y[A] * Arm * 0.66;
    if A in Pressed then
      Colour := WHITE
    else
      Colour := OUTLINE;
    if DIR_X[A] <> 0 then
      Cv.Paint([Triangle(AX + DIR_X[A] * T, AY,
                         AX - DIR_X[A] * T * 0.7, AY - T,
                         AX - DIR_X[A] * T * 0.7, AY + T)], Colour)
    else
      Cv.Paint([Triangle(AX, AY + DIR_Y[A] * T,
                         AX - T, AY - DIR_Y[A] * T * 0.7,
                         AX + T, AY - DIR_Y[A] * T * 0.7)], Colour);
  end;
  Result := Cv.ToSurface(OPACITY);
end;

{ A and B as strokes, so no font is needed. H is the cap height, W the
  stroke width, (CX, CY) the letter's centre. }
procedure PaintLetter(var Cv: TCanvas; Button: TFaceButton;
                      CX, CY, H, W: Single);
var
  Top, Bot, HalfW, X0, Mid, Reach, Y0, Y1, R, XR: Single;
  I: Integer;
  Shapes: array[0..8] of TShape;
begin
  Top := CY - H / 2;
  Bot := CY + H / 2;
  if Button = fbA then
  begin
    HalfW := H * 0.40;
    Cv.Paint([Stroke(CX - HalfW, Bot, CX, Top, W),
              Stroke(CX, Top, CX + HalfW, Bot, W),
              Stroke(CX - HalfW * 0.52, CY + H * 0.14,
                     CX + HalfW * 0.52, CY + H * 0.14, W)], WHITE);
    Exit;
  end;
  { B: a stem and two bowls, the lower one wider. }
  X0 := CX - H * 0.26;
  Mid := CY - H * 0.03;
  Shapes[0] := Stroke(X0, Top, X0, Bot, W);
  for I := 0 to 1 do
  begin
    if I = 0 then
    begin
      Y0 := Top; Y1 := Mid; Reach := H * 0.44;
    end
    else
    begin
      Y0 := Mid; Y1 := Bot; Reach := H * 0.52;
    end;
    R := (Y1 - Y0) / 2;
    XR := X0 + Reach - R;
    Shapes[1 + I * 3] := Stroke(X0, Y0, XR, Y0, W);
    Shapes[2 + I * 3] := Stroke(X0, Y1, XR, Y1, W);
    Shapes[3 + I * 3] := RightArc(XR, (Y0 + Y1) / 2, R, W);
  end;
  Cv.Paint(Slice(Shapes, 7), WHITE);
end;

function DrawFaceButton(Size: Integer; Button: TFaceButton;
                        Pressed: Boolean): PSDL_Surface;
var
  Cv: TCanvas;
  S, C, R, Rim, Bev: Single;
begin
  Cv.Init(Size);
  S := Size;
  C := S / 2;
  R := S * 0.48;
  Rim := S * 0.05;
  Bev := S * 0.035;
  Cv.Paint([Circle(C, C, R)], OUTLINE);
  if Pressed then
  begin
    Cv.Paint([Circle(C, C, R - Rim)], BUTTON_RING[Button]);
    Cv.Paint([Circle(C, C, R - Rim - Bev)], BUTTON_PRESS[Button]);
  end
  else
  begin
    Cv.Paint([Circle(C, C, R - Rim)], BUTTON_BEVEL[Button]);
    Cv.Paint([Circle(C, C, R - Rim - Bev)], BUTTON_FACE[Button]);
  end;
  if Button = fbA then
    PaintLetter(Cv, Button, C, C, S * 0.42, S * 0.085)
  else
    PaintLetter(Cv, Button, C, C, S * 0.42, S * 0.072);
  Result := Cv.ToSurface(OPACITY);
end;

function DrawPauseButton(Size: Integer; Pressed: Boolean): PSDL_Surface;
var
  Cv: TCanvas;
  S, A, B, E: Single;
begin
  Cv.Init(Size);
  S := Size;
  Cv.Paint([BoxLTRB(S * 0.04, S * 0.04, S * 0.96, S * 0.96, S * 0.22)], OUTLINE);
  A := S * 0.12;
  B := S * 0.88;
  E := S * 0.035;
  if Pressed then
  begin
    Cv.Paint([BoxLTRB(A, A, B, B, S * 0.16)], SHADE_RING);
    Cv.Paint([BoxLTRB(A + E, A + E, B - E, B - E, S * 0.13)], SHADE);
  end
  else
  begin
    Cv.Paint([BoxLTRB(A, A, B, B, S * 0.16)], BEVEL);
    Cv.Paint([BoxLTRB(A + E, A + E, B - E, B - E, S * 0.13)], FACE);
  end;
  Cv.Paint([BoxLTRB(S * 0.36, S * 0.31, S * 0.44, S * 0.69, S * 0.03),
            BoxLTRB(S * 0.56, S * 0.31, S * 0.64, S * 0.69, S * 0.03)], OUTLINE);
  Result := Cv.ToSurface(OPACITY);
end;

initialization
  InitColours;

end.
