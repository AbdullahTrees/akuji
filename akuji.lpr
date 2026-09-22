{ Akuji the Demon application entry point.

  Self-test modes exit before a window is opened; everything they run lives
  in selftests/. }

program akuji;

{$MODE DELPHI}{$H+}



uses
  {$IFDEF UNIX}cthreads,{$ENDIF}
  SDL2,
  GmMain,
  SelfTests;

{ $R *.res  -- re-enable once Lazarus generates akuji.res (icon/manifest) }

{ DIVERGENCE DIV-007: self-test modes exit before the window is created;
  normal startup builds the shell and enters its frame loop. }
begin
  if IsSelfTestMode then
  begin
    ExitCode := RunSelfTest;
    Exit;
  end;

  ExitCode := RunGame;
end.
