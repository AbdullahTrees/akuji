{ UTF-8 text as the dialogue box sees it: characters, their width, and the
  units it reveals one at a time.

  THE ORIGINAL'S UNIT

  The game was written for Shift-JIS, where a full-width character is two
  bytes and a half-width one is one. The dialogue box uncovers TWO BYTES per
  tick, so it reveals one full-width character or two half-width ones, plays
  one blip for each, and recognises a line break only as an aligned "\n"
  pair. The English data kept that rule by padding - "sealed off! \e" - so
  every escape still lands on an even byte.

  Text is UTF-8 now, where a character can be one to four bytes, so bytes no
  longer say anything about width. The same rule is stated in characters:

    * a wide character (CJK, kana, full-width forms, Hangul) is one unit;
    * narrow characters pair up, two to a unit;
    * "\n" is a unit of its own wherever it falls.

  On text whose escapes are aligned - all of the English data, and the
  Japanese data after conversion - this gives exactly the units the byte
  rule gave; --selftest-lang compares the two over every English record. The
  one difference is deliberate: a translator no longer has to pad. See
  notes/divergences.md, DIV-026.

  WIDTH

  Columns, as a terminal counts them: 2 for a wide character, 1 otherwise.
  A keycap icon (a private-use character) counts as wide: it reveals in one
  step and is about two columns across.
  That is what the Shift-JIS byte length measured, which is how the item panel
  centres its line. }

unit TextUnits;

{$MODE DELPHI}{$H+}

interface

{ The byte length of the UTF-8 character starting at S[I]; 1 for a byte that
  does not start a valid sequence, so a malformed string still advances. }
function Utf8CharLen(const S: string; I: Integer): Integer;

{ The code point starting at S[I], and its byte length. A malformed byte
  decodes as itself. }
function Utf8CodePoint(const S: string; I: Integer; out Len: Integer): Cardinal;

{ East Asian Wide or Full-width. }
function IsWideCodePoint(C: Cardinal): Boolean;

{ Display columns: 2 per wide character, 1 per other character. }
function TextColumns(const S: string): Integer;

{ The page split into the units the dialogue box reveals. }
function RevealUnitsOf(const S: string): TArray<string>;

implementation

function Utf8CharLen(const S: string; I: Integer): Integer;
var
  B: Byte;
  N, K: Integer;
begin
  B := Ord(S[I]);
  if B < $80 then
    Exit(1);
  if (B and $E0) = $C0 then N := 2
  else if (B and $F0) = $E0 then N := 3
  else if (B and $F8) = $F0 then N := 4
  else Exit(1);
  if I + N - 1 > Length(S) then
    Exit(1);
  for K := 1 to N - 1 do
    if (Ord(S[I + K]) and $C0) <> $80 then
      Exit(1);
  Result := N;
end;

function Utf8CodePoint(const S: string; I: Integer; out Len: Integer): Cardinal;
var
  K: Integer;
begin
  Len := Utf8CharLen(S, I);
  case Len of
    2: Result := Ord(S[I]) and $1F;
    3: Result := Ord(S[I]) and $0F;
    4: Result := Ord(S[I]) and $07;
  else
    Exit(Ord(S[I]));
  end;
  for K := 1 to Len - 1 do
    Result := (Result shl 6) or (Ord(S[I + K]) and $3F);
end;

function IsWideCodePoint(C: Cardinal): Boolean;
begin
  case C of
    $1100..$115F,          { Hangul Jamo initials }
    $2E80..$303E,          { CJK radicals, punctuation, ideographic space }
    $3041..$33FF,          { kana, CJK symbols }
    $3400..$4DBF,          { CJK extension A }
    $4E00..$9FFF,          { CJK unified ideographs }
    $A000..$A4CF,          { Yi }
    $AC00..$D7A3,          { Hangul syllables }
    $F900..$FAFF,          { CJK compatibility ideographs }
    $FE30..$FE4F,          { CJK compatibility forms }
    $FF00..$FF60,          { full-width forms }
    $FFE0..$FFE6,          { full-width signs }
    $E000..$F8FF,          { private use: the keycap icons, see KeyIcons }
    $20000..$3FFFD:        { CJK extensions B onwards }
      Result := True;
  else
    Result := False;
  end;
end;

function TextColumns(const S: string): Integer;
var
  I, Len: Integer;
begin
  Result := 0;
  I := 1;
  while I <= Length(S) do
  begin
    if IsWideCodePoint(Utf8CodePoint(S, I, Len)) then
      Inc(Result, 2)
    else
      Inc(Result);
    Inc(I, Len);
  end;
end;

function RevealUnitsOf(const S: string): TArray<string>;
var
  Count, I, Len: Integer;
  Pending: string;

  procedure Add(const U: string);
  begin
    if Count = Length(Result) then
      SetLength(Result, Count * 2 + 16);
    Result[Count] := U;
    Inc(Count);
  end;

  procedure Flush;
  begin
    if Pending <> '' then
    begin
      Add(Pending);
      Pending := '';
    end;
  end;

begin
  Count := 0;
  Pending := '';
  SetLength(Result, 0);
  I := 1;
  while I <= Length(S) do
  begin
    if (S[I] = '\') and (I < Length(S)) and (S[I + 1] = 'n') then
    begin
      Flush;
      Add('\n');
      Inc(I, 2);
      Continue;
    end;
    Len := Utf8CharLen(S, I);
    if IsWideCodePoint(Utf8CodePoint(S, I, Len)) then
    begin
      Flush;
      Add(Copy(S, I, Len));
    end
    else
    begin
      Pending := Pending + Copy(S, I, Len);
      { Two narrow characters make a unit - counted in characters, not
        bytes, so an accented letter pairs like any other. }
      if (Length(Pending) > Len) then
        Flush;
    end;
    Inc(I, Len);
  end;
  Flush;
  SetLength(Result, Count);
end;

end.
