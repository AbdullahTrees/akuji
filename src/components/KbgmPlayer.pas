{ Background-music component used by the main form. AutoLoadMidis is the
  extensionless 15-track playlist; ResolvePath appends `.mid`. Playlist entry
  zero is a MIDI initialization sequence rather than a song.

  Playback is SDL_mixer's. On Windows it hands the file to the system MIDI
  Mapper, which is the same synthesiser this game has always played through, so
  the music sounds the same. Elsewhere SDL_mixer renders MIDI itself through
  Timidity or FluidSynth, which needs a patch set or a soundfont and will not
  sound identical - see NOTICE.md. }

unit KbgmPlayer;

{$MODE DELPHI}{$H+}

interface

uses
  Classes, SysUtils;

const
  { KBGMFadeOut's own arithmetic: twenty volume steps, one every arg*50 ms. }
  KBGM_FADE_MS_PER_SECOND = 1000;
  { Stop modes used when changing or resuming the game. }
  KBGM_STOP_HARD = 0;
  KBGM_STOP_FADE_NEWGAME = 2;

  KBGM_VOLUME_MAX = 10;

type
  TKbgmPlayer = class(TComponent)
  private
    FAutoLoadMidis: TStrings;
    FGameDir: string;
    FMusic: Pointer;             { PMix_Music for the loaded track, or nil }
    FCurrent: Integer;
    FVolume: Integer;
    { Track to restart after an interruption such as a power-up fanfare. }
    FRemembered: string;
    FOpened: Boolean;
    procedure SetAutoLoadMidis(Value: TStrings);
    procedure SetVolumeProp(Value: Integer);
    function ResolvePath(const Name: string): string;
    function IndexOfName(const Name: string): Integer;
    procedure ReleaseTrack;
    procedure ApplyVolume;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    { Opens the mixer. Returns False if there is no device; music is never
      fatal, so callers should carry on regardless. }
    function Open(const AGameDir: string): Boolean;
    procedure Close;

    { PlayName is the primary entry point; Play resolves an AutoLoadMidis
      index. A request for the track already playing RESTARTS it - there is no
      same-track guard, and the stage loader re-asserting the area theme is
      audible for that reason. }
    { FadeSeconds is a duration: zero stops immediately and positive values
      begin a fade of that many seconds. The requested track then starts at
      once either way, so a fade here cuts short rather than completing. }
    procedure PlayName(const Name: string; Loop: Boolean = True);
    procedure Play(Index: Integer; Loop: Boolean = True;
                   FadeSeconds: Integer = 0);
    { Zero stops immediately; positive values fade for that many seconds. }
    procedure StopOrFade(FadeSeconds: Integer);

    { RememberCurrent stores the track name, not its playback position.
      ResumeRemembered restarts that track from the beginning and loops it. }
    procedure RememberCurrent;
    procedure ResumeRemembered;
    procedure Stop;
    procedure FadeOut(MilliSeconds: Integer);
    procedure FadeIn(Index: Integer; MilliSeconds: Integer);
    procedure SetVolume(Volume: Integer);

    function IsPlaying: Boolean;
    function TrackName(Index: Integer): string;

    property Current: Integer read FCurrent;
    property Opened: Boolean read FOpened;

    { Component gain on the same 0..10 scale used by the options screen. }
    property Volume: Integer read FVolume write SetVolumeProp;
  published
    property AutoLoadMidis: TStrings read FAutoLoadMidis write SetAutoLoadMidis;
  end;

implementation

uses
  SDL2, SDL2_mixer;

const
  { SDL_mixer's own mixing rate for the music stream. Native MIDI does not pass
    through it on Windows - the Mapper renders straight to the sound card - but
    the mixer still has to be opened before any music call is legal. }
  MIX_MUSIC_RATE    = 44100;
  MIX_MUSIC_BUFFER  = 2048;

constructor TKbgmPlayer.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FAutoLoadMidis := TStringList.Create;
  FMusic := nil;
  FCurrent := -1;
  FVolume := KBGM_VOLUME_MAX;
  FOpened := False;
end;

destructor TKbgmPlayer.Destroy;
begin
  Close;
  FAutoLoadMidis.Free;
  inherited Destroy;
end;

procedure TKbgmPlayer.SetAutoLoadMidis(Value: TStrings);
begin
  FAutoLoadMidis.Assign(Value);
end;

function TKbgmPlayer.ResolvePath(const Name: string): string;
begin
  Result := '';
  if Name = '' then
    Exit;
  Result := FGameDir + Name + '.mid';
  if not FileExists(Result) then
    Result := '';
end;

function TKbgmPlayer.IndexOfName(const Name: string): Integer;
var
  I: Integer;
begin
  for I := 0 to FAutoLoadMidis.Count - 1 do
    if SameText(FAutoLoadMidis[I], Name) then
      Exit(I);
  Result := -1;
end;

function TKbgmPlayer.TrackName(Index: Integer): string;
begin
  if (Index >= 0) and (Index < FAutoLoadMidis.Count) then
    Result := FAutoLoadMidis[Index]
  else
    Result := '';
end;

function TKbgmPlayer.Open(const AGameDir: string): Boolean;
begin
  Result := FOpened;
  if Result then
    Exit;

  FGameDir := IncludeTrailingPathDelimiter(AGameDir)
              + 'midi' + PathDelim;

  if SDL_InitSubSystem(SDL_INIT_AUDIO) <> 0 then
    Exit(False);

  { Its own device, separate from the effects mixer's. They coexist: the sound
    card mixes them, and on Windows the music does not reach this device at all
    because native MIDI goes to the Mapper. }
  if Mix_OpenAudio(MIX_MUSIC_RATE, AUDIO_S16SYS, 2, MIX_MUSIC_BUFFER) <> 0 then
  begin
    SDL_QuitSubSystem(SDL_INIT_AUDIO);
    Exit(False);
  end;

  FOpened := True;
  ApplyVolume;
  Result := True;
end;

procedure TKbgmPlayer.Close;
begin
  if not FOpened then
    Exit;
  Mix_HaltMusic;
  ReleaseTrack;
  Mix_CloseAudio;
  SDL_QuitSubSystem(SDL_INIT_AUDIO);
  FOpened := False;
  FCurrent := -1;
end;

procedure TKbgmPlayer.ReleaseTrack;
begin
  if FMusic <> nil then
  begin
    Mix_FreeMusic(PMix_Music(FMusic));
    FMusic := nil;
  end;
end;

procedure TKbgmPlayer.ApplyVolume;
begin
  if FOpened then
    Mix_VolumeMusic((FVolume * MIX_MAX_VOLUME) div KBGM_VOLUME_MAX);
end;

procedure TKbgmPlayer.PlayName(const Name: string; Loop: Boolean);
var
  TrackPath: string;
  Loops: Integer;
begin
  if not FOpened then
    Exit;
  TrackPath := ResolvePath(Name);
  if TrackPath = '' then
    Exit;

  { Freeing the old track after loading the new one would double the peak, and
    freeing music that is still playing is what Mix_HaltMusic exists to make
    safe. }
  Mix_HaltMusic;
  ReleaseTrack;

  FMusic := Mix_LoadMUS(PAnsiChar(AnsiString(TrackPath)));
  if FMusic = nil then
  begin
    FCurrent := -1;
    Exit;
  end;

  if Loop then
    Loops := -1
  else
    Loops := 1;

  ApplyVolume;
  if Mix_PlayMusic(PMix_Music(FMusic), Loops) <> 0 then
  begin
    ReleaseTrack;
    FCurrent := -1;
    Exit;
  end;
  FCurrent := IndexOfName(Name);
end;

procedure TKbgmPlayer.Play(Index: Integer; Loop: Boolean;
                           FadeSeconds: Integer);
begin
  if (Index < 0) or (Index >= FAutoLoadMidis.Count) then
    Exit;
  { The default is an immediate stop; a new game requests a two-second fade. }
  StopOrFade(FadeSeconds);
  PlayName(FAutoLoadMidis[Index], Loop);
end;

procedure TKbgmPlayer.StopOrFade(FadeSeconds: Integer);
begin
  if FadeSeconds < 1 then
    Stop
  else
    FadeOut(FadeSeconds * KBGM_FADE_MS_PER_SECOND);
end;

procedure TKbgmPlayer.RememberCurrent;
begin
  { Remember the name rather than a playback position, so resume restarts it. }
  if (FCurrent >= 0) and (FCurrent < FAutoLoadMidis.Count) then
    FRemembered := FAutoLoadMidis[FCurrent]
  else
    FRemembered := '';
end;

procedure TKbgmPlayer.ResumeRemembered;
begin
  if FRemembered = '' then
    Exit;
  StopOrFade(KBGM_STOP_HARD);
  PlayName(FRemembered, True);
end;

procedure TKbgmPlayer.Stop;
begin
  if FOpened then
  begin
    Mix_HaltMusic;
    ReleaseTrack;
  end;
  FCurrent := -1;
end;

procedure TKbgmPlayer.FadeOut(MilliSeconds: Integer);
begin
  if FOpened then
    Mix_FadeOutMusic(MilliSeconds);
  { The track is left loaded: the fade runs on in SDL_mixer's thread and
    freeing it here would pull the music out from under it. Whatever starts
    next halts and releases it. }
  FCurrent := -1;
end;

procedure TKbgmPlayer.FadeIn(Index: Integer; MilliSeconds: Integer);
var
  TrackPath: string;
begin
  if not FOpened then
    Exit;
  if (Index < 0) or (Index >= FAutoLoadMidis.Count) then
    Exit;
  TrackPath := ResolvePath(FAutoLoadMidis[Index]);
  if TrackPath = '' then
    Exit;

  Mix_HaltMusic;
  ReleaseTrack;
  FMusic := Mix_LoadMUS(PAnsiChar(AnsiString(TrackPath)));
  if FMusic = nil then
  begin
    FCurrent := -1;
    Exit;
  end;
  ApplyVolume;
  if Mix_FadeInMusic(PMix_Music(FMusic), -1, MilliSeconds) <> 0 then
  begin
    ReleaseTrack;
    FCurrent := -1;
    Exit;
  end;
  FCurrent := Index;
end;

procedure TKbgmPlayer.SetVolume(Volume: Integer);
begin
  SetVolumeProp(Volume);
end;

procedure TKbgmPlayer.SetVolumeProp(Value: Integer);
begin
  if Value < 0 then Value := 0;
  if Value > KBGM_VOLUME_MAX then Value := KBGM_VOLUME_MAX;
  FVolume := Value;
  ApplyVolume;
end;

function TKbgmPlayer.IsPlaying: Boolean;
begin
  Result := FOpened and (Mix_PlayingMusic <> 0);
end;

end.
