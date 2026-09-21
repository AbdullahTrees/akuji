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
  Classes, SysUtils, Graphics, RenderTarget;

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
  FONT_KEY_COLOR  = clBlack;

type
  TGameFont = class
  private
    { Glyphs are pre-cut because LCL will not do a transparent blit from a
      sub-rectangle - Draw() honours TBitmap.Transparent, CopyRect does not.
      64 glyphs x 3 variants of 9x9 is trivial to hold. }
    { Each glyph is cut once into its own image, which is what lets it carry
      a colour key at all - see the note on the two blits in RenderTarget. }
    FGlyphs: array of TRenderImage;
    FVariants: Integer;
    function GlyphIndex(Ch: Char; AVariant: Integer): Integer;
  public
    constructor Create(Sheet: TBitmap);
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

constructor TGameFont.Create(Sheet: TBitmap);
var
  VariantIndex, CharacterIndex, Column, Row, SourceX, SourceY: Integer;
  Glyph: TBitmap;
begin
  inherited Create;
  FVariants := Sheet.Height div (FONT_CELL_H * 2);
  if FVariants < 1 then FVariants := 1;
  if FVariants > FONT_VARIANTS then FVariants := FONT_VARIANTS;

  SetLength(FGlyphs, FVariants * (FONT_LAST_CHAR - FONT_FIRST_CHAR + 1));

  for VariantIndex := 0 to FVariants - 1 do
    for CharacterIndex := 0 to FONT_LAST_CHAR - FONT_FIRST_CHAR do
    begin
      Column := CharacterIndex mod FONT_COLS;
      Row := CharacterIndex div FONT_COLS;
      SourceX := Column * FONT_CELL_W;
      SourceY := Row * FONT_CELL_H + FONT_CELL_H * VariantIndex * 2;

      Glyph := TBitmap.Create;
      Glyph.SetSize(FONT_CELL_W, FONT_CELL_H);
      Glyph.Canvas.CopyRect(Rect(0, 0, FONT_CELL_W, FONT_CELL_H), Sheet.Canvas,
        Rect(SourceX, SourceY, SourceX + FONT_CELL_W, SourceY + FONT_CELL_H));
      Glyph.TransparentColor := FONT_KEY_COLOR;
      Glyph.Transparent := True;

      FGlyphs[VariantIndex * (FONT_LAST_CHAR - FONT_FIRST_CHAR + 1)
              + CharacterIndex] := TRenderImage.Create(Glyph, True);
    end;
end;

destructor TGameFont.Destroy;
var
  GlyphIndex: Integer;
begin
  for GlyphIndex := 0 to High(FGlyphs) do
    FGlyphs[GlyphIndex].Free;
  inherited Destroy;
end;

function TGameFont.GlyphIndex(Ch: Char; AVariant: Integer): Integer;
var
  CharacterCode: Integer;
begin
  CharacterCode := Ord(Ch);
  { Fold lowercase into the sheet's uppercase-only range. }
  if (CharacterCode >= Ord('a')) and (CharacterCode <= Ord('z')) then
    Dec(CharacterCode, 32);
  if (CharacterCode < FONT_FIRST_CHAR) or (CharacterCode > FONT_LAST_CHAR) then
    Exit(-1);
  if (AVariant < 0) or (AVariant >= FVariants) then
    AVariant := 0;
  Result := AVariant * (FONT_LAST_CHAR - FONT_FIRST_CHAR + 1)
            + (CharacterCode - FONT_FIRST_CHAR);
end;

procedure TGameFont.TextOut(Dest: TRenderTarget; X, Y: Integer; const S: string;
  AVariant: Integer);
var
  CharacterIndex, Glyph: Integer;
begin
  for CharacterIndex := 1 to Length(S) do
  begin
    Glyph := GlyphIndex(S[CharacterIndex], AVariant);
    if Glyph >= 0 then
      Dest.DrawImage(FGlyphs[Glyph], X + (CharacterIndex - 1) * FONT_ADVANCE, Y);
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
