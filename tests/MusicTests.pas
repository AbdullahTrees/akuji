{ --selftest-music : the music, rendered with no audio device.

  TMusicSynth renders into a buffer on request, so everything the player does
  can be checked by pulling samples out and measuring them: that a bank loads,
  that a track makes sound, that the volume scales it by exactly the curve the
  options screen promises, that 0 is silence, that a fade ends in silence and
  stops, that a once-through track ends and a looping one does not, and that
  the same input renders the same output twice.

  What cannot be checked here is whether it sounds like the Windows
  synthesiser. That was judged by ear. }

unit MusicTests;

{$MODE DELPHI}{$H+}

interface

uses
  Classes, SysUtils;

function SelfTestMusic(Log: TStrings): Integer;

implementation

uses
  Math, FluidSynth, MusicSynth, AudioMixer, KbgmPlayer;

const
  BLOCK = 1024;

type
  TRenderStats = record
    Frames: Integer;
    SumSquares: Double;
    Peak: Integer;
    Checksum: LongWord;
  end;

function ReadBytes(const Path: string): TBytes;
var
  Stream: TFileStream;
begin
  Result := nil;
  if not FileExists(Path) then
    Exit;
  Stream := TFileStream.Create(Path, fmOpenRead or fmShareDenyNone);
  try
    SetLength(Result, Stream.Size);
    if Stream.Size > 0 then
      Stream.ReadBuffer(Result[0], Stream.Size);
  finally
    Stream.Free;
  end;
end;

{ Renders Ms of audio and measures it. }
function RenderFor(Synth: TMusicSynth; Ms: Integer): TRenderStats;
var
  Buf: array[0..BLOCK * MUSIC_CHANNELS - 1] of SmallInt;
  Left, N, I: Integer;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.Checksum := 2166136261;
  Left := Round(Ms * MUSIC_RATE / 1000.0);
  while Left > 0 do
  begin
    N := Min(Left, BLOCK);
    Synth.Render(@Buf[0], N);
    for I := 0 to N * MUSIC_CHANNELS - 1 do
    begin
      Result.SumSquares := Result.SumSquares + Sqr(1.0 * Buf[I]);
      if Abs(Buf[I]) > Result.Peak then
        Result.Peak := Abs(Buf[I]);
      { FNV-1a over the samples, for a render-twice-compare. }
      Result.Checksum := (Result.Checksum xor Word(Buf[I])) * 16777619;
    end;
    Inc(Result.Frames, N);
    Dec(Left, N);
  end;
end;

{ Every .mid in Dir, sorted, so the log reads the same run to run. }
procedure FindAllMidi(const Dir: string; Names: TStringList);
var
  SR: TSearchRec;
begin
  if FindFirst(Dir + '*.mid', faAnyFile, SR) = 0 then
  try
    repeat
      Names.Add(SR.Name);
    until FindNext(SR) <> 0;
  finally
    FindClose(SR);
  end;
  Names.Sort;
end;

function Rms(const S: TRenderStats): Double;
begin
  if S.Frames = 0 then
    Exit(0);
  Result := Sqrt(S.SumSquares / (S.Frames * MUSIC_CHANNELS));
end;

function SelfTestMusic(Log: TStrings): Integer;
var
  GameDir, BankGM, BankGS, Midi: string;
  Bad: Integer;

  procedure Want(Cond: Boolean; const Msg: string);
  begin
    if not Cond then
    begin
      Log.Add('  FAIL: ' + Msg);
      Inc(Bad);
    end;
  end;

  { A synthesiser with nothing behind it. A track rendered straight after
    another is not rendered from the same state - voices, filters and
    oscillators carry on - so every comparison below starts from here. }
  procedure Fresh(Synth: TMusicSynth; Effects: Boolean = False);
  begin
    Want(Synth.Open(BankGM, Effects), 'gm.dls did not load: ' + Synth.LastError);
    Synth.SetGain(1.0);
  end;

  function Track(const Name: string): TBytes;
  begin
    Result := ReadBytes(Midi + Name + '.mid');
    Want(Length(Result) > 0, 'cannot read midi\' + Name + '.mid');
  end;

var
  Synth: TMusicSynth;
  Main01, Item, Bytes: TBytes;
  Full, Half, Silent, Again, Wet, Early, Late: TRenderStats;
  Ratio, WantRatio: Double;
  I: Integer;
  Names: TStringList;
begin
  Result := 0;
  Bad := 0;
  GameDir := IncludeTrailingPathDelimiter(ParamStr(2));
  Midi := GameDir + 'midi' + PathDelim;
  BankGM := GameDir + SOUNDFONT_DIR + PathDelim + SOUNDFONT_GM_FILE;
  BankGS := GameDir + SOUNDFONT_DIR + PathDelim + SOUNDFONT_GS_FILE;
  Log.Add(Format('game dir: %s', [GameDir]));

  if not LoadFluidSynth then
  begin
    Log.Add('FAILED: FluidSynth did not load: ' + FluidSynthError);
    Exit(1);
  end;
  Log.Add('FluidSynth loaded');

  Main01 := Track('main01');
  Item := Track('itemget');

  Synth := TMusicSynth.Create;
  try
    { 1. Both banks load. }
    Want(Synth.Open(BankGS, False), 'GeneralUser GS did not load: ' + Synth.LastError);
    Want(Synth.Open(BankGM, False), 'gm.dls did not load: ' + Synth.LastError);
    Log.Add('both instrument banks load');

    { 2. A track makes sound, without clipping. }
    Want(Synth.Play(Main01, True), 'main01 would not play');
    Full := RenderFor(Synth, 3000);
    Log.Add(Format('main01, first 3 s at full volume: rms %.0f, peak %d',
      [Rms(Full), Full.Peak]));
    Want(Rms(Full) > 300, 'main01 is silent, or nearly');
    Want(Full.Peak < 32767, 'main01 clips in its first 3 s');

    { 3. The same input from the same state renders the same output. What
         the volume and fade checks below compare only means anything if this
         holds. }
    Fresh(Synth);
    Synth.Play(Main01, True);
    Full := RenderFor(Synth, 3000);
    Fresh(Synth);
    Synth.Play(Main01, True);
    Again := RenderFor(Synth, 3000);
    Want(Again.Checksum = Full.Checksum,
      'the same track rendered twice from a fresh start came out different');

    { 4. The volume curve is SE VOLUME's: 4.5 dB a step, applied after
         synthesis, so the ratio is exact. }
    Fresh(Synth);
    Synth.SetGain(VolumeToGain(5) / 65536.0);
    Synth.Play(Main01, True);
    Half := RenderFor(Synth, 3000);
    Ratio := Rms(Half) / Rms(Full);
    WantRatio := VolumeToGain(5) / 65536.0;
    Log.Add(Format('volume 5 of 10: level ratio %.4f, want %.4f (%.1f dB)',
      [Ratio, WantRatio, 20 * Log10(WantRatio)]));
    Want(Abs(Ratio - WantRatio) < 0.01,
      'volume 5 does not scale the music by the SE VOLUME curve');

    Synth.SetGain(VolumeToGain(0) / 65536.0);
    Synth.Play(Main01, True);
    Silent := RenderFor(Synth, 1000);
    Want(Silent.Peak = 0, 'volume 0 is not silent');
    Synth.SetGain(1.0);

    { 5. A once-through track ends; a looping one does not. itemget is 7 s. }
    Synth.Play(Item, False);
    RenderFor(Synth, 9000);
    Want(not Synth.IsPlaying, 'a once-through track is still playing after it ended');
    Synth.Play(Item, True);
    RenderFor(Synth, 9000);
    Want(Synth.IsPlaying, 'a looping track stopped at its end');

    { 6. A fade out ends in silence and stops. }
    Synth.Play(Main01, True);
    RenderFor(Synth, 500);
    Synth.FadeOut(500);
    Want(Synth.IsPlaying, 'a fade stopped the track at once');
    RenderFor(Synth, 550);
    Want(not Synth.IsPlaying, 'the track is still playing after its fade');
    Silent := RenderFor(Synth, 200);
    Want(Silent.Peak = 0, 'there is sound after the fade finished');

    { 7. A fade in is a straight ramp from silence. The same window is
         rendered with and without it, from a fresh start each time, so the
         track's own dynamics cancel out: half-way through a 2 s fade the
         level has to be half. }
    Fresh(Synth);
    Synth.Play(Main01, True);
    RenderFor(Synth, 900);
    Late := RenderFor(Synth, 200);
    Fresh(Synth);
    Synth.Play(Main01, True, 2000);
    RenderFor(Synth, 900);
    Early := RenderFor(Synth, 200);
    Ratio := Rms(Early) / Rms(Late);
    Log.Add(Format('fade in over 2 s: level at 0.9-1.1 s is %.3f of the '
      + 'unfaded level, want 0.500', [Ratio]));
    Want(Abs(Ratio - 0.5) < 0.03, 'the fade in is not a straight ramp');

    { 8. Effects change the sound. }
    Fresh(Synth, True);
    Synth.Play(Main01, True);
    Wet := RenderFor(Synth, 3000);
    Want(Wet.Checksum <> Full.Checksum, 'effects on sounds the same as effects off');
    Log.Add(Format('effects on: rms %.0f against %.0f dry', [Rms(Wet), Rms(Full)]));

    { 9. Every track in the playlist plays and makes sound - except init,
         which is a setup sequence with no notes. }
    Want(Synth.Open(BankGM, False), 'gm.dls did not reload');
    Names := TStringList.Create;
    try
      FindAllMidi(Midi, Names);
      for I := 0 to Names.Count - 1 do
      begin
        Bytes := ReadBytes(Midi + Names[I]);
        Want(Synth.Play(Bytes, False), Names[I] + ' would not play');
        Full := RenderFor(Synth, 5000);
        if SameText(Names[I], 'init.mid') then
          Continue;
        Want(Rms(Full) > 30, Names[I] + ' is silent');
      end;
      Log.Add(Format('%d tracks play', [Names.Count]));
    finally
      Names.Free;
    end;
  finally
    Synth.Free;
  end;

  Log.Add('');
  if Bad = 0 then
    Log.Add('OK - the music renders, scales, fades, loops and ends as it should')
  else
  begin
    Log.Add(Format('FAILED - %d check(s)', [Bad]));
    Result := 1;
  end;
end;

end.
