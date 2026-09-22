{ The colour type the game speaks in.

  This used to come from the LCL's Graphics unit, and it was the last thing
  most of these units wanted from the LCL at all - a type and a handful of
  names, in code that has drawn through SDL for some time. Pulling in a
  widget set for that is what kept the window from moving.

  THE VALUES ARE THE LCL'S EXACTLY, and so is the byte order: a TColor is
  $00BBGGRR, blue in the high byte, which is backwards from how the constants
  read and is why clRed is $0000FF. Nothing here is a new decision - the
  renderer already unpacks colours this way, the shipped art already matches,
  and every render baseline was taken against these numbers. }

unit GameColors;

{$MODE DELPHI}{$H+}

interface

type
  { Longint rather than an enumeration, because the game stores colours in
    integer fields and compares them with integers. }
  TColor = type Longint;

const
  clBlack = TColor($000000);
  clWhite = TColor($FFFFFF);
  clRed   = TColor($0000FF);
  clNavy  = TColor($800000);
  clOlive = TColor($008080);

{ The three channels of a TColor. Named because $00BBGGRR is easy to get
  backwards and every site that unpacks one had its own shift. }
function RedOf(C: TColor): Byte; inline;
function GreenOf(C: TColor): Byte; inline;
function BlueOf(C: TColor): Byte; inline;
function RGBColor(R, G, B: Byte): TColor; inline;

{ Strips the system-colour tag, which is what the LCL's function of this name
  did before it went looking up a theme. The game names no system colour - it
  says clBlack, clWhite and a handful of literals - so for every value that
  reaches it this is the identity, and it is kept only so that a corrupt or
  stray value cannot arrive at SDL as a number with its high byte set. }
function ColorToRGB(C: TColor): TColor; inline;

implementation

function RedOf(C: TColor): Byte;
begin
  Result := Byte(C);
end;

function GreenOf(C: TColor): Byte;
begin
  Result := Byte(C shr 8);
end;

function BlueOf(C: TColor): Byte;
begin
  Result := Byte(C shr 16);
end;

function RGBColor(R, G, B: Byte): TColor;
begin
  Result := TColor(R) or (TColor(G) shl 8) or (TColor(B) shl 16);
end;

function ColorToRGB(C: TColor): TColor;
begin
  Result := C and $00FFFFFF;
end;

end.
