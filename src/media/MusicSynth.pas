{ The music, rendered in software and played through SDL.

  FluidSynth turns each track's MIDI into audio using an instrument bank, and
  the result goes out through an SDL audio device of its own - the slot
  SDL_mixer's device used to occupy, beside the effects mixer's. Nothing here
  goes near the operating system's MIDI synthesiser, which is what makes the
  volume controllable and the whole thing portable.

  Rendering is a separate call from the device, so that a test can pull audio
  out of Render with no device at all and check what it is.

  THREADS. SDL calls Render on its own audio thread; everything else is called
  from the game. One lock covers both, so a track cannot be torn down while a
  block of it is being rendered. FluidSynth's player keeps time by the samples
  the synthesiser renders, so the music advances exactly as fast as it is
  played and stops advancing when nothing is listening. }

unit MusicSynth;

{$MODE DELPHI}{$H+}

interface

uses
  Classes, SysUtils, SyncObjs, ctypes, SDL2, FluidSynth, GameLog;

const
  { The Windows synthesiser renders at the device's rate. 22050, the effects
    mixer's rate, would take the top octave off the music. }
  MUSIC_RATE = 44100;
  MUSIC_CHANNELS = 2;
  MUSIC_FRAMES_PER_BLOCK = 1024;

  { FluidSynth's own output gain. Its default, 0.2, is far quieter than the
    Windows synthesiser. This is the loudest setting at which none of the 14
    tracks clips when rendered from gm.dls with effects off - measured, the
    loudest being end01 at 0.72 of full scale with gain 0.4 - which puts the
    music somewhat below the Windows synthesiser's measured level rather than
    distorting on its loudest passages. }
  MUSIC_SYNTH_GAIN = 0.5;

type
  TMusicSynth = class
  private
    FLock: TCriticalSection;
    FSettings: PFluidSettings;
    FSynth: PFluidSynthInst;
    FPlayer: PFluidPlayer;
    FGain: Single;           { the volume setting as amplitude, 0..1 }
    FFade: Single;           { where a fade has got to, 0..1 }
    FFadeStep: Single;       { per frame; 0 when no fade is running }
    FStopWhenSilent: Boolean;{ a fade OUT, which ends by stopping the track }
    FScratch: array of Single;
    FDevice: TSDL_AudioDeviceID;
    FLastError: string;
    procedure HaltLocked;
  public
    constructor Create;
    destructor Destroy; override;

    { Creates the synthesiser and loads an instrument bank - SF2 or DLS.
      Effects switches FluidSynth's reverb and chorus on; off is the dry sound
      the game has always had. False, with LastError set, if FluidSynth is
      missing or the bank will not load. }
    function Open(const BankPath: string; Effects: Boolean): Boolean;
    procedure Close;
    function Opened: Boolean;

    { Starts a track from the bytes of a MIDI file, replacing whatever was
      playing - cut, not faded, as SDL_mixer's halt was. FadeInMs above zero
      brings it up from silence over that long. }
    function Play(const Midi: TBytes; Loop: Boolean;
                  FadeInMs: Integer = 0): Boolean;
    procedure Stop;
    { Fades to silence over Ms, then stops. Zero or less stops at once. }
    procedure FadeOut(Ms: Integer);
    { True while a track is sounding, including through a fade-out. }
    function IsPlaying: Boolean;

    { 0..1 amplitude, applied after synthesis. }
    procedure SetGain(Value: Single);

    { Fills Frames of interleaved signed 16-bit stereo. }
    procedure Render(Dest: PSmallInt; Frames: Integer);

    { The SDL output device, separate from the effects mixer's. }
    function StartDevice: Boolean;
    procedure StopDevice;

    property LastError: string read FLastError;
  end;

implementation

{ FluidSynth's own warnings and errors, which otherwise go to a stderr that
  a windowed game does not have. One of them is expected on every start with
  gm.dls - it tries the file as a SoundFont before trying it as DLS - and
  the line after it says whether DLS worked. }
procedure FluidLog(Level: cint; Message: PAnsiChar; Data: Pointer); cdecl;
const
  LEVELS: array[FLUID_PANIC..FLUID_DBG] of string =
    ('panic', 'error', 'warning', 'info', 'debug');
begin
  if (Level >= FLUID_PANIC) and (Level <= FLUID_DBG) then
    LogFmt(lsMusic, 'fluidsynth %s: %s', [LEVELS[Level], string(Message)])
  else
    LogFmt(lsMusic, 'fluidsynth: %s', [string(Message)]);
end;

procedure FeedMusic(UserData: Pointer; Stream: pcuint8; Len: cint); cdecl;
begin
  if UserData = nil then
  begin
    FillChar(Stream^, Len, 0);
    Exit;
  end;
  TMusicSynth(UserData).Render(PSmallInt(Stream),
    Len div (MUSIC_CHANNELS * SizeOf(SmallInt)));
end;

constructor TMusicSynth.Create;
begin
  inherited Create;
  FLock := TCriticalSection.Create;
  FGain := 1.0;
  FFade := 1.0;
end;

destructor TMusicSynth.Destroy;
begin
  Close;
  FLock.Free;
  inherited Destroy;
end;

function TMusicSynth.Open(const BankPath: string; Effects: Boolean): Boolean;
begin
  Result := False;
  Close;
  if not LoadFluidSynth then
  begin
    FLastError := FluidSynthError;
    Exit;
  end;
  { Info and debug are FluidSynth talking to itself; the rest is worth
    keeping. }
  fluid_set_log_function(FLUID_PANIC, @FluidLog, nil);
  fluid_set_log_function(FLUID_ERR, @FluidLog, nil);
  fluid_set_log_function(FLUID_WARN, @FluidLog, nil);
  fluid_set_log_function(FLUID_INFO, nil, nil);
  fluid_set_log_function(FLUID_DBG, nil, nil);

  FSettings := new_fluid_settings();
  if FSettings = nil then
  begin
    FLastError := 'new_fluid_settings failed';
    Exit;
  end;
  { All of this has to be settled before the synthesiser exists. }
  fluid_settings_setnum(FSettings, 'synth.sample-rate', MUSIC_RATE);
  fluid_settings_setnum(FSettings, 'synth.gain', MUSIC_SYNTH_GAIN);
  fluid_settings_setint(FSettings, 'synth.reverb.active', Ord(Effects));
  fluid_settings_setint(FSettings, 'synth.chorus.active', Ord(Effects));

  FSynth := new_fluid_synth(FSettings);
  if FSynth = nil then
  begin
    FLastError := 'new_fluid_synth failed';
    Close;
    Exit;
  end;

  { UTF-8, which is what FluidSynth expects a path in on every platform. }
  if fluid_synth_sfload(FSynth, PAnsiChar(UTF8Encode(BankPath)), 1)
     = FLUID_FAILED then
  begin
    FLastError := 'could not load the instrument bank ' + BankPath;
    Close;
    Exit;
  end;
  Result := True;
end;

procedure TMusicSynth.Close;
begin
  StopDevice;
  FLock.Acquire;
  try
    HaltLocked;
    if FSynth <> nil then
      delete_fluid_synth(FSynth);
    FSynth := nil;
    if FSettings <> nil then
      delete_fluid_settings(FSettings);
    FSettings := nil;
  finally
    FLock.Release;
  end;
end;

function TMusicSynth.Opened: Boolean;
begin
  Result := FSynth <> nil;
end;

procedure TMusicSynth.HaltLocked;
begin
  if FPlayer <> nil then
  begin
    fluid_player_stop(FPlayer);
    delete_fluid_player(FPlayer);
    FPlayer := nil;
  end;
  { Silence now, including the release tails, which is what a halt did. }
  if FSynth <> nil then
    fluid_synth_all_sounds_off(FSynth, -1);
  FFadeStep := 0;
  FStopWhenSilent := False;
end;

function TMusicSynth.Play(const Midi: TBytes; Loop: Boolean;
  FadeInMs: Integer): Boolean;
begin
  Result := False;
  if (FSynth = nil) or (Length(Midi) = 0) then
    Exit;
  FLock.Acquire;
  try
    HaltLocked;
    FPlayer := new_fluid_player(FSynth);
    if FPlayer = nil then
      Exit;
    { The buffer is copied, so the caller's bytes need not outlive this. }
    if fluid_player_add_mem(FPlayer, @Midi[0], Length(Midi)) <> FLUID_OK then
    begin
      HaltLocked;
      Exit;
    end;
    { -1 is for ever; 1 is once through. }
    if Loop then
      fluid_player_set_loop(FPlayer, -1)
    else
      fluid_player_set_loop(FPlayer, 1);

    if FadeInMs > 0 then
    begin
      FFade := 0;
      FFadeStep := 1.0 / (FadeInMs * (MUSIC_RATE / 1000.0));
    end
    else
    begin
      FFade := 1;
      FFadeStep := 0;
    end;
    FStopWhenSilent := False;

    Result := fluid_player_play(FPlayer) = FLUID_OK;
    if not Result then
      HaltLocked;
  finally
    FLock.Release;
  end;
end;

procedure TMusicSynth.Stop;
begin
  FLock.Acquire;
  try
    HaltLocked;
  finally
    FLock.Release;
  end;
end;

procedure TMusicSynth.FadeOut(Ms: Integer);
begin
  FLock.Acquire;
  try
    if FPlayer = nil then
      Exit;
    if (Ms <= 0) or (FFade <= 0) then
    begin
      HaltLocked;
      Exit;
    end;
    { From wherever the level is now, so fading out part-way through a fade in
      takes the time asked for rather than jumping. }
    FFadeStep := -FFade / (Ms * (MUSIC_RATE / 1000.0));
    FStopWhenSilent := True;
  finally
    FLock.Release;
  end;
end;

function TMusicSynth.IsPlaying: Boolean;
begin
  FLock.Acquire;
  try
    Result := (FPlayer <> nil)
      and (fluid_player_get_status(FPlayer) = FLUID_PLAYER_PLAYING);
  finally
    FLock.Release;
  end;
end;

procedure TMusicSynth.SetGain(Value: Single);
begin
  if Value < 0 then
    Value := 0;
  if Value > 1 then
    Value := 1;
  FLock.Acquire;
  try
    FGain := Value;
  finally
    FLock.Release;
  end;
end;

procedure TMusicSynth.Render(Dest: PSmallInt; Frames: Integer);
var
  I, C, Sample: Integer;
  Level: Single;
begin
  if Frames <= 0 then
    Exit;
  FLock.Acquire;
  try
    if FSynth = nil then
    begin
      FillChar(Dest^, Frames * MUSIC_CHANNELS * SizeOf(SmallInt), 0);
      Exit;
    end;
    if Length(FScratch) < Frames * MUSIC_CHANNELS then
      SetLength(FScratch, Frames * MUSIC_CHANNELS);
    { Rendered even with nothing playing: it is what advances the player, and
      it lets release tails and effects decay rather than stopping dead. }
    fluid_synth_write_float(FSynth, Frames,
      @FScratch[0], 0, MUSIC_CHANNELS, @FScratch[0], 1, MUSIC_CHANNELS);

    for I := 0 to Frames - 1 do
    begin
      if FFadeStep <> 0 then
      begin
        FFade := FFade + FFadeStep;
        if FFade <= 0 then
        begin
          FFade := 0;
          FFadeStep := 0;
          if FStopWhenSilent then
            HaltLocked;
        end
        else if FFade >= 1 then
        begin
          FFade := 1;
          FFadeStep := 0;
        end;
      end;
      Level := FGain * FFade;
      for C := 0 to MUSIC_CHANNELS - 1 do
      begin
        Sample := Round(FScratch[I * MUSIC_CHANNELS + C] * Level * 32767.0);
        if Sample > 32767 then
          Sample := 32767
        else if Sample < -32768 then
          Sample := -32768;
        Dest[I * MUSIC_CHANNELS + C] := Sample;
      end;
    end;
  finally
    FLock.Release;
  end;
end;

function TMusicSynth.StartDevice: Boolean;
var
  Want, Got: TSDL_AudioSpec;
begin
  Result := FDevice <> 0;
  if Result then
    Exit;
  if SDL_InitSubSystem(SDL_INIT_AUDIO) <> 0 then
  begin
    FLastError := 'SDL audio will not start: ' + SDL_GetError;
    Exit;
  end;
  FillChar(Want, SizeOf(Want), 0);
  Want.freq := MUSIC_RATE;
  Want.format := AUDIO_S16SYS;
  Want.channels := MUSIC_CHANNELS;
  Want.samples := MUSIC_FRAMES_PER_BLOCK;
  Want.callback := @FeedMusic;
  Want.userdata := Self;
  { No allowed changes: SDL converts if the hardware wants something else,
    and Render only ever produces this one format. }
  FDevice := SDL_OpenAudioDevice(nil, 0, @Want, @Got, 0);
  if FDevice = 0 then
  begin
    FLastError := 'SDL_OpenAudioDevice failed: ' + SDL_GetError;
    SDL_QuitSubSystem(SDL_INIT_AUDIO);
    Exit;
  end;
  SDL_PauseAudioDevice(FDevice, 0);
  Result := True;
end;

procedure TMusicSynth.StopDevice;
begin
  if FDevice = 0 then
    Exit;
  { Closing waits for the callback to return, so nothing renders after this. }
  SDL_CloseAudioDevice(FDevice);
  FDevice := 0;
  SDL_QuitSubSystem(SDL_INIT_AUDIO);
end;

end.
