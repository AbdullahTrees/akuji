{ --selftest-log : the log switch.

  The log exists for the run that went wrong, so the parts that decide what
  reaches it have to be right before anyone needs them: the subsystem list is
  parsed as written, a typo is reported rather than silently logging less, a
  subsystem that was not asked for writes nothing, and the previous run's log
  survives the next start. }

unit LogTests;

{$MODE DELPHI}{$H+}

interface

uses
  Classes, SysUtils;

function SelfTestLog(Log: TStrings): Integer;

implementation

uses
  GameLog;

function SelfTestLog(Log: TStrings): Integer;
var
  Bad: Integer;
  Dir, Unknown: string;
  Parsed: TLogSubsystems;
  Lines: TStringList;

  procedure Want(Cond: Boolean; const Msg: string);
  begin
    if not Cond then
    begin
      Log.Add('  FAIL: ' + Msg);
      Inc(Bad);
    end;
  end;

  function Contains(const Needle: string): Boolean;
  var
    I: Integer;
  begin
    for I := 0 to Lines.Count - 1 do
      if Pos(Needle, Lines[I]) > 0 then
        Exit(True);
    Result := False;
  end;

begin
  Result := 0;
  Bad := 0;

  { 1. The subsystem list. }
  Want(ParseLogSubsystems('', Unknown) = LOG_ALL, 'an empty list is not all');
  Want(ParseLogSubsystems('all', Unknown) = LOG_ALL, '"all" is not all');
  Parsed := ParseLogSubsystems(' Music , init ', Unknown);
  Want(Parsed = [lsMusic, lsInit], 'a list with spaces and capitals parsed wrong');
  Want(Unknown = '', 'a valid list reported unknown names');
  Parsed := ParseLogSubsystems('music,sound,vidoe', Unknown);
  Want(Parsed = [lsMusic], 'names that match nothing were taken as something');
  Want(Unknown = 'sound, vidoe', 'typos were not reported: "' + Unknown + '"');
  Log.Add('subsystem lists parse as written, and typos are reported');

  { 2. Only what was asked for is written, and the previous log survives. }
  Dir := IncludeTrailingPathDelimiter(GetTempDir) + 'akuji-logtest';
  ForceDirectories(Dir);
  DeleteFile(IncludeTrailingPathDelimiter(Dir) + LOG_FILE);
  DeleteFile(IncludeTrailingPathDelimiter(Dir) + LOG_PREV_FILE);

  StartLog(Dir, [lsMusic]);
  LogLine(lsMusic, 'first run, music line');
  LogLine(lsVideo, 'first run, video line');
  Want(LogOn(lsMusic) and not LogOn(lsVideo), 'LogOn does not follow the list');
  StopLog;
  Want(not LogOn(lsMusic), 'still logging after StopLog');

  StartLog(Dir, LOG_ALL);
  LogLine(lsInit, 'second run');
  StopLog;

  Lines := TStringList.Create;
  try
    Lines.LoadFromFile(IncludeTrailingPathDelimiter(Dir) + LOG_PREV_FILE);
    Want(Contains('first run, music line'), 'the previous log lost its music line');
    Want(not Contains('first run, video line'),
      'a subsystem that was not asked for was written');
    Want(Contains('  music  '), 'lines do not name their subsystem');
    Lines.LoadFromFile(IncludeTrailingPathDelimiter(Dir) + LOG_FILE);
    Want(Contains('second run'), 'the new log is missing its line');
    Want(not Contains('first run'), 'the new log still holds the old run');
  finally
    Lines.Free;
  end;
  Log.Add('only the named subsystems are written, and the last run is kept');

  { 3. An empty set leaves logging off entirely. }
  StartLog(Dir, []);
  Want(not LogOn(lsInit), 'an empty subsystem set turned logging on');
  StopLog;

  Log.Add('');
  if Bad = 0 then
    Log.Add('OK - the log writes what was asked for and keeps the last run')
  else
  begin
    Log.Add(Format('FAILED - %d check(s)', [Bad]));
    Result := 1;
  end;
end;

end.
