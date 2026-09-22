{ Helpers shared by the self-test units: locating the reference executable
  and the bias between its data addresses and its file offsets. }

unit TestSupport;

{$MODE DELPHI}{$H+}

interface

uses
  Classes, SysUtils, TypInfo,
  QdaArchive, SoundTable, WaveFile, AudioMixer, AudioOut, MidiFile, KbgmPlayer,
  Directions, Entities, EventScripts, EventCommands, PlayerState, GameState,
  Stages, Camera, TileMaps, Player, EntityHandlers, EventRunner, GameSession,
  SpritePool, Sprites, Dialogue, BgAnime, UnitInit, Title, Ending, Opening,
  GameFont, DDDDComponent, Surfaces;

const
  { A data address in the reference executable minus this is its file offset.
    The CODE section uses a different bias, $00400C00, which is why this one is
    named rather than inlined. }
  DATA_VA_BIAS       = $00401A00;

  { Where the player's sprite tables start, right-facing then left. }
  PLAYER_SPRITE_BASE = $0046BB9C;

{ The reference executable, or '' if it is not beside the game data. Its size
  and a known string are both checked, so a differential test cannot silently
  end up comparing this build against itself. }
function OriginalExe(const GameDir: string): string;

type
  { One decoded picture, a row at a time, each pixel as the $00BBGGRR a
    TColor is. }
  TDecodedPixels = array of LongWord;

{ A SECOND OPINION ON EVERY PICTURE IN bmp.qda.

  The archive's pictures are read by SDL, and the pinned scenes cannot tell a
  decoding mistake from a correct decode: the picture and the baseline both
  come from whichever decoder is in use, so a palette read backwards, or the
  rows the wrong way up, would simply become the new normal. Something has to
  read them independently.

  That used to be the LCL's decoder, which was free. It is not free any more -
  the widget set is gone - so this reads the format instead, from the
  specification rather than from any other decoder's behaviour, which makes it
  a better witness than the one it replaces.

  Deliberately narrow: uncompressed 24-bit, which is what all 44 entries of
  the shipped bmp.qda are, and uncompressed 8-bit paletted, which costs four
  lines and covers the format the archive was long assumed to hold. Anything
  else returns False rather than guessing, and the caller reports that as a
  failure. }
function DecodeBmp(Data: TStream; out W, H: Integer;
                   out Pixels: TDecodedPixels): Boolean;

implementation

function DecodeBmp(Data: TStream; out W, H: Integer;
                   out Pixels: TDecodedPixels): Boolean;
var
  Magic: Word;
  OffBits, HeaderSize, Compression, ClrUsed: LongWord;
  Planes, BitCount: Word;
  RawH: Integer;
  Palette: array[0..255] of LongWord;
  Row: array of Byte;
  Stride, X, Y, DestY, I: Integer;
  Quad: array[0..3] of Byte;
begin
  Result := False;
  W := 0; H := 0; Pixels := nil;
  if Data.Size < 54 then
    Exit;
  Data.Position := 0;

  Data.ReadBuffer(Magic, 2);
  if Magic <> $4D42 then            { 'BM', little-endian }
    Exit;
  Data.Position := 10;
  Data.ReadBuffer(OffBits, 4);
  Data.ReadBuffer(HeaderSize, 4);
  if HeaderSize < 40 then           { BITMAPCOREHEADER is not supported }
    Exit;
  Data.ReadBuffer(W, 4);
  Data.ReadBuffer(RawH, 4);
  Data.ReadBuffer(Planes, 2);
  Data.ReadBuffer(BitCount, 2);
  Data.ReadBuffer(Compression, 4);
  if (Planes <> 1) or (Compression <> 0) then
    Exit;
  if (BitCount <> 24) and (BitCount <> 8) then
    Exit;
  Data.Position := 14 + 32;
  Data.ReadBuffer(ClrUsed, 4);
  if (W <= 0) or (RawH = 0) then
    Exit;

  { A negative height means the rows are stored top down. }
  H := Abs(RawH);

  if BitCount = 8 then
  begin
    if ClrUsed = 0 then
      ClrUsed := 256;
    if ClrUsed > 256 then
      Exit;
    Data.Position := 14 + HeaderSize;
    FillChar(Palette, SizeOf(Palette), 0);
    for I := 0 to Integer(ClrUsed) - 1 do
    begin
      { Stored blue, green, red, reserved. }
      Data.ReadBuffer(Quad, 4);
      Palette[I] := LongWord(Quad[2])
                    or (LongWord(Quad[1]) shl 8)
                    or (LongWord(Quad[0]) shl 16);
    end;
    Stride := (W + 3) and not 3;
  end
  else
    { 24-bit rows are three bytes a pixel, blue first. }
    Stride := (W * 3 + 3) and not 3;

  SetLength(Row, Stride);
  SetLength(Pixels, W * H);
  Data.Position := OffBits;
  if Data.Position + Int64(Stride) * H > Data.Size then
    Exit;
  for Y := 0 to H - 1 do
  begin
    Data.ReadBuffer(Row[0], Stride);
    if RawH > 0 then
      DestY := H - 1 - Y        { bottom-up, the usual way }
    else
      DestY := Y;
    for X := 0 to W - 1 do
      if BitCount = 8 then
        Pixels[DestY * W + X] := Palette[Row[X]]
      else
        Pixels[DestY * W + X] := LongWord(Row[X * 3 + 2])
                                 or (LongWord(Row[X * 3 + 1]) shl 8)
                                 or (LongWord(Row[X * 3]) shl 16);
  end;
  Result := True;
end;

{ Locate the 502784-byte reference executable. Size and a known data string are
  checked so differential tests cannot accidentally compare the build with
  itself. }
function OriginalExe(const GameDir: string): string;
const
  ORIGINAL_BYTES = 502784;
var
  Dir: string;

  function LooksLikeOriginal(const FileName: string): Boolean;
  var
    Stream: TFileStream;
    Buffer: array[0..15] of Char;
  begin
    Result := False;
    if not FileExists(FileName) then
      Exit;
    Stream := TFileStream.Create(FileName, fmOpenRead or fmShareDenyNone);
    try
      if Stream.Size <> ORIGINAL_BYTES then
        Exit;
      { 0x004568BC in the CODE section: VA - 0x400C00 is the file offset. }
      Stream.Position := $004568BC - $00400C00;
      Stream.ReadBuffer(Buffer, SizeOf(Buffer));
      Result := Buffer = ' was recovered! ';
    finally
      Stream.Free;
    end;
  end;

begin
  Dir := IncludeTrailingPathDelimiter(GameDir);
  Result := Dir + 'akuji_source.exe';
  if LooksLikeOriginal(Result) then
    Exit;
  Result := Dir + 'akuji.exe';
  if LooksLikeOriginal(Result) then
    Exit;
  Result := '';
end;

end.
