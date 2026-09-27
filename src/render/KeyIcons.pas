{ Keycap icons for the keys a sign names: which keys have one, where each is
  on the sheet, and how a line of text carries one.

  THE SHEET

  assets/fonts/input-prompts.bmp is Kenney's "Input Prompts Pixel" (CC0),
  converted to an 8-bit BMP whose colour key is magenta, the sheet's
  transparent entry. Each keycap is 13-14 pixels tall on a 16-pixel tile,
  which is the dialogue's line pitch. The sheet also holds gamepad buttons
  for when controllers are named.

  IN A LINE OF TEXT

  An icon travels inside the string as one private-use character, U+E000
  plus its index here, so everything that already handles text - the reveal
  units, the pages, the text cache - carries it untouched, and only the
  renderer and the width measure look inside. }

unit KeyIcons;

{$MODE DELPHI}{$H+}

interface

uses
  Types, SDL2;

type
  TKeyIcon = record
    Key: TSDL_KeyCode;
    X, Y, W: Integer;   { on the sheet; every icon is KEY_ICON_H tall }
  end;

const
  KEY_ICON_H = 16;
  KEY_ICON_SHEET = 'input-prompts.bmp';
  { The first private-use code point; icon I is KEY_ICON_BASE + I. }
  KEY_ICON_BASE = $E000;

  { Generated from Kenney's Input Prompts Pixel sheet by make_icons.py:
    the light keycaps, each rectangle trimmed to the keycap plus a clear
    column either side. }
  KEY_ICONS: array[0..83] of TKeyIcon = (
    (Key: SDLK_ESCAPE; X: 272; Y: 0; W: 16),
    (Key: SDLK_F1; X: 288; Y: 0; W: 15),
    (Key: SDLK_F2; X: 304; Y: 0; W: 15),
    (Key: SDLK_F3; X: 320; Y: 0; W: 15),
    (Key: SDLK_F4; X: 336; Y: 0; W: 15),
    (Key: SDLK_F5; X: 352; Y: 0; W: 15),
    (Key: SDLK_F6; X: 368; Y: 0; W: 15),
    (Key: SDLK_F7; X: 384; Y: 0; W: 15),
    (Key: SDLK_F8; X: 400; Y: 0; W: 15),
    (Key: SDLK_F9; X: 416; Y: 0; W: 15),
    (Key: SDLK_F10; X: 432; Y: 0; W: 16),
    (Key: SDLK_F11; X: 448; Y: 0; W: 16),
    (Key: SDLK_F12; X: 464; Y: 0; W: 16),
    (Key: SDLK_BACKQUOTE; X: 480; Y: 0; W: 15),
    (Key: SDLK_1; X: 272; Y: 16; W: 15),
    (Key: SDLK_2; X: 288; Y: 16; W: 15),
    (Key: SDLK_3; X: 304; Y: 16; W: 15),
    (Key: SDLK_4; X: 320; Y: 16; W: 15),
    (Key: SDLK_5; X: 336; Y: 16; W: 15),
    (Key: SDLK_6; X: 352; Y: 16; W: 15),
    (Key: SDLK_7; X: 368; Y: 16; W: 15),
    (Key: SDLK_8; X: 384; Y: 16; W: 15),
    (Key: SDLK_9; X: 400; Y: 16; W: 15),
    (Key: SDLK_0; X: 416; Y: 16; W: 15),
    (Key: SDLK_MINUS; X: 432; Y: 16; W: 15),
    (Key: SDLK_EQUALS; X: 464; Y: 16; W: 15),
    (Key: SDLK_BACKSPACE; X: 512; Y: 16; W: 32),
    (Key: SDLK_q; X: 272; Y: 32; W: 15),
    (Key: SDLK_w; X: 288; Y: 32; W: 15),
    (Key: SDLK_e; X: 304; Y: 32; W: 15),
    (Key: SDLK_r; X: 320; Y: 32; W: 15),
    (Key: SDLK_t; X: 336; Y: 32; W: 15),
    (Key: SDLK_y; X: 352; Y: 32; W: 15),
    (Key: SDLK_u; X: 368; Y: 32; W: 15),
    (Key: SDLK_i; X: 384; Y: 32; W: 15),
    (Key: SDLK_o; X: 400; Y: 32; W: 15),
    (Key: SDLK_p; X: 416; Y: 32; W: 15),
    (Key: SDLK_LEFTBRACKET; X: 432; Y: 32; W: 15),
    (Key: SDLK_RIGHTBRACKET; X: 448; Y: 32; W: 15),
    (Key: SDLK_BACKSLASH; X: 496; Y: 32; W: 15),
    (Key: SDLK_a; X: 288; Y: 48; W: 15),
    (Key: SDLK_s; X: 304; Y: 48; W: 15),
    (Key: SDLK_d; X: 320; Y: 48; W: 15),
    (Key: SDLK_f; X: 336; Y: 48; W: 15),
    (Key: SDLK_g; X: 352; Y: 48; W: 15),
    (Key: SDLK_h; X: 368; Y: 48; W: 15),
    (Key: SDLK_j; X: 384; Y: 48; W: 15),
    (Key: SDLK_k; X: 400; Y: 48; W: 15),
    (Key: SDLK_l; X: 416; Y: 48; W: 15),
    (Key: SDLK_QUOTE; X: 432; Y: 48; W: 15),
    (Key: SDLK_SEMICOLON; X: 480; Y: 48; W: 15),
    (Key: SDLK_SPACE; X: 272; Y: 64; W: 15),
    (Key: SDLK_z; X: 304; Y: 64; W: 15),
    (Key: SDLK_x; X: 320; Y: 64; W: 15),
    (Key: SDLK_c; X: 336; Y: 64; W: 15),
    (Key: SDLK_v; X: 352; Y: 64; W: 15),
    (Key: SDLK_b; X: 368; Y: 64; W: 15),
    (Key: SDLK_n; X: 384; Y: 64; W: 15),
    (Key: SDLK_m; X: 400; Y: 64; W: 15),
    (Key: SDLK_COMMA; X: 432; Y: 96; W: 15),
    (Key: SDLK_PERIOD; X: 432; Y: 80; W: 15),
    (Key: SDLK_SLASH; X: 464; Y: 64; W: 15),
    (Key: SDLK_UP; X: 480; Y: 64; W: 15),
    (Key: SDLK_RIGHT; X: 496; Y: 64; W: 15),
    (Key: SDLK_DOWN; X: 512; Y: 64; W: 15),
    (Key: SDLK_LEFT; X: 528; Y: 64; W: 15),
    (Key: SDLK_LALT; X: 272; Y: 80; W: 23),
    (Key: SDLK_RALT; X: 272; Y: 80; W: 23),
    (Key: SDLK_TAB; X: 304; Y: 80; W: 23),
    (Key: SDLK_DELETE; X: 336; Y: 80; W: 23),
    (Key: SDLK_END; X: 368; Y: 80; W: 23),
    (Key: SDLK_NUMLOCKCLEAR; X: 400; Y: 80; W: 23),
    (Key: SDLK_LCTRL; X: 272; Y: 96; W: 27),
    (Key: SDLK_RCTRL; X: 272; Y: 96; W: 27),
    (Key: SDLK_CAPSLOCK; X: 304; Y: 96; W: 27),
    (Key: SDLK_HOME; X: 336; Y: 96; W: 27),
    (Key: SDLK_PAGEUP; X: 368; Y: 96; W: 32),
    (Key: SDLK_PAGEDOWN; X: 400; Y: 96; W: 32),
    (Key: SDLK_LSHIFT; X: 272; Y: 112; W: 32),
    (Key: SDLK_RSHIFT; X: 272; Y: 112; W: 32),
    (Key: SDLK_INSERT; X: 304; Y: 112; W: 32),
    (Key: SDLK_PRINTSCREEN; X: 336; Y: 112; W: 32),
    (Key: SDLK_SCROLLLOCK; X: 368; Y: 112; W: 32),
    (Key: SDLK_PAUSE; X: 400; Y: 112; W: 32));

{ The icon for this key, or -1 when the sheet has none. }
function KeyIconIndex(Key: TSDL_KeyCode): Integer;

{ Icon I as the character that stands for it in a line. }
function KeyIconChar(Index: Integer): string;

{ Which icon a code point stands for, or -1. }
function KeyIconOfCodePoint(CodePoint: Cardinal): Integer;

function KeyIconRect(Index: Integer): TRect;

implementation

function KeyIconIndex(Key: TSDL_KeyCode): Integer;
var
  I: Integer;
begin
  for I := Low(KEY_ICONS) to High(KEY_ICONS) do
    if KEY_ICONS[I].Key = Key then
      Exit(I);
  Result := -1;
end;

function KeyIconChar(Index: Integer): string;
var
  C: Cardinal;
begin
  { Three UTF-8 bytes, as for any code point in U+0800..U+FFFF. }
  C := KEY_ICON_BASE + Cardinal(Index);
  Result := Chr($E0 or (C shr 12)) + Chr($80 or ((C shr 6) and $3F))
            + Chr($80 or (C and $3F));
end;

function KeyIconOfCodePoint(CodePoint: Cardinal): Integer;
begin
  if (CodePoint >= KEY_ICON_BASE)
     and (CodePoint <= KEY_ICON_BASE + Cardinal(High(KEY_ICONS))) then
    Result := CodePoint - KEY_ICON_BASE
  else
    Result := -1;
end;

function KeyIconRect(Index: Integer): TRect;
begin
  with KEY_ICONS[Index] do
    Result := Rect(X, Y, X + W, Y + KEY_ICON_H);
end;

end.
