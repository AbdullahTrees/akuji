{ FluidSynth, loaded at run time.

  FluidSynth renders MIDI in software from an instrument bank. That is what
  lets the music play without the operating system's MIDI synthesiser - which
  was the last part of the game's sound that only Windows could provide, and
  whose volume could not be controlled from here at all.

  Loaded dynamically rather than linked, so that a machine without the library
  still starts the game and plays it in silence. Music has never been fatal
  here, and a missing optional library should not be the first thing to make
  it so. Only the calls the music player makes are bound. }

unit FluidSynth;

{$MODE DELPHI}{$H+}

interface

uses
  ctypes;

type
  PFluidSettings = Pointer;
  PFluidSynthInst = Pointer;
  PFluidPlayer = Pointer;
  TFluidLogFunction = procedure(Level: cint; Message: PAnsiChar;
    Data: Pointer); cdecl;

const
  FLUID_OK = 0;
  FLUID_FAILED = -1;

  FLUID_PLAYER_READY = 0;
  FLUID_PLAYER_PLAYING = 1;
  FLUID_PLAYER_STOPPING = 2;
  FLUID_PLAYER_DONE = 3;

  FLUID_PANIC = 0;
  FLUID_ERR = 1;
  FLUID_WARN = 2;
  FLUID_INFO = 3;
  FLUID_DBG = 4;

  { The shared object's name on each platform. Windows takes the copy vendored
    beside the executable; elsewhere it is the system's package. }
  FLUIDSYNTH_LIB =
    {$IFDEF WINDOWS}'libfluidsynth-3.dll'
    {$ELSE}{$IFDEF DARWIN}'libfluidsynth.3.dylib'
    {$ELSE}'libfluidsynth.so.3'{$ENDIF}{$ENDIF};

var
  new_fluid_settings: function: PFluidSettings; cdecl;
  delete_fluid_settings: procedure(Settings: PFluidSettings); cdecl;
  fluid_settings_setnum: function(Settings: PFluidSettings; Name: PAnsiChar;
    Value: cdouble): cint; cdecl;
  fluid_settings_setint: function(Settings: PFluidSettings; Name: PAnsiChar;
    Value: cint): cint; cdecl;

  new_fluid_synth: function(Settings: PFluidSettings): PFluidSynthInst; cdecl;
  delete_fluid_synth: procedure(Synth: PFluidSynthInst); cdecl;
  fluid_synth_sfload: function(Synth: PFluidSynthInst; FileName: PAnsiChar;
    ResetPresets: cint): cint; cdecl;
  fluid_synth_write_float: function(Synth: PFluidSynthInst; Len: cint;
    LOut: Pointer; LOff, LIncr: cint;
    ROut: Pointer; ROff, RIncr: cint): cint; cdecl;
  fluid_synth_all_sounds_off: function(Synth: PFluidSynthInst;
    Channel: cint): cint; cdecl;

  new_fluid_player: function(Synth: PFluidSynthInst): PFluidPlayer; cdecl;
  delete_fluid_player: procedure(Player: PFluidPlayer); cdecl;
  fluid_player_add_mem: function(Player: PFluidPlayer; Buffer: Pointer;
    Len: PtrUInt): cint; cdecl;
  fluid_player_set_loop: function(Player: PFluidPlayer; Loop: cint): cint; cdecl;
  fluid_player_play: function(Player: PFluidPlayer): cint; cdecl;
  fluid_player_stop: function(Player: PFluidPlayer): cint; cdecl;
  fluid_player_get_status: function(Player: PFluidPlayer): cint; cdecl;
  fluid_set_log_function: function(Level: cint; Fun: TFluidLogFunction;
    Data: Pointer): Pointer; cdecl;

{ Loads the library and every entry point above. True once that has
  succeeded; safe to call again. On failure FluidSynthError says which part -
  the library, or the first entry point it lacks. }
function LoadFluidSynth: Boolean;
function FluidSynthError: string;

implementation

uses
  SysUtils, dynlibs;

var
  Lib: TLibHandle = NilHandle;
  LastError: string = '';

function LoadFluidSynth: Boolean;

  function Bind(var Entry: Pointer; const Name: string): Boolean;
  begin
    Entry := GetProcedureAddress(Lib, Name);
    Result := Entry <> nil;
    if not Result then
      LastError := FLUIDSYNTH_LIB + ' has no entry point ' + Name;
  end;

begin
  if Lib <> NilHandle then
    Exit(True);

  Lib := LoadLibrary(FLUIDSYNTH_LIB);
  if Lib = NilHandle then
  begin
    LastError := 'could not load ' + FLUIDSYNTH_LIB;
    Exit(False);
  end;

  Result :=
    Bind(Pointer(@new_fluid_settings), 'new_fluid_settings') and
    Bind(Pointer(@delete_fluid_settings), 'delete_fluid_settings') and
    Bind(Pointer(@fluid_settings_setnum), 'fluid_settings_setnum') and
    Bind(Pointer(@fluid_settings_setint), 'fluid_settings_setint') and
    Bind(Pointer(@new_fluid_synth), 'new_fluid_synth') and
    Bind(Pointer(@delete_fluid_synth), 'delete_fluid_synth') and
    Bind(Pointer(@fluid_synth_sfload), 'fluid_synth_sfload') and
    Bind(Pointer(@fluid_synth_write_float), 'fluid_synth_write_float') and
    Bind(Pointer(@fluid_synth_all_sounds_off), 'fluid_synth_all_sounds_off') and
    Bind(Pointer(@new_fluid_player), 'new_fluid_player') and
    Bind(Pointer(@delete_fluid_player), 'delete_fluid_player') and
    Bind(Pointer(@fluid_player_add_mem), 'fluid_player_add_mem') and
    Bind(Pointer(@fluid_player_set_loop), 'fluid_player_set_loop') and
    Bind(Pointer(@fluid_player_play), 'fluid_player_play') and
    Bind(Pointer(@fluid_player_stop), 'fluid_player_stop') and
    Bind(Pointer(@fluid_player_get_status), 'fluid_player_get_status') and
    Bind(Pointer(@fluid_set_log_function), 'fluid_set_log_function');

  if not Result then
  begin
    UnloadLibrary(Lib);
    Lib := NilHandle;
  end;
end;

function FluidSynthError: string;
begin
  Result := LastError;
end;

end.
