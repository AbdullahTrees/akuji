{ Build switches shared by every unit that needs them. Included, not
  passed on the command line, so the Lazarus IDE and tools/build.sh agree.

  AKUJI_TOUCH - the on-screen touch controls (TouchControls, TouchArt).
  On for Android, which has no other way to play. Left out of desktop and
  handheld builds, whose players have keys or buttons; tools/build.sh adds
  it there with TOUCH=1, to try the controls with a mouse. }

{$IFDEF ANDROID}
  {$DEFINE AKUJI_TOUCH}
{$ENDIF}
