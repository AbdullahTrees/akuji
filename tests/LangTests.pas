{ Translations: the text units, the PO reader and writer, the template, and
  every shipped language file.

  --selftest-lang <game dir> [preview.bmp]
  --write-pot <game dir> [output]     writes lang/akuji.pot by default

  WHAT IS HELD

    * The UTF-8 reveal units give the ORIGINAL's units: over every English
      record, page by page, RevealUnitsOf must equal the two-byte pairs the
      Shift-JIS rule produced. That is what makes the switch to UTF-8 a
      non-event for English.
    * The template round-trips: written, read back, every entry is the
      English it came from, and the dialogue's \n survive the trip.
    * Each lang/*.po: no entry the game does not look up (a stale context
      is a translation that silently never shows), the dialogue codes that
      steer the game kept, every character in its font, every line inside
      the box, and the Yes/No words clear of the hand cursor. }

unit LangTests;

{$MODE DELPHI}{$H+}

interface

uses
  Classes, SysUtils;

function SelfTestLang(Log: TStrings): Integer;
function WritePot(Log: TStrings): Integer;

implementation

uses
  SDL2, TextUnits, Translation, LangTemplate, Dialogue, TextRender,
  RenderTarget, SDLTarget, GameFont, GameColors, PlayerState;

const
  { The box's text starts at BOX_TEXT_X; its inner border is one tile in
    from the right edge of BOX_COLS + 1 tiles. }
  BOX_TEXT_RIGHT = BOX_X + BOX_COLS * BOX_TILE;
  BOX_TEXT_WIDTH = BOX_TEXT_RIGHT - BOX_TEXT_X;
  { The Yes/No row is drawn on a text line - the third - so a page that ends
    with \w has room for only the lines above it. }
  PROMPT_LINE = (MB_PROMPT_TEXT_DY - BOX_FIRST_LINE) div BOX_LINE_STEP;

  { ja.po's preview, the same on Windows (SDL_ttf 2.24) and in the PortMaster
    image (2.0.15). It moves if the font, the renderer or ja.po's tk001:0,
    opening:0-1, powerup:4, powerup.found or prompt.yesno change - re-pin
    after looking at the picture. }
  JA_PREVIEW = $4CC263FF;

  PO_SAMPLE =
    '# a comment'#10 +
    'msgid ""'#10 +
    'msgstr ""'#10 +
    '"Language: xx\n"'#10 +
    '"X-Akuji-Font: Some.ttf\n"'#10 +
    '"X-Akuji-Font-Size: 14\n"'#10 +
    ''#10 +
    '#. for the translator'#10 +
    '#: data/tk001.dat:1'#10 +
    'msgctxt "tk001:0"'#10 +
    'msgid ""'#10 +
    '"First line\n"'#10 +
    '"second \"quoted\" \\k"'#10 +
    'msgstr ""'#10 +
    '"Erste Zeile\n"'#10 +
    '"zweite \\k"'#10 +
    ''#10 +
    '#, fuzzy'#10 +
    'msgctxt "tk001:1"'#10 +
    'msgid "old"'#10 +
    'msgstr "stale"'#10 +
    ''#10 +
    'msgctxt "tk001:2"'#10 +
    'msgid "untranslated"'#10 +
    'msgstr ""'#10;

function GameDirArg: string;
begin
  Result := IncludeTrailingPathDelimiter(ParamStr(2));
end;

function FileText(const FileName: string): string;
var
  Stream: TStringStream;
begin
  Result := '';
  if not FileExists(FileName) then
    Exit;
  Stream := TStringStream.Create('');
  try
    Stream.LoadFromFile(FileName);
    Result := StringReplace(Stream.DataString, #13#10, #10, [rfReplaceAll]);
  finally
    Stream.Free;
  end;
end;

function WithoutVersion(const S: string): string;
var
  A, B: Integer;
begin
  Result := S;
  A := Pos('"Project-Id-Version:', Result);
  if A = 0 then
    Exit;
  B := A;
  while (B <= Length(Result)) and (Result[B] <> #10) do
    Inc(B);
  Delete(Result, A, B - A);
end;

{ preview.bmp becomes preview-ja.bmp, one per language; '' without one. }
function PreviewFile(const Code: string): string;
begin
  Result := '';
  if ParamStr(3) <> '' then
    Result := ChangeFileExt(ParamStr(3), '') + '-' + Code
              + ExtractFileExt(ParamStr(3));
end;

{ The original's units: two bytes at a time. Only meaningful for text whose
  bytes are one character each, which the English data is. }
function BytePairs(const S: string): TArray<string>;
var
  I: Integer;
begin
  Result := nil;
  SetLength(Result, (Length(S) + 1) div 2);
  for I := 0 to High(Result) do
    Result[I] := Copy(S, I * 2 + 1, 2);
end;

{ A dialogue record's pages, as the box takes them. A page that ends with the
  Yes/No prompt carries a non-nil Objects entry. }
function PagesOf(const Text: string): TStringList;
var
  Page, Rest, Left: string;
  Prompt: Boolean;
  Guard: Integer;
begin
  Result := TStringList.Create;
  Left := Text;
  Guard := 0;
  while (Left <> '') and (Guard < 64) do
  begin
    Page := SplitPage(Left, Rest, Prompt);
    Result.AddObject(Page, TObject(PtrInt(Ord(Prompt))));
    Left := Rest;
    Inc(Guard);
  end;
end;

function SameUnits(const A, B: TArray<string>): Boolean;
var
  I: Integer;
begin
  Result := Length(A) = Length(B);
  if Result then
    for I := 0 to High(A) do
      if A[I] <> B[I] then
        Exit(False);
end;

function UnitsText(const A: TArray<string>): string;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to High(A) do
    Result := Result + '[' + A[I] + ']';
end;

{ The terminating code of a dialogue record: its last \e, \k or \w. }
function Terminator(const S: string): string;
var
  I: Integer;
begin
  Result := '';
  for I := Length(S) - 1 downto 1 do
    if (S[I] = '\') and (S[I + 1] in ['e', 'k', 'w']) then
      Exit(Copy(S, I, 2));
end;

function IsValidUtf8(const S: string): Boolean;
var
  I, Len: Integer;
begin
  I := 1;
  while I <= Length(S) do
  begin
    Len := Utf8CharLen(S, I);
    if (Len = 1) and (Ord(S[I]) >= $80) then
      Exit(False);
    Inc(I, Len);
  end;
  Result := True;
end;

{ The chosen language's text at the places the game draws it - a dialogue
  page, the prompt, the power-up line and a line of narration - over a flat
  box colour, saved as a BMP. The checksum is reported so a font or renderer
  change shows up as a number. }
function Preview(const FileName: string; Log: TStrings): LongWord;
const
  BOX_COLOUR = $00385878;
var
  Surf: PSDL_Surface;
  Target: TSDLRenderTarget;
  Lines: TStringList;
  Page, Rest: string;
  Prompt: Boolean;
  I, Y: Integer;
  P: PLongWord;
begin
  Result := 0;
  Surf := SDL_CreateRGBSurface(0, 320, 240, 32, $00FF0000, $0000FF00,
                               $000000FF, 0);
  if Surf = nil then
    Exit;
  Target := TSDLRenderTarget.Create(Surf);
  Lines := TStringList.Create;
  try
    SDL_FillRect(Surf, nil, BOX_COLOUR);
    { Stage 1's first message, first page, where the box puts it when low. }
    Page := SplitPage(Tr('tk001:0', ''), Rest, Prompt);
    { Raw PO text: its line breaks are real ones already. }
    Lines.Text := Page;
    for I := 0 to Lines.Count - 1 do
      Game_DrawTextOutlined(BOX_TEXT_X, 8 + I * BOX_LINE_STEP, Lines[I],
        BOX_TEXT_OUTLINE, BOX_TEXT_FILL, OUTLINED_FONT_SIZE, Target);
    Game_DrawTextOutlined(MB_PROMPT_TEXT_X, 64, PromptText,
      MB_PROMPT_OUTLINE, MB_PROMPT_FILL, OUTLINED_FONT_SIZE, Target);
    Page := StringReplace(Tr('powerup.found', POWERUP_FOUND), '%s',
                          PowerUpName(4), []);
    Game_DrawTextOutlined((PANEL_W - TextColumns(Page) * PANEL_CHAR_W) div 2,
      100, Page, PANEL_TEXT_OUTLINE, PANEL_TEXT_FILL, OUTLINED_FONT_SIZE,
      Target);
    Game_DrawTextOutlined(BOX_TEXT_X - 4, 140, Tr('opening:0', ''),
      BOX_TEXT_OUTLINE, BOX_TEXT_FILL, OUTLINED_FONT_SIZE, Target);
    Game_DrawTextOutlined(BOX_TEXT_X - 4, 156, Tr('opening:1', ''),
      BOX_TEXT_OUTLINE, BOX_TEXT_FILL, OUTLINED_FONT_SIZE, Target);

    { FNV-1a over the pixels, alpha ignored. }
    Result := 2166136261;
    for Y := 0 to Surf^.h - 1 do
    begin
      P := PLongWord(PByte(Surf^.pixels) + Y * Surf^.pitch);
      for I := 0 to Surf^.w - 1 do
      begin
        Result := (Result xor (P^ and $FFFFFF)) * 16777619;
        Inc(P);
      end;
    end;
    if FileName <> '' then
    begin
      SDL_SaveBMP(Surf, PAnsiChar(AnsiString(FileName)));
      Log.Add('  wrote ' + FileName);
    end;
  finally
    Lines.Free;
    Target.Free;
    SDL_FreeSurface(Surf);
  end;
end;

function SelfTestLang(Log: TStrings): Integer;
var
  Bad: Integer;

  procedure Want(Cond: Boolean; const Msg: string);
  begin
    if not Cond then
    begin
      Log.Add('  FAIL: ' + Msg);
      Inc(Bad);
    end;
  end;

  { --- 1. the unit rule, by hand -------------------------------------- }
  procedure CheckUnits;
  begin
    Want(UnitsText(RevealUnitsOf('ab\ncd')) = '[ab][\n][cd]', 'ab\ncd');
    Want(UnitsText(RevealUnitsOf('abc')) = '[ab][c]', 'odd narrow tail');
    Want(Length(RevealUnitsOf('あいう')) = 3, 'three kana are three units');
    Want(UnitsText(RevealUnitsOf('aあ')) = '[a][あ]',
         'a narrow character before a wide one stands alone');
    Want(Length(RevealUnitsOf('éa')) = 1, 'an accented letter pairs like any');
    Want(TextColumns('【ア】x') = 7, 'columns: three wide and one narrow');
    Want(TextColumns('Fire') = 4, 'columns: ASCII');
  end;

  { --- 2. the unit rule against the original's, on every English record }
  procedure CheckAgainstBytePairs;
  var
    Found: TSearchRec;
    Lines, Pages: TStringList;
    Records, PageCount, Mismatch, L, P: Integer;
    First: string;
  begin
    Records := 0;
    PageCount := 0;
    Mismatch := 0;
    First := '';
    Lines := TStringList.Create;
    try
      if FindFirst(GameDirArg + 'data' + PathDelim + 'tk*.dat', faAnyFile,
                   Found) = 0 then
      try
        repeat
          Lines.LoadFromFile(GameDirArg + 'data' + PathDelim + Found.Name);
          for L := 0 to Lines.Count - 1 do
          begin
            if Lines[L] = '' then
              Continue;
            Inc(Records);
            Pages := PagesOf(Lines[L]);
            try
              for P := 0 to Pages.Count - 1 do
              begin
                Inc(PageCount);
                if not SameUnits(RevealUnitsOf(Pages[P]),
                                 BytePairs(Pages[P])) then
                begin
                  Inc(Mismatch);
                  if First = '' then
                    First := Format('%s line %d: %s', [Found.Name, L,
                      UnitsText(RevealUnitsOf(Pages[P]))]);
                end;
              end;
            finally
              Pages.Free;
            end;
          end;
        until FindNext(Found) <> 0;
      finally
        FindClose(Found);
      end;
    finally
      Lines.Free;
    end;
    Log.Add(Format('reveal units: %d English records, %d pages, %d differ '
      + 'from the two-byte rule', [Records, PageCount, Mismatch]));
    Want(Records > 0, 'no English dialogue found');
    Want(Mismatch = 0, 'reveal units differ from the original''s: ' + First);
  end;

  { --- 3. the PO reader ----------------------------------------------- }
  procedure CheckReader;
  var
    Po: TPoFile;
  begin
    Po := TPoFile.Create;
    try
      Po.LoadFromString(PO_SAMPLE);
      Want(Po.Count = 3, Format('sample has 3 entries, read %d', [Po.Count]));
      Want(Po.Header('Language') = 'xx', 'header Language');
      Want(Po.Header('X-Akuji-Font-Size') = '14', 'header font size');
      Want(Po.Lookup('tk001:0') = 'Erste Zeile'#10'zweite \k',
           'multi-line msgstr with escapes');
      Want((Po.IndexOfContext('tk001:0') >= 0)
           and (Po.Entries[Po.IndexOfContext('tk001:0')].Id
                = 'First line'#10'second "quoted" \k'), 'multi-line msgid');
      Want(Po.Lookup('tk001:1') = '', 'a fuzzy entry is not used');
      Want(Po.Lookup('tk001:2') = '', 'an empty msgstr is not used');
      Want(Po.Lookup('nope') = '', 'an unknown context');
      Want(PoToDialogue(Po.Lookup('tk001:0')) = 'Erste Zeile\nzweite \k',
           'line breaks become \n');
    finally
      Po.Free;
    end;
  end;

  { --- 4. the template round-trips ------------------------------------ }
  procedure CheckTemplate(out Template: TPoFile);
  var
    E: TTemplateEntries;
    I, Wrong: Integer;
  begin
    E := TemplateEntries(GameDirArg);
    Template := TPoFile.Create;
    Template.LoadFromString(TemplateText(GameDirArg));
    Log.Add(Format('template: %d entries', [Length(E)]));
    Want(Template.Count = Length(E), Format('template reads back %d of %d',
      [Template.Count, Length(E)]));
    Wrong := 0;
    for I := 0 to High(E) do
      if (Template.IndexOfContext(E[I].Context) < 0)
         or (Template.Entries[Template.IndexOfContext(E[I].Context)].Id
             <> E[I].Id) then
      begin
        if Wrong = 0 then
          Log.Add('  first: ' + E[I].Context);
        Inc(Wrong);
      end;
    Want(Wrong = 0, Format('%d template entries do not read back', [Wrong]));

    { The committed template is what the game would write now - apart from
      the version in its header, which moves with every release. }
    Want(WithoutVersion(FileText(GameDirArg + 'lang' + PathDelim + 'akuji.pot'))
         = WithoutVersion(TemplateText(GameDirArg)),
         'lang/akuji.pot is out of date - run akuji --write-pot <game dir>');
  end;

  { --- 5. a language file --------------------------------------------- }
  procedure CheckLanguage(const Code: string; Template: TPoFile);
  var
    Po: TPoFile;
    I, K, Translated, Fuzzy, Stale, Len, Lines, W, Widest: Integer;
    E, T: TPoEntry;
    S, Line, Missing, Word1, Word2: string;
    Pages, BoxLines: TStringList;
    Cp: Cardinal;
    Seen: TStringList;
    Gap1, Start2, Need2: Integer;
    Sum: LongWord;
    AsEnglish, Room: Integer;
  begin
    Log.Add('');
    Log.Add(Format('lang/%s.po:', [Code]));
    Po := TPoFile.Create;
    Seen := TStringList.Create;
    Seen.Sorted := True;
    Seen.Duplicates := dupIgnore;
    try
      Po.LoadFromFile(GameDirArg + 'lang' + PathDelim + Code + '.po');
      if not LoadLanguage(GameDirArg + 'lang', Code) then
      begin
        Want(False, 'LoadLanguage refused ' + Code);
        Exit;
      end;
      if LanguageFontFile = '' then
        Log.Add('  default font')
      else
        Log.Add(Format('  font %s at %s px', [LanguageFontFile,
          Po.Header('X-Akuji-Font-Size')]));
      if LanguageFontFile <> '' then
        Want(FileExists(GameDirArg + 'fonts' + PathDelim + LanguageFontFile),
             'font file missing: fonts/' + LanguageFontFile);

      Translated := 0;
      AsEnglish := 0;
      Fuzzy := 0;
      Stale := 0;
      Widest := 0;
      Missing := '';
      for I := 0 to Po.Count - 1 do
      begin
        E := Po.Entries[I];
        if E.Fuzzy then
          Inc(Fuzzy);
        K := Template.IndexOfContext(E.Context);
        if K < 0 then
        begin
          Inc(Stale);
          if Stale <= 3 then
            Log.Add('  stale: ' + E.Context);
          Continue;
        end;
        T := Template.Entries[K];
        if (E.Str = '') or E.Fuzzy then
          Continue;
        Inc(Translated);
        { The template's msgid is the built-in English, proven by the round
          trip above, so an equal msgstr shows exactly what no file would. }
        if E.Str = T.Id then
          Inc(AsEnglish);

        Want(IsValidUtf8(E.Str), E.Context + ' is not valid UTF-8');

        { Every character, in the font that will draw it. }
        Len := 0;
        K := 1;
        while K <= Length(E.Str) do
        begin
          Cp := Utf8CodePoint(E.Str, K, Len);
          if (Cp >= 32) and not OutlinedFontHasGlyph(Cp, OUTLINED_FONT_FACE)
             and (Seen.IndexOf(Copy(E.Str, K, Len)) < 0) then
          begin
            Seen.Add(Copy(E.Str, K, Len));
            Missing := Missing + Copy(E.Str, K, Len);
          end;
          Inc(K, Len);
        end;

        if Copy(E.Context, 1, 2) = 'tk' then
        begin
          S := PoToDialogue(E.Str);
          { The codes that steer the game, kept. }
          Want(Terminator(S) = Terminator(PoToDialogue(T.Id)),
               Format('%s ends with %s, the English with %s',
                 [E.Context, Terminator(S), Terminator(PoToDialogue(T.Id))]));
          Want((Pos('\w', S) > 0) = (Pos('\w', PoToDialogue(T.Id)) > 0),
               E.Context + ' adds or drops the Yes/No prompt (\w)');
          { And inside the box. }
          Pages := PagesOf(S);
          BoxLines := TStringList.Create;
          try
            for K := 0 to Pages.Count - 1 do
            begin
              BoxLines.Text := StringReplace(Pages[K], '\n', #10,
                                             [rfReplaceAll]);
              Lines := BoxLines.Count;
              if Pages.Objects[K] <> nil then
                Room := PROMPT_LINE
              else
                Room := BOX_LINES;
              Want(Lines <= Room, Format('%s page %d has %d lines and room '
                + 'for %d - start another box with \k', [E.Context, K + 1,
                Lines, Room]));
              for Line in BoxLines do
              begin
                W := OutlinedTextWidth(Line, OUTLINED_FONT_FACE);
                if W > Widest then
                  Widest := W;
                Want(W <= BOX_TEXT_WIDTH, Format('%s: "%s" is %d px, the box '
                  + 'holds %d', [E.Context, Line, W, BOX_TEXT_WIDTH]));
              end;
            end;
          finally
            BoxLines.Free;
            Pages.Free;
          end;
        end;

        if E.Context = 'powerup.found' then
          Want(Pos('%s', E.Str) > 0, 'powerup.found has no %s for the name');

        if E.Context = 'prompt.yesno' then
        begin
          { The two words, found as the first two runs of anything but
            spaces (ASCII or ideographic). }
          S := StringReplace(E.Str, #$E3#$80#$80, #1#1#1, [rfReplaceAll]);
          K := 1;
          while (K <= Length(S)) and (S[K] in [' ', #1]) do Inc(K);
          Word1 := Copy(E.Str, 1, K - 1);
          while (K <= Length(S)) and not (S[K] in [' ', #1]) do Inc(K);
          while (K <= Length(S)) and (S[K] in [' ', #1]) do Inc(K);
          Word2 := Copy(E.Str, 1, K - 1);
          Gap1 := MB_PROMPT_TEXT_X
                  + OutlinedTextWidth(Word1, OUTLINED_FONT_FACE)
                  - (MB_HAND_ICON_X + MB_ICON_SIZE);
          Start2 := MB_PROMPT_TEXT_X
                    + OutlinedTextWidth(Word2, OUTLINED_FONT_FACE);
          Need2 := MB_HAND_ICON_X + MB_HAND_ICON_STEP + MB_ICON_SIZE;
          Log.Add(Format('  prompt: first word %d px clear of the hand, '
            + 'second starts at x=%d, the hand ends at %d',
            [Gap1, Start2, Need2]));
          Want(Gap1 >= 1, 'the hand touches the first answer');
          Want(Start2 >= Need2, 'the hand covers the second answer');
        end;
      end;

      Sum := Preview(PreviewFile(Code), Log);
      Log.Add(Format('  preview checksum %.8x', [Sum]));
      if Code = 'ja' then
        Want(Sum = JA_PREVIEW, Format('the Japanese preview is %.8x, pinned '
          + '%.8x - look at it (--selftest-lang <dir> preview.bmp)',
          [Sum, JA_PREVIEW]));
      Log.Add(Format('  %d of %d entries translated (%d identical to the '
        + 'built-in English), %d fuzzy, %d stale; widest dialogue line %d of '
        + '%d px', [Translated, Template.Count, AsEnglish, Fuzzy, Stale,
        Widest, BOX_TEXT_WIDTH]));
      Want(Stale = 0, Format('%d entries the game never looks up', [Stale]));
      Want(Missing = '', 'not in the font: ' + Missing);
    finally
      Seen.Free;
      Po.Free;
      UnloadLanguage;
    end;
  end;

var
  Template: TPoFile;
  Found: TSearchRec;
begin
  Bad := 0;
  SetFontDirectory(GameDirArg);
  Log.Add('game dir: ' + GameDirArg);
  CheckUnits;
  CheckAgainstBytePairs;
  CheckReader;
  CheckTemplate(Template);
  try
    if FindFirst(GameDirArg + 'lang' + PathDelim + '*.po', faAnyFile,
                 Found) = 0 then
    try
      repeat
        CheckLanguage(ChangeFileExt(Found.Name, ''), Template);
      until FindNext(Found) <> 0;
    finally
      FindClose(Found);
    end;
  finally
    Template.Free;
  end;

  Log.Add('');
  if Bad = 0 then
  begin
    Log.Add('OK - English reveals as it did, the template round-trips, and '
      + 'every language fits');
    Result := 0;
  end
  else
  begin
    Log.Add(Format('FAILED: %d check(s)', [Bad]));
    Result := 1;
  end;
end;

function WritePot(Log: TStrings): Integer;
var
  FileName: string;
  Stream: TStringStream;
begin
  if ParamStr(3) <> '' then
    FileName := ParamStr(3)
  else
    FileName := GameDirArg + 'lang' + PathDelim + 'akuji.pot';
  ForceDirectories(ExtractFileDir(FileName));
  Stream := TStringStream.Create(TemplateText(GameDirArg));
  try
    Stream.SaveToFile(FileName);
  finally
    Stream.Free;
  end;
  Log.Add('wrote ' + FileName);
  Result := 0;
end;

end.
