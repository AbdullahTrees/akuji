{ Platform audio output: streams the software mixer to the sound device.

  SDL calls back on its own thread whenever the device wants more samples, so
  there is no feed thread here and frame stalls cannot starve the device. The
  mixer takes its own lock, which is what makes that callback safe. }

unit AudioOut;

{$MODE DELPHI}{$H+}

interface

uses
  Classes, SysUtils, WaveFile, AudioMixer;

const
  { 256 frames at 22050 Hz is 11.6 ms. SDL keeps one buffer playing while the
    callback fills the next, so this is about 23 ms of latency: low enough that
    a jump sound still feels attached to the jump, high enough that a busy
    frame does not underrun. }
  OUT_FRAMES_PER_BLOCK = 256;

type
  TAudioOut = class
  private
    FMixer: TAudioMixer;
    FActive: Boolean;
    FDevice: Cardinal;
    FLastError: string;
  public
    constructor Create(AMixer: TAudioMixer);
    destructor Destroy; override;

    { Opens the device and starts playback. Returns False and sets LastError if
      no device is available; the game must stay playable in that case, so
      callers should not treat it as fatal. }
    function Start: Boolean;
    procedure Stop;

    property Active: Boolean read FActive;
    property LastError: string read FLastError;
  end;

{$IFDEF ANDROID}
{ Android gives an app one output device: OpenSL ES refuses a second, and
  the other two backends keep only one. So the music does not open its own,
  as it does everywhere else - it renders into this one, which runs at the
  music's 44100 Hz and carries the 22050 Hz effects doubled up to it.

  Render is called on the audio thread with Frames of interleaved signed
  16-bit stereo to fill. Attach fails, with the reason, if the effects
  device is not open. Detach returns only once Render will not be called
  again. }
type
  TMusicRender = procedure(Dest: PSmallInt; Frames: Integer) of object;

function AttachMusic(Render: TMusicRender; out Error: string): Boolean;
procedure DetachMusic;
{$ENDIF}

implementation

uses
  { ctypes is what supplies pcuint8 and cint. The bindings include ctypes.inc
    privately rather than re-exporting it, so a unit that declares a callback
    with SDL's own parameter types has to name it. }
  ctypes, SDL2;

{$IFDEF ANDROID}
const
  SHARED_RATE = 2 * MIX_RATE;

var
  SharedDevice: TSDL_AudioDeviceID = 0;
  SharedMusic: TMusicRender = nil;
  Effects: array of SmallInt;
  { The last effects frame of the previous block, which the first output
    frame of this one is interpolated from. }
  PrevL: SmallInt = 0;
  PrevR: SmallInt = 0;

function Clip(V: Integer): SmallInt; inline;
begin
  if V > 32767 then
    Result := 32767
  else if V < -32768 then
    Result := -32768
  else
    Result := V;
end;

{ The music, if any, then the effects on top, each effects frame becoming
  two: the midpoint from the one before, then itself. }
procedure FeedShared(Mixer: TAudioMixer; Dest: PSmallInt; Frames: Integer);
var
  Half, I, L, R: Integer;
  Out_: PSmallInt;
begin
  if Assigned(SharedMusic) then
    SharedMusic(Dest, Frames)
  else
    FillChar(Dest^, Frames * MIX_CHANNELS * SizeOf(SmallInt), 0);
  Half := Frames div 2;
  if (Half = 0) or (Half * MIX_CHANNELS > Length(Effects)) then
    Exit;
  Mixer.MixInto(@Effects[0], Half);
  Out_ := Dest;
  for I := 0 to Half - 1 do
  begin
    L := Effects[I * 2];
    R := Effects[I * 2 + 1];
    Out_[0] := Clip(Out_[0] + (PrevL + L) div 2);
    Out_[1] := Clip(Out_[1] + (PrevR + R) div 2);
    Out_[2] := Clip(Out_[2] + L);
    Out_[3] := Clip(Out_[3] + R);
    Inc(Out_, 4);
    PrevL := L;
    PrevR := R;
  end;
end;

function AttachMusic(Render: TMusicRender; out Error: string): Boolean;
begin
  Error := '';
  if SharedDevice = 0 then
  begin
    Error := 'the effects device is not open';
    Exit(False);
  end;
  SDL_LockAudioDevice(SharedDevice);
  SharedMusic := Render;
  SDL_UnlockAudioDevice(SharedDevice);
  Result := True;
end;

procedure DetachMusic;
begin
  if SharedDevice <> 0 then
    SDL_LockAudioDevice(SharedDevice);
  SharedMusic := nil;
  if SharedDevice <> 0 then
    SDL_UnlockAudioDevice(SharedDevice);
end;
{$ENDIF}

{ Runs on SDL's audio thread. Len is in BYTES; the mixer counts frames, and a
  frame is one sample per channel. }
procedure FeedDevice(UserData: Pointer; Stream: pcuint8; Len: cint); cdecl;
var
  Frames: Integer;
begin
  Frames := Len div (MIX_CHANNELS * SizeOf(SmallInt));
  if (UserData = nil) or (Frames <= 0) then
  begin
    { SDL does not clear the buffer first, so a callback that writes nothing
      plays whatever was left in it. }
    if Len > 0 then
      FillChar(Stream^, Len, 0);
    Exit;
  end;
  {$IFDEF ANDROID}
  FeedShared(TAudioMixer(UserData), PSmallInt(Stream), Frames);
  {$ELSE}
  TAudioMixer(UserData).MixInto(PSmallInt(Stream), Frames);
  {$ENDIF}
end;

constructor TAudioOut.Create(AMixer: TAudioMixer);
begin
  inherited Create;
  FMixer := AMixer;
  FDevice := 0;
  FActive := False;
end;

destructor TAudioOut.Destroy;
begin
  Stop;
  inherited Destroy;
end;

function TAudioOut.Start: Boolean;
var
  Want, Got: TSDL_AudioSpec;
begin
  Result := FActive;
  if Result then
    Exit;
  FLastError := '';

  if SDL_InitSubSystem(SDL_INIT_AUDIO) <> 0 then
  begin
    FLastError := 'SDL_InitSubSystem(AUDIO) failed: ' + SDL_GetError;
    Exit(False);
  end;

  FillChar(Want, SizeOf(Want), 0);
  Want.freq := MIX_RATE;
  Want.format := AUDIO_S16SYS;
  Want.channels := MIX_CHANNELS;
  Want.samples := OUT_FRAMES_PER_BLOCK;
  Want.callback := @FeedDevice;
  Want.userdata := FMixer;
  {$IFDEF ANDROID}
  Want.freq := SHARED_RATE;
  Want.samples := 2 * OUT_FRAMES_PER_BLOCK;
  {$ENDIF}

  { No allowed changes, so SDL converts for us if the hardware wants something
    else. The mixer only ever emits signed 16-bit stereo at MIX_RATE and has no
    way to do anything else, so letting the format vary would be a silent
    defect rather than a flexibility. }
  FDevice := SDL_OpenAudioDevice(nil, 0, @Want, @Got, 0);
  if FDevice = 0 then
  begin
    FLastError := 'SDL_OpenAudioDevice failed: ' + SDL_GetError;
    SDL_QuitSubSystem(SDL_INIT_AUDIO);
    Exit(False);
  end;

  {$IFDEF ANDROID}
  SetLength(Effects, (Got.samples div 2) * MIX_CHANNELS);
  SharedDevice := FDevice;
  {$ENDIF}
  SDL_PauseAudioDevice(FDevice, 0);
  FActive := True;
  Result := True;
end;

procedure TAudioOut.Stop;
begin
  if FDevice <> 0 then
  begin
    { Closing both stops the callback and waits for one already running, so the
      mixer cannot be touched after this returns. }
    SDL_CloseAudioDevice(FDevice);
    FDevice := 0;
    {$IFDEF ANDROID}
    SharedDevice := 0;
    {$ENDIF}
    SDL_QuitSubSystem(SDL_INIT_AUDIO);
  end;
  FActive := False;
end;

end.
