{ Translations: gettext PO files in assets/lang/, chosen in system.ini.

  WHY PO

  It is the format translation tools already speak - Poedit, Weblate,
  Crowdin, Lokalize, a plain text editor. Each entry keeps the English beside
  the translation, an untranslated entry falls back to English on its own,
  and when the English changes, msgmerge marks the old translation fuzzy
  instead of leaving it silently wrong. assets/lang/akuji.pot is the template,
  written by the game itself (--write-pot) from the English data, so it
  cannot drift from what the game shows.

  WHAT A TRANSLATION CAN REPLACE

  Everything drawn in the outlined font: the dialogue (data/tk*.dat), the
  opening and ending narration, the power-up names and the line that
  announces them, the Yes/No prompt, and the window title. The menus and the
  results screen are drawn from a bitmap font that has only ASCII, and are
  not in the template yet.

  Each entry's msgctxt says where it is used - "tk006:1" is line 1 of
  data/tk006.dat. English is not a PO file: it is the game's own data, and
  English is what shows whenever no language is chosen or an entry is empty.

  THE DIALOGUE'S CODES

  In a PO file a line break is a line break. The game's other codes stay as
  written: \k waits for a key and starts a new page, \e ends the message,
  and \w ends it with the Yes/No prompt. A tool shows them as \k, \e and \w;
  inside the file they are escaped, "\\k".

  THE HEADER

  Besides the usual fields, two of the game's own:

    X-Akuji-Font: PixelMplus12-Regular.ttf    a file in assets/fonts/
    X-Akuji-Font-Size: 12                      in pixels

  A language whose script the default font lacks names its own. }

unit Translation;

{$MODE DELPHI}{$H+}

interface

uses
  Classes, SysUtils;

type
  TPoEntry = record
    Context: string;
    Id: string;
    Str: string;
    Fuzzy: Boolean;
    Comment: string;      { #. lines, for the translator }
  end;

  TPoFile = class
  private
    FEntries: array of TPoEntry;
    FIndex: TStringList;  { context -> entry number, sorted }
    FHeader: TStringList; { Name=Value }
    function GetCount: Integer;
    function GetEntry(I: Integer): TPoEntry;
  public
    constructor Create;
    destructor Destroy; override;
    procedure LoadFromFile(const FileName: string);
    procedure LoadFromString(const Text: string);
    { The translation for this context, or '' if there is none usable - an
      empty msgstr, a fuzzy one, or no entry at all. }
    function Lookup(const Context: string): string;
    function Header(const Name: string): string;
    function IndexOfContext(const Context: string): Integer;
    property Count: Integer read GetCount;
    property Entries[I: Integer]: TPoEntry read GetEntry;
  end;

{ Loads assets/lang/<Code>.po. 'en', '' or a missing file leave English in
  place, which is not an error - the result says whether a file was used. }
function LoadLanguage(const LangDir, Code: string): Boolean;
procedure UnloadLanguage;

{ The chosen language's code, 'en' when none is loaded. }
function LanguageCode: string;

{ Context lookup with English fallback. }
function Tr(const Context, English: string): string;

{ The same, for dialogue: a PO line break becomes the game's \n code. }
function TrDialogue(const Context, English: string): string;

{ The font the chosen language asks for: a file name under assets/fonts/
  and a pixel size, or '' and 0 for the default. }
function LanguageFontFile: string;
function LanguageFontSize: Integer;

{ Writing PO: a string as one or more quoted lines, split after each line
  break the way the gettext tools write them. }
function PoQuote(const Keyword, S: string): string;

{ The game's dialogue codes to PO text and back: \n <-> line break. }
function DialogueToPo(const S: string): string;
function PoToDialogue(const S: string): string;

implementation

var
  Current: TPoFile = nil;
  CurrentCode: string = 'en';

{ --- reading ------------------------------------------------------------- }

function Unescape(const S: string): string;
var
  I: Integer;
begin
  Result := '';
  I := 1;
  while I <= Length(S) do
  begin
    if (S[I] = '\') and (I < Length(S)) then
    begin
      Inc(I);
      case S[I] of
        'n': Result := Result + #10;
        't': Result := Result + #9;
        'r': Result := Result + #13;
        '"': Result := Result + '"';
        '\': Result := Result + '\';
      else
        Result := Result + '\' + S[I];
      end;
    end
    else
      Result := Result + S[I];
    Inc(I);
  end;
end;

{ The text between the first and last double quote of a line. }
function QuotedPart(const Line: string): string;
var
  A, B: Integer;
begin
  A := Pos('"', Line);
  B := Length(Line);
  while (B > A) and (Line[B] <> '"') do
    Dec(B);
  if (A = 0) or (B <= A) then
    Exit('');
  Result := Unescape(Copy(Line, A + 1, B - A - 1));
end;

constructor TPoFile.Create;
begin
  inherited Create;
  FIndex := TStringList.Create;
  FIndex.CaseSensitive := True;
  FIndex.Sorted := True;
  FIndex.Duplicates := dupIgnore;
  FHeader := TStringList.Create;
end;

destructor TPoFile.Destroy;
begin
  FIndex.Free;
  FHeader.Free;
  inherited Destroy;
end;

function TPoFile.GetCount: Integer;
begin
  Result := Length(FEntries);
end;

function TPoFile.GetEntry(I: Integer): TPoEntry;
begin
  Result := FEntries[I];
end;

procedure TPoFile.LoadFromFile(const FileName: string);
var
  Stream: TStringStream;
begin
  Stream := TStringStream.Create('');
  try
    Stream.LoadFromFile(FileName);
    LoadFromString(Stream.DataString);
  finally
    Stream.Free;
  end;
end;

procedure TPoFile.LoadFromString(const Text: string);
type
  TField = (fNone, fCtx, fId, fStr);
var
  Lines: TStringList;
  E: TPoEntry;
  Field: TField;
  Have: Boolean;
  I, N: Integer;
  Line, Body: string;

  procedure Finish;
  var
    HeaderLines: TStringList;
    K, Colon: Integer;
  begin
    if not Have then
      Exit;
    if (E.Id = '') and (E.Context = '') then
    begin
      { The header: "Name: value" lines inside the empty msgid's msgstr. }
      HeaderLines := TStringList.Create;
      try
        HeaderLines.Text := E.Str;
        for K := 0 to HeaderLines.Count - 1 do
        begin
          Colon := Pos(':', HeaderLines[K]);
          if Colon > 0 then
            FHeader.Values[Trim(Copy(HeaderLines[K], 1, Colon - 1))] :=
              Trim(Copy(HeaderLines[K], Colon + 1, MaxInt));
        end;
      finally
        HeaderLines.Free;
      end;
    end
    else
    begin
      N := Length(FEntries);
      SetLength(FEntries, N + 1);
      FEntries[N] := E;
      FIndex.AddObject(E.Context, TObject(PtrInt(N)));
    end;
    Have := False;
    E := Default(TPoEntry);
    Field := fNone;
  end;

begin
  SetLength(FEntries, 0);
  FIndex.Clear;
  FHeader.Clear;
  Lines := TStringList.Create;
  try
    Body := Text;
    if Copy(Body, 1, 3) = #$EF#$BB#$BF then
      Delete(Body, 1, 3);
    Lines.Text := Body;
    E := Default(TPoEntry);
    Have := False;
    Field := fNone;
    for I := 0 to Lines.Count - 1 do
    begin
      Line := Trim(Lines[I]);
      if Line = '' then
        Continue;
      if Line[1] = '#' then
      begin
        { A comment starts the next entry if the last one is complete. }
        if Field = fStr then
          Finish;
        if Copy(Line, 1, 2) = '#,' then
          E.Fuzzy := E.Fuzzy or (Pos('fuzzy', Line) > 0)
        else if Copy(Line, 1, 2) = '#.' then
        begin
          if E.Comment <> '' then
            E.Comment := E.Comment + #10;
          E.Comment := E.Comment + Trim(Copy(Line, 3, MaxInt));
        end;
        Continue;
      end;
      if Copy(Line, 1, 7) = 'msgctxt' then
      begin
        if Field = fStr then
          Finish;
        E.Context := QuotedPart(Line);
        Field := fCtx;
        Have := True;
      end
      else if Copy(Line, 1, 5) = 'msgid' then
      begin
        if Field = fStr then
          Finish;
        E.Id := QuotedPart(Line);
        Field := fId;
        Have := True;
      end
      else if Copy(Line, 1, 6) = 'msgstr' then
      begin
        E.Str := QuotedPart(Line);
        Field := fStr;
      end
      else if Line[1] = '"' then
        case Field of
          fCtx: E.Context := E.Context + QuotedPart(Line);
          fId:  E.Id := E.Id + QuotedPart(Line);
          fStr: E.Str := E.Str + QuotedPart(Line);
        end;
    end;
    Finish;
  finally
    Lines.Free;
  end;
end;

function TPoFile.IndexOfContext(const Context: string): Integer;
var
  I: Integer;
begin
  if FIndex.Find(Context, I) then
    Result := PtrInt(FIndex.Objects[I])
  else
    Result := -1;
end;

function TPoFile.Lookup(const Context: string): string;
var
  I: Integer;
begin
  I := IndexOfContext(Context);
  if (I < 0) or FEntries[I].Fuzzy then
    Exit('');
  Result := FEntries[I].Str;
end;

function TPoFile.Header(const Name: string): string;
begin
  Result := FHeader.Values[Name];
end;

{ --- the chosen language -------------------------------------------------- }

function LoadLanguage(const LangDir, Code: string): Boolean;
var
  FileName: string;
begin
  UnloadLanguage;
  Result := False;
  if (Code = '') or SameText(Code, 'en') then
    Exit;
  FileName := IncludeTrailingPathDelimiter(LangDir) + LowerCase(Code) + '.po';
  if not FileExists(FileName) then
    Exit;
  Current := TPoFile.Create;
  Current.LoadFromFile(FileName);
  CurrentCode := LowerCase(Code);
  Result := True;
end;

procedure UnloadLanguage;
begin
  FreeAndNil(Current);
  CurrentCode := 'en';
end;

function LanguageCode: string;
begin
  Result := CurrentCode;
end;

function Tr(const Context, English: string): string;
begin
  Result := '';
  if Current <> nil then
    Result := Current.Lookup(Context);
  if Result = '' then
    Result := English;
end;

function TrDialogue(const Context, English: string): string;
var
  S: string;
begin
  S := '';
  if Current <> nil then
    S := Current.Lookup(Context);
  if S = '' then
    Result := English
  else
    Result := PoToDialogue(S);
end;

function LanguageFontFile: string;
begin
  Result := '';
  if Current <> nil then
    Result := Current.Header('X-Akuji-Font');
end;

function LanguageFontSize: Integer;
begin
  Result := 0;
  if Current <> nil then
    Result := StrToIntDef(Current.Header('X-Akuji-Font-Size'), 0);
end;

{ --- writing -------------------------------------------------------------- }

function Escape(const S: string): string;
var
  I: Integer;
begin
  Result := '';
  for I := 1 to Length(S) do
    case S[I] of
      '\': Result := Result + '\\';
      '"': Result := Result + '\"';
      #10: Result := Result + '\n';
      #9:  Result := Result + '\t';
      #13: Result := Result + '\r';
    else
      Result := Result + S[I];
    end;
end;

function PoQuote(const Keyword, S: string): string;
var
  Parts: TStringList;
  I, Start: Integer;
begin
  if Pos(#10, S) = 0 then
    Exit(Keyword + ' "' + Escape(S) + '"');
  Parts := TStringList.Create;
  try
    Start := 1;
    for I := 1 to Length(S) do
      if S[I] = #10 then
      begin
        Parts.Add(Copy(S, Start, I - Start + 1));
        Start := I + 1;
      end;
    if Start <= Length(S) then
      Parts.Add(Copy(S, Start, MaxInt));
    Result := Keyword + ' ""';
    for I := 0 to Parts.Count - 1 do
      Result := Result + #10 + '"' + Escape(Parts[I]) + '"';
  finally
    Parts.Free;
  end;
end;

function DialogueToPo(const S: string): string;
begin
  Result := StringReplace(S, '\n', #10, [rfReplaceAll]);
end;

function PoToDialogue(const S: string): string;
begin
  Result := StringReplace(StringReplace(S, #13#10, #10, [rfReplaceAll]),
                          #10, '\n', [rfReplaceAll]);
end;

finalization
  UnloadLanguage;

end.
