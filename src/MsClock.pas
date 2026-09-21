{ Shared millisecond clock for frame limiting and MIDI sequencing.

  BeginMsClock and EndMsClock bracket the period where the clock and Sleep are
  expected to have one-millisecond granularity. They must be called in pairs:
  the timer subsystem is reference-counted, and so is the raised timer
  resolution that Windows needs for Sleep to be accurate. }

unit MsClock;

{$MODE DELPHI}{$H+}

interface

{ A 32-bit millisecond count. It is an elapsed time from an arbitrary origin,
  not a wall clock, so only differences between two readings mean anything.
  DWord subtraction handles the wraparound, which arrives after 49 days. }
function MsNow: DWord;

procedure BeginMsClock;
procedure EndMsClock;

implementation

uses
  SDL2;

function MsNow: DWord;
begin
  Result := SDL_GetTicks;
end;

procedure BeginMsClock;
begin
  SDL_InitSubSystem(SDL_INIT_TIMER);
end;

procedure EndMsClock;
begin
  SDL_QuitSubSystem(SDL_INIT_TIMER);
end;

initialization
  { The clock has to read correctly before anything calls BeginMsClock, because
    the music thread starts timing as soon as it opens a track and does not
    wait for the frame loop. Initialising here rather than lazily also keeps it
    off the threaded path: this runs once, during unit initialization, while
    a lazy check would race the sequencer. }
  SDL_InitSubSystem(SDL_INIT_TIMER);

finalization
  SDL_QuitSubSystem(SDL_INIT_TIMER);

end.
