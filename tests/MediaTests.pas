{ Self-tests for the archive reader, the sound effects, the MIDI playlist and
  the software mixer. }

unit MediaTests;

{$MODE DELPHI}{$H+}

interface

uses
  Classes, SysUtils, TypInfo, Math,
  QdaArchive, SoundTable, WaveFile, AudioMixer, AudioOut, MidiFile, KbgmPlayer,
  Directions, Entities, EventScripts, EventCommands, PlayerState, GameState,
  Stages, Camera, TileMaps, Player, EntityHandlers, EventRunner, GameSession,
  SpritePool, Sprites, Dialogue, BgAnime, UnitInit, Title, Ending, Opening,
  GameFont, DDDDComponent, Surfaces;

function SelfTestArchive(Log: TStrings): Integer;
function SelfTestAudio(Log: TStrings): Integer;
function SelfTestMidi(Log: TStrings): Integer;
function PlayTest(Log: TStrings): Integer;
function MixDump(Log: TStrings): Integer;

implementation

function SelfTestArchive(Log: TStrings): Integer;
var
  Archive: TQdaArchive;
  EntryIndex: Integer;
  RawData: TMemoryStream;
  OutDir: string;
begin
  Result := 0;
  OutDir := '';
  if ParamCount >= 3 then
    OutDir := IncludeTrailingPathDelimiter(ParamStr(3));

  Archive := TQdaArchive.Create(ParamStr(2));
  try
    Log.Add(Format('archive: %s', [ParamStr(2)]));
    Log.Add(Format('entries: %d', [Archive.Count]));
    for EntryIndex := 0 to Archive.Count - 1 do
    begin
      Log.Add(Format('%-18s off=%-9d size=%d',
        [Archive.Entries[EntryIndex].Name, Archive.Entries[EntryIndex].Offset,
         Archive.Entries[EntryIndex].Size]));
      if OutDir <> '' then
      begin
        RawData := TMemoryStream.Create;
        try
          Archive.LoadRaw(EntryIndex, RawData);
          RawData.SaveToFile(OutDir + Archive.Entries[EntryIndex].Name);
        finally
          RawData.Free;
        end;
      end;
    end;
    Log.Add('OK');
  finally
    Archive.Free;
  end;
end;

{ Additive 32-bit checksum over the decoded samples. Cheap, order-sensitive,
  and trivial to reproduce in another language - which is the whole point. }
function SampleChecksum(const Wave: TWaveData): LongWord;
var
  SampleIndex: Integer;
begin
  Result := 0;
  for SampleIndex := 0 to High(Wave.Samples) do
    Result := ((Result shl 1) or (Result shr 31))
      xor LongWord(Word(Wave.Samples[SampleIndex]));
end;

{ --selftest-audio <gamedir> [outdir] : the sound-effect path.

  Decodes all 57 effects and reports the source format of each. If outdir is
  given, the normalised PCM (signed 16-bit mono at MIX_RATE) is written there
  as raw .pcm so tools/decode_wav_ref.py can compare byte for byte. }
function SelfTestAudio(Log: TStrings): Integer;
var
  GameDir, OutDir, Path: string;
  SoundIndex, DecodedCount, MissingCount: Integer;
  CurveBad, Want: Integer;
  Wave: TWaveData;
  Stream: TFileStream;
begin
  Result := 0;
  GameDir := ParamStr(2);
  OutDir := '';
  if ParamCount >= 3 then
    OutDir := IncludeTrailingPathDelimiter(ParamStr(3));

  Log.Add(Format('game dir: %s', [GameDir]));
  Log.Add(Format('table entries: %d   mix rate: %d Hz', [SOUND_COUNT, MIX_RATE]));
  Log.Add('');
  Log.Add('idx name              rate  bits ch  samples     ms  checksum');

  DecodedCount := 0;
  MissingCount := 0;
  for SoundIndex := 0 to SOUND_COUNT - 1 do
  begin
    Path := SoundPath(GameDir, SoundIndex);
    if not LoadWave(Path, Wave) then
    begin
      Log.Add(Format('%3d %-17s MISSING OR UNDECODABLE (%s)',
        [SoundIndex, SoundNames[SoundIndex], Path]));
      Inc(MissingCount);
      Continue;
    end;
    Inc(DecodedCount);
    Log.Add(Format('%3d %-17s %5d %5d %2d %8d %6d  %8.8x',
      [SoundIndex, SoundNames[SoundIndex], Wave.SourceRate, Wave.SourceBits,
       Wave.SourceChannels, Length(Wave.Samples), WaveDurationMs(Wave),
       SampleChecksum(Wave)]));

    if (OutDir <> '') and (Length(Wave.Samples) > 0) then
    begin
      Stream := TFileStream.Create(
        Format('%s%.2d.pcm', [OutDir, SoundIndex]), fmCreate);
      try
        Stream.WriteBuffer(Wave.Samples[0],
          Length(Wave.Samples) * SizeOf(SmallInt));
      finally
        Stream.Free;
      end;
    end;
  end;

  Log.Add('');
  Log.Add(Format('decoded %d of %d, %d missing',
    [DecodedCount, SOUND_COUNT, MissingCount]));
  if DecodedCount = 0 then
    Log.Add('FAILED: nothing decoded at all - wrong game directory?');

  { Report the game's attenuation curve in hundredths of a decibel. }
  Log.Add('');
  Log.Add('volume curve (settings +0x24 -> DirectSound mB -> linear gain):');
  CurveBad := 0;
  for SoundIndex := 0 to VOLUME_MAX do
  begin
    Log.Add(Format('  v=%2d  %6d mB  gain %.5f',
      [SoundIndex, (VOLUME_MAX - SoundIndex) * VOLUME_STEP_MB,
       VolumeToGain(SoundIndex) / 65536.0]));
    { 0 is silent - DIV-023 - and every other step is the original's
      DirectSound attenuation, exactly. }
    if SoundIndex = 0 then
      Want := 0
    else
      Want := Round(65536.0 * Power(10.0,
        ((VOLUME_MAX - SoundIndex) * VOLUME_STEP_MB) / 2000.0));
    if VolumeToGain(SoundIndex) <> Want then
    begin
      Log.Add(Format('  FAIL: v=%d gives gain %d, want %d',
        [SoundIndex, VolumeToGain(SoundIndex), Want]));
      Inc(CurveBad);
    end;
  end;

  if (MissingCount > 0) or (CurveBad > 0) then
    Result := 1
  else
    Log.Add('OK');
end;

{ --selftest-midi <gamedir> : the music path.

  Parses every track in the playlist and reports what the reader made of it.
  The event checksum covers the MERGED stream, so it validates the k-way merge
  and the running-status handling, not just the chunk walk - a parser that
  merged tracks in the wrong order would still report the right event count.
  tools/parse_midi_ref.py recomputes the same numbers independently. }
function SelfTestMidi(Log: TStrings): Integer;
const
  { The playlist normally comes from the form resource. }
  PLAYLIST: array[0..14] of string = (
    'init', 'main01', 'gameover', 'boss01', 'itemget', 'open01', 'end01',
    'main02', 'open02', 'boss02', 'end02', 'soulget', 'end03', 'end04',
    'end05');
var
  GameDir, Path: string;
  TrackIndex, EventIndex, FailedCount: Integer;
  Midi: TMidiFile;
  Player: TKbgmPlayer;
  MidiEvent: TMidiEvent;
  Checksum: LongWord;
begin
  Result := 0;
  GameDir := IncludeTrailingPathDelimiter(ParamStr(2));
  Log.Add(Format('game dir: %s', [GameDir]));
  Log.Add('');
  Log.Add('name        fmt trks  div   events   ms  checksum');

  FailedCount := 0;
  Midi := TMidiFile.Create;
  try
    for TrackIndex := 0 to High(PLAYLIST) do
    begin
      Path := GameDir + 'midi' + PathDelim + PLAYLIST[TrackIndex] + '.mid';
      if not Midi.LoadFromFile(Path) then
      begin
        Log.Add(Format('%-11s PARSE FAILED (%s)',
          [PLAYLIST[TrackIndex], Path]));
        Inc(FailedCount);
        Continue;
      end;

      Checksum := 0;
      for EventIndex := 0 to Midi.Count - 1 do
      begin
        MidiEvent := Midi[EventIndex];
        Checksum := ((Checksum shl 1) or (Checksum shr 31)) xor MidiEvent.Tick;
        Checksum := ((Checksum shl 1) or (Checksum shr 31)) xor MidiEvent.Msg;
        Checksum := ((Checksum shl 1) or (Checksum shr 31))
          xor LongWord(Ord(MidiEvent.Kind));
      end;

      Log.Add(Format('%-11s %3d %4d %4d %8d %6d  %8.8x',
        [PLAYLIST[TrackIndex], Midi.Format, Midi.TrackCount, Midi.Division,
         Midi.Count, Midi.DurationUs div 1000, Checksum]));
    end;
  finally
    Midi.Free;
  end;

  Log.Add('');
  Log.Add(Format('parsed %d of %d',
    [Length(PLAYLIST) - FailedCount, Length(PLAYLIST)]));
  if FailedCount > 0 then
    Result := 1;

  { The playlist the PLAYER resolves, not the one this test builds.

    Everything above composes its own path, so it passes while the component
    looks somewhere else entirely - which is what happened: the player gained a
    second `midi/` in its game directory, every PlayName silently found
    nothing, and the game shipped with no music while this test stayed green.
    Going through TrackPath is what makes the two agree. }
  Player := TKbgmPlayer.Create(nil);
  try
    for TrackIndex := 0 to High(PLAYLIST) do
      Player.AutoLoadMidis.Add('midi\' + PLAYLIST[TrackIndex]);
    { Open assigns the game directory before it touches a device, so the paths
      resolve whether or not this machine has one. }
    Player.Open(ParamStr(2));
    for TrackIndex := 0 to High(PLAYLIST) do
    begin
      Path := Player.TrackPath(TrackIndex);
      if (Path = '') or not FileExists(Path) then
      begin
        Log.Add(Format('FAILED: the player resolves %s to "%s", which is not a file',
          [Player.TrackName(TrackIndex), Path]));
        Inc(Result);
      end;
    end;
    Player.Close;
  finally
    Player.Free;
  end;

  if Result = 0 then
  begin
    Log.Add(Format('the player resolves all %d playlist entries to real files',
      [Length(PLAYLIST)]));
    Log.Add('OK');
  end;
end;

{ --playtest <gamedir> [seconds] opens both audio devices, plays representative
  sound effects, then plays main01. Track 0 is intentionally excluded because
  midi/init.mid contains setup messages but no notes. }
function PlayTest(Log: TStrings): Integer;
const
  { A spread of formats: 8-bit and 16-bit, 11025 and 22050. }
  DEMO: array[0..5] of Integer = (
    SND_PI, SND_OK, SND_NG, SND_JUMP, SND_BELL, SND_POWER01);
var
  GameDir: string;
  Mixer: TAudioMixer;
  Device: TAudioOut;
  Music: TKbgmPlayer;
  I, Secs, MusicVol: Integer;
begin
  Result := 0;
  GameDir := ParamStr(2);
  Secs := 20;
  if ParamCount >= 3 then
    Secs := StrToIntDef(ParamStr(3), 20);
  { The music volume, 0..10. Optional, so that MUSIC VOLUME can be measured
    from outside the process - the title screen plays no music to meter. }
  MusicVol := KBGM_VOLUME_MAX;
  if ParamCount >= 4 then
    MusicVol := StrToIntDef(ParamStr(4), KBGM_VOLUME_MAX);

  Log.Add(Format('game dir: %s', [GameDir]));
  Log.Add('');

  Mixer := TAudioMixer.Create;
  Device := TAudioOut.Create(Mixer);
  Music := TKbgmPlayer.Create(nil);
  try
    Log.Add(Format('effects loaded: %d of %d',
      [Mixer.LoadAll(GameDir), SOUND_COUNT]));

    if not Device.Start then
    begin
      Log.Add('AUDIO DEVICE FAILED: ' + Device.LastError);
      Result := 1;
    end
    else
    begin
      Log.Add('audio device: open');
      Mixer.Volume := VOLUME_MAX;
      for I := Low(DEMO) to High(DEMO) do
      begin
        Log.Add(Format('  playing %2d  %s', [DEMO[I], SoundNames[DEMO[I]]]));
        Mixer.Play(DEMO[I]);
        Sleep(900);
      end;
      { All at once, to prove the mixer really mixes rather than cutting to the
        newest sound. }
      Log.Add('  playing all six together');
      for I := Low(DEMO) to High(DEMO) do
        Mixer.Play(DEMO[I]);
      Sleep(2000);
    end;

    { The playlist normally arrives by streaming the form; there is no form
      here, so fill it the same way the .lfm does. }
    Music.AutoLoadMidis.Add('midi\main01');
    if not Music.Open(GameDir) then
      Log.Add('MIDI DEVICE FAILED: opened=' + BoolToStr(Music.Opened, True))
    else
    begin
      Log.Add('midi device: open');
      Music.Volume := MusicVol;
      Log.Add(Format('  music volume %d of %d', [Music.Volume, KBGM_VOLUME_MAX]));
      Music.Play(0, True);
      { ASSERT, do not announce. This block used to log that it was playing and
        then sleep, which reports success whether or not a note is ever sounded
        - and it did exactly that through a release where the playlist path was
        wrong and the game was silent. }
      if not Music.IsPlaying then
      begin
        Log.Add('FAILED: Play(0) did not start midi\main01 - nothing is playing');
        Inc(Result);
      end
      else
      begin
        Log.Add(Format('  playing midi\main01 for %d seconds', [Secs]));
        Sleep(Secs * 1000);
        if not Music.IsPlaying then
        begin
          Log.Add('FAILED: the track stopped early despite looping');
          Inc(Result);
        end;
        Music.FadeOut(1500);
        Sleep(2000);
        if Music.IsPlaying then
        begin
          Log.Add('FAILED: still playing 2 s after a 1.5 s fade');
          Inc(Result);
        end
        else
          Log.Add('  faded out');
      end;
    end;
  finally
    Music.Free;
    Device.Free;
    Mixer.Free;
  end;

  Log.Add('');
  if Result = 0 then
    Log.Add('OK');
end;

{ --mixdump <gamedir> <out.wav> : render the mixer to a file, no device.

  This splits "the decoder and mixer produce sound" from "the machine plays
  sound", which --playtest cannot: waveOut reports success whether or not
  anything reaches your speakers. If the WAV this writes sounds right in any
  player, everything up to AudioOut is correct and the problem is the device,
  the default output, or the volume. If it is silent, the fault is ours.

  Peak and RMS are reported too, so the log answers the question even without
  listening to the file. }
function MixDump(Log: TStrings): Integer;
const
  DEMO: array[0..5] of Integer = (
    SND_PI, SND_OK, SND_NG, SND_JUMP, SND_BELL, SND_POWER01);
  BLOCK = 1024;                 { frames per mix call }
  TOTAL_SECS = 8;
var
  GameDir, OutName: string;
  Mixer: TAudioMixer;
  Buf: array of SmallInt;
  F: TFileStream;
  TotalFrames, Done, Next, I, Peak, V, Clipped: Integer;
  Sum: Int64;
  DataBytes: LongWord;
  W: LongWord;
  H: Word;

  procedure W32(X: LongWord);
  begin
    F.WriteBuffer(X, 4);
  end;

  procedure W16(X: Word);
  begin
    F.WriteBuffer(X, 2);
  end;

  procedure WTag(const S: string);
  var
    B: array[0..3] of AnsiChar;
  begin
    B[0] := S[1]; B[1] := S[2]; B[2] := S[3]; B[3] := S[4];
    F.WriteBuffer(B, 4);
  end;

begin
  Result := 0;
  GameDir := ParamStr(2);
  OutName := ParamStr(3);
  if OutName = '' then
    OutName := ExtractFilePath(ParamStr(0)) + 'mixdump.wav';

  Log.Add(Format('game dir: %s', [GameDir]));
  Log.Add(Format('writing:  %s', [OutName]));
  Log.Add('');

  Mixer := TAudioMixer.Create;
  try
    Log.Add(Format('effects loaded: %d of %d',
      [Mixer.LoadAll(GameDir), SOUND_COUNT]));
    Mixer.Volume := VOLUME_MAX;

    { Rounded up to a whole number of mix blocks, because the render loop below
      writes whole blocks. Declaring 22050*8 frames and then writing 177152
      leaves the RIFF size fields disagreeing with the file, which some players
      accept and others truncate. }
    TotalFrames := ((MIX_RATE * TOTAL_SECS + BLOCK - 1) div BLOCK) * BLOCK;
    DataBytes := LongWord(TotalFrames) * MIX_CHANNELS * 2;
    SetLength(Buf, BLOCK * MIX_CHANNELS);

    F := TFileStream.Create(OutName, fmCreate);
    try
      { Canonical 44-byte RIFF/WAVE header, 22050 Hz 16-bit stereo. }
      WTag('RIFF');  W32(36 + DataBytes);  WTag('WAVE');
      WTag('fmt ');  W32(16);
      H := 1;              W16(H);                    { PCM }
      H := MIX_CHANNELS;   W16(H);
      W := MIX_RATE;       W32(W);
      W := MIX_RATE * MIX_CHANNELS * 2; W32(W);       { byte rate }
      H := MIX_CHANNELS * 2; W16(H);                  { block align }
      H := 16;             W16(H);                    { bits }
      WTag('data');  W32(DataBytes);

      Peak := 0;
      Sum := 0;
      Done := 0;
      Next := 0;
      Clipped := 0;
      while Done < TotalFrames do
      begin
        { Trigger one effect per second, then all six together at the end. }
        if Done >= Next then
        begin
          I := Next div MIX_RATE;
          if I <= High(DEMO) then
            Mixer.Play(DEMO[I])
          else
            for I := Low(DEMO) to High(DEMO) do
              Mixer.Play(DEMO[I]);
          Inc(Next, MIX_RATE);
        end;

        Mixer.MixInto(@Buf[0], BLOCK);
        F.WriteBuffer(Buf[0], BLOCK * MIX_CHANNELS * 2);

        for I := 0 to BLOCK - 1 do
        begin
          V := Buf[I * MIX_CHANNELS];
          { -32768 has no positive counterpart, so Abs would overflow and
            report 32768 - a peak one above full scale, which looks like a bug
            in the mixer rather than in the meter. Negate the other way. }
          if V < 0 then
            V := -(V + 1);
          if V > Peak then
            Peak := V;
          Sum := Sum + Int64(Buf[I * MIX_CHANNELS]) * Buf[I * MIX_CHANNELS];
          if (Buf[I * MIX_CHANNELS] >= 32767) or
             (Buf[I * MIX_CHANNELS] <= -32768) then
            Inc(Clipped);
        end;
        Inc(Done, BLOCK);
      end;
    finally
      F.Free;
    end;

    Log.Add('');
    Log.Add(Format('rendered %d frames (%.2f s), peak %d of 32767, RMS %.1f',
      [TotalFrames, TotalFrames / MIX_RATE, Peak, Sqrt(Sum / Done)]));
    { Six effects at full volume will sum past full scale. The original summed
      in DirectSound and clipped too, so this is faithful rather than a defect -
      but it should be visible rather than silently absorbed. }
    Log.Add(Format('clipped samples: %d of %d (%.2f%%)',
      [Clipped, Done, (Clipped * 100.0) / Done]));
    if Peak = 0 then
    begin
      Log.Add('SILENT - the fault is in the decoder or mixer, not the device.');
      Result := 1;
    end
    else
    begin
      Log.Add('Non-silent. Play the file above to confirm it sounds right;');
      Log.Add('if it does, decoding and mixing are fine and the device is not.');
    end;
  finally
    Mixer.Free;
  end;

  if Result = 0 then
    Log.Add('OK');
end;

end.
