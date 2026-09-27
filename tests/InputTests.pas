{ --selftest-input : the key bindings.

  DDIDComponent used to carry a hard-wired case statement from virtual key to
  logical button. It now carries bindings that a file can move, which is a much
  larger surface: the same ten keys have to keep doing the same ten things by
  default, no key may end up driving two actions, and a system.dat written by
  the ORIGINAL - which stored device button indices, not keycodes - has to load
  as the keys it named rather than as whatever those numbers mean now.

  None of that needs a window: the keyboard handlers maintain the pressed set
  themselves, and only the gamepad half wants Update. So this runs headless. }

unit InputTests;

{$MODE DELPHI}{$H+}

interface

uses
  Classes, SysUtils;

function SelfTestInput(Log: TStrings): Integer;

implementation

uses
  Math, Types, SDL2, DDIDComponent, GameState, SoundTable, Title, Translation,
  RenderTarget, GameFont, GameColors;

type
  { One row of the table DDIDComponent had before bindings existed, recovered
    from the version this replaced. It was written in Windows virtual keys
    then, because the keyboard came from the LCL; it is the same thirteen
    keys, said in the keycodes SDL now delivers. S and D are absent on
    purpose: they set abAux2 and abAux3, which nothing anywhere read. }
  TOldRow = record
    Key: TSDL_KeyCode;
    Button: TAkujiButton;
  end;

const
  OLD_TABLE: array[0..12] of TOldRow = (
    (Key: SDLK_UP;    Button: abUp),
    (Key: SDLK_KP_8;  Button: abUp),
    (Key: SDLK_DOWN;  Button: abDown),
    (Key: SDLK_KP_2;  Button: abDown),
    (Key: SDLK_LEFT;  Button: abLeft),
    (Key: SDLK_KP_4;  Button: abLeft),
    (Key: SDLK_RIGHT; Button: abRight),
    (Key: SDLK_KP_6;  Button: abRight),
    (Key: SDLK_z;     Button: abJump),
    (Key: SDLK_SPACE; Button: abJump),
    (Key: SDLK_x;     Button: abFire),
    (Key: SDLK_c;     Button: abPause),
    (Key: SDLK_a;     Button: abAux));

  { Every key the old translation could name, plus a few it could not, which
    are there to prove they do nothing. This is what the sweep over all 256
    virtual keys became when the virtual keys went: the same question - does
    any key press something the old table did not - asked of the keys that
    exist rather than of a number space. }
  PROBE_KEYS: array[0..47] of TSDL_KeyCode = (
    SDLK_a, SDLK_b, SDLK_c, SDLK_d, SDLK_e, SDLK_f, SDLK_g, SDLK_h,
    SDLK_i, SDLK_j, SDLK_k, SDLK_l, SDLK_m, SDLK_n, SDLK_o, SDLK_p,
    SDLK_q, SDLK_r, SDLK_s, SDLK_t, SDLK_u, SDLK_v, SDLK_w, SDLK_x,
    SDLK_y, SDLK_z,
    SDLK_0, SDLK_1, SDLK_2, SDLK_3, SDLK_4,
    SDLK_UP, SDLK_DOWN, SDLK_LEFT, SDLK_RIGHT,
    SDLK_KP_0, SDLK_KP_2, SDLK_KP_4, SDLK_KP_6, SDLK_KP_8,
    SDLK_SPACE, SDLK_RETURN, SDLK_ESCAPE, SDLK_TAB, SDLK_BACKSPACE,
    SDLK_LSHIFT, SDLK_LCTRL,
    { One the old translation had no name for at all. }
    SDLK_F1);

  BUTTON_NAMES: array[TAkujiButton] of string =
    ('UP', 'DOWN', 'LEFT', 'RIGHT', 'JUMP', 'FIRE', 'PAUSE', 'AUX');

type
  { Stands in for the form while the options screen is driven with no window.
    It records which row was offered a key and what sound came back, which is
    all the screen contributes: the rule itself is the component's. }
  TFakeHost = class
  public
    Offers: Integer;
    LastRow: Integer;
    Sounds: Integer;
    LastSound: Integer;
    Accept: Boolean;
    Language: string;
    Languages: Integer;
    Held: Boolean;
    function KeyHeld: Boolean;
    constructor Create;
    procedure ChooseLanguage(const Code: string);
    function BindKey(Row: Integer): Boolean;
    function KeyName(Row: Integer): string;
    procedure Sound(Index: Integer);
  end;

constructor TFakeHost.Create;
begin
  inherited Create;
  LastRow := -1;
  LastSound := -1;
end;

function TFakeHost.BindKey(Row: Integer): Boolean;
begin
  Inc(Offers);
  LastRow := Row;
  Result := Accept;
end;

function TFakeHost.KeyName(Row: Integer): string;
begin
  Result := Format('R%d', [Row]);
end;

function TFakeHost.KeyHeld: Boolean;
begin
  Result := Held;
end;

procedure TFakeHost.ChooseLanguage(const Code: string);
begin
  Inc(Languages);
  Language := Code;
end;

procedure TFakeHost.Sound(Index: Integer);
begin
  Inc(Sounds);
  LastSound := Index;
end;

type
  { Remembers every glyph drawn onto it and draws nothing, so a test can
    ask exactly what a screen put where. }
  TGlyphRecorder = class(TRenderTarget)
  protected
    function GetWidth: Integer; override;
    function GetHeight: Integer; override;
  public
    Glyphs: TStringList;   { 'x,y,srcLeft,srcTop' per keyed blit }
    constructor Create;
    destructor Destroy; override;
    procedure Fill(const R: TRect; AColor: TColor); override;
    procedure BlitRect(Src: TRenderImage; const SrcRect: TRect;
                       X, Y: Integer); override;
    procedure BlitRectKeyed(Src: TRenderImage; const SrcRect: TRect;
                            X, Y: Integer); override;
    procedure DrawImage(Src: TRenderImage; X, Y: Integer); override;
    procedure DrawOutlinedText(X, Y: Integer; const S: string;
                               Outline, Fill: TColor;
                               Size: Integer); override;
    { The glyphs on one text row, at or right of X, in drawing order. }
    function Row(Y, FromX: Integer): string;
  end;

constructor TGlyphRecorder.Create;
begin
  inherited Create;
  Glyphs := TStringList.Create;
end;

destructor TGlyphRecorder.Destroy;
begin
  Glyphs.Free;
  inherited Destroy;
end;

function TGlyphRecorder.GetWidth: Integer;  begin Result := 320; end;
function TGlyphRecorder.GetHeight: Integer; begin Result := 240; end;
procedure TGlyphRecorder.Fill(const R: TRect; AColor: TColor); begin end;
procedure TGlyphRecorder.BlitRect(Src: TRenderImage; const SrcRect: TRect;
  X, Y: Integer); begin end;
procedure TGlyphRecorder.DrawImage(Src: TRenderImage; X, Y: Integer); begin end;
procedure TGlyphRecorder.DrawOutlinedText(X, Y: Integer; const S: string;
  Outline, Fill: TColor; Size: Integer); begin end;

procedure TGlyphRecorder.BlitRectKeyed(Src: TRenderImage; const SrcRect: TRect;
  X, Y: Integer);
begin
  Glyphs.Add(Format('%d,%d,%d,%d', [X, Y, SrcRect.Left, SrcRect.Top]));
end;

function TGlyphRecorder.Row(Y, FromX: Integer): string;
var
  I: Integer;
  Parts: TStringArray;
begin
  Result := '';
  for I := 0 to Glyphs.Count - 1 do
  begin
    Parts := Glyphs[I].Split([',']);
    if (StrToInt(Parts[1]) = Y) and (StrToInt(Parts[0]) >= FromX) then
      Result := Result + Glyphs[I] + ';';
  end;
end;

function SetText(S: TAkujiButtons): string;
var
  B: TAkujiButton;
begin
  Result := '';
  for B := Low(TAkujiButton) to High(TAkujiButton) do
    if B in S then
    begin
      if Result <> '' then
        Result := Result + '+';
      Result := Result + BUTTON_NAMES[B];
    end;
  if Result = '' then
    Result := '-';
end;

function SelfTestInput(Log: TStrings): Integer;
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

  { Every key held by more than one action, which is the invariant the whole
    swap rule exists to keep. }
  function Duplicates(D: TDDIDEX): Integer;
  var
    A, B: TAkujiButton;

    function Holds(Which: TAkujiButton; Key: TSDL_KeyCode): Boolean;
    begin
      Result := (Key <> SDLK_UNKNOWN) and
                ((D.Bindings[Which].Primary = Key) or
                 (D.Bindings[Which].Alternate = Key));
    end;

  begin
    Result := 0;
    for A := Low(TAkujiButton) to High(TAkujiButton) do
      for B := Low(TAkujiButton) to High(TAkujiButton) do
        if B > A then
        begin
          if Holds(B, D.Bindings[A].Primary) then
          begin
            Log.Add(Format('  %s and %s both hold %s',
              [BUTTON_NAMES[A], BUTTON_NAMES[B],
               D.KeyNameOf(D.Bindings[A].Primary)]));
            Inc(Result);
          end;
          if Holds(B, D.Bindings[A].Alternate) then
          begin
            Log.Add(Format('  %s and %s both hold %s',
              [BUTTON_NAMES[A], BUTTON_NAMES[B],
               D.KeyNameOf(D.Bindings[A].Alternate)]));
            Inc(Result);
          end;
        end;
  end;

  { What one key presses, pressed and released in isolation. }
  function Press(D: TDDIDEX; Key: TSDL_KeyCode): TAkujiButtons;
  begin
    D.KeyDown(Key);
    Result := D.Down;
    D.KeyUp(Key);
  end;

var
  D, E: TDDIDEX;
  Probe: TSDL_KeyCode;
  I, J, Dups: Integer;
  Wanted, Got: TAkujiButtons;
  Map, Back: array[0..3] of Integer;
  K: TSDL_KeyCode;
  Frames: Integer;
  Host: TFakeHost;
  Rows, Scroll, Cursor, Bad0: Integer;
  Langs: TArray<TLanguageInfo>;
  Sheet: TRenderImage;
  Font: TGameFont;
  Rec, Alone: TGlyphRecorder;
  Screen: TTitleScreen;
  Pads, Found: Integer;
  B: TAkujiButton;
  Checked, Pressing: Integer;
begin
  Result := 0;
  Bad := 0;

  { 1. The defaults must be the old table, key for key. Sweeping every key the
       old translation could name, rather than the thirteen in the table, is
       the point: a binding that reaches a key the old one did not is just as
       wrong as one that misses. }
  Log.Add('default bindings vs the pre-binding table, every key it could name:');
  D := TDDIDEX.Create(nil);
  try
    Checked := 0;
    Pressing := 0;
    for J := Low(PROBE_KEYS) to High(PROBE_KEYS) do
    begin
      Probe := PROBE_KEYS[J];
      Wanted := [];
      for I := Low(OLD_TABLE) to High(OLD_TABLE) do
        if OLD_TABLE[I].Key = Probe then
          Wanted := [OLD_TABLE[I].Button];
      Got := Press(D, Probe);
      Inc(Checked);
      if Wanted <> [] then
        Inc(Pressing);
      if Got <> Wanted then
      begin
        Log.Add(Format('  %s: was %s, now %s',
          [D.KeyNameOf(Probe), SetText(Wanted), SetText(Got)]));
        Inc(Bad);
      end;
      Want(D.Down = [],
        Format('%s left something held after release', [D.KeyNameOf(Probe)]));
    end;
    Log.Add(Format('  %d keys checked, %d of them press something',
      [Checked, Pressing]));
    Want(Pressing = Length(OLD_TABLE),
      'the sweep does not reach every key the old table named');

    { 2. Holding two at once is a set, not a last-one-wins. }
    D.KeyDown(SDLK_LEFT);
    D.KeyDown(SDLK_z);
    Want(D.Down = [abLeft, abJump], 'LEFT+Z does not hold both');
    D.KeyUp(SDLK_LEFT);
    Want(D.Down = [abJump], 'releasing LEFT did not leave Z held');
    D.KeyUp(SDLK_z);
    Want(D.Down = [], 'nothing should be held');

    Want(Duplicates(D) = 0, 'the defaults put one key on two actions');
  finally
    D.Free;
  end;

  { 3. A system.dat written by the original. Its four ints are device button
       indices into the twelve names its options screen could show, and the
       shipped file holds 0,1,2,3 - Z, X, C, A - which is exactly the default. }
  Log.Add('');
  Log.Add('migration of the original''s KeyMap:');
  D := TDDIDEX.Create(nil);
  try
    Map[0] := 0; Map[1] := 1; Map[2] := 2; Map[3] := 3;
    D.LoadKeyMap(Map);
    Want(D.Bindings[abJump].Primary = SDLK_z, 'KeyMap 0 is not Z');
    Want(D.Bindings[abFire].Primary = SDLK_x, 'KeyMap 1 is not X');
    Want(D.Bindings[abPause].Primary = SDLK_c, 'KeyMap 2 is not C');
    Want(D.Bindings[abAux].Primary = SDLK_a, 'KeyMap 3 is not A');
    Want(D.Bindings[abJump].Alternate = SDLK_SPACE,
      'loading a KeyMap dropped the space bar');
    Want(Duplicates(D) = 0, 'a legacy load put one key on two actions');

    { The names the options screen now draws. It used to index a table of
      twelve strings; it asks SDL instead, so what SDL answers is what the
      player reads - and the bitmap font has no lowercase. }
    Log.Add(Format('  names: %s / %s / %s / %s',
      [D.KeyNameOf(D.Bindings[abJump].Primary),
       D.KeyNameOf(D.Bindings[abFire].Primary),
       D.KeyNameOf(D.Bindings[abPause].Primary),
       D.KeyNameOf(D.Bindings[abAux].Primary)]));
    Want(D.KeyNameOf(D.Bindings[abJump].Primary) = 'Z', 'JUMP is not named Z');
    Want(D.KeyNameOf(D.Bindings[abFire].Primary) = 'X', 'FIRE is not named X');
    Want(D.KeyNameOf(D.Bindings[abPause].Primary) = 'C', 'PAUSE is not named C');
    Want(D.KeyNameOf(SDLK_UNKNOWN) = 'NONE', 'an unbound key is not named NONE');

    { The whole twelve, so a shifted table would show up rather than only the
      first four entries agreeing. }
    for I := Low(LEGACY_KEYS) to High(LEGACY_KEYS) do
    begin
      E := TDDIDEX.Create(nil);
      try
        { Only the first entry, so the other three cannot trade with it and
          what is measured is the index rather than the swap rule. }
        Map[0] := I; Map[1] := -1; Map[2] := -1; Map[3] := -1;
        E.LoadKeyMap(Map);
        Want(E.Bindings[abJump].Primary = LEGACY_KEYS[I],
          Format('legacy index %d did not load as %s',
            [I, E.KeyNameOf(LEGACY_KEYS[I])]));
        Want(Duplicates(E) = 0,
          Format('legacy index %d left a key on two actions', [I]));
      finally
        E.Free;
      end;
    end;
    Log.Add(Format('  %d legacy indices load as their key',
      [Length(LEGACY_KEYS)]));

    { 4. And out again in this port's own form, which must survive a round
         trip through the file. }
    D.StoreKeyMap(Back);
    Log.Add(Format('  stored as %d, %d, %d, %d',
      [Back[0], Back[1], Back[2], Back[3]]));
    Want(Back[0] = KEYMAP_TAG + Ord('z'),
      'Z did not store as a tagged keycode');
    E := TDDIDEX.Create(nil);
    try
      E.LoadKeyMap(Back);
      for I := Low(AKUJI_MAPPED) to High(AKUJI_MAPPED) do
        Want(E.Bindings[AKUJI_MAPPED[I]].Primary =
             D.Bindings[AKUJI_MAPPED[I]].Primary,
          Format('round trip moved %s', [BUTTON_NAMES[AKUJI_MAPPED[I]]]));
    finally
      E.Free;
    end;
  finally
    D.Free;
  end;

  { 5. Nonsense in the file leaves the defaults alone rather than unbinding.
       999 is past the legacy table, -5 is impossible, 12 is one past its end,
       and a bare tag is SDLK_UNKNOWN. }
  Log.Add('');
  Log.Add('a corrupt KeyMap:');
  D := TDDIDEX.Create(nil);
  try
    Map[0] := 999; Map[1] := -5; Map[2] := 12; Map[3] := KEYMAP_TAG;
    D.LoadKeyMap(Map);
    for B := Low(TAkujiButton) to High(TAkujiButton) do
      Want(D.Bindings[B].Primary = DefaultBinding(B).Primary,
        Format('%s moved off its default', [BUTTON_NAMES[B]]));
    Want(Press(D, SDLK_z) = [abJump], 'Z stopped jumping');
    Log.Add('  four unreadable entries, four defaults kept');
  finally
    D.Free;
  end;

  { 6. Rebinding. A free key is taken; a key another action holds is traded
       for, so that action is never left without one; rebinding to what is
       already there does nothing, which is what makes holding a key down
       during a rebind harmless. }
  Log.Add('');
  Log.Add('rebinding:');
  D := TDDIDEX.Create(nil);
  try
    Want(D.BindKey(abJump, SDLK_s), 'a free key was refused');
    Want(Press(D, SDLK_s) = [abJump], 'S does not jump');
    Want(Press(D, SDLK_z) = [], 'Z still jumps after being replaced');
    Want(Press(D, SDLK_SPACE) = [abJump], 'the alternate was lost');
    Want(Press(D, SDLK_x) = [abFire], 'FIRE moved');
    Want(Duplicates(D) = 0, 'binding a free key made a duplicate');

    { Trade: FIRE takes S, which JUMP holds, and JUMP gets X back. }
    Want(D.BindKey(abFire, SDLK_s), 'a held key was refused');
    Want(Press(D, SDLK_s) = [abFire], 'S does not fire');
    Want(Press(D, SDLK_x) = [abJump], 'JUMP was left without the traded key');
    Want(Duplicates(D) = 0, 'the trade made a duplicate');

    { Trading against an ALTERNATE moves the alternate, not the primary. }
    Want(D.BindKey(abPause, SDLK_SPACE), 'the space bar was refused');
    Want(Press(D, SDLK_SPACE) = [abPause], 'space does not pause');
    Want(Press(D, SDLK_x) = [abJump],
      'JUMP lost its primary to an alternate swap');
    Want(D.Bindings[abJump].Alternate = SDLK_c,
      'PAUSE''s key did not land on the alternate it traded with');
    Want(Duplicates(D) = 0, 'the alternate trade made a duplicate');

    { Held down for many frames: the same bind over and over is a fixed point. }
    for J := 1 to 60 do
      Want(D.BindKey(abPause, SDLK_SPACE), 'a repeat bind was refused');
    Want(Press(D, SDLK_SPACE) = [abPause], 'a repeated bind drifted');
    Want(Press(D, SDLK_x) = [abJump], 'a repeated bind moved another action');
    Want(Duplicates(D) = 0, 'a repeated bind made a duplicate');

    Want(not D.BindKey(abJump, SDLK_UNKNOWN), 'no key at all was accepted');

    { Every action in turn onto one key: seven trades, still no duplicate. }
    Dups := 0;
    for B := Low(TAkujiButton) to High(TAkujiButton) do
    begin
      D.BindKey(B, SDLK_q);
      Want(Press(D, SDLK_q) = [B],
        Format('Q does not drive %s after being bound to it',
          [BUTTON_NAMES[B]]));
      Inc(Dups, Duplicates(D));
    end;
    Want(Dups = 0, 'passing one key around the eight actions made a duplicate');
    Log.Add(Format('  %d actions took the same key in turn, %d duplicates',
      [Ord(High(TAkujiButton)) + 1, Dups]));
  finally
    D.Free;
  end;

  { 7. What the options screen does with those rows. It offers whatever key is
       held to the selected row, every frame, and the component decides. }
  Log.Add('');
  Log.Add('the options screen''s three key rows:');
  D := TDDIDEX.Create(nil);
  try
    { Nothing held: nothing to offer. }
    Want(not D.AnyKeyDown(K), 'a key is reported held before anything is pressed');

    { An UNBOUND key is what rebinding is for, so it has to be visible even
      though it drives nothing - V is in no default binding. }
    D.KeyDown(SDLK_v);
    Want(D.AnyKeyDown(K) and (K = SDLK_v), 'an unbound key is not offered');
    Want(D.Down = [], 'an unbound key pressed something');
    Want(D.BindAction(abJump, K), 'the JUMP row refused a free key');
    D.KeyUp(SDLK_v);
    Want(not D.AnyKeyDown(K), 'the key is still held after release');
    Want(Press(D, SDLK_v) = [abJump], 'V does not jump');

    { Offered again while still held: no change, so the screen stays silent. }
    D.KeyDown(SDLK_v);
    Want(not D.BindAction(abJump, SDLK_v), 'a key already on the row rebound');
    Frames := 0;
    for J := 1 to 60 do
      if D.BindAction(abJump, SDLK_v) then
        Inc(Frames);
    Want(Frames = 0, 'holding the key down rebinds every frame');
    D.KeyUp(SDLK_v);

    { The cursor keys are the refusal that matters: taking one would trade the
      arrow away and strand the player on the row. }
    for B := Low(TAkujiButton) to High(TAkujiButton) do
      if B in AKUJI_DIRECTIONS then
      begin
        Want(not D.BindAction(abJump, D.Bindings[B].Primary),
          Format('the JUMP row took %s, which drives %s',
            [D.KeyNameOf(D.Bindings[B].Primary), BUTTON_NAMES[B]]));
        Want(not D.BindAction(abJump, D.Bindings[B].Alternate),
          Format('the JUMP row took the alternate driving %s',
            [BUTTON_NAMES[B]]));
      end;
    Want(Press(D, SDLK_DOWN) = [abDown], 'the down arrow stopped moving the cursor');
    Want(Press(D, SDLK_v) = [abJump], 'a refused bind moved the row anyway');

    { The rows are the three the screen shows, and a direction has no row. }
    Want(not D.BindAction(abUp, SDLK_v), 'a direction was bound from a row');

    { A key held ACROSS a rebind must not stay stuck. X drives FIRE on the way
      down and JUMP on the way up, so the release has to clear both. }
    D.KeyDown(SDLK_x);
    Want(D.Down = [abFire], 'X does not fire');
    Want(D.BindAction(abJump, SDLK_x), 'the JUMP row refused a key FIRE held');
    D.KeyUp(SDLK_x);
    Want(D.Down = [], 'a key held across a rebind stayed down: ' + SetText(D.Down));
    Want(Duplicates(D) = 0, 'the row''s trade made a duplicate');
    Log.Add('  offered, refused and traded with nothing left held');
  finally
    D.Free;
  end;

  { 8. The screen's side of it, driven with no window: which rows offer a key,
       with what row number, and whether the sound follows the answer. }
  Log.Add('');
  Log.Add('the options screen, driven row by row:');
  Host := TFakeHost.Create;
  Screen := TTitleScreen.Create;
  try
    Screen.OnBindKey := Host.BindKey;
    Screen.OnKeyName := Host.KeyName;
    Screen.OnSound := Host.Sound;
    Screen.OnKeyHeld := Host.KeyHeld;
    TitleSubMode := TSM_OPTIONS;
    Host.Accept := True;

    { No row of the options screen binds a key any more. }
    for I := 0 to Ord(High(TOptionRow)) do
    begin
      MenuIndex := I;
      Host.Offers := 0;
      Screen.Update(0, 0, False);
      Want(Host.Offers = 0,
        Format('options row %d offered a key and should not have', [I]));
    end;

    { CONTROLS opens its page with SND_OK, the cursor on JUMP. }
    MenuIndex := Ord(orControls);
    Host.Sounds := 0;
    Host.Held := True;       { the key that confirmed is still down }
    Screen.Update(0, 0, True);
    Want((TitleSubMode = TSM_CONTROLS) and (MenuIndex = 0)
         and (Host.LastSound = SND_OK),
      'CONTROLS did not open its page on JUMP with SND_OK');

    { Nothing binds while that key is held - it would become JUMP - nor on
      the frame everything is let go; from the next frame the rows bind. }
    Host.Offers := 0;
    Screen.Update(0, 0, False);
    Screen.Update(0, 0, False);
    Want(Host.Offers = 0, 'the key that opened CONTROLS was offered to JUMP');
    Host.Held := False;
    Screen.Update(0, 0, False);
    Want(Host.Offers = 0, 'a key was offered on the frame binding armed');

    for I := 0 to Ord(High(TControlRow)) do
    begin
      MenuIndex := I;
      Host.Offers := 0;
      Host.LastRow := -1;
      Host.Sounds := 0;
      Screen.Update(0, 0, False);
      if I < CTL_ROW_EXIT then
      begin
        Want(Host.Offers = 1,
          Format('row %d offered %d times, not once', [I, Host.Offers]));
        Want(Host.LastRow = I,
          Format('row %d offered as row %d', [I, Host.LastRow]));
        Want((Host.Sounds = 1) and (Host.LastSound = SND_OK),
          Format('row %d did not sound once on a bind', [I]));
      end
      else
        Want(Host.Offers = 0, 'CONTROLS'' EXIT offered a key');
    end;
    Log.Add(Format('  %d options rows bind nothing; CONTROLS'' %d rows, 3 '
      + 'of them bind once the confirming key is let go',
      [Ord(High(TOptionRow)) + 1, Ord(High(TControlRow)) + 1]));

    { Refused: the row is still offered the key, and stays silent. }
    Host.Accept := False;
    MenuIndex := Ord(crKey0);
    Host.Offers := 0;
    Host.Sounds := 0;
    Screen.Update(0, 0, False);
    Want(Host.Offers = 1, 'a refused row was not offered the key');
    Want(Host.Sounds = 0, 'a refused bind still played a sound');

    { What the page draws in its value column is the three key names and
      nothing else - every glyph on each row, compared with the name drawn
      alone. GAME LEVEL's value once shared row 0 and showed through a
      one-letter key: "Z KEY" read ZAKEY. }
    Sheet := TRenderImage.Create(SDL_CreateRGBSurface(0, 288, 54, 32,
      $FF0000, $FF00, $FF, 0));
    Font := TGameFont.Create(Sheet);
    Rec := TGlyphRecorder.Create;
    Alone := TGlyphRecorder.Create;
    try
      Settings.GameLevel := 0;
      MenuIndex := CTL_ROW_EXIT;   { the cursor out of the key rows }
      Screen.Draw(Rec, Font, nil, nil, nil);
      for I := 0 to CTL_ROW_EXIT - 1 do
      begin
        Alone.Glyphs.Clear;
        Font.TextOut(Alone, OPT_VALUE_X, Screen.ControlRowY(I),
                     Host.KeyName(I) + ' KEY', 0);
        Want(Rec.Row(Screen.ControlRowY(I), OPT_VALUE_X)
             = Alone.Row(Screen.ControlRowY(I), OPT_VALUE_X),
          Format('CONTROLS row %d draws more than its key name', [I]));
      end;
    finally
      Alone.Free;
      Rec.Free;
      Font.Free;
      Sheet.Free;
    end;
    Log.Add('  CONTROLS draws the three key names and nothing over them');

    { The cursor wraps within the page, and EXIT goes back to CONTROLS. }
    MenuIndex := 0;
    Screen.Update(-1, 0, False);
    Want(MenuIndex = CTL_ROW_EXIT, 'up from JUMP did not wrap to EXIT');
    Host.Sounds := 0;
    Screen.Update(0, 0, True);
    Want((TitleSubMode = TSM_OPTIONS) and (MenuIndex = Ord(orControls))
         and (Host.LastSound = SND_OK),
      'EXIT did not return to the options screen on CONTROLS');

    { LANGUAGE: left and right step through what is installed, sounding
      and telling the form, and are silent and still at either end. }
    SetLength(Langs, 2);
    Langs[0].Code := 'en';  Langs[0].MenuName := 'ENGLISH';
    Langs[1].Code := 'ja';  Langs[1].MenuName := 'JAPANESE';
    Screen.OnLanguage := Host.ChooseLanguage;
    Screen.SetLanguages(Langs, 'en');
    MenuIndex := Ord(orLanguage);
    Host.Languages := 0;
    Host.Sounds := 0;
    Screen.Update(0, -1, False);
    Want((Host.Languages = 0) and (Host.Sounds = 0),
      'LANGUAGE moved or sounded past its first entry');
    Screen.Update(0, 1, False);
    Want((Host.Languages = 1) and (Host.Language = 'ja')
         and (Screen.LanguageIndex = 1) and (Host.LastSound = SND_OK),
      'LANGUAGE right did not choose ja with SND_OK');
    Screen.Update(0, 1, False);
    Want(Host.Languages = 1, 'LANGUAGE moved past its last entry');
    Screen.Update(0, -1, False);
    Want((Host.Languages = 2) and (Host.Language = 'en'),
      'LANGUAGE left did not come back to en');
    Screen.SetLanguages(Langs, 'JA');
    Want(Screen.LanguageIndex = 1, 'SetLanguages did not find the current one');
    Log.Add('  LANGUAGE steps en <-> ja, silent and still at the ends');

    { Where the rows are drawn. Nothing scrolled, a row sits where the
      original's (index*2 + 7) * 8 put it, and EXIT where row 9 was. }
    Screen.Reset;
    TitleSubMode := TSM_OPTIONS;
    for I := 0 to OPT_ROW_EXIT - 1 do
      if I < OPT_VISIBLE_ROWS then
        Want(Screen.OptionRowY(I) = (I * 2 + 7) * 8,
          Format('row %d drawn at y=%d, the original''s is %d',
            [I, Screen.OptionRowY(I), (I * 2 + 7) * 8]))
      else
        Want(Screen.OptionRowY(I) = -1,
          Format('row %d is drawn below the ninth before any scrolling', [I]));
    Want(Screen.OptionRowY(OPT_ROW_EXIT) = (9 * 2 + 7) * 8,
      'EXIT is not where the original drew it');

    { Walk the cursor down every row and back up with the screen's own
      Update: whatever the scroll does, the cursor's row is always on screen
      and EXIT always at its place. }
    MenuIndex := 0;
    for J := 1 to 2 * (OPT_ROW_EXIT + 1) do
    begin
      if J <= OPT_ROW_EXIT + 1 then
        Screen.Update(1, 0, False)
      else
        Screen.Update(-1, 0, False);
      Want(Screen.OptionRowY(MenuIndex) >= 0,
        Format('the cursor''s row %d is scrolled out of view', [MenuIndex]));
    end;
    Log.Add(Format('  %d rows, %d on screen; the cursor stayed in view '
      + 'down and back up', [OPT_ROW_EXIT, OPT_VISIBLE_ROWS]));
  finally
    Screen.Free;
    Host.Free;
    TitleSubMode := TSM_MENU;
    MenuIndex := 0;
  end;

  { 8b. The scroll rule itself, for any number of rows - the screen has
        however many it has today, and this must hold for all of them. }
  Log.Add('');
  Log.Add('options scrolling:');
  Bad0 := Bad;
  for Rows := 1 to 24 do
  begin
    { Straight down from the top: the view holds still until the cursor
      reaches its last row, then moves one row per step. }
    Scroll := 0;
    for Cursor := 0 to Rows - 1 do
    begin
      Scroll := OptionsScroll(Cursor, Scroll, Rows, OPT_VISIBLE_ROWS);
      Want(Scroll = Max(0, Cursor - OPT_VISIBLE_ROWS + 1),
        Format('%d rows, down to %d: scroll %d', [Rows, Cursor, Scroll]));
    end;
    { And back up: still until the cursor reaches the view's first row. }
    for Cursor := Rows - 1 downto 0 do
    begin
      Want(OptionsScroll(Cursor, Scroll, Rows, OPT_VISIBLE_ROWS)
           = Min(Scroll, Cursor),
        Format('%d rows, up to %d: scroll %d', [Rows, Cursor, Scroll]));
      Scroll := OptionsScroll(Cursor, Scroll, Rows, OPT_VISIBLE_ROWS);
    end;
    { A cursor on EXIT - past the rows - leaves the view alone. }
    Want(OptionsScroll(Rows, Max(0, Rows - OPT_VISIBLE_ROWS), Rows,
                       OPT_VISIBLE_ROWS) = Max(0, Rows - OPT_VISIBLE_ROWS),
      Format('%d rows: EXIT moved the view', [Rows]));
    { Random walks, wrapping at both ends like the screen does: the cursor
      is always in view and the view never runs past the last row. }
    RandSeed := Rows;
    Scroll := 0;
    Cursor := 0;
    for J := 1 to 500 do
    begin
      Cursor := (Cursor + Random(3) - 1 + Rows + 1) mod (Rows + 1);
      Scroll := OptionsScroll(Cursor, Scroll, Rows, OPT_VISIBLE_ROWS);
      Want((Scroll >= 0) and (Scroll <= Max(0, Rows - OPT_VISIBLE_ROWS)),
        Format('%d rows: scroll %d is out of range', [Rows, Scroll]));
      if Cursor < Rows then
        Want((Cursor >= Scroll) and (Cursor < Scroll + OPT_VISIBLE_ROWS),
          Format('%d rows: cursor %d off screen at scroll %d',
            [Rows, Cursor, Scroll]));
    end;
  end;
  if Bad = Bad0 then
    Log.Add(Format('  1..24 rows, %d on screen: straight walks, EXIT and '
      + '500-step random walks', [OPT_VISIBLE_ROWS]));

  { 9. The gamepad. Everything up to the device is checkable here - that the
       subsystem starts with no video subsystem and no window, that the
       defaults name a button for every action, and that Update survives being
       called with nothing attached. What a real controller reports is not,
       so it is logged and skipped when there is none. }
  Log.Add('');
  Log.Add('gamepad:');
  D := TDDIDEX.Create(nil);
  try
    for B := Low(TAkujiButton) to High(TAkujiButton) do
      Want(DefaultBinding(B).Pad <> SDL_CONTROLLER_BUTTON_INVALID,
        Format('%s has no default pad button', [BUTTON_NAMES[B]]));

    { Sixty frames with nothing plugged in: no controller appears from
      nowhere, nothing is reported held, and the keyboard still works. }
    for J := 1 to 60 do
      D.Update;
    Want(D.Down = [], 'something was held with no keys and no pad');
    D.KeyDown(SDLK_z);
    D.Update;
    Want(D.Down = [abJump], 'the pad snapshot dropped a held key');
    D.KeyUp(SDLK_z);

    if SDL_InitSubSystem(SDL_INIT_GAMECONTROLLER) <> 0 then
      Log.Add('SKIP gamepad: the subsystem will not start: ' + SDL_GetError)
    else
    begin
      SDL_GameControllerUpdate;
      Pads := SDL_NumJoysticks;
      Log.Add(Format('  subsystem started with no video subsystem, %d joystick(s)',
        [Pads]));
      Found := 0;
      for J := 0 to Pads - 1 do
        if SDL_IsGameController(J) = SDL_TRUE then
        begin
          Inc(Found);
          Log.Add(Format('  controller %d: %s', [J, SDL_GameControllerNameForIndex(J)]));
        end;
      if Found = 0 then
        Log.Add('SKIP gamepad: no controller attached, so nothing to read')
      else
      begin
        Want(D.HasPad, 'a controller is attached but the component has none');
        Log.Add(Format('  %d controller(s) opened', [Found]));
      end;
      SDL_QuitSubSystem(SDL_INIT_GAMECONTROLLER);
    end;
  finally
    D.Free;
  end;

  Log.Add('');
  if Bad = 0 then
    Log.Add('OK - the defaults are the old table, and no key drives two actions')
  else
  begin
    Log.Add(Format('FAILED - %d check(s)', [Bad]));
    Result := 1;
  end;
end;

end.
