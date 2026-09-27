{ The game's text: gettext PO files in assets/lang/, chosen in system.ini.

  WHERE THE TEXT LIVES

  Only here. Everything drawn in the outlined font - the dialogue, the
  opening and ending narration, the power-up names and the line announcing
  them, the Yes/No prompt, the window title - is looked up by context in
  the loaded PO files; nothing of it is compiled into the game, and the
  English release's data/tk*.dat are gone. en.po is the English and the
  base: it is always loaded, and the chosen language is laid over it, so an
  entry a translation lacks shows in English. An entry neither has shows
  nothing and is logged. With no en.po and no chosen file the game will not
  start. The menus and the results screen, drawn from an ASCII bitmap font,
  are still in the code.

  Each entry's msgctxt says where it is used: "tk006:1" is dialogue line 1
  of stage 6, the line the stage's event script names as 1.

  WHY PO

  It is the format translation tools already speak - Poedit, Weblate,
  Crowdin, Lokalize, a plain text editor. Each entry keeps the English beside
  the translation, and when the English changes, msgmerge marks the old
  translation fuzzy instead of leaving it silently wrong. The template,
  assets/lang/akuji.pot, is written by the game from en.po (--write-pot).

  KEYS

  The placeholders in KEY_PLACEHOLDERS - JUMP, FIRE and PAUSE in braces -
  are replaced, when a line is shown, by the name of the key bound to that
  action, so a sign that says "the FIRE-in-braces key" names whatever key
  the player chose. See ExpandKeys.

  THE DIALOGUE'S CODES

  In a PO file a line break is a line break. The game's other codes stay as
  written: \k waits for a key and starts a new page, \e ends the message,
  and \w ends it with the Yes/No prompt. A tool shows them as \k, \e and \w;
  inside the file they are escaped, "\\k".

  THE HEADER

  Besides the usual fields, two of the game's own:

    X-Akuji-Font: PixelMplus12-Regular.ttf    a file in assets/fonts/
    X-Akuji-Font-Size: 12                      in pixels
    X-Akuji-Menu-Name: JP                      what the options screen shows

  A language whose script the default font lacks names its own. }

unit Translation;

{$MODE DELPHI}{$H+}

interface

uses
  Classes, SysUtils;

{ Nothing here draws or plays; GameLog is the one dependency, for the
  missing-entry report. }

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

type
  TLanguageInfo = record
    Code: string;       { the file's name: ja for lang/ja.po }
    MenuName: string;   { in capitals the menu font can draw }
  end;

{ The languages in lang/, English first and the rest by code. The menu name
  is the file's X-Akuji-Menu-Name if the options screen's font can draw it -
  capitals, digits and punctuation - and the code in capitals otherwise. }
function ListLanguages(const LangDir: string): TArray<TLanguageInfo>;

{ Whether the options screen's bitmap font can draw S: $20..$5F only. }
function MenuFontCanDraw(const S: string): Boolean;

{ Loads lang/en.po as the base and lang/<Code>.po over it. False when
  neither loaded - the game has no text then, and must not start. A missing
  chosen file with en.po present gives English. }
function LoadLanguage(const LangDir, Code: string): Boolean;
procedure UnloadLanguage;

{ The language showing: the chosen code, 'en' when only the base loaded,
  '' when nothing did. }
function LanguageCode: string;

{ The text for a context: the chosen language's, else en.po's, else '' -
  logged the first time. }
function Tr(const Context: string): string;

{ The same, for dialogue: a PO line break becomes the game's \n code. }
function TrDialogue(const Context: string): string;

{ How many dialogue lines stage Stage has: one past the highest tkNNN:i in
  the loaded files. The event scripts name lines by that number. }
function DialogueLineCount(Stage: Integer): Integer;

{ The placeholders a line may use, and the action each names. }
const
  KEY_PLACEHOLDERS: array[0..2] of string = ('{JUMP}', '{FIRE}', '{PAUSE}');

type
  { The name to show for the key bound to KEY_PLACEHOLDERS[Index]. }
  TKeyNameFunc = function(Index: Integer): string of object;

{ Who answers for the key names - the form, which owns the bindings. }
procedure SetKeyNameProvider(F: TKeyNameFunc);

{ S with each placeholder replaced by its key's name. Done when a message
  opens, so a key rebound a moment ago is the one named. }
function ExpandKeys(const S: string): string;

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

uses
  GameLog;

var
  Base: TPoFile = nil;       { en.po }
  Current: TPoFile = nil;    { the chosen language, when it is not English }
  CurrentCode: string = '';
  Reported: TStringList = nil;
  KeyNames: TKeyNameFunc = nil;

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

function MenuFontCanDraw(const S: string): Boolean;
var
  I: Integer;
begin
  Result := S <> '';
  for I := 1 to Length(S) do
    if not (S[I] in [#$20..#$5F]) then
      Exit(False);
end;

function ListLanguages(const LangDir: string): TArray<TLanguageInfo>;
var
  Found: TSearchRec;
  Codes: TStringList;
  Po: TPoFile;
  Dir: string;
  I: Integer;
begin
  SetLength(Result, 0);
  Dir := IncludeTrailingPathDelimiter(LangDir);
  Codes := TStringList.Create;
  Po := TPoFile.Create;
  try
    if FindFirst(Dir + '*.po', faAnyFile, Found) = 0 then
    try
      repeat
        Codes.Add(LowerCase(ChangeFileExt(Found.Name, '')));
      until FindNext(Found) <> 0;
    finally
      FindClose(Found);
    end;
    Codes.Sort;
    I := Codes.IndexOf('en');
    if I > 0 then
      Codes.Move(I, 0);
    SetLength(Result, Codes.Count);
    for I := 0 to Codes.Count - 1 do
    begin
      Result[I].Code := Codes[I];
      Po.LoadFromFile(Dir + Codes[I] + '.po');
      Result[I].MenuName := UpperCase(Trim(Po.Header('X-Akuji-Menu-Name')));
      if not MenuFontCanDraw(Result[I].MenuName) then
        Result[I].MenuName := UpperCase(Codes[I]);
    end;
  finally
    Po.Free;
    Codes.Free;
  end;
end;

function LoadLanguage(const LangDir, Code: string): Boolean;
var
  Dir, Chosen: string;
begin
  UnloadLanguage;
  Dir := IncludeTrailingPathDelimiter(LangDir);
  if FileExists(Dir + 'en.po') then
  begin
    Base := TPoFile.Create;
    Base.LoadFromFile(Dir + 'en.po');
    CurrentCode := 'en';
  end;
  Chosen := LowerCase(Trim(Code));
  if (Chosen <> '') and (Chosen <> 'en') and FileExists(Dir + Chosen + '.po') then
  begin
    Current := TPoFile.Create;
    Current.LoadFromFile(Dir + Chosen + '.po');
    CurrentCode := Chosen;
  end;
  Result := (Base <> nil) or (Current <> nil);
end;

procedure UnloadLanguage;
begin
  FreeAndNil(Current);
  FreeAndNil(Base);
  CurrentCode := '';
  if Reported <> nil then
    Reported.Clear;
end;

function LanguageCode: string;
begin
  Result := CurrentCode;
end;

function Tr(const Context: string): string;
begin
  Result := '';
  if Current <> nil then
    Result := Current.Lookup(Context);
  if (Result = '') and (Base <> nil) then
    Result := Base.Lookup(Context);
  if (Result = '') and ((Base <> nil) or (Current <> nil)) then
  begin
    if Reported = nil then
    begin
      Reported := TStringList.Create;
      Reported.Sorted := True;
    end;
    if Reported.IndexOf(Context) < 0 then
    begin
      Reported.Add(Context);
      LogFmt(lsData, 'no text for %s in lang/%s.po or lang/en.po',
        [Context, CurrentCode]);
    end;
  end;
end;

function TrDialogue(const Context: string): string;
begin
  Result := PoToDialogue(Tr(Context));
end;

function DialogueLineCount(Stage: Integer): Integer;
var
  Prefix: string;

  procedure Scan(Po: TPoFile);
  var
    I, N: Integer;
    C: string;
  begin
    if Po = nil then
      Exit;
    for I := 0 to Po.Count - 1 do
    begin
      C := Po.Entries[I].Context;
      if Copy(C, 1, Length(Prefix)) = Prefix then
      begin
        N := StrToIntDef(Copy(C, Length(Prefix) + 1, MaxInt), -1);
        if N + 1 > Result then
          Result := N + 1;
      end;
    end;
  end;

begin
  Result := 0;
  Prefix := Format('tk%.3d:', [Stage]);
  Scan(Base);
  Scan(Current);
end;

procedure SetKeyNameProvider(F: TKeyNameFunc);
begin
  KeyNames := F;
end;

function ExpandKeys(const S: string): string;
var
  I: Integer;
begin
  Result := S;
  if (Pos('{', Result) = 0) or not Assigned(KeyNames) then
    Exit;
  for I := Low(KEY_PLACEHOLDERS) to High(KEY_PLACEHOLDERS) do
    Result := StringReplace(Result, KEY_PLACEHOLDERS[I], KeyNames(I),
                            [rfReplaceAll]);
end;

{ A header field from the chosen language, else from en.po. }
function HeaderOf(const Name: string): string;
begin
  Result := '';
  if Current <> nil then
    Result := Current.Header(Name);
  if (Result = '') and (Current = nil) and (Base <> nil) then
    Result := Base.Header(Name);
end;

function LanguageFontFile: string;
begin
  Result := HeaderOf('X-Akuji-Font');
end;

function LanguageFontSize: Integer;
begin
  Result := StrToIntDef(HeaderOf('X-Akuji-Font-Size'), 0);
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
  Reported.Free;

end.
