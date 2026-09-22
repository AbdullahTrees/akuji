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
  LCLType, SDL2, DDIDComponent;

type
  { One row of the table DDIDComponent had before bindings existed, recovered
    from the version this replaced. S and D are absent on purpose: they set
    abAux2 and abAux3, which nothing anywhere read. }
  TOldRow = record
    VK: Word;
    Button: TAkujiButton;
  end;

const
  OLD_TABLE: array[0..12] of TOldRow = (
    (VK: VK_UP;      Button: abUp),
    (VK: VK_NUMPAD8; Button: abUp),
    (VK: VK_DOWN;    Button: abDown),
    (VK: VK_NUMPAD2; Button: abDown),
    (VK: VK_LEFT;    Button: abLeft),
    (VK: VK_NUMPAD4; Button: abLeft),
    (VK: VK_RIGHT;   Button: abRight),
    (VK: VK_NUMPAD6; Button: abRight),
    (VK: VK_Z;       Button: abJump),
    (VK: VK_SPACE;   Button: abJump),
    (VK: VK_X;       Button: abFire),
    (VK: VK_C;       Button: abPause),
    (VK: VK_A;       Button: abAux));

  BUTTON_NAMES: array[TAkujiButton] of string =
    ('UP', 'DOWN', 'LEFT', 'RIGHT', 'JUMP', 'FIRE', 'PAUSE', 'AUX');

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

  { What one virtual key presses, pressed and released in isolation. }
  function Press(D: TDDIDEX; VK: Word): TAkujiButtons;
  begin
    D.KeyDown(VK);
    Result := D.Down;
    D.KeyUp(VK);
  end;

var
  D, E: TDDIDEX;
  VK, I, J, Dups: Integer;
  Wanted, Got: TAkujiButtons;
  Map, Back: array[0..3] of Integer;
  B: TAkujiButton;
  Checked, Pressing: Integer;
begin
  Result := 0;
  Bad := 0;

  { 1. The defaults must be the old table, key for key. Driving all 256 virtual
       keys rather than the twelve in the table is the point: a binding that
       reaches a key the old one did not is just as wrong as one that misses. }
  Log.Add('default bindings vs the pre-binding VK table, all 256 virtual keys:');
  D := TDDIDEX.Create(nil);
  try
    Checked := 0;
    Pressing := 0;
    for VK := 0 to 255 do
    begin
      Wanted := [];
      for I := Low(OLD_TABLE) to High(OLD_TABLE) do
        if OLD_TABLE[I].VK = VK then
          Wanted := [OLD_TABLE[I].Button];
      Got := Press(D, VK);
      Inc(Checked);
      if Wanted <> [] then
        Inc(Pressing);
      if Got <> Wanted then
      begin
        Log.Add(Format('  VK $%.2X: was %s, now %s',
          [VK, SetText(Wanted), SetText(Got)]));
        Inc(Bad);
      end;
      Want(D.Down = [],
        Format('VK $%.2X left something held after release', [VK]));
    end;
    Log.Add(Format('  %d keys checked, %d of them press something',
      [Checked, Pressing]));
    Want(Pressing = Length(OLD_TABLE),
      'the old table names keys this build has no virtual key for');

    { 2. Holding two at once is a set, not a last-one-wins. }
    D.KeyDown(VK_LEFT);
    D.KeyDown(VK_Z);
    Want(D.Down = [abLeft, abJump], 'LEFT+Z does not hold both');
    D.KeyUp(VK_LEFT);
    Want(D.Down = [abJump], 'releasing LEFT did not leave Z held');
    D.KeyUp(VK_Z);
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
    Want(Press(D, VK_Z) = [abJump], 'Z stopped jumping');
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
    Want(Press(D, VK_S) = [abJump], 'S does not jump');
    Want(Press(D, VK_Z) = [], 'Z still jumps after being replaced');
    Want(Press(D, VK_SPACE) = [abJump], 'the alternate was lost');
    Want(Press(D, VK_X) = [abFire], 'FIRE moved');
    Want(Duplicates(D) = 0, 'binding a free key made a duplicate');

    { Trade: FIRE takes S, which JUMP holds, and JUMP gets X back. }
    Want(D.BindKey(abFire, SDLK_s), 'a held key was refused');
    Want(Press(D, VK_S) = [abFire], 'S does not fire');
    Want(Press(D, VK_X) = [abJump], 'JUMP was left without the traded key');
    Want(Duplicates(D) = 0, 'the trade made a duplicate');

    { Trading against an ALTERNATE moves the alternate, not the primary. }
    Want(D.BindKey(abPause, SDLK_SPACE), 'the space bar was refused');
    Want(Press(D, VK_SPACE) = [abPause], 'space does not pause');
    Want(Press(D, VK_X) = [abJump],
      'JUMP lost its primary to an alternate swap');
    Want(D.Bindings[abJump].Alternate = SDLK_c,
      'PAUSE''s key did not land on the alternate it traded with');
    Want(Duplicates(D) = 0, 'the alternate trade made a duplicate');

    { Held down for many frames: the same bind over and over is a fixed point. }
    for J := 1 to 60 do
      Want(D.BindKey(abPause, SDLK_SPACE), 'a repeat bind was refused');
    Want(Press(D, VK_SPACE) = [abPause], 'a repeated bind drifted');
    Want(Press(D, VK_X) = [abJump], 'a repeated bind moved another action');
    Want(Duplicates(D) = 0, 'a repeated bind made a duplicate');

    Want(not D.BindKey(abJump, SDLK_UNKNOWN), 'no key at all was accepted');

    { Every action in turn onto one key: seven trades, still no duplicate. }
    Dups := 0;
    for B := Low(TAkujiButton) to High(TAkujiButton) do
    begin
      D.BindKey(B, SDLK_q);
      Want(Press(D, VK_Q) = [B],
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
