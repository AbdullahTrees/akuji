{ The input component named `Joy` on the main form.

  WHAT IT STANDS FOR

  The original reads input through DIRECTINPUT - `dinput.dll` is in its import
  table, and `Input_ReadJoyState` snapshots a whole DIJOYSTATE. Its chain has
  two stages:

      physical input -> device button 0..15 -> KeyMap -> logical button 0..3

  The device owns the first arrow: each of its sixteen buttons carries a
  primary and an alternate key binding, written by `Input_SetKeyBinding`, and
  `AppIdle` then polls `Input_IsKeyDown(Dev, KeyMap[i])` for each of the four
  buttons the game asks about. So KeyMap does not name a key. It says WHICH
  DEVICE BUTTON each action watches, which is what let the same four actions
  be driven by a keyboard or by either of two joysticks - `Settings.InputDevice`
  picks between them.

  WHAT THIS DOES

  The same two stages, with the middle one named in SDL's terms rather than in
  DirectInput's: an action carries a primary and an alternate SDL KEYCODE, and
  a gamepad button. SDL keycodes because they are the same numbers on every
  platform, which is the whole point of moving off dinput.

  The keyboard still ARRIVES from the LCL, through the form's OnKeyDown, which
  hands over Windows-shaped virtual key codes. That is the one platform-bound
  thing left in here and it is confined to VKToKeycode below: SDL cannot see a
  keyboard without a window of its own, and the window is still the LCL's. When
  that changes, VKToKeycode is deleted and SDL keycodes arrive already in SDL's
  terms - nothing above this line moves.

  The gamepad needs no window. Its subsystem starts with no video subsystem at
  all, which was measured before this was written, so it is read here directly. }

unit DDIDComponent;

{$MODE DELPHI}{$H+}

interface

uses
  Classes, SysUtils, LCLType, ctypes, SDL2;

type
  TDDIDDebugOptionItem = (dioHaltOnError);
  TDDIDDebugOption = set of TDDIDDebugOptionItem;

  { What the game asks about.

    The four buttons are the four the original polls, in the order its KeyMap
    holds them, so KeyMap[0] is the jump button and KeyMap[3] the one the
    options screen never names. The four directions were never rebindable
    there - the screen has no row for them - but they are bindings here all
    the same, because a binding that is a special case is a binding that gets
    forgotten. }
  TAkujiButton = (abUp, abDown, abLeft, abRight,
                  abJump, abFire, abPause, abAux);
  TAkujiButtons = set of TAkujiButton;

const
  { The four the options screen can reach, and the four it cannot. }
  AKUJI_ACTIONS = [abJump, abFire, abPause, abAux];
  AKUJI_DIRECTIONS = [abUp, abDown, abLeft, abRight];

  { KeyMap's four entries, in order. }
  AKUJI_MAPPED: array[0..3] of TAkujiButton = (abJump, abFire, abPause, abAux);

  { WHAT Settings.KeyMap HOLDS NOW.

    The original stored a device button INDEX, 0..15. This stores an SDL
    keycode - a different thing in the same four ints - so a file written by
    either has to be recognised for what it is.

    Not by range: three keycodes land inside the original's, backspace at 8,
    tab at 9 and return at 13, and reading one of those as an index would
    quietly rebind the key to something else. A tag says it instead, and the
    tag is far above any index the original could write. }
  KEYMAP_TAG = $10000000;

  { The twelve keys the original's options screen could name, in the order of
    its name table - so index 0 is Z, which is what the shipped system.dat
    carries for the jump button, and the shipped (0,1,2,3) migrates to exactly
    the four defaults. }
  LEGACY_KEYS: array[0..11] of TSDL_KeyCode = (
    SDLK_z, SDLK_x, SDLK_c, SDLK_a, SDLK_s, SDLK_d,
    SDLK_1, SDLK_2, SDLK_3, SDLK_4, SDLK_5, SDLK_6);

type
  { One action's inputs. Primary and Alternate are the two key bindings the
    original's device carried per button; Pad is the gamepad button that does
    the same thing, which the original expressed as a second device entirely. }
  TAkujiBinding = record
    Primary: TSDL_KeyCode;
    Alternate: TSDL_KeyCode;
    Pad: TSDL_GameControllerButton;
  end;

  TDDIDEX = class(TComponent)
  private
    FDebugOption: TDDIDDebugOption;
    FDown: TAkujiButtons;
    FKeysDown: TAkujiButtons;       { from the keyboard }
    FPadDown: TAkujiButtons;        { from the gamepad }
    FBindings: array[TAkujiButton] of TAkujiBinding;
    FPad: PSDL_GameController;
    FPadStarted: Boolean;
    { The last key the window reported, BOUND OR NOT. Rebinding is the reason
      it exists: a key that drives nothing yet is exactly the one the player
      is about to assign, and the pressed sets above only track bound keys. }
    FPressedKey: TSDL_KeyCode;
    function GetBinding(Button: TAkujiButton): TAkujiBinding;
    procedure SetBinding(Button: TAkujiButton; const Value: TAkujiBinding);
    { Whichever action this key drives, or False. }
    function ActionOfKey(Key: TSDL_KeyCode; out Button: TAkujiButton): Boolean;
    procedure OpenPad;
    procedure ReadPad;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    { Once a frame. The keyboard maintains itself through KeyDown and KeyUp;
      this is where the gamepad is read. }
    procedure Update;

    function IsDown(Button: TAkujiButton): Boolean;

    { Called from the form's OnKeyDown/OnKeyUp, with an LCL virtual key. }
    procedure KeyDown(Key: Word);
    procedure KeyUp(Key: Word);

    { Bind a key to an action, taking it off whatever held it.

      The original swaps: it looks for the pressed button among the three rows
      the screen can edit and, finding it, gives that row the selected row's
      button. Swapping over ALL of them rather than three is the same rule
      carried to its conclusion - no key ends up driving two actions, which is
      the property that made the original swap in the first place.

      Returns False if the key is not one a binding can hold. }
    function BindKey(Button: TAkujiButton; Key: TSDL_KeyCode): Boolean;

    { The bind the options screen makes, which is BindKey with the screen's
      two extra rules - and they are here rather than up there so that a test
      with no window can hold them.

      A key already on this row is refused, so that holding it down does not
      re-announce itself every frame. A key that currently drives a DIRECTION
      is refused too: binding one would trade the arrow away, and the player
      would be left on a row they could no longer move off. It is the same
      restriction the original had, arrived at differently - its screen polled
      twelve buttons and the arrows were not among them. }
    function BindAction(Button: TAkujiButton; Key: TSDL_KeyCode): Boolean;

    { The four mapped actions' PRIMARY keys, the way Settings.KeyMap holds
      them - one int per action, which is the shape the original's record has
      and the reason alternates are not persisted: Space stays a default
      second way to jump rather than something the player can move.

      Loading goes through BindKey, so a file holding the same key twice
      resolves by the same rule the options screen uses instead of leaving two
      actions on one key. An entry naming no key leaves that action's default
      where it is. }
    procedure LoadKeyMap(const Map: array of Integer);
    procedure StoreKeyMap(var Map: array of Integer);

    { The name to show for a binding, in the bitmap font's uppercase. }
    function KeyNameOf(Key: TSDL_KeyCode): string;

    { True while any key that could be bound is held, and which one. Used by
      the options screen, which binds whatever the player presses. }
    function AnyKeyDown(out Key: TSDL_KeyCode): Boolean;

    property Bindings[Button: TAkujiButton]: TAkujiBinding
      read GetBinding write SetBinding;
    property Down: TAkujiButtons read FDown;
    property HasPad: Boolean read FPadStarted;
  published
    property DebugOption: TDDIDDebugOption read FDebugOption write FDebugOption;
  end;

{ The defaults, which reproduce exactly what the hard-wired table did before
  bindings existed: arrows and the numpad for the directions, Z X C A for the
  four buttons, and space as a second way to jump.

  Space was a case arm here and is now an alternate binding, which is the
  difference the player can act on: it is a default rather than a fact. }
function DefaultBinding(Button: TAkujiButton): TAkujiBinding;

{ One Settings.KeyMap entry as a keycode, and back. Anything neither tagged
  nor a legal legacy index reads as SDLK_UNKNOWN, which loads as "leave the
  default alone" - system.dat is a 56-byte blob the player can corrupt. }
function KeyMapToKeycode(Stored: Integer): TSDL_KeyCode;
function KeycodeToKeyMap(Key: TSDL_KeyCode): Integer;

{ An LCL virtual key as the SDL keycode meaning the same key, or SDLK_UNKNOWN.

  THE ONE PLATFORM-SHAPED THING LEFT IN THIS UNIT. It exists because the
  keyboard arrives from the window, and the window is the LCL's; when the
  window becomes SDL's, SDL hands over keycodes directly and this goes. }
function VKToKeycode(Key: Word): TSDL_KeyCode;

implementation

function DefaultBinding(Button: TAkujiButton): TAkujiBinding;
begin
  Result.Primary := SDLK_UNKNOWN;
  Result.Alternate := SDLK_UNKNOWN;
  Result.Pad := SDL_CONTROLLER_BUTTON_INVALID;
  case Button of
    abUp:
      begin
        Result.Primary := SDLK_UP;    Result.Alternate := SDLK_KP_8;
        Result.Pad := SDL_CONTROLLER_BUTTON_DPAD_UP;
      end;
    abDown:
      begin
        Result.Primary := SDLK_DOWN;  Result.Alternate := SDLK_KP_2;
        Result.Pad := SDL_CONTROLLER_BUTTON_DPAD_DOWN;
      end;
    abLeft:
      begin
        Result.Primary := SDLK_LEFT;  Result.Alternate := SDLK_KP_4;
        Result.Pad := SDL_CONTROLLER_BUTTON_DPAD_LEFT;
      end;
    abRight:
      begin
        Result.Primary := SDLK_RIGHT; Result.Alternate := SDLK_KP_6;
        Result.Pad := SDL_CONTROLLER_BUTTON_DPAD_RIGHT;
      end;
    { Jump, and the space bar that has always also jumped. }
    abJump:
      begin
        Result.Primary := SDLK_z;     Result.Alternate := SDLK_SPACE;
        Result.Pad := SDL_CONTROLLER_BUTTON_A;
      end;
    abFire:
      begin
        Result.Primary := SDLK_x;
        Result.Pad := SDL_CONTROLLER_BUTTON_X;
      end;
    abPause:
      begin
        Result.Primary := SDLK_c;
        Result.Pad := SDL_CONTROLLER_BUTTON_START;
      end;
    abAux:
      begin
        Result.Primary := SDLK_a;
        Result.Pad := SDL_CONTROLLER_BUTTON_B;
      end;
  end;
end;

function KeyMapToKeycode(Stored: Integer): TSDL_KeyCode;
begin
  if Stored >= KEYMAP_TAG then
    Result := TSDL_KeyCode(Stored - KEYMAP_TAG)
  else if (Stored >= Low(LEGACY_KEYS)) and (Stored <= High(LEGACY_KEYS)) then
    Result := LEGACY_KEYS[Stored]
  else
    Result := SDLK_UNKNOWN;
end;

function KeycodeToKeyMap(Key: TSDL_KeyCode): Integer;
begin
  Result := KEYMAP_TAG + Integer(Key);
end;

function VKToKeycode(Key: Word): TSDL_KeyCode;
begin
  { The letters and digits are contiguous in both, so they go as ranges: an
    LCL VK_A is the ordinal of 'A' and an SDL keycode is the ordinal of the
    LOWERCASE letter, which is the only catch. }
  if (Key >= VK_A) and (Key <= VK_Z) then
    Exit(TSDL_KeyCode(Ord('a') + (Key - VK_A)));
  if (Key >= VK_0) and (Key <= VK_9) then
    Exit(TSDL_KeyCode(Ord('0') + (Key - VK_0)));

  case Key of
    VK_UP:       Result := SDLK_UP;
    VK_DOWN:     Result := SDLK_DOWN;
    VK_LEFT:     Result := SDLK_LEFT;
    VK_RIGHT:    Result := SDLK_RIGHT;
    VK_NUMPAD0:  Result := SDLK_KP_0;
    VK_NUMPAD1:  Result := SDLK_KP_1;
    VK_NUMPAD2:  Result := SDLK_KP_2;
    VK_NUMPAD3:  Result := SDLK_KP_3;
    VK_NUMPAD4:  Result := SDLK_KP_4;
    VK_NUMPAD5:  Result := SDLK_KP_5;
    VK_NUMPAD6:  Result := SDLK_KP_6;
    VK_NUMPAD7:  Result := SDLK_KP_7;
    VK_NUMPAD8:  Result := SDLK_KP_8;
    VK_NUMPAD9:  Result := SDLK_KP_9;
    VK_SPACE:    Result := SDLK_SPACE;
    VK_RETURN:   Result := SDLK_RETURN;
    VK_ESCAPE:   Result := SDLK_ESCAPE;
    VK_TAB:      Result := SDLK_TAB;
    VK_BACK:     Result := SDLK_BACKSPACE;
    VK_SHIFT:    Result := SDLK_LSHIFT;
    VK_CONTROL:  Result := SDLK_LCTRL;
  else
    Result := SDLK_UNKNOWN;
  end;
end;

constructor TDDIDEX.Create(AOwner: TComponent);
var
  B: TAkujiButton;
begin
  inherited Create(AOwner);
  for B := Low(TAkujiButton) to High(TAkujiButton) do
    FBindings[B] := DefaultBinding(B);
end;

destructor TDDIDEX.Destroy;
begin
  if FPad <> nil then
    SDL_GameControllerClose(FPad);
  if FPadStarted then
    SDL_QuitSubSystem(SDL_INIT_GAMECONTROLLER);
  inherited Destroy;
end;

function TDDIDEX.GetBinding(Button: TAkujiButton): TAkujiBinding;
begin
  Result := FBindings[Button];
end;

procedure TDDIDEX.SetBinding(Button: TAkujiButton; const Value: TAkujiBinding);
begin
  FBindings[Button] := Value;
end;

function TDDIDEX.ActionOfKey(Key: TSDL_KeyCode;
  out Button: TAkujiButton): Boolean;
var
  B: TAkujiButton;
begin
  Result := False;
  if Key = SDLK_UNKNOWN then
    Exit;
  for B := Low(TAkujiButton) to High(TAkujiButton) do
    if (FBindings[B].Primary = Key) or (FBindings[B].Alternate = Key) then
    begin
      Button := B;
      Exit(True);
    end;
end;

procedure TDDIDEX.KeyDown(Key: Word);
var
  Button: TAkujiButton;
  Code: TSDL_KeyCode;
begin
  Code := VKToKeycode(Key);
  if Code = SDLK_UNKNOWN then
    Exit;
  FPressedKey := Code;
  if ActionOfKey(Code, Button) then
  begin
    Include(FKeysDown, Button);
    Include(FDown, Button);
  end;
end;

procedure TDDIDEX.KeyUp(Key: Word);
var
  Button: TAkujiButton;
  Code: TSDL_KeyCode;
begin
  Code := VKToKeycode(Key);
  if Code = SDLK_UNKNOWN then
    Exit;
  if FPressedKey = Code then
    FPressedKey := SDLK_UNKNOWN;
  if ActionOfKey(Code, Button) then
  begin
    Exclude(FKeysDown, Button);
    { Only if the pad is not holding it too. }
    if not (Button in FPadDown) then
      Exclude(FDown, Button);
  end;
end;

function TDDIDEX.AnyKeyDown(out Key: TSDL_KeyCode): Boolean;
var
  State: PUInt8;
  Count: cint;
  I: Integer;
begin
  { Read from SDL rather than from what this component happens to have seen,
    so that a key NOT currently bound to anything can still be offered - which
    is exactly what rebinding needs. Without an SDL window this array is never
    filled, so it reports nothing and the caller falls back on what the
    keyboard handlers know. }
  { What the window last reported, which is the only source there is while the
    window is the LCL's. SDL's own array is read after it rather than instead
    of it, so nothing here changes when the window becomes SDL's. }
  Key := FPressedKey;
  if Key <> SDLK_UNKNOWN then
    Exit(True);

  Result := False;
  State := SDL_GetKeyboardState(@Count);
  if State = nil then
    Exit;
  for I := 0 to Count - 1 do
    if State[I] <> 0 then
    begin
      Key := SDL_GetKeyFromScancode(TSDL_ScanCode(I));
      Exit(True);
    end;
end;

function TDDIDEX.BindKey(Button: TAkujiButton; Key: TSDL_KeyCode): Boolean;
var
  Holder: TAkujiButton;
  Swap: TSDL_KeyCode;
begin
  Result := False;
  if Key = SDLK_UNKNOWN then
    Exit;

  if ActionOfKey(Key, Holder) then
  begin
    { Already where it was asked to go: nothing to do, and saying so is what
      makes holding the key down harmless. }
    if Holder = Button then
      Exit(True);
    { Held elsewhere: the two trade primaries, so neither action is left
      without one and no key drives two actions. }
    Swap := FBindings[Button].Primary;
    if FBindings[Holder].Primary = Key then
      FBindings[Holder].Primary := Swap
    else
      FBindings[Holder].Alternate := Swap;
  end;
  FBindings[Button].Primary := Key;

  { Nothing stays held across a rebind. The key the player is holding was
    resolved to an action on the way down and would resolve to a DIFFERENT
    one on the way up, which would leave the first stuck down for the rest of
    the run - a fire button that never releases. }
  FKeysDown := [];
  FPadDown := [];
  FDown := [];
  Result := True;
end;

procedure TDDIDEX.LoadKeyMap(const Map: array of Integer);
var
  I: Integer;
begin
  for I := Low(AKUJI_MAPPED) to High(AKUJI_MAPPED) do
    if I <= High(Map) then
      BindKey(AKUJI_MAPPED[I], KeyMapToKeycode(Map[I]));
end;

procedure TDDIDEX.StoreKeyMap(var Map: array of Integer);
var
  I: Integer;
begin
  for I := Low(AKUJI_MAPPED) to High(AKUJI_MAPPED) do
    if I <= High(Map) then
      Map[I] := KeycodeToKeyMap(FBindings[AKUJI_MAPPED[I]].Primary);
end;

function TDDIDEX.BindAction(Button: TAkujiButton; Key: TSDL_KeyCode): Boolean;
var
  Holder: TAkujiButton;
begin
  Result := False;
  if not (Button in AKUJI_ACTIONS) then
    Exit;
  if (Key = SDLK_UNKNOWN) or (FBindings[Button].Primary = Key) then
    Exit;
  if ActionOfKey(Key, Holder) and (Holder in AKUJI_DIRECTIONS) then
    Exit;
  Result := BindKey(Button, Key);
end;

function TDDIDEX.KeyNameOf(Key: TSDL_KeyCode): string;
begin
  if Key = SDLK_UNKNOWN then
    Exit('NONE');
  { SDL names every key the same way on every platform, which is one fewer
    table to keep. The font has no lowercase. }
  Result := UpperCase(SDL_GetKeyName(Key));
  if Result = '' then
    Result := 'NONE';
end;

procedure TDDIDEX.OpenPad;
var
  I: Integer;
begin
  if not FPadStarted then
  begin
    { No video subsystem is needed for this, which is what lets it happen
      while the window is still the LCL's. }
    if SDL_InitSubSystem(SDL_INIT_GAMECONTROLLER) <> 0 then
      Exit;
    FPadStarted := True;
  end;
  if FPad <> nil then
  begin
    { Unplugged since last frame. }
    if SDL_GameControllerGetAttached(FPad) = SDL_TRUE then
      Exit;
    SDL_GameControllerClose(FPad);
    FPad := nil;
  end;
  for I := 0 to SDL_NumJoysticks - 1 do
    if SDL_IsGameController(I) = SDL_TRUE then
    begin
      FPad := SDL_GameControllerOpen(I);
      if FPad <> nil then
        Exit;
    end;
end;

procedure TDDIDEX.ReadPad;
const
  { Past halfway on a stick counts as the direction being held, which is what
    a game with four-way movement and no analogue speed needs. }
  STICK_EDGE = 16384;
var
  B: TAkujiButton;
  Held: Boolean;
  AxisX, AxisY: cint16;
begin
  FPadDown := [];
  if FPad = nil then
    Exit;

  AxisX := SDL_GameControllerGetAxis(FPad, SDL_CONTROLLER_AXIS_LEFTX);
  AxisY := SDL_GameControllerGetAxis(FPad, SDL_CONTROLLER_AXIS_LEFTY);

  for B := Low(TAkujiButton) to High(TAkujiButton) do
  begin
    Held := False;
    if FBindings[B].Pad <> SDL_CONTROLLER_BUTTON_INVALID then
      Held := SDL_GameControllerGetButton(FPad, FBindings[B].Pad) <> 0;
    { The left stick drives the directions as well as the d-pad. }
    case B of
      abLeft:  Held := Held or (AxisX < -STICK_EDGE);
      abRight: Held := Held or (AxisX > STICK_EDGE);
      abUp:    Held := Held or (AxisY < -STICK_EDGE);
      abDown:  Held := Held or (AxisY > STICK_EDGE);
    end;
    if Held then
      Include(FPadDown, B);
  end;
end;

procedure TDDIDEX.Update;
begin
  OpenPad;
  ReadPad;
  { The keyboard half is maintained by KeyDown and KeyUp as the events arrive;
    the pad half is a snapshot. What the game sees is either. }
  FDown := FKeysDown + FPadDown;
end;

function TDDIDEX.IsDown(Button: TAkujiButton): Boolean;
begin
  Result := Button in FDown;
end;

initialization
  RegisterClass(TDDIDEX);

end.
