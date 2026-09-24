{ Background-music component used by the main form. AutoLoadMidis is the
  extensionless 15-track playlist; ResolvePath appends `.mid`. Playlist entry
  zero is a MIDI initialization sequence rather than a song.

  The music is rendered in software by FluidSynth from an instrument bank and
  played through an SDL audio device - see MusicSynth. It used to be handed to
  the operating system's MIDI synthesiser through SDL_mixer, which on Windows
  sounded right and could not have its volume changed, and elsewhere did not
  sound right at all.

  THE BANK. soundfonts/gm.dls is the Windows GS sound set, which is what the
  game has always played through, so it is the default and the music sounds as
  it always has. soundfonts/GeneralUser-GS.sf2 is a free GS-style bank shipped
  as the alternative, and as the fallback if the first will not load. Which one
  is chosen in system.ini - see NOTICE.md for where each comes from. }

unit KbgmPlayer;

{$MODE DELPHI}{$H+}

interface

uses
  Classes, SysUtils, MusicSynth;

const
  { KBGMFadeOut's own arithmetic: twenty volume steps, one every arg*50 ms. }
  KBGM_FADE_MS_PER_SECOND = 1000;
  { Stop modes used when changing or resuming the game. }
  KBGM_STOP_HARD = 0;
  KBGM_STOP_FADE_NEWGAME = 2;

  KBGM_VOLUME_MAX = 10;

  { The instrument banks, under the game directory. }
  SOUNDFONT_DIR = 'soundfonts';
  SOUNDFONT_GM_FILE = 'gm.dls';
  SOUNDFONT_GS_FILE = 'GeneralUser-GS.sf2';
  { What system.ini names them. Anything else is taken as a file name under
    the same directory, so another bank can be tried without a rebuild. }
  SOUNDFONT_GM = 'gm';
  SOUNDFONT_GS = 'gs';

type
  TKbgmPlayer = class(TComponent)
  private
    FAutoLoadMidis: TStrings;
    FGameDir: string;
    FSynth: TMusicSynth;
    FCurrent: Integer;
    FVolume: Integer;
    { Track to restart after an interruption such as a power-up fanfare. }
    FRemembered: string;
    FOpened: Boolean;
    FSoundFont: string;
    FEffects: Boolean;
    FLoadedBank: string;
    procedure SetAutoLoadMidis(Value: TStrings);
    procedure SetVolumeProp(Value: Integer);
    function ResolvePath(const Name: string): string;
    function IndexOfName(const Name: string): Integer;
    function BankPath(const Choice: string): string;
    function ReadTrack(const Path: string; out Bytes: TBytes): Boolean;
    procedure ApplyVolume;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    { Loads the chosen instrument bank - falling back to the other if it will
      not load - and opens the music's audio device. Returns False if there is
      no music at all; music is never fatal, so callers carry on regardless,
      and the log says why. }
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
    { The file a playlist entry resolves to, whether or not it exists. Public
      so a test can check the playlist points at real files without opening a
      device: a wrong directory here makes PlayName fail silently, which is
      exactly the shape of defect that is otherwise only audible. }
    function TrackPath(Index: Integer): string;

    property Current: Integer read FCurrent;
    property Opened: Boolean read FOpened;

    { 'gm', 'gs', or a file name under soundfonts/. Set before Open. }
    property SoundFont: string read FSoundFont write FSoundFont;
    { FluidSynth's reverb and chorus. Off is the dry sound the game has always
      had. Set before Open. }
    property Effects: Boolean read FEffects write FEffects;
    { The bank that actually loaded, which is not the one asked for when the
      fallback was needed. Empty before Open or if nothing loaded. }
    property LoadedBank: string read FLoadedBank;
    { The engine, for a test to render from without a device. }
    property Synth: TMusicSynth read FSynth;

    { Component gain on the same 0..10 scale used by the options screen, and
      the same curve SE VOLUME uses: 4.5 dB a step, 0 silent. }
    property Volume: Integer read FVolume write SetVolumeProp;
  published
    property AutoLoadMidis: TStrings read FAutoLoadMidis write SetAutoLoadMidis;
  end;

implementation

uses
  AudioMixer, GameLog;

constructor TKbgmPlayer.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FAutoLoadMidis := TStringList.Create;
  FSynth := TMusicSynth.Create;
  FCurrent := -1;
  FVolume := KBGM_VOLUME_MAX;
  FOpened := False;
  FSoundFont := SOUNDFONT_GM;
end;

destructor TKbgmPlayer.Destroy;
begin
  Close;
  FSynth.Free;
  FAutoLoadMidis.Free;
  inherited Destroy;
end;

procedure TKbgmPlayer.SetAutoLoadMidis(Value: TStrings);
begin
  FAutoLoadMidis.Assign(Value);
end;

function TKbgmPlayer.ResolvePath(const Name: string): string;
var
  RelativePath: string;
begin
  Result := '';
  if Name = '' then
    Exit;
  { Playlist entries carry their own directory and a Windows separator -
    `midi\main01` - so the game directory is all that is prepended. }
  RelativePath := Name;
{$IFNDEF WINDOWS}
  RelativePath := StringReplace(RelativePath, '\', PathDelim, [rfReplaceAll]);
{$ENDIF}
  { Playlist entries are extensionless. }
  if ExtractFileExt(RelativePath) = '' then
    RelativePath := RelativePath + '.mid';
  Result := IncludeTrailingPathDelimiter(FGameDir) + RelativePath;
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

function TKbgmPlayer.TrackPath(Index: Integer): string;
begin
  Result := ResolvePath(TrackName(Index));
end;

function TKbgmPlayer.BankPath(const Choice: string): string;
var
  FileName: string;
begin
  if SameText(Choice, SOUNDFONT_GM) then
    FileName := SOUNDFONT_GM_FILE
  else if SameText(Choice, SOUNDFONT_GS) then
    FileName := SOUNDFONT_GS_FILE
  else
    FileName := Choice;
  Result := IncludeTrailingPathDelimiter(FGameDir) + SOUNDFONT_DIR + PathDelim
            + FileName;
end;

function TKbgmPlayer.ReadTrack(const Path: string; out Bytes: TBytes): Boolean;
var
  Stream: TFileStream;
begin
  Bytes := nil;
  Result := False;
  try
    Stream := TFileStream.Create(Path, fmOpenRead or fmShareDenyNone);
    try
      SetLength(Bytes, Stream.Size);
      if Stream.Size > 0 then
        Stream.ReadBuffer(Bytes[0], Stream.Size);
    finally
      Stream.Free;
    end;
    Result := Length(Bytes) > 0;
  except
    on E: Exception do
      LogFmt(lsMusic, 'cannot read %s: %s', [Path, E.Message]);
  end;
end;

function TKbgmPlayer.Open(const AGameDir: string): Boolean;
var
  Choices: array[0..1] of string;
  I: Integer;
  Path: string;
begin
  Result := FOpened;
  if Result then
    Exit;
  FGameDir := AGameDir;
  FLoadedBank := '';

  { The one asked for, then the other one, so a missing or damaged bank costs
    the preferred sound rather than all of it. }
  Choices[0] := FSoundFont;
  if SameText(FSoundFont, SOUNDFONT_GS) then
    Choices[1] := SOUNDFONT_GM
  else
    Choices[1] := SOUNDFONT_GS;

  LogFmt(lsMusic, 'instrument bank %s, effects %s',
    [FSoundFont, BoolToStr(FEffects, 'on', 'off')]);
  for I := Low(Choices) to High(Choices) do
  begin
    Path := BankPath(Choices[I]);
    if not FileExists(Path) then
    begin
      LogFmt(lsMusic, 'no bank at %s', [Path]);
      Continue;
    end;
    if FSynth.Open(Path, FEffects) then
    begin
      FLoadedBank := Path;
      if I > 0 then
        LogFmt(lsMusic, 'fell back to %s', [Path])
      else
        LogFmt(lsMusic, 'loaded %s', [Path]);
      Break;
    end;
    LogFmt(lsMusic, 'could not use %s: %s', [Path, FSynth.LastError]);
  end;

  if FLoadedBank = '' then
  begin
    LogLine(lsMusic, 'no instrument bank loaded - the game will run without music');
    Exit(False);
  end;

  if not FSynth.StartDevice then
  begin
    LogFmt(lsMusic, 'no audio device for the music: %s', [FSynth.LastError]);
    FSynth.Close;
    FLoadedBank := '';
    Exit(False);
  end;
  LogFmt(lsMusic, 'music device open, %d Hz stereo', [MUSIC_RATE]);

  FOpened := True;
  ApplyVolume;
  Result := True;
end;

procedure TKbgmPlayer.Close;
begin
  if not FOpened then
    Exit;
  FSynth.Close;
  FOpened := False;
  FCurrent := -1;
  LogLine(lsMusic, 'closed');
end;

procedure TKbgmPlayer.ApplyVolume;
begin
  FSynth.SetGain(VolumeToGain(FVolume) / 65536.0);
end;

procedure TKbgmPlayer.PlayName(const Name: string; Loop: Boolean);
var
  Path: string;
  Bytes: TBytes;
begin
  if not FOpened then
    Exit;
  Path := ResolvePath(Name);
  if Path = '' then
    Exit;
  FCurrent := -1;
  if not ReadTrack(Path, Bytes) then
    Exit;
  if not FSynth.Play(Bytes, Loop) then
  begin
    LogFmt(lsMusic, 'could not play %s', [Path]);
    Exit;
  end;
  FCurrent := IndexOfName(Name);
  LogFmt(lsMusic, 'play %s%s', [Name, BoolToStr(Loop, ', looping', '')]);
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
    FSynth.Stop;
  FCurrent := -1;
end;

procedure TKbgmPlayer.FadeOut(MilliSeconds: Integer);
begin
  if FOpened then
  begin
    FSynth.FadeOut(MilliSeconds);
    LogFmt(lsMusic, 'fade out over %d ms', [MilliSeconds]);
  end;
  FCurrent := -1;
end;

procedure TKbgmPlayer.FadeIn(Index: Integer; MilliSeconds: Integer);
var
  Path: string;
  Bytes: TBytes;
begin
  if not FOpened then
    Exit;
  if (Index < 0) or (Index >= FAutoLoadMidis.Count) then
    Exit;
  Path := ResolvePath(FAutoLoadMidis[Index]);
  if Path = '' then
    Exit;
  FCurrent := -1;
  if not ReadTrack(Path, Bytes) then
    Exit;
  if not FSynth.Play(Bytes, True, MilliSeconds) then
  begin
    LogFmt(lsMusic, 'could not play %s', [Path]);
    Exit;
  end;
  FCurrent := Index;
  LogFmt(lsMusic, 'play %s, fading in over %d ms',
    [FAutoLoadMidis[Index], MilliSeconds]);
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
  Result := FOpened and FSynth.IsPlaying;
end;

end.
