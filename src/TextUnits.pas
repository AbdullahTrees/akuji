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

uses
  Classes, SysUtils;

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

type
  { How wide a piece of one line is drawn, in pixels. }
  TMeasureFunc = function(const S: string): Integer;

{ A whole dialogue message - pages ended by \k, \e or \w, lines by \n - with
  every line wider than MaxWidth broken so it fits, and every page that then
  has more lines than the box holds continued on a new page, as if a \k were
  written there.

  The original had no way to measure text: its lines broke where the writer
  put \n, and a line too long for the box ran past its edge. This breaks
  only what does not fit, so text that fits comes back byte for byte.

    * Latin text breaks at a space, and the space at the break is dropped.
    * Between wide characters - kana, kanji, full-width forms, keycaps - any
      gap is a break, except before a character that may not start a line
      (、。」】ー, small kana, and their like) or after one that may not end
      one (「【 and their like). The same holds for ASCII ,.!?:;)] and ([.
    * A word with no break in it that is still too long is cut where it must.

  PageLines is how many lines a page holds; PromptLines how many a page
  ending in \w holds, the Yes/No row taking the rest. A message's own \k,
  \e and \w are kept, and a \w stays on the last page. }
function WrapMessage(const S: string; MaxWidth, PageLines,
                     PromptLines: Integer; Measure: TMeasureFunc): string;

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

{ --- wrapping ---------------------------------------------------------- }

const
  { May not start a line. }
  NO_START: array[0..41] of Cardinal = (
    $3001, $3002, $FF0C, $FF0E, $30FB, $FF1A, $FF1B, $FF1F, $FF01, $30FC,
    $FF09, $300D, $300F, $3011, $3015, $3009, $300B, $2026, $2025, $3063,
    $3041, $3043, $3045, $3047, $3049, $3083, $3085, $3087, $308E, $30C3,
    $30A1, $30A3, $30A5, $30A7, $30A9, $30E3, $30E5, $30E7, $30EE, $30F5,
    $30F6, $301C);
  { May not end a line. }
  NO_END: array[0..6] of Cardinal = (
    $FF08, $300C, $300E, $3010, $3014, $3008, $300A);

function InList(C: Cardinal; const L: array of Cardinal): Boolean;
var
  I: Integer;
begin
  for I := Low(L) to High(L) do
    if L[I] = C then
      Exit(True);
  Result := False;
end;

function NoStart(C: Cardinal): Boolean;
begin
  Result := InList(C, NO_START) or (C in [Ord(','), Ord('.'), Ord('!'),
            Ord('?'), Ord(':'), Ord(';'), Ord(')'), Ord(']'), Ord('}')]);
end;

function NoEnd(C: Cardinal): Boolean;
begin
  Result := InList(C, NO_END) or (C in [Ord('('), Ord('['), Ord('{')]);
end;

type
  TChar = record
    Text: string;
    Code: Cardinal;
  end;

function CharsOf(const S: string): TArray<TChar>;
var
  I, Len, N: Integer;
begin
  SetLength(Result, Length(S));
  N := 0;
  I := 1;
  while I <= Length(S) do
  begin
    Result[N].Code := Utf8CodePoint(S, I, Len);
    Result[N].Text := Copy(S, I, Len);
    Inc(N);
    Inc(I, Len);
  end;
  SetLength(Result, N);
end;

function Joined(const C: TArray<TChar>; First, Last: Integer): string;
var
  I: Integer;
begin
  Result := '';
  for I := First to Last do
    Result := Result + C[I].Text;
end;

{ Whether a line may break between C[I - 1] and C[I]. }
function CanBreakBefore(const C: TArray<TChar>; I: Integer): Boolean;
var
  A, B: Cardinal;
begin
  A := C[I - 1].Code;
  B := C[I].Code;
  if (A = Ord(' ')) and (B <> Ord(' ')) then
    Exit(True);
  if (B = Ord(' ')) or (A = Ord(' ')) then
    Exit(False);
  Result := (IsWideCodePoint(A) or IsWideCodePoint(B))
            and not NoStart(B) and not NoEnd(A);
end;

{ One line, broken into as many as it needs. }
procedure WrapLine(const Line: string; MaxWidth: Integer;
                   Measure: TMeasureFunc; Lines: TStrings);
var
  C: TArray<TChar>;
  Start, I, Best, Cut, Last: Integer;
begin
  if (Line = '') or (Measure(TrimRight(Line)) <= MaxWidth) then
  begin
    Lines.Add(Line);
    Exit;
  end;
  C := CharsOf(Line);
  Start := 0;
  while Start <= High(C) do
  begin
    { The rest fits: done. }
    if Measure(TrimRight(Joined(C, Start, High(C)))) <= MaxWidth then
    begin
      Lines.Add(Joined(C, Start, High(C)));
      Break;
    end;
    { The last allowed break with everything before it inside the width. }
    Best := -1;
    for I := Start + 1 to High(C) do
    begin
      if Measure(TrimRight(Joined(C, Start, I - 1))) > MaxWidth then
        Break;
      if CanBreakBefore(C, I) then
        Best := I;
    end;
    if Best < 0 then
    begin
      { No break fits: cut after the last character that does, at least one. }
      Cut := Start + 1;
      while (Cut <= High(C))
            and (Measure(Joined(C, Start, Cut)) <= MaxWidth) do
        Inc(Cut);
      Best := Cut;
    end;
    Last := Best - 1;
    Lines.Add(TrimRight(Joined(C, Start, Last)));
    { The space the line broke at is not carried to the next. }
    Start := Best;
    while (Start <= High(C)) and (C[Start].Code = Ord(' ')) do
      Inc(Start);
  end;
end;

{ The line breaks of a page, split exactly: 'a\nb\n' is 'a', 'b', ''. }
function SplitLines(const Page: string): TArray<string>;
var
  P, N: Integer;
  Rest: string;
begin
  N := 0;
  SetLength(Result, 0);
  Rest := Page;
  repeat
    P := Pos('\n', Rest);
    SetLength(Result, N + 1);
    if P = 0 then
      Result[N] := Rest
    else
    begin
      Result[N] := Copy(Rest, 1, P - 1);
      Rest := Copy(Rest, P + 2, MaxInt);
    end;
    Inc(N);
  until P = 0;
end;

function WrapMessage(const S: string; MaxWidth, PageLines,
                     PromptLines: Integer; Measure: TMeasureFunc): string;
var
  Rest, Page, Term: string;
  Lines: TArray<string>;
  Wrapped: TStringList;
  I, K, Found, Room, Take: Integer;
  Same: Boolean;
begin
  Result := '';
  Rest := S;
  Wrapped := TStringList.Create;
  try
    while Rest <> '' do
    begin
      { The next page, and the code that ends it - '' where the text just
        stops. }
      Found := 0;
      for I := 1 to Length(Rest) - 1 do
        if (Rest[I] = '\') and (Rest[I + 1] in ['k', 'e', 'w']) then
        begin
          Found := I;
          Break;
        end;
      if Found = 0 then
      begin
        Page := Rest;
        Term := '';
        Rest := '';
      end
      else
      begin
        Page := Copy(Rest, 1, Found - 1);
        Term := Copy(Rest, Found, 2);
        Rest := Copy(Rest, Found + 2, MaxInt);
      end;

      Lines := SplitLines(Page);
      Wrapped.Clear;
      for I := 0 to High(Lines) do
        WrapLine(Lines[I], MaxWidth, Measure, Wrapped);
      if Term = '\w' then
        Room := PromptLines
      else
        Room := PageLines;

      Same := (Wrapped.Count = Length(Lines)) and (Wrapped.Count <= Room);
      if Same then
        for I := 0 to High(Lines) do
          Same := Same and (Wrapped[I] = Lines[I]);

      if Same then
        { Fits as written: kept byte for byte. }
        Result := Result + Page + Term
      else
      begin
        { Pages ahead of the last, which keeps the page's own code. Each
          takes what a page holds but always leaves the last at least one
          line - a Yes/No question never ends up on a page of its own with
          nothing on it. }
        K := 0;
        while Wrapped.Count - K > Room do
        begin
          Take := PageLines;
          if Take > Wrapped.Count - K - 1 then
            Take := Wrapped.Count - K - 1;
          for I := K to K + Take - 1 do
          begin
            if I > K then
              Result := Result + '\n';
            Result := Result + Wrapped[I];
          end;
          Result := Result + '\k';
          Inc(K, Take);
        end;
        for I := K to Wrapped.Count - 1 do
        begin
          if I > K then
            Result := Result + '\n';
          Result := Result + Wrapped[I];
        end;
        Result := Result + Term;
      end;

      { Nothing after \e is shown; it stays as it was. }
      if Term = '\e' then
      begin
        Result := Result + Rest;
        Rest := '';
      end;
    end;
  finally
    Wrapped.Free;
  end;
end;

end.
