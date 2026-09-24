{ The game's log: what each subsystem did, and what went wrong.

  Off unless asked for. Two switches turn it on - [log] enabled=on in
  system.ini, or --log on the command line, which needs no file edited and is
  the one to reach for when something has just gone wrong. Either way it
  writes akuji.log beside the executable, and the previous run's log is kept
  as akuji.prev.log, so a run that crashed is not overwritten by the one
  started to look at it.

  Each line is flushed as it is written, so a crash still leaves everything
  up to the moment it happened. Nothing here is called per frame or from the
  audio threads: a log line is a file write, and those belong on the main
  thread at the moments something changes. }

unit GameLog;

{$MODE DELPHI}{$H+}

interface

uses
  Classes, SysUtils;

type
  TLogSubsystem = (
    lsInit,       { startup and shutdown, phase by phase }
    lsVideo,      { SDL video, the window, fullscreen and scaling }
    lsAudio,      { the effects mixer and its device }
    lsMusic,      { FluidSynth, the instrument bank, the music device, tracks }
    lsInput,      { the keyboard bindings and the gamepad }
    lsData,       { finding and loading the game's files }
    lsSettings);  { system.ini and system.dat }
  TLogSubsystems = set of TLogSubsystem;

const
  LOG_ALL: TLogSubsystems = [Low(TLogSubsystem)..High(TLogSubsystem)];
  LOG_FILE = 'akuji.log';
  LOG_PREV_FILE = 'akuji.prev.log';

{ Opens the log in Dir, keeping the previous one, and logs only the named
  subsystems. An empty set, or a directory that cannot be written, leaves
  logging off - a log that cannot be written must not stop the game. }
procedure StartLog(const Dir: string; Subsystems: TLogSubsystems);
procedure StopLog;

function LogOn(Subsystem: TLogSubsystem): Boolean;
procedure LogLine(Subsystem: TLogSubsystem; const Msg: string);
procedure LogFmt(Subsystem: TLogSubsystem; const Fmt: string;
                 const Args: array of const);

{ The subsystems named in a comma-separated list: 'all', or any of init,
  video, audio, music, input, data, settings. An empty list is all of them.
  Names that match nothing are returned in Unknown so they can be logged,
  rather than a typo silently logging less than was asked for. }
function ParseLogSubsystems(const Text: string; out Unknown: string): TLogSubsystems;
function LogSubsystemName(Subsystem: TLogSubsystem): string;

implementation

uses
  SyncObjs;

const
  SUBSYSTEM_NAMES: array[TLogSubsystem] of string =
    ('init', 'video', 'audio', 'music', 'input', 'data', 'settings');

var
  Lock: TCriticalSection = nil;
  LogFile: TextFile;
  LogOpen: Boolean = False;
  Enabled: TLogSubsystems = [];
  StartTicks: QWord = 0;

function LogSubsystemName(Subsystem: TLogSubsystem): string;
begin
  Result := SUBSYSTEM_NAMES[Subsystem];
end;

function ParseLogSubsystems(const Text: string; out Unknown: string): TLogSubsystems;
var
  Parts: TStringList;
  I: Integer;
  Name: string;
  S: TLogSubsystem;
  Found: Boolean;
begin
  Unknown := '';
  if Trim(Text) = '' then
    Exit(LOG_ALL);
  Result := [];
  Parts := TStringList.Create;
  try
    Parts.StrictDelimiter := True;
    Parts.Delimiter := ',';
    Parts.DelimitedText := Text;
    for I := 0 to Parts.Count - 1 do
    begin
      Name := LowerCase(Trim(Parts[I]));
      if Name = '' then
        Continue;
      if Name = 'all' then
      begin
        Result := LOG_ALL;
        Continue;
      end;
      Found := False;
      for S := Low(TLogSubsystem) to High(TLogSubsystem) do
        if SUBSYSTEM_NAMES[S] = Name then
        begin
          Include(Result, S);
          Found := True;
        end;
      if not Found then
      begin
        if Unknown <> '' then
          Unknown := Unknown + ', ';
        Unknown := Unknown + Name;
      end;
    end;
  finally
    Parts.Free;
  end;
end;

procedure StartLog(const Dir: string; Subsystems: TLogSubsystems);
var
  Path, Prev: string;
begin
  StopLog;
  if Subsystems = [] then
    Exit;
  Path := IncludeTrailingPathDelimiter(Dir) + LOG_FILE;
  Prev := IncludeTrailingPathDelimiter(Dir) + LOG_PREV_FILE;
  try
    if FileExists(Path) then
    begin
      if FileExists(Prev) then
        DeleteFile(Prev);
      RenameFile(Path, Prev);
    end;
    AssignFile(LogFile, Path);
    Rewrite(LogFile);
  except
    Exit;
  end;
  LogOpen := True;
  Enabled := Subsystems;
  StartTicks := GetTickCount64;
end;

procedure StopLog;
begin
  if Lock <> nil then
    Lock.Acquire;
  try
    if LogOpen then
    begin
      LogOpen := False;
      try
        CloseFile(LogFile);
      except
      end;
    end;
    Enabled := [];
  finally
    if Lock <> nil then
      Lock.Release;
  end;
end;

function LogOn(Subsystem: TLogSubsystem): Boolean;
begin
  Result := LogOpen and (Subsystem in Enabled);
end;

procedure LogLine(Subsystem: TLogSubsystem; const Msg: string);
begin
  if not LogOn(Subsystem) then
    Exit;
  Lock.Acquire;
  try
    if not LogOpen then
      Exit;
    try
      WriteLn(LogFile, Format('%9.3f  %-8s  %s',
        [(GetTickCount64 - StartTicks) / 1000.0,
         SUBSYSTEM_NAMES[Subsystem], Msg]));
      Flush(LogFile);
    except
      { A full disk ends the log, not the game. }
      LogOpen := False;
    end;
  finally
    Lock.Release;
  end;
end;

procedure LogFmt(Subsystem: TLogSubsystem; const Fmt: string;
  const Args: array of const);
begin
  if LogOn(Subsystem) then
    LogLine(Subsystem, Format(Fmt, Args));
end;

initialization
  Lock := TCriticalSection.Create;

finalization
  StopLog;
  FreeAndNil(Lock);

end.
