{ The game shell: the window, the components it owns, and the frame loop.

  TFrm_main IS NO LONGER A FORM. The name stays, and so do FormDestroy,
  FormKeyDown and FormKeyUp, because the original is a Delphi form called
  TFrm_main with handlers of those names - keeping them keeps the
  correspondence with the binary readable, which is what this port is for.
  What changed is everything underneath: the window is SDL's, the components
  are built here rather than streamed from GmMain.lfm, and the loop is an
  SDL_PollEvent loop instead of Application.OnIdle. }

unit GmMain;

{$MODE DELPHI}{$H+}
{$I akuji.inc}

interface

uses
  Classes, SysUtils, Types, GameColors, SDL2, GameLog, Version,
  DDDDComponent, DDIDComponent, DDSDComponent, KbgmPlayer, GameState,
  IniFiles, QdaArchive, Title, Ending, Opening, GameFont, Surfaces, Sprites, Stages, TileMaps, PlayerState,
  Entities, GameSession, SpritePool, Dialogue, RenderTarget, TextRender,
  Translation, KeyIcons{$IFDEF AKUJI_TOUCH}, TouchControls{$ENDIF};

type
  TFrm_main = class;

  { Form-level adapters connect session services to streamed components. }
  TFormAudio = class(TSessionAudio)
  private
    FForm: TFrm_main;
  public
    constructor Create(AForm: TFrm_main);
    procedure PlayEffect(Id: Integer); override;
    procedure PlayMusic(Track: Integer; Loop: Boolean); override;
    procedure StopMusic; override;
  end;

  TFormStartHost = class(TStartHost)
  private
    FForm: TFrm_main;
  public
    constructor Create(AForm: TFrm_main);
    function Opening: Boolean; override;
    { Starts either the new-game track or the track stored in a save. }
    procedure PlayMusic(Track: Integer; Loop: Boolean;
                        FadeSeconds: Integer); override;
  end;

  TFrm_main = class(TComponent)
  public
    DDDD1: TDDDD;
    Joy: TDDIDEX;
    KbgmPlayer1: TKbgmPlayer;
    DDSD1: TDDSD;

    { Builds the window and the four components, then starts the game the way
      streaming used to: by calling the display component's Initialize, whose
      OnInit is where startup lives. }
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    { The frame loop. Returns when the game has quit. }
    procedure Run;
  private
    FWindow: PSDL_Window;
    FQuit: Boolean;
    FFirstFrameLogged: Boolean;
    { Reads the [log] switch and opens the log - first, before anything that
      could fail, so a start that goes wrong still leaves a trail. }
    procedure StartLogging;
    procedure KeepAlive;
    procedure PumpEvents;
    {$IFDEF AKUJI_TOUCH}
    procedure TouchFinger(const F: TSDL_TouchFingerEvent);
    procedure TouchFrame;
    procedure DrawTouch(Surface: PSDL_Surface);
    {$ENDIF}
    { One frame, when the clock says it is time for one. }
    procedure Frame;
    { True when only Ctrl is held - not Ctrl with Shift or Alt. }
    class function CtrlOnly(Modifiers: Word): Boolean;
  private
    procedure FormDestroy(Sender: TObject);
    procedure FormKeyDown(Key: TSDL_KeyCode; Modifiers: Word);
    procedure FormKeyUp(Key: TSDL_KeyCode);
    procedure DDDD1Init(Sender: TObject);
    procedure TitleSound(Index: Integer);
  private
    FLastFrame: DWord;
    FShakeOffset: Integer; // this frame's Random(0x10) - 8
    FArchive: TQdaArchive;
    FTitleScreen: TTitleScreen;
    FFont: TGameFont;
    FSurfaces: TSurfaceSet;
    FSprites: TSpriteSet;
    FStages: TStageTable;
    FMap: TTileMap;
    FStageLoaded: Integer;
    FStartHost: TStartHost;
    { Session event host; closing the message box advances the script. }
    FDialogue: TDialogueBox;
    { bmp\power.bmp, the panel's backdrop. Loaded once - PowerUp_Show builds
      the surface every time and frees it when the panel closes, which is a
      lifetime detail, not a behaviour. }
    FPowerBmp: TRenderImage;
    FGameOver: TGameOverScreen;
    FPause: TPauseMenu;
    FOpening: TOpeningScreen;
    FTitleSlept: Boolean;
    FEnding: TEndingScreen;
    { Once-per-second debug frame-rate sample. }
    FDebugStamp: DWord;
    FDebugFrames: Integer;
    FDebugFps: Integer;
    FUseArchive: Boolean;
    FEndingBmp: TRenderImage;
    FOpeningBmp: TRenderImage;     { bmp\op%.3d.bmp, one slide at a time }
    FConfirmLatch: Boolean;
    { Owns the active player, entity pool, camera, and event state. }
    FSession: TGameSession;
    FDataDir: string;
    FMoveY: Integer;
    FMoveX: Integer;
    FConfirm: Boolean;
    {$IFDEF AKUJI_TOUCH}
    FTouch: TTouchControls;
    FTouchPrev: TAkujiButtons;
    {$ENDIF}
    { HUD life-icon animation, the three ints at PTR_DAT_0046D320. }
    FLifeAnimX: Integer;
    FLifeAnimIndex: Integer;
    FLifeAnimTimer: Integer;
    function FindGameData: string;
    procedure LoadStage(StageIndex: Integer);
    procedure DrawHud;
    procedure Redraw;
    procedure PollInput;
    procedure InputStep7;
    { The state dispatch is in two halves with the entity update between
      them - see the note in Frame. }
    procedure DispatchPre;
    procedure DispatchPost;

    procedure DrawScene;
    procedure DrawDebugOverlay;
    procedure SetFullScreen(Enable: Boolean);
    { Switch to whatever FullScreenOn now says, for the options row. }
    procedure ApplyFullScreen;
    { Resize the window to the chosen whole-number scale. }
    procedure ApplyWindowScale;
    procedure DrawGameOver;
    { The opening cutscene. Game_StartOrLoad calls Opening_Update every frame
      while the state is 40, and does nothing else until it finishes - which is
      why TStartHost.Opening gates the whole of GameStartOrLoad. }
    function OpeningStep: Boolean;
    procedure OpeningPicture(Id: Integer);
    procedure PlayMusicTrack(Track: Integer; Loop: Boolean;
                             FadeSeconds: Integer);
    { Starts a track immediately for cutscenes and power-up panels. }
    procedure PlayMusicCut(Track: Integer; Loop: Boolean);
    { Stops with a two-second fade before playing the next track. }
    procedure PlayMusicFading(Track: Integer; Loop: Boolean);
    { Save and restore the current music track. }
    procedure RememberMusicTrack;
    procedure ResumeMusicTrack;
    { Dialogue fade adapter for the display component. }
    procedure DialogueStartFade(FadeOut: Boolean);
    function DialogueFadeBusy: Boolean;
    function DialogueMusicBusy: Boolean;
    { Sub-op 80's last phase, which is all form-level work. }
    procedure DialogueSoulGetDone;
    procedure StopMusicTrack;
    procedure OpeningFade(FadeIn: Boolean);
    procedure EndingPicture(Index: Integer);
    procedure EndingPictureNamed(const Name: string);
    procedure DrawEndingCredits;
    procedure DrawEndingStill;
    procedure DrawEndingResults;
    function EndingConfirm: Boolean;
    procedure EndingFade(Step: Integer; FadeOut: Boolean);
    function EndingMusicPlaying: Boolean;
    function EndingFadeBusy: Boolean;
    procedure EndingStopMusicFade(FadeSeconds: Integer);
    procedure DrawEndingSlide;
    procedure EndingMusic(Track: Integer; Loop: Boolean);
    procedure SessionResetHost;
    procedure StageBeginFade;
    procedure TitleVolume;
    procedure TitleMusicVolume;
    function  TitleKeyName(Row: Integer): string;
    function  TitleBindKey(Row: Integer): Boolean;
    procedure TitleLanguage(const Code: string);
    function  TitleKeyHeld: Boolean;
    function  PlaceholderKeyName(Index: Integer): string;
    procedure TitleResetState;
    procedure TitleResetOpening;
    procedure TitleGallery(Slot: Integer);
    procedure TitleInit;
    procedure GameOverRestart;
    procedure GameOverFade(FadeIn: Boolean);
    procedure GameOverMusic(Track: Integer);
    function  GameOverMusicPlaying: Boolean;
    function  EntityWorldFading: Boolean;
  end;

{ Builds the shell, runs it, and tears it down. The process exit code. }
function RunGame: Integer;

implementation

{ Finds game data beside the executable or in the packaged data directory. }
function TFrm_main.FindGameData: string;
const
  { Searched in order, relative to the executable. The first covers a packaged
    build with the data beside the binary; the rest cover running out of the
    source tree, where the binary is in bin/ and the data is in assets/. }
  Candidates: array[0..3] of string = (
    '',
    'assets' + PathDelim,
    '..' + PathDelim + 'assets' + PathDelim,
    '..' + PathDelim + '..' + PathDelim + 'assets' + PathDelim);
var
  BaseDirectory, CandidatePath: string;
  CandidateIndex: Integer;
begin
  BaseDirectory := ExtractFilePath(ParamStr(0));
  for CandidateIndex := Low(Candidates) to High(Candidates) do
  begin
    CandidatePath := BaseDirectory + Candidates[CandidateIndex];
    if FileExists(CandidatePath + 'bmp.qda') then
      Exit(CandidatePath);
  end;
  Result := '';
end;

{ Loads settings, assets, audio, screens, and frame-loop state.

  Two things worth knowing about the settings record:

    * +0x1A, fullscreen, DEFAULTS TO 1. It stands only when system.ini is
      missing - the INI read sets it unconditionally either way.
    * +0x28, the gallery selection, is zeroed AFTER the file is read, so it
      does not persist across a run even though it sits inside the 56 bytes
      written back.

  The title's one-time startup delay is armed after initialization. }
procedure TFrm_main.DDDD1Init(Sender: TObject);
var
  DataDir, Language: string;
  Sheet: TRenderImage;
  Ini: TIniFile;
  I: Integer;
begin
  DataDir := FindGameData;
  if DataDir <> '' then
  begin
    FDataDir := DataDir;
    { The narration font is loaded from the data directory, so the text
      renderer cannot be used until that directory is known. }
    SetFontDirectory(DataDir);

    { Missing or short settings data leaves the initialized defaults intact. }
    if LoadSettings(DataDir) then
      LogLine(lsSettings, 'system.dat loaded')
    else
      LogLine(lsSettings, 'no usable system.dat - starting from defaults');
    KeepAlive;

    { system.ini overrides fullscreen and input-device settings. Compatibility
      requires two parsing details:

        * the fullscreen comparison is case-sensitive,
          so 'ON', 'On' and ' on ' all mean WINDOWED.
        * input uses StrToInt and raises for missing or malformed values.

      The shipped file parses the same either way. }
    { Use the resolved data directory consistently for packaged builds. }
    Ini := TIniFile.Create(DataDir + 'system.ini');
    try
      Settings.FullScreenFlag :=
        Ord(Ini.ReadString('disp', 'fullscreen', '') = 'on');
      Settings.InputDevice :=
        StrToInt(Ini.ReadString('device', 'input', ''));
      { Ours, not the original's: which instrument bank the music uses, and
        whether FluidSynth adds its reverb and chorus. The defaults are the
        sound the game has always had. }
      KbgmPlayer1.SoundFont :=
        Trim(Ini.ReadString('music', 'soundfont', SOUNDFONT_GM));
      KbgmPlayer1.Effects :=
        SameText(Trim(Ini.ReadString('music', 'effects', 'off')), 'on');
      { Ours too: the language, a PO file in lang/ over lang/en.po. }
      Language := Trim(Ini.ReadString('language', 'lang', 'en'));
    finally
      Ini.Free;
    end;
    { Every word the game shows is in those files; without them there is
      nothing to show, so it stops here - in English, the one message that
      cannot come from a language file. }
    if not LoadLanguage(DataDir + 'lang', Language) then
    begin
      SDL_ShowSimpleMessageBox(SDL_MESSAGEBOX_ERROR, 'Akuji the Demon',
        PAnsiChar(AnsiString('No language files: assets/lang/ needs en.po '
          + 'or the language chosen in system.ini.')), FWindow);
      raise Exception.Create('no language files in ' + DataDir + 'lang');
    end;
    if not SameText(LanguageCode, Language) then
      LogFmt(lsData, 'no lang%s%s.po - %s', [PathDelim, Language, LanguageCode])
    else
      LogFmt(lsData, 'language %s', [LanguageCode]);
    SetKeyNameProvider(PlaceholderKeyName);
    if FWindow <> nil then
      SDL_SetWindowTitle(FWindow, PAnsiChar(AnsiString(Tr('window.title'))));
    { Zeroed after the read, so the gallery cursor never persists. }
    Settings.GallerySel := 0;
    SettingsToGlobals;
    LogFmt(lsSettings, 'fullscreen %s, scale %dx, SE volume %d, music volume %d, '
      + 'level %d', [BoolToStr(FullScreenOn, 'on', 'off'), WindowScale,
       Settings.Volume, MusicVolume, Settings.GameLevel]);

    { The bindings are the only copy from here on; FormDestroy writes them
      back into the record just before it is saved. The original kept a second
      copy in a global, which this port never read. }
    Joy.LoadKeyMap(Settings.KeyMap);

    KeepAlive;
    FArchive := TQdaArchive.Create(DataDir + 'bmp.qda');
    LogFmt(lsData, 'bmp.qda: %d pictures', [FArchive.Count]);
    { p_UseArchive, set by DDDD1Init the same way. }
    FUseArchive := True;

    { Load title surfaces, sprites, and font assets. }
    FSurfaces := TSurfaceSet.Create(FArchive);
    FSurfaces.LoadSet(DataDir, 0);
    FSprites := TSpriteSet.Create;
    FSprites.LoadSet(DataDir, 0);

    { Load the stage table once; stage assets are selected from it later. }
    FStages := TStageTable.Create;
    FStages.Load(DataDir);
    LogLine(lsData, 'stage table loaded');
    KeepAlive;
    FMap := TTileMap.Create;
    FStageLoaded := -1;

    { The running game. It borrows the stage table and the map; the form keeps
      owning both, and the surfaces and sprite sheets with them. }
    FSession := TGameSession.Create(DataDir, FStages, FMap);
    { Replace the no-op audio the session builds for itself. The session
      owns the slot, so assigning frees what was there. }
    FSession.Audio := TFormAudio.Create(Self);
    { Game_StartOrLoad's presentation hooks. The concrete host connects the
      opening sequence and playlist operations to the form-owned components. }
    FStartHost := TFormStartHost.Create(Self);
    FDialogue := TDialogueBox.Create;
    FPowerBmp := FArchive.LoadImageByName('power.bmp');
    FSession.EventHost := FDialogue;

    Sheet := FSurfaces.Images[0];
    if Sheet <> nil then
      FFont := TGameFont.Create(Sheet);


    { Effects are loaded up front. Audio initialization failures remain
      non-fatal so the game can run without a sound device. }
    DDSD1.Open(DataDir);
    KeepAlive;
    DDSD1.Volume := Settings.Volume;
    KbgmPlayer1.Open(DataDir);
    KeepAlive;
    KbgmPlayer1.Volume := MusicVolume;
  end;

  { Apply the fullscreen setting after display initialization. }
  SetFullScreen(FullScreenOn);
  ApplyWindowScale;

  FTitleScreen := TTitleScreen.Create;
  FGameOver := TGameOverScreen.Create;
  FPause := TPauseMenu.Create;
  FOpening := TOpeningScreen.Create;
  SetPauseSound(TitleSound);
  FEnding := TEndingScreen.Create;
  FEnding.OnPicture := EndingPicture;
  FEnding.OnMusic := EndingMusic;
  FEnding.OnStopMusic := EndingStopMusicFade;
  FEnding.OnPictureNamed := EndingPictureNamed;
  FEnding.OnSound := TitleSound;
  FEnding.OnConfirm := EndingConfirm;
  FEnding.OnFade := EndingFade;
  FEnding.OnMusicPlaying := EndingMusicPlaying;
  FEnding.OnFadeBusy := EndingFadeBusy;
  { PowerUp_Show's fanfare. The panel closes when this track ends, so without
    it the overlay was waiting on the looping stage music - see Dialogue.pas. }
  FDialogue.OnSound := TitleSound;
  FDialogue.OnMusic := PlayMusicCut;
  FDialogue.OnRememberMusic := RememberMusicTrack;
  FDialogue.OnResumeMusic := ResumeMusicTrack;
  FDialogue.OnStartFade := DialogueStartFade;
  FDialogue.OnFadeBusy := DialogueFadeBusy;
  { Sub-op 12 goes through the FADE wrapper; the power-up fanfare cuts. }
  FDialogue.OnFadeMusic := PlayMusicFading;
  FDialogue.OnMusicBusy := DialogueMusicBusy;
  FDialogue.OnSoulGetDone := DialogueSoulGetDone;
  FOpening.OnPicture := OpeningPicture;
  FOpening.OnMusic := PlayMusicCut;
  FOpening.OnStopMusic := StopMusicTrack;
  FOpening.OnFade := OpeningFade;
  FGameOver.OnRestart := GameOverRestart;
  FGameOver.OnFade := GameOverFade;
  FGameOver.OnMusic := GameOverMusic;
  FGameOver.OnMusicPlaying := GameOverMusicPlaying;
  { Player_Update's soft-landing guard reads the fader. Wired here rather
    than copied into the world each frame - see TEntityWorld.Fading. }
  FSession.World.OnFading := EntityWorldFading;
  { Keep Title.pas independent of the component layer through callbacks. }
  FTitleScreen.OnSound := TitleSound;
  FTitleScreen.OnResetState := TitleResetState;
  FTitleScreen.OnResetOpening := TitleResetOpening;
  FTitleScreen.OnGallery := TitleGallery;
  FTitleScreen.OnVolume := TitleVolume;
  FTitleScreen.OnMusicVolume := TitleMusicVolume;
  FTitleScreen.OnWindowScale := ApplyWindowScale;
  FTitleScreen.OnFullScreen := ApplyFullScreen;
  FTitleScreen.OnKeyName := TitleKeyName;
  FTitleScreen.OnBindKey := TitleBindKey;
  FTitleScreen.OnLanguage := TitleLanguage;
  FTitleScreen.OnKeyHeld := TitleKeyHeld;
  if FDataDir <> '' then
    FTitleScreen.SetLanguages(ListLanguages(FDataDir + 'lang'), LanguageCode);
  FSession.OnStartFade := StageBeginFade;
  FSession.OnResetHost := SessionResetHost;
  { Raise the multimedia timer period before the first frame: without it
    the Sleep(1) below takes about 15.6 ms and caps the rate anyway. }
  BeginFrameClock;
  FLastFrame := FrameClockMs;

  { Initialize global frame-loop state. }
  Randomize;
  FillChar(FSession.Input, SizeOf(FSession.Input), 0);
  EntitiesLive := 0;
  EntitiesDrawn := 0;
  GameStateValue := GS_TITLE_INIT;
  SavedGameState := 0;
  { Arm TitleInit's one-time delay. }
  FTitleSlept := False;
end;

{ DIVERGENCE DIV-001: frame pacing yields between updates instead of spinning. }
{ Runs one frame when the frame clock reaches the target interval, and yields
  the rest of the time. }
procedure TFrm_main.Frame;
var
  Now_, Elapsed: DWord;
begin
  { DWord subtraction intentionally handles the multimedia clock's wraparound. }
  Now_ := FrameClockMs;
  Elapsed := Now_ - FLastFrame;

  { Unconditional. The original let the player turn this off, and doing so
    did not uncap a fixed-rate game - it has no fixed rate, one idle callback
    being one whole frame - it made the game run as fast as the loop went.
    See notes/divergences.md, DIV-018. }
  if Elapsed < FRAME_MS then
  begin
    SDL_Delay(1);    { yield instead of spinning, then come straight back }
    Exit;
  end;
  FLastFrame := Now_;

  {$IFDEF AKUJI_TOUCH}
  TouchFrame;
  {$ENDIF}
  PollInput;              { step 2-3 }
  DDDD1.Clear;
  { The animated background tiles, once a frame and OUTSIDE the state
    dispatch - which is where Frame ticks them, so a wall keeps moving
    behind a dialogue box or a pause. }
  FSession.TickBackground;

  { State handling is split around entity updates so transitions made by the
    pre-dispatch are visible to the post-dispatch in the same frame. }
  FSession.BeginFrame;
  DispatchPre;
  { Event delays tick after script setup and before entity updates. }
  FSession.Runner.TickDelay(FSession.Events, FSession.Player, GameStateValue);
  { Player_Update's SOFT landing sound is suppressed while the screen fades.
    That matters at every door: the transition fades, the player is placed
    standing on the floor as it ends with PF_LANDED clear, and its first update
    would otherwise run the whole just-landed sequence. The hard landing sounds
    either way. }
  FSession.TickEntities(GameStateValue);

  { After Entity_UpdateAll, before anything is drawn. The offset is subtracted
    from every sprite here and ADDED to the tilemap's scroll Y further down, so
    map and sprites shift together. }
  FShakeOffset := 0;
  if ScreenShakeOn then
  begin
    Dec(ScreenShakeTimer);
    FShakeOffset := DelphiRandom(SHAKE_RANGE) - SHAKE_CENTRE;
    if ScreenShakeTimer < 1 then
      ScreenShakeOn := False;
    FSession.Sprites.ShiftY(-FShakeOffset);
  end;
  DispatchPost;
  { Fades pause with the game instead of completing behind the pause menu. }
  if GameStateValue <> GS_PAUSE then
    DDDD1.TickFade;

  { The cancel button enters pause except while paused or editing options -
    on the CONTROLS page it is a key being bound. }
  if (GameStateValue <> GS_PAUSE)
     and not ((GameStateValue = GS_TITLE_MENU)
              and (TitleSubMode in [TSM_OPTIONS, TSM_CONTROLS]))
     and FSession.Input.Button[PAUSE_CANCEL_BUTTON]
     and not FSession.Input.ButtonLatch[PAUSE_CANCEL_BUTTON] then
    EnterPause;

  { Clear one-frame keyboard fallback input after every state has consumed it. }
  FMoveY := 0;
  FMoveX := 0;
  FConfirm := False;

  { Update latches after dispatch so handlers see the previous frame's state. }
  InputStep7;
  DrawDebugOverlay;
  DDDD1.Present;
  if not FFirstFrameLogged then
  begin
    FFirstFrameLogged := True;
    LogLine(lsInit, 'first frame on screen');
  end;
end;

{ Polls the configured controls. Opposing directions cancel to zero. }
{ POLLING ONLY. Everything else about the input belongs to the END of the
  frame, in InputEndOfFrame.

  Moving has to hold the PREVIOUS frame's value while the handlers run,
  because Player_Update's dash tests `Moving = 0 and AxisX <> 0` - set
  Moving from this frame's axes here and those two are contradictory, so
  the dash can never fire at all. The test is an EDGE: a direction is
  pressed now and was not last frame. }
procedure TFrm_main.PollInput;
begin
  Joy.Update;

  FSession.Input.AxisX := Ord(Joy.IsDown(abRight)) - Ord(Joy.IsDown(abLeft));
  FSession.Input.AxisY := Ord(Joy.IsDown(abDown)) - Ord(Joy.IsDown(abUp));

  { The confirm edge the message box needs, taken before Button[0] is
    overwritten below. }
  FConfirmLatch := FSession.Input.Button[0];

  FSession.Input.Button[0] := Joy.IsDown(abJump);
  FSession.Input.Button[1] := Joy.IsDown(abFire);
  FSession.Input.Button[2] := Joy.IsDown(abPause);
  FSession.Input.Button[3] := Joy.IsDown(abAux);

  { AnyPressed includes the first three action buttons. }
  FSession.Input.AnyPressed :=
       (FSession.Input.Button[0] and not FSession.Input.ButtonLatch[0])
    or (FSession.Input.Button[1] and not FSession.Input.ButtonLatch[1])
    or (FSession.Input.Button[2] and not FSession.Input.ButtonLatch[2]);
end;

{ Step 7: edge detection, the repeat timers and the double-tap window. AFTER
  the state handlers, so what they read is the previous frame's. }
procedure TFrm_main.InputStep7;
var
  Down: array[0..3] of Boolean;
begin
  Down[0] := Joy.IsDown(abJump);
  Down[1] := Joy.IsDown(abFire);
  Down[2] := Joy.IsDown(abPause);
  Down[3] := Joy.IsDown(abAux);
  InputEndOfFrame(FSession.Input, Down);
end;

{ Draws the map, sprites, HUD, dialogue, and top sprite layer in order. }
procedure TFrm_main.DrawScene;
begin
  { Draw with the layer's tileset slot, not the stage's surface-set id. }
  if (FMap <> nil) and (FStages <> nil) then
    FMap.Draw(DDDD1.Target, FSurfaces,
              FStages.Tileset[Settings.CurrentStage, 0],
              PixelOf(FSession.Layer.OriginX),
              PixelOf(FSession.Layer.OriginY) + FShakeOffset,
              SCREEN_W, SCREEN_H);
  { The panel covers everything, so it replaces the scene rather than sitting
    on it - PowerUp_Show blits a full 320x240 picture before Overlay_Update
    draws its line. }
  if FDialogue.Active and (FDialogue.Mode = omPanel) then
  begin
    if FPowerBmp <> nil then
      DDDD1.Target.DrawImage(FPowerBmp, 0, 0);
    FDialogue.Draw(DDDD1.Target, FFont, 0);
    Exit;
  end;

  FSession.Sprites.DrawAll(DDDD1.Target, FSurfaces);
  DrawHud;
  FDialogue.Draw(DDDD1.Target, FFont,
                 PixelOf(FSession.Pool.Field(0, EF_POS_Y)));
  { Bucket 8 is reserved for sprites drawn above the HUD and dialogue. }
  FSession.Sprites.DrawTop(DDDD1.Target, FSurfaces);
end;

{ Loads the surface set, sprite set, and primary map named by a stage record.
  Repeated requests for the active stage are ignored. }
procedure TFrm_main.LoadStage(StageIndex: Integer);
var
  SurfaceSetId, SpriteSetId, MapId: Integer;
begin
  if StageIndex = FStageLoaded then Exit;
  if (FStages = nil) or (StageIndex < 0) or (StageIndex >= FStages.Count) then Exit;

  SurfaceSetId := FStages.SurfaceSet[StageIndex];
  SpriteSetId  := FStages.SpriteSet[StageIndex];
  MapId        := FStages.Layer[StageIndex, 0];

  if SurfaceSetId >= 0 then
  begin
    FSurfaces.LoadSet(FDataDir, SurfaceSetId);
    { The font lives in slot 0 of whichever set is current, so it is rebuilt
      when the set changes. }
    FreeAndNil(FFont);
    if FSurfaces.Images[0] <> nil then
      FFont := TGameFont.Create(FSurfaces.Images[0]);
  end;
  if SpriteSetId >= 0 then
    FSprites.LoadSet(FDataDir, SpriteSetId);
  if MapId <> LAYER_NONE then
    FMap.Load(FDataDir, MapId);

  FStageLoaded := StageIndex;
end;

{ Draws entity counts and a once-per-second frame-rate sample when DebugLog is
  enabled.

  The FPS line is a once-a-second SAMPLE, not an average: the frame count is
  latched and zeroed when a second has elapsed, so what is on screen is the
  previous second's total. }
procedure TFrm_main.DrawDebugOverlay;
var
  Now: DWord;
begin
  if not DebugLog then Exit;

  Now := FrameClockMs;
  { DWord, not Int64. Widening the subtraction defeats the wrap: the clock
    rolls over every 49 days and 32-bit arithmetic carries through it,
    where a 64-bit difference goes hugely negative and the counter stops
    updating. }
  if Now - FDebugStamp > 1000 then
  begin
    FDebugFps := FDebugFrames;
    FDebugFrames := 0;
    FDebugStamp := FrameClockMs;
  end;
  Inc(FDebugFrames);

  if FFont = nil then Exit;
  FFont.TextOut(DDDD1.Target, 0, 0,  'FPS:' + IntToStr(FDebugFps));
  FFont.TextOut(DDDD1.Target, 0, 8,  'OBJ:' + IntToStr(EntitiesLive));
  FFont.TextOut(DDDD1.Target, 0, 16, 'S P:' + IntToStr(EntitiesDrawn));
end;

procedure TFrm_main.ApplyFullScreen;
begin
  SetFullScreen(FullScreenOn);
end;

{ The window is sized to an exact multiple of the picture, so that what
  Present works out is that multiple and there is nothing to letterbox.
  Fullscreen owns the window size, so this leaves it alone. }
procedure TFrm_main.ApplyWindowScale;
begin
  if FullScreenOn or (FWindow = nil) then
    Exit;
  if (WindowScale < WINDOW_SCALE_MIN) or (WindowScale > WINDOW_SCALE_MAX) then
    WindowScale := WINDOW_SCALE_MIN;
  SDL_SetWindowSize(FWindow, SCREEN_W * WindowScale, SCREEN_H * WindowScale);
  SDL_SetWindowPosition(FWindow, SDL_WINDOWPOS_CENTERED,
                                 SDL_WINDOWPOS_CENTERED);
  LogFmt(lsVideo, 'window scale %dx, %dx%d', [WindowScale,
    SCREEN_W * WindowScale, SCREEN_H * WindowScale]);
end;

{ Applies fullscreen or restores the fixed-size centred window.

  FULLSCREEN DESKTOP, not a mode change. The original switches the display to
  320x240 at 16 bits; this leaves the desktop where it is and scales the
  picture into it by a whole number, centred, with the rest painted black -
  see DIV-018. Nothing on a modern machine wants its display mode set to
  320x240, and monitors that would accept it are gone.

  The border bug that DIV-019 found is gone with the LCL: an SDL window that
  was never created borderless still has its border when fullscreen is turned
  off, so there is nothing to restore and no archive flag to get wrong. }
procedure TFrm_main.SetFullScreen(Enable: Boolean);
begin
  FullScreenOn := Enable;
  if FWindow = nil then
    Exit;
  LogFmt(lsVideo, 'fullscreen %s', [BoolToStr(Enable, 'on', 'off')]);
  if Enable then
  begin
    SDL_SetWindowFullscreen(FWindow, SDL_WINDOW_FULLSCREEN_DESKTOP);
    SDL_ShowCursor(SDL_DISABLE);
  end
  else
  begin
    SDL_SetWindowFullscreen(FWindow, 0);
    SDL_ShowCursor(SDL_ENABLE);
    SDL_SetWindowSize(FWindow, SCREEN_W * WindowScale,
                               SCREEN_H * WindowScale);
    SDL_SetWindowPosition(FWindow, SDL_WINDOWPOS_CENTERED,
                                   SDL_WINDOWPOS_CENTERED);
  end;
end;

{ One frame of the cutscene. True while it is still running, which is what
  holds GameStartOrLoad at the door. Ten slides, 4726 frames in the trace. }
function TFrm_main.OpeningStep: Boolean;
begin
  { FadeBusy must be the live one: the last phase arms a fade and then holds
    at Opening's 999 sentinel until it lands. A constant False here falls
    through on the same frame and cuts straight to stage 1. }
  Result := FOpening.Update(ConfirmPressed(FSession.Input),
                            KbgmPlayer1.IsPlaying, DDDD1.FadeBusy);
  FOpening.Draw(DDDD1.Target, FFont, FOpeningBmp);
end;

procedure TFrm_main.OpeningPicture(Id: Integer);
begin
  FreeAndNil(FOpeningBmp);
  if FArchive <> nil then
    FOpeningBmp := FArchive.LoadImageByName(Format(OPENING_PICTURE_FMT, [Id]));
end;

procedure TFrm_main.PlayMusicTrack(Track: Integer; Loop: Boolean;
                                   FadeSeconds: Integer);
begin
  KbgmPlayer1.Play(Track, Loop, FadeSeconds);
end;

procedure TFrm_main.PlayMusicCut(Track: Integer; Loop: Boolean);
begin
  PlayMusicTrack(Track, Loop, KBGM_STOP_HARD);
end;

procedure TFrm_main.PlayMusicFading(Track: Integer; Loop: Boolean);
begin
  PlayMusicTrack(Track, Loop, KBGM_STOP_FADE_NEWGAME);
end;

procedure TFrm_main.RememberMusicTrack;
begin
  KbgmPlayer1.RememberCurrent;
end;

procedure TFrm_main.ResumeMusicTrack;
begin
  KbgmPlayer1.ResumeRemembered;
end;

procedure TFrm_main.DialogueStartFade(FadeOut: Boolean);
begin
  { Restore the normal fade step because the ending results screen uses a
    different persistent value. }
  DDDD1.FadeStep := FADE_STEP;
  DDDD1.StartFade(0, FadeOut);
end;

function TFrm_main.DialogueFadeBusy: Boolean;
begin
  Result := DDDD1.FadeBusy;
end;

function TFrm_main.DialogueMusicBusy: Boolean;
begin
  Result := KbgmPlayer1.IsPlaying;
end;

procedure TFrm_main.DialogueSoulGetDone;
begin
  { GameState_Reset(form, 0), the title asset load, and the font - then the
    ending, with the opening's two counters cleared so a later new game does
    not resume mid-cutscene. }
  FSession.ResetState(0);   { first, so a title reached from a running game
                              does not inherit its pool, events or camera }
  LoadStage(0);
  GameStateValue := GS_ENDING;
  FOpening.Reset;
end;

procedure TFrm_main.StopMusicTrack;
begin
  KbgmPlayer1.Stop;
end;

procedure TFrm_main.OpeningFade(FadeIn: Boolean);
begin
  { StartFade takes the inverse FadeOut direction. }
  DDDD1.FadeStep := FADE_STEP;
  DDDD1.StartFade(0, not FadeIn);
end;

constructor TFormAudio.Create(AForm: TFrm_main);
begin
  inherited Create;
  FForm := AForm;
end;

procedure TFormAudio.PlayEffect(Id: Integer);
begin
  FForm.DDSD1.Play(Id);
end;

procedure TFormAudio.PlayMusic(Track: Integer; Loop: Boolean);
begin
  { The fade wrapper - see the note on the class. }
  FForm.PlayMusicTrack(Track, Loop, KBGM_STOP_FADE_NEWGAME);
end;

procedure TFormAudio.StopMusic;
begin
  { Stop immediately without fading. }
  FForm.StopMusicTrack;
end;

constructor TFormStartHost.Create(AForm: TFrm_main);
begin
  inherited Create;
  FForm := AForm;
end;

function TFormStartHost.Opening: Boolean;
begin
  Result := FForm.OpeningStep;
end;

procedure TFormStartHost.PlayMusic(Track: Integer; Loop: Boolean;
                                   FadeSeconds: Integer);
begin
  FForm.PlayMusicTrack(Track, Loop, FadeSeconds);
end;

{ Replaces the current numbered ending slide. A negative index clears it. }
procedure TFrm_main.EndingPicture(Index: Integer);
begin
  FreeAndNil(FEndingBmp);
  if (Index >= 0) and (FArchive <> nil) then
    FEndingBmp := FArchive.LoadImageByName(Format(ENDING_PICTURE_FMT, [Index]));
end;

{ Replaces the ending image with a named full-screen asset. }
procedure TFrm_main.EndingPictureNamed(const Name: string);
begin
  FreeAndNil(FEndingBmp);
  if FArchive <> nil then
    FEndingBmp := FArchive.LoadImageByName(Name);
end;

{ Phase 2, the staff roll: seventeen crops of one sheet, scrolling. Ending.pas
  holds where each one has got to. }
procedure TFrm_main.DrawEndingCredits;
var
  CreditIndex: Integer;
begin
  DDDD1.Target.Fill(Rect(0, 0, SCREEN_W, SCREEN_H), clBlack);
  if FEndingBmp = nil then
    Exit;
  for CreditIndex := 0 to CREDITS_ENTRIES - 1 do
    if FEnding.CreditOnScreen(CreditIndex) then
      DDDD1.Target.BlitRect(FEndingBmp,
        Rect(CREDITS_LAYOUT[CreditIndex][CREDITS_SX],
             CREDITS_LAYOUT[CreditIndex][CREDITS_SY],
             CREDITS_LAYOUT[CreditIndex][CREDITS_SX]
               + CREDITS_LAYOUT[CreditIndex][CREDITS_W],
             CREDITS_LAYOUT[CreditIndex][CREDITS_SY]
               + CREDITS_LAYOUT[CreditIndex][CREDITS_H]),
        FEnding.CreditX(CreditIndex), FEnding.CreditY[CreditIndex]);
end;

{ Phases 3 and 4: one crop of the phase-2 sheet, its right edge growing, drawn
  at the same place each time so the picture fills in. }
procedure TFrm_main.DrawEndingStill;
var
  SourceRight: Integer;
begin
  DDDD1.Target.Fill(Rect(0, 0, SCREEN_W, SCREEN_H), clBlack);
  SourceRight := FEnding.StillRight;
  if (FEndingBmp = nil) or (SourceRight < 0) then
    Exit;
  DDDD1.Target.BlitRect(FEndingBmp,
    Rect(STILL_SRC_LEFT, STILL_SRC_TOP, SourceRight, STILL_SRC_BOTTOM),
    STILL_X, STILL_Y);
end;

{ Phase 5: Option.bmp, then a line a second over it. }
procedure TFrm_main.DrawEndingResults;
var
  RevealedLines, GalleryIndex, SourceX: Integer;
  PlayerState: TPlayerState;
begin
  { Not until phase 5 has loaded its own picture. On the frame phase 4 hands
    over, the loaded picture is still the staff roll's sheet, and drawing it
    full screen flashed the whole sheet for one frame; the original draws
    nothing on that frame. }
  if not FEnding.ResultsShown then
  begin
    DDDD1.Target.Fill(Rect(0, 0, SCREEN_W, SCREEN_H), clBlack);
    Exit;
  end;
  if FEndingBmp <> nil then
    DDDD1.Target.DrawImage(FEndingBmp, 0, 0)
  else
  begin
    DDDD1.Target.Fill(Rect(0, 0, SCREEN_W, SCREEN_H), clBlack);
  end;
  if FFont = nil then
    Exit;

  PlayerState := FSession.Player;
  RevealedLines := FEnding.ResultsRevealed;

  if RevealedLines > 1 then
  begin
    FFont.TextOut(DDDD1.Target, RESULT_TITLE_X, RESULT_TITLE_Y,
                  RESULT_TITLE, RESULT_LABEL_VARIANT);
    FFont.TextOut(DDDD1.Target, RESULT_TITLE_X, RESULT_RULE_Y,
                  RESULT_RULE, RESULT_LABEL_VARIANT);
  end;
  if RevealedLines > 2 then
  begin
    FFont.TextOut(DDDD1.Target, RESULT_LABEL_X, RESULT_TIME_Y,
                  RESULT_TIME_LABEL, RESULT_LABEL_VARIANT);
    FFont.TextOut(DDDD1.Target, RESULT_VALUE_X, RESULT_TIME_Y,
                  EndingTimeText(PlayerState.ElapsedSec), RESULT_VALUE_VARIANT);
  end;
  if RevealedLines > 3 then
  begin
    FFont.TextOut(DDDD1.Target, RESULT_LABEL_X, RESULT_MANA_Y,
                  RESULT_MANA_LABEL, RESULT_LABEL_VARIANT);
    FFont.TextOut(DDDD1.Target, RESULT_VALUE_X, RESULT_MANA_Y,
                  EndingPercentText(PlayerState.Counter), RESULT_VALUE_VARIANT);
  end;
  if (RevealedLines > 4) and (FSurfaces.Images[GALLERY_SURFACE] <> nil) then
    for GalleryIndex := 0 to GALLERY_COUNT - 1 do
    begin
      { A locked entry is the one dark cell; an unlocked one is its own. }
      if PlayerState.Progress[GALLERY_FIRST_FLAG + GalleryIndex] = 0 then
        SourceX := GALLERY_DARK_X
      else
        SourceX := (GalleryIndex + GALLERY_LIT_COL0) * GALLERY_CELL;
      { Keyed: Ending_Update draws both cells with DDBLTFAST_SRCCOLORKEY -
        see notes/divergences.md, DIV-017. This was the last drawing left in
        the game that went straight to a canvas rather than through the
        render target. }
      DDDD1.Target.BlitRectKeyed(FSurfaces.Images[GALLERY_SURFACE],
        Rect(SourceX, GALLERY_SRC_TOP, SourceX + GALLERY_CELL,
             GALLERY_SRC_BOTTOM),
        GalleryIndex * GALLERY_STEP + GALLERY_X0, GALLERY_Y);
    end;
  if RevealedLines > 5 then
    { The rank flickers - its variant is the frame timer mod 3. }
    FFont.TextOut(DDDD1.Target, RANK_X, RANK_Y,
                  FEnding.RankName(PlayerState.Counter, PlayerState.ElapsedSec),
                  FEnding.Timer mod RANK_VARIANTS);
end;

function TFrm_main.EndingConfirm: Boolean;
begin
  Result := ConfirmPressed(FSession.Input);
end;

procedure TFrm_main.EndingFade(Step: Integer; FadeOut: Boolean);
begin
  DDDD1.FadeStep := Step;
  DDDD1.StartFade(0, FadeOut);
end;

function TFrm_main.EndingMusicPlaying: Boolean;
begin
  Result := KbgmPlayer1.IsPlaying;
end;

function TFrm_main.EndingFadeBusy: Boolean;
begin
  Result := DDDD1.FadeBusy;
end;



{ Phase 1, the slide show: the picture at (0x28, 8) and two rows of outlined
  text under it. Ending.pas holds which slide and which words; where they go
  is the host's. The picture is Ending_Update's TDDDD_DrawSprite(.., 0x28, 8,
  0x11, Rect(0, 0, 0xF0, 0xB4)): a 1:1 BltFast with SRCCOLORKEY | WAIT. The
  slides are 240x180 already, so nothing is scaled. }
procedure TFrm_main.DrawEndingSlide;
begin
  DDDD1.Target.Fill(Rect(0, 0, SCREEN_W, SCREEN_H), clBlack);
  if (FEndingBmp <> nil) and (FEnding.SlideImage >= 0) then
    DDDD1.Target.BlitRectKeyed(FEndingBmp,
      Rect(0, 0, ENDING_PIC_W, ENDING_PIC_H), ENDING_PIC_X, ENDING_PIC_Y);
  Game_DrawTextOutlined(ENDING_LINE_X, ENDING_LINE1_Y, FEnding.SlideLine(0),
                        ENDING_TEXT_OUTLINE, ENDING_TEXT_FILL, 10,
                        DDDD1.Target);
  Game_DrawTextOutlined(ENDING_LINE_X, ENDING_LINE2_Y, FEnding.SlideLine(1),
                        ENDING_TEXT_OUTLINE, ENDING_TEXT_FILL, 10,
                        DDDD1.Target);
end;

procedure TFrm_main.EndingMusic(Track: Integer; Loop: Boolean);
begin
  KbgmPlayer1.Play(Track, Loop);
end;

procedure TFrm_main.EndingStopMusicFade(FadeSeconds: Integer);
begin
  KbgmPlayer1.StopOrFade(FadeSeconds);
end;

{ Resets title state and assets; the menu renderer draws the background. }
procedure TFrm_main.TitleInit;
begin
  FSession.ResetState(0);
  { Load_Stage_Assets(Self, nil) - stage 0, which is also what rebuilds the
    font sheet in surface slot 0. }
  FStageLoaded := -1;
  LoadStage(0);

  { Track 0 initializes the MIDI device and runs once. }
  KbgmPlayer1.Play(0, False);

  { ScreenPhase is shared with the game-over screen, the opening and the
    message box, so a title reached from any of them starts mid-phase. }
  ScreenPhase := 0;
  TitleSubMode := 0;
  GameStateValue := GS_TITLE_MENU;

  { Allow the audio device to settle once after startup. }
  if not FTitleSlept then
  begin
    FTitleSlept := True;
    Sleep(TITLE_INIT_SLEEP_MS);
  end;

  { The volume sweep over all 57 effect buffers, which is the last thing it
    does and the reason it comes after the sleep. }
  DDSD1.Volume := Settings.Volume;
end;

{ What Title_MainMenu reaches out for on NEW GAME / CONTINUE, and for the
  gallery. Callbacks so Title.pas stays off the session and the archive. }
{ The options volume row reapplies volume to all effect buffers. }
{ Stage_Begin's first two statements: the fader's step is 4 - which FADE_STEP
  already is - and then FUN_0044DC48(fader, 0, 0), a fade IN. }
{ GameState_Reset also clears the message box and the overlay, which live
  here rather than on the session. }
procedure TFrm_main.SessionResetHost;
begin
  FDialogue.Reset;
end;

procedure TFrm_main.StageBeginFade;
begin
  DDDD1.FadeStep := FADE_STEP;
  DDDD1.StartFade(0, False);
end;

procedure TFrm_main.TitleVolume;
begin
  DDSD1.Volume := Settings.Volume;
end;

procedure TFrm_main.TitleMusicVolume;
begin
  KbgmPlayer1.Volume := MusicVolume;
end;

function TFrm_main.TitleKeyName(Row: Integer): string;
begin
  { The three editable rows are the first three of the four mapped actions. }
  Result := Joy.KeyNameOf(Joy.Bindings[AKUJI_MAPPED[Row]].Primary);
end;

{ A line's key placeholders (Translation.KEY_PLACEHOLDERS): the key bound
  to that action, by the short name the CONTROLS page shows. }
function TFrm_main.PlaceholderKeyName(Index: Integer): string;
const
  { KEY_PLACEHOLDERS' actions, in its order. The directions cannot be rebound
    yet; naming them the same way means the signs need nothing when they can. }
  ACTIONS: array[0..6] of TAkujiButton =
    (abJump, abFire, abPause, abUp, abDown, abLeft, abRight);
var
  Key: TSDL_KeyCode;
begin
  if (Index < Low(ACTIONS)) or (Index > High(ACTIONS)) then
    Exit('');
  Key := Joy.Bindings[ACTIONS[Index]].Primary;
  { A keycap when the sheet has one; the name, as the CONTROLS page shows
    it, when it does not. }
  if KeyIconIndex(Key) >= 0 then
    Result := KeyIconChar(KeyIconIndex(Key))
  else
    Result := ShortKeyName(Joy.KeyNameOf(Key));
end;

function TFrm_main.TitleBindKey(Row: Integer): Boolean;
var
  Key: TSDL_KeyCode;
begin
  { Which keys may be bound, and what happens to whatever held one, is the
    component's business - see TDDIDEX.BindAction. }
  Result := Joy.AnyKeyDown(Key) and Joy.BindAction(AKUJI_MAPPED[Row], Key);
end;

function TFrm_main.TitleKeyHeld: Boolean;
var
  Key: TSDL_KeyCode;
begin
  Result := Joy.AnyKeyDown(Key);
end;

{ The LANGUAGE row. Loaded now, and written back to system.ini - where it is
  read at startup and where a player may set it by hand - so it holds for
  the next run. }
procedure TFrm_main.TitleLanguage(const Code: string);
var
  Ini: TIniFile;
begin
  if FDataDir = '' then
    Exit;
  { The row lists only files that exist, and en.po stays the base, so this
    cannot leave the game with no text. }
  LoadLanguage(FDataDir + 'lang', Code);
  LogFmt(lsSettings, 'language %s', [LanguageCode]);
  if FWindow <> nil then
    SDL_SetWindowTitle(FWindow, PAnsiChar(AnsiString(Tr('window.title'))));
  Ini := TIniFile.Create(FDataDir + 'system.ini');
  try
    Ini.WriteString('language', 'lang', Code);
  finally
    Ini.Free;
  end;
end;

procedure TFrm_main.TitleResetState;
begin
  FSession.ResetState(0);
end;

procedure TFrm_main.TitleResetOpening;
begin
  FOpening.Reset;
end;

{ Loads the selected gallery image. The pictures are numbered from one:
  Title_MainMenu increments the slot before formatting the name (inc ebx at
  0x462C2B), so slot 0 is omake01.bmp. }
procedure TFrm_main.TitleGallery(Slot: Integer);
begin
  FreeAndNil(FEndingBmp);
  if FArchive <> nil then
    FEndingBmp := FArchive.LoadImageByName(Format('omake%.2d.bmp', [Slot + 1]));
end;

{ Form adapters used by the game-over screen. }
procedure TFrm_main.GameOverRestart;
begin
  FSession.ResetState(0);
  { Load_Stage_Assets(MainForm, nil) - stage 0, the placeholder row, which is
    what reloads surface slot 0 and forces the font rebuild below. }
  FStageLoaded := -1;
  LoadStage(0);
end;

function TFrm_main.EntityWorldFading: Boolean;
begin
  Result := DDDD1.FadeBusy;
end;

function TFrm_main.GameOverMusicPlaying: Boolean;
begin
  Result := KbgmPlayer1.IsPlaying;
end;

procedure TFrm_main.GameOverFade(FadeIn: Boolean);
begin
  DDDD1.FadeStep := FADE_STEP;
  DDDD1.StartFade(0, not FadeIn);
end;

procedure TFrm_main.GameOverMusic(Track: Integer);
begin
  KbgmPlayer1.Play(Track, False);
end;

{ Phase 2 of the game-over screen: surface slot 3, whole screen, no HUD. }
procedure TFrm_main.DrawGameOver;
begin
  if FSurfaces.Images[GAMEOVER_SURFACE] <> nil then
    DDDD1.Target.DrawImage(FSurfaces.Images[GAMEOVER_SURFACE], 0, 0);
end;

{ HUD counter, elapsed time, and animated life icons. }
const
  { Life-icon ping-pong animation. }
  LIFE_ANIM_X: array[0..3] of Integer = (19, 38, 57, 38);
  LIFE_ANIM_TICKS = 8;      { advances once the timer passes 8 }
  LIFE_ICON_W = $12;        { 0x86 - 0x74 }
  LIFE_ICON_H = $14;
  LIFE_ICON_X0 = $74;       { source x of the unlit icon }
  LIFE_ICON_Y = 8;          { on screen }
  LIFE_ICON_STEP = $10;

  { Counter goals selected by Player.TargetIndex. }
  COUNTER_TARGETS: array[0..11] of Integer =
    (20, 50, 70, 130, 160, 400, 999, 30, 90, 270, 999, 0);

procedure TFrm_main.DrawHud;
var
  Secs, I, Target: Integer;
  Sheet: TRenderImage;
begin
  if FFont = nil then Exit;
  { Keyed, as HUD_Draw passes DDBLTFAST_SRCCOLORKEY for all three of these -
    see notes/divergences.md, DIV-017. }
  Sheet := FSurfaces.Images[1];

  { Draw the counter icon followed by its '@ ' glyph and values. }
  if Sheet <> nil then
    DDDD1.Target.BlitRectKeyed(Sheet, Rect($60, 0, $74, 10), 7, $12);

  Target := 0;
  if (FSession.Player.TargetIndex >= 0) and
     (FSession.Player.TargetIndex <= High(COUNTER_TARGETS)) then
    Target := COUNTER_TARGETS[FSession.Player.TargetIndex];
  { The padded format aligns both values; Trim removes its outer padding before
    the '@ ' prefix is added. }
  FFont.TextOut(DDDD1.Target, 8, $20,
    '@ ' + Trim(Format('%3d/%-3d', [FSession.Player.Counter, Target])), 0);

  { Labels and digits use separate font variants. }
  FFont.TextOut(DDDD1.Target, $D0, $E0, 'TIME', 2);
  Secs := FSession.Player.ElapsedSec;
  FFont.TextOut(DDDD1.Target, $F8, $E0,
    Format('%.2d:%.2d:%.2d', [Secs div 3600, (Secs div 60) mod 60, Secs mod 60]), 0);

  { Life-icon animation advances only while the HUD is drawn. }
  Inc(FLifeAnimTimer);
  if FLifeAnimTimer > LIFE_ANIM_TICKS then
  begin
    FLifeAnimTimer := 0;
    FLifeAnimIndex := (FLifeAnimIndex + 1) and 3;
    FLifeAnimX := LIFE_ANIM_X[FLifeAnimIndex];
  end;

  { Normalize invalid life counts loaded from save data. }
  if FSession.Player.Lives < 0 then
    FSession.Player.Lives := 0;
  if FSession.Player.MaxLives < FSession.Player.Lives then
    FSession.Player.Lives := FSession.Player.MaxLives;

  if Sheet = nil then Exit;
  { Lit icons run 1..Lives, unlit ones Lives+1..MaxLives, both at i*0x10 + 9. }
  for I := 1 to FSession.Player.Lives do
    DDDD1.Target.BlitRectKeyed(Sheet,
      Rect(FLifeAnimX + LIFE_ICON_X0, 0,
           FLifeAnimX + LIFE_ICON_X0 + LIFE_ICON_W, LIFE_ICON_H),
      I * LIFE_ICON_STEP + 9, LIFE_ICON_Y);
  for I := FSession.Player.Lives + 1 to FSession.Player.MaxLives do
    DDDD1.Target.BlitRectKeyed(Sheet,
      Rect(LIFE_ICON_X0, 0, LIFE_ICON_X0 + LIFE_ICON_W, LIFE_ICON_H),
      I * LIFE_ICON_STEP + 9, LIFE_ICON_Y);
end;

{ Sound requests from the title screen. See notes/audio_map.md for which index
  is which. }
procedure TFrm_main.TitleSound(Index: Integer);
begin
  DDSD1.Play(Index);
end;

{ Step 5: the state machine. }
{ The arms that run BEFORE the entity update. }
procedure TFrm_main.DispatchPre;
begin
  case GameStateValue of
    GS_TITLE_INIT:
      { Initialize title state, music, and effect volume. }
      TitleInit;
    GS_STAGE_BEGIN:
      begin
        { Load form-owned assets before session terrain, events, camera, and
          player setup consume them. }
        LoadStage(Settings.CurrentStage);
        FSession.SetFrames(FSprites);
        { Configure terrain, background animation, and event scripts. }
        FSession.LoadStageAssets(Settings.CurrentStage);
        FSession.BeginStage(Settings.CurrentStage, GameStateValue);
        FDialogue.Bind(FSession.Events, FSession.Runner, @FSession.Player,
                       FSession.Pool, FSession.World);
        { Sub-op 14 modifies the primary tile map. }
        FDialogue.Map := FMap;
        { Stage_Begin hands the box drawer p_Surfaces[1] with its origin
          at (0,0) - FUN_0044DE18. }
        if FSurfaces <> nil then
          FDialogue.FrameSheet := FSurfaces.Images[BOX_SHEET_SLOT];
        FDialogue.SaveFileName := FDataDir + 'data' + PathDelim + 'save.dat';
      end;
    GS_PLAY,
    GS_STATE_140:
      { Event spawning and script execution precede the entity update and
        continue while a message box is active. }
      FSession.TickPre(GameStateValue);
  end;
end;

{ The arms that run AFTER it. }
procedure TFrm_main.DispatchPost;
var
  Mode: TStartMode;
begin
  case GameStateValue of
    { AFTER the entity update: frame 1 of a real session runs Title_Init,
      then Entity_UpdateAll, then Title_MainMenu. Both arms in one frame,
      because Title_Init sets the state to 20 before this dispatch reads it -
      which is also why the very first frame draws the menu rather than
      showing a blank one. }
    GS_TITLE_MENU:
      begin
        { DRAW FIRST, THEN INPUT - the order inside Title_MainMenu, where
          each sub-mode arm draws and only then reads the stick.

          It matters because TitleSubMode is OVERLOADED: on NEW GAME or
          CONTINUE the menu arm stores MenuIndex into it to carry the choice
          into state 40, reusing the variable that means OPTIONS here. Update
          first and the options screen appears for one frame on the way into
          CONTINUE.

          It also makes the cursor lag by design - the highlight drawn is the
          position BEFORE this frame's input. }
        FTitleScreen.Draw(DDDD1.Target, FFont, FSurfaces.Images[1], FSurfaces.Images[2],
                          FEndingBmp);
        FTitleScreen.Update(FMoveY, FMoveX, FConfirm);
      end;
    GS_PLAYER_INIT:
      begin
        { Apply new-game or saved state, music, unlocks, and opening flow. }
        if FTitleScreen.SubMode = 1 then
          Mode := smContinue
        else
          Mode := smNewGame;
        GameStartOrLoad(FSession.Player, Settings, Mode, FStartHost, True,
                        FDataDir + 'data' + PathDelim + 'save.dat',
                        GameStateValue);
      end;
    { GS_PLAY_ALT hosts the game-over phase machine. }
    GS_PLAY_ALT:
      begin
        { Query live fade state so phase transitions wait for each dissolve. }
        if FGameOver.Update(DDDD1.FadeBusy,
                            ConfirmPressed(FSession.Input), GameStateValue) then
          DrawGameOver;
      end;
    GS_PLAY,
    GS_STATE_140:
      begin
        { While an overlay is active it drives script advancement. }
        if FDialogue.Active then
        begin
          { Dialogue is dismissed by input; the power-up panel closes when its
            fanfare ends.

            The session does NOT stop while the box is up - entities keep
            updating through a conversation. What stops is
            Entity_PlayerTouch, and that gating belongs to the handlers. }
          if FDialogue.Mode = omPanel then
            FDialogue.Update(not KbgmPlayer1.IsPlaying, FSession.Input,
                             GameStateValue)
          else
            FDialogue.Update(FSession.Input.Button[0] and not FConfirmLatch,
                             FSession.Input, GameStateValue);
        end;
        DrawScene;
      end;
    GS_PAUSE:
      begin
        { Draw the pause menu over a cleared screen, not the frozen scene. }
        FPause.Update(FSession.Input, GameStateValue);
        FPause.Draw(DDDD1.Target, FFont, SCREEN_W, SCREEN_H);
      end;
    GS_ENDING:
      begin
        FEnding.Update(Settings, FSession.Player, GameStateValue);
        { The ending owns the whole screen: slide show, staff roll, stills,
          and the results panel. }
        case ScreenPhase of
          1:    DrawEndingSlide;
          2:    DrawEndingCredits;
          3, 4: DrawEndingStill;
          5:    DrawEndingResults;
        end;
      end;
    GS_QUIT:
      FQuit := True;
  end;
end;

{ The window's own repaints - uncovered, restored, resized, or coming back
  from fullscreen. Present draws the same offscreen surface the frame loop
  does, so what the window shows is whatever the last frame drew rather than
  whatever was underneath it. }
procedure TFrm_main.Redraw;
begin
  DDDD1.Present;
end;

{ Two intentional input details:
  Escape while ALREADY paused quits rather than resuming - resuming is the
  pause menu's own PAUSE_CONTINUE entry - and Ctrl+R compares Shift for
  EQUALITY with $04, so Ctrl+Shift+R deliberately does not fire, which is
  why this asks for Ctrl ALONE rather than Ctrl among whatever else is held. }
class function TFrm_main.CtrlOnly(Modifiers: Word): Boolean;
const
  { Caps lock, num lock and the mode key are left out of the comparison, as
    they are left out of the TShiftState the original compared. }
  CHORD = KMOD_CTRL or KMOD_SHIFT or KMOD_ALT or KMOD_GUI;
begin
  Result := ((Modifiers and KMOD_CTRL) <> 0)
        and ((Modifiers and CHORD and not KMOD_CTRL) = 0);
end;

procedure TFrm_main.FormKeyDown(Key: TSDL_KeyCode; Modifiers: Word);
begin
  if Key = SDLK_ESCAPE then
  begin
    if GameStateValue = GS_PAUSE then
    begin
      GameStateValue := GS_QUIT;
      Exit;
    end;
    EnterPause;
  end;

  if (Key = SDLK_r) and CtrlOnly(Modifiers) then
    GameStateValue := GS_TITLE_INIT;

  { DIVERGENCE DIV-002: menus also accept raw key input here rather than
    reading the bound buttons. The keys are the same ones the LCL path named,
    now said in SDL's terms; that a rebound JUMP does not also rebind what
    confirms a menu is what retiring DIV-002 would fix. }
  case Key of
    SDLK_UP:                 FMoveY := -1;
    SDLK_DOWN:               FMoveY := 1;
    SDLK_LEFT:               FMoveX := -1;
    SDLK_RIGHT:              FMoveX := 1;
    SDLK_RETURN, SDLK_SPACE,
    SDLK_z:                  FConfirm := True;
  end;
  Joy.KeyDown(Key);
end;

procedure TFrm_main.FormKeyUp(Key: TSDL_KeyCode);
begin
  Joy.KeyUp(Key);
end;

{ Saves runtime settings and releases form-owned resources. }
procedure TFrm_main.FormDestroy(Sender: TObject);
begin
  { Give the multimedia timer period back - raising it is process-wide. }
  EndFrameClock;
  { Before the save, not after: SaveSettings writes the record as it stands. }
  Joy.StoreKeyMap(Settings.KeyMap);
  LogLine(lsInit, 'shutting down');
  if FDataDir <> '' then
    if SaveSettings(FDataDir) then
      LogLine(lsSettings, 'system.dat saved')
    else
      LogLine(lsSettings, 'could not save system.dat');
  FFont.Free;
  FTitleScreen.Free;
  { FDialogue is the session's EventHost, and the session DOES own it - so it
    goes with the session and must not be freed again here. }
  FSession.Free;
  FDialogue := nil;
  FPowerBmp.Free;
  FreeAndNil(FOpeningBmp);
  FStartHost.Free;
  FMap.Free;
  FStages.Free;
  FSprites.Free;
  FSurfaces.Free;
  FArchive.Free;
  { Stop the audio device before the component tree is torn down - the feed
    thread holds a pointer to the mixer. }
  KbgmPlayer1.Close;
  DDSD1.Close;
  { FGameOver, FPause, FOpening, and FEnding live for the process lifetime. }
end;

{ ---------------------------------------------------------------- the shell }

constructor TFrm_main.Create(AOwner: TComponent);
const
  { What GmMain.lfm used to carry, kept together and named so that the
    correspondence with the original's form resource stays readable. }
  SE_CHANNELS = 57;
  AUTO_LOAD_MIDIS =
    'midi\init'#10'midi\main01'#10'midi\gameover'#10'midi\boss01'#10 +
    'midi\itemget'#10'midi\open01'#10'midi\end01'#10'midi\main02'#10 +
    'midi\open02'#10'midi\boss02'#10'midi\end02'#10'midi\soulget'#10 +
    'midi\end03'#10'midi\end04'#10'midi\end05';
var
  SdlVersion: TSDL_Version;
  WindowSurface: PSDL_Surface;
begin
  inherited Create(AOwner);
  StartLogging;

  {$IFDEF AKUJI_TOUCH}
  {$IFNDEF ANDROID}
  { A desktop build with the touch controls is for trying them: the mouse
    plays a finger. }
  SDL_SetHint(SDL_HINT_MOUSE_TOUCH_EVENTS, '1');
  {$ENDIF}
  FTouch := TTouchControls.Create;
  {$ENDIF}

  { The video subsystem, which the renderer never needed - it draws into
    surfaces - but a window does. }
  if SDL_InitSubSystem(SDL_INIT_VIDEO) <> 0 then
  begin
    LogFmt(lsVideo, 'SDL video will not start: %s', [SDL_GetError]);
    raise Exception.CreateFmt('SDL video will not start: %s', [SDL_GetError]);
  end;
  SDL_GetVersion(@SdlVersion);
  LogFmt(lsVideo, 'SDL %d.%d.%d, video driver %s',
    [SdlVersion.major, SdlVersion.minor, SdlVersion.patch,
     SDL_GetCurrentVideoDriver]);

  { Titled once the language files are read, in DDDD1Init. }
  FWindow := SDL_CreateWindow('',
                              SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED,
                              SCREEN_W, SCREEN_H, SDL_WINDOW_SHOWN);
  if FWindow = nil then
  begin
    LogFmt(lsVideo, 'no window: %s', [SDL_GetError]);
    raise Exception.CreateFmt('no window: %s', [SDL_GetError]);
  end;
  LogFmt(lsVideo, 'window created, %dx%d', [SCREEN_W, SCREEN_H]);
  { Black from the start, rather than whatever the system paints a new window
    with until the first frame is presented. }
  WindowSurface := SDL_GetWindowSurface(FWindow);
  if WindowSurface <> nil then
  begin
    SDL_FillRect(WindowSurface, nil, SDL_MapRGB(WindowSurface^.format, 0, 0, 0));
    SDL_UpdateWindowSurface(FWindow);
  end;

  DDDD1 := TDDDD.Create(Self);
  DDDD1.InitialScreenWidth := SCREEN_W;
  DDDD1.InitialScreenHeight := SCREEN_H;
  DDDD1.BackColor := clBlack;
  DDDD1.DisableScreenSaver := True;
  DDDD1.Window := FWindow;
  DDDD1.OnInit := DDDD1Init;
  {$IFDEF AKUJI_TOUCH}
  DDDD1.OnOverlay := DrawTouch;
  {$ENDIF}

  Joy := TDDIDEX.Create(Self);

  DDSD1 := TDDSD.Create(Self);
  DDSD1.ChannelCount := SE_CHANNELS;

  KbgmPlayer1 := TKbgmPlayer.Create(Self);
  KbgmPlayer1.AutoLoadMidis.Text := AUTO_LOAD_MIDIS;

  { Streaming used to do this from Loaded, once the .lfm properties were in.
    They are in, so this is the same moment. }
  DDDD1.Initialize;
  LogLine(lsInit, 'startup complete');
end;

{ Start-up loads for a while before the frame loop runs; on a cold start,
  long enough for Windows to mark a window that has not answered for five
  seconds "(Not Responding)". Taking its messages between the steps keeps it
  answering. Only messages are taken - input is left queued for the game. }
procedure TFrm_main.KeepAlive;
begin
  SDL_PumpEvents;
end;

procedure TFrm_main.StartLogging;
var
  Dir, Unknown: string;
  Ini: TIniFile;
  Want: Boolean;
  Parts: TLogSubsystems;
  I: Integer;
begin
  Want := False;
  Parts := LOG_ALL;
  Unknown := '';
  Dir := FindGameData;
  if Dir <> '' then
  begin
    Ini := TIniFile.Create(Dir + 'system.ini');
    try
      Want := SameText(Trim(Ini.ReadString('log', 'enabled', 'off')), 'on');
      Parts := ParseLogSubsystems(Ini.ReadString('log', 'subsystems', 'all'),
                                  Unknown);
    finally
      Ini.Free;
    end;
  end;
  { The switch that needs no file edited: everything, this run only. }
  for I := 1 to ParamCount do
    if ParamStr(I) = '--log' then
    begin
      Want := True;
      Parts := LOG_ALL;
    end;
  if not Want then
    Exit;

  StartLog(ExtractFilePath(ParamStr(0)), Parts);
  LogFmt(lsInit, '%s %s, started %s',
    [APP_NAME, APP_VERSION, FormatDateTime('yyyy-mm-dd hh:nn:ss', Now)]);
  LogFmt(lsInit, 'executable %s', [ParamStr(0)]);
  if ProcessAgeSeconds >= 0 then
    LogFmt(lsInit, 'process started %.3f s before this line (loading the '
      + 'program and its libraries)', [ProcessAgeSeconds]);
  if Unknown <> '' then
    LogFmt(lsInit, 'system.ini [log] names subsystems that do not exist: %s',
      [Unknown]);
  if Dir = '' then
    LogLine(lsData, 'no game data found beside the executable')
  else
    LogFmt(lsData, 'game data in %s', [Dir]);
end;

destructor TFrm_main.Destroy;
begin
  FormDestroy(Self);
  { The components go with the inherited destructor, which frees everything
    this owns; the window outlives them because Present reads it. }
  inherited Destroy;
  {$IFDEF AKUJI_TOUCH}
  FTouch.Free;
  {$ENDIF}
  if FWindow <> nil then
    SDL_DestroyWindow(FWindow);
  SDL_QuitSubSystem(SDL_INIT_VIDEO);
end;

{$IFDEF AKUJI_TOUCH}
{ A finger's position comes as a fraction of the window; the controls work
  in the window's pixels, the same ones they are drawn in. }
procedure TFrm_main.TouchFinger(const F: TSDL_TouchFingerEvent);
var
  W, H: Integer;
begin
  if (FTouch = nil) or (FWindow = nil) then
    Exit;
  SDL_GetWindowSize(FWindow, @W, @H);
  case F.type_ of
    SDL_FINGERDOWN: FTouch.FingerDown(F.fingerId, F.x * W, F.y * H);
    SDL_FINGERMOTION: FTouch.FingerMove(F.fingerId, F.x * W, F.y * H);
    SDL_FINGERUP: FTouch.FingerUp(F.fingerId);
  end;
end;

{ Once a frame, before the input is read. What the fingers press joins the
  keys and the pad. The title screen's menus listen to key presses rather
  than to the buttons (DIV-002), so a press that has just begun on the d-pad
  or on A is also handed to them as the key press it stands for. }
procedure TFrm_main.TouchFrame;
var
  Down, Began: TAkujiButtons;
begin
  if FTouch = nil then
    Exit;
  Down := FTouch.Pressed;
  Joy.TouchDown := Down;
  Began := Down - FTouchPrev;
  FTouchPrev := Down;
  if abUp in Began then FMoveY := -1;
  if abDown in Began then FMoveY := 1;
  if abLeft in Began then FMoveX := -1;
  if abRight in Began then FMoveX := 1;
  if abJump in Began then FConfirm := True;
end;

procedure TFrm_main.DrawTouch(Surface: PSDL_Surface);
begin
  if FTouch <> nil then
    FTouch.Draw(Surface);
end;
{$ENDIF}

procedure TFrm_main.PumpEvents;
var
  E: TSDL_Event;
begin
  while SDL_PollEvent(@E) = 1 do
    case E.type_ of
      SDL_QUITEV:
        FQuit := True;
      SDL_KEYDOWN:
        { Repeats included, deliberately: holding an arrow walks the menu
          cursor, which is what the window's own auto-repeat used to do. }
        FormKeyDown(E.key.keysym.sym, E.key.keysym.mod_);
      SDL_KEYUP:
        FormKeyUp(E.key.keysym.sym);
      {$IFDEF AKUJI_TOUCH}
      SDL_FINGERDOWN, SDL_FINGERMOTION, SDL_FINGERUP:
        TouchFinger(E.tfinger);
      {$ENDIF}
      SDL_WINDOWEVENT:
        case E.window.event of
          SDL_WINDOWEVENT_EXPOSED,
          SDL_WINDOWEVENT_RESTORED,
          SDL_WINDOWEVENT_SIZE_CHANGED:
            Redraw;
        end;
    end;
end;

procedure TFrm_main.Run;
begin
  while not FQuit do
  begin
    PumpEvents;
    if FQuit then
      Break;
    Frame;
  end;
end;

function RunGame: Integer;
var
  Game: TFrm_main;
begin
  Result := 0;
  try
    Game := TFrm_main.Create(nil);
    try
      Game.Run;
    finally
      Game.Free;
    end;
  except
    { Logged, then raised on: the log is where it will be looked for. }
    on E: Exception do
    begin
      LogFmt(lsInit, 'FATAL %s: %s', [E.ClassName, E.Message]);
      StopLog;
      raise;
    end;
  end;
  LogLine(lsInit, 'exited cleanly');
  StopLog;
end;

end.
