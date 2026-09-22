{ Bitmap-font rendering. The sheet contains three colour variants of the
  $20..$5F glyph
  range in 32-column rows. Each 9x9 glyph advances by eight pixels.

  Glyph coordinates are calculated as follows:

      idx = ch - FirstChar
      col = idx mod 32            srcX = col * CellW
      row = idx div 32            srcY = row * CellH + CellH * Variant * 2
      dest x = X + charIndex * Advance
      centred: X = (ScreenW - Length(S) * Advance) div 2

  This column/row order intentionally differs from TileMaps' tileset indexing. }

unit GameFont;

{$MODE DELPHI}{$H+}

interface

uses
  Classes, SysUtils, Types, GameColors, RenderTarget;

const
  { Font used for outlined narrative text. }
  { Re-exported from RenderTarget, which is where the drawing happens. }
  OUTLINED_FONT_NAME = RenderTarget.OUTLINED_FONT_NAME;
  OUTLINED_FONT_SIZE = 10;

  FONT_FIRST_CHAR = $20;   { space }
  FONT_LAST_CHAR  = $5F;   { underscore - no lowercase in the sheet }
  FONT_COLS       = 32;    { glyphs per sheet row }
  FONT_CELL_W     = 9;
  FONT_CELL_H     = 9;
  FONT_ADVANCE    = 8;     { one pixel less than the cell, so glyphs overlap }
  FONT_VARIANTS   = 3;

type
  TGameFont = class
  private
    { The sheet itself, borrowed from the surface set that owns it.

      Every glyph used to be cut into a bitmap of its own here, because the
      LCL will not do a transparent blit from a sub-rectangle: Draw() honours
      a bitmap's colour key and CopyRect does not. BlitRectKeyed does both, so
      the 192 cut bitmaps and their masks are gone and the glyph is read
      straight out of the sheet. }
    FSheet: TRenderImage;
    FVariants: Integer;
    { The cell this character occupies in the sheet, or an empty rect for one
      the sheet does not carry. }
    function GlyphRect(Ch: Char; AVariant: Integer): TRect;
  public
    constructor Create(Sheet: TRenderImage);
    destructor Destroy; override;

    procedure TextOut(Dest: TRenderTarget; X, Y: Integer; const S: string;
                      AVariant: Integer = 0);
    { Centred within ScreenW. }
    procedure TextOutCentered(Dest: TRenderTarget; Y: Integer; const S: string;
                              ScreenW: Integer = 320; AVariant: Integer = 0);
    function TextWidth(const S: string): Integer;

    property Variants: Integer read FVariants;
  end;

{ Draw narrative text with a four-direction, one-pixel outline. Diagonal
  outline pixels are omitted. }
procedure Game_DrawTextOutlined(X, Y: Integer; const S: string;
                                Outline, Fill: TColor; Size: Integer;
                                Dest: TRenderTarget);

implementation

constructor TGameFont.Create(Sheet: TRenderImage);
begin
  inherited Create;
  FSheet := Sheet;
  FVariants := 1;
  if Sheet <> nil then
    FVariants := Sheet.Height div (FONT_CELL_H * 2);
  if FVariants < 1 then FVariants := 1;
  if FVariants > FONT_VARIANTS then FVariants := FONT_VARIANTS;
end;

destructor TGameFont.Destroy;
begin
  { The sheet belongs to the surface set. }
  inherited Destroy;
end;

function TGameFont.GlyphRect(Ch: Char; AVariant: Integer): TRect;
var
  CharacterCode, Index, Column, Row, SourceX, SourceY: Integer;
begin
  Result := Rect(0, 0, 0, 0);
  CharacterCode := Ord(Ch);
  { Fold lowercase into the sheet's uppercase-only range. }
  if (CharacterCode >= Ord('a')) and (CharacterCode <= Ord('z')) then
    Dec(CharacterCode, 32);
  if (CharacterCode < FONT_FIRST_CHAR) or (CharacterCode > FONT_LAST_CHAR) then
    Exit;
  if (AVariant < 0) or (AVariant >= FVariants) then
    AVariant := 0;

  Index := CharacterCode - FONT_FIRST_CHAR;
  Column := Index mod FONT_COLS;
  Row := Index div FONT_COLS;
  SourceX := Column * FONT_CELL_W;
  SourceY := Row * FONT_CELL_H + FONT_CELL_H * AVariant * 2;
  Result := Rect(SourceX, SourceY,
                 SourceX + FONT_CELL_W, SourceY + FONT_CELL_H);
end;

procedure TGameFont.TextOut(Dest: TRenderTarget; X, Y: Integer; const S: string;
  AVariant: Integer);
var
  CharacterIndex: Integer;
  Src: TRect;
begin
  if FSheet = nil then
    Exit;
  for CharacterIndex := 1 to Length(S) do
  begin
    Src := GlyphRect(S[CharacterIndex], AVariant);
    { The cell is 9 wide and the advance is 8, so each glyph overlaps the one
      before it by a pixel. The key is what makes that harmless. }
    if not IsRectEmpty(Src) then
      Dest.BlitRectKeyed(FSheet, Src,
                         X + (CharacterIndex - 1) * FONT_ADVANCE, Y);
  end;
end;

function TGameFont.TextWidth(const S: string): Integer;
begin
  Result := Length(S) * FONT_ADVANCE;
end;

procedure TGameFont.TextOutCentered(Dest: TRenderTarget; Y: Integer; const S: string;
  ScreenW: Integer; AVariant: Integer);
begin
  TextOut(Dest, (ScreenW - TextWidth(S)) div 2, Y, S, AVariant);
end;

procedure Game_DrawTextOutlined(X, Y: Integer; const S: string;
                                Outline, Fill: TColor; Size: Integer;
                                Dest: TRenderTarget);
begin
  if Dest = nil then
    Exit;
  Dest.DrawOutlinedText(X, Y, S, Outline, Fill, Size);
end;

end.
