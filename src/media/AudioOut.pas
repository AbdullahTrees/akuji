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

implementation

uses
  { ctypes is what supplies pcuint8 and cint. The bindings include ctypes.inc
    privately rather than re-exporting it, so a unit that declares a callback
    with SDL's own parameter types has to name it. }
  ctypes, SDL2;

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
  TAudioMixer(UserData).MixInto(PSmallInt(Stream), Frames);
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
    SDL_QuitSubSystem(SDL_INIT_AUDIO);
  end;
  FActive := False;
end;

end.
