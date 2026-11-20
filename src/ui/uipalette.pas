unit UIPalette;

{$mode objfpc}{$H+}

interface

uses
  Graphics;

{ Семантические цвета. Не тема, а носители данных: P&L, ошибки, предупреждения.
  Значения подбираются при старте по яркости системного clWindow, чтобы тёмная
  тема не давала нечитаемый текст. }

var
  clDataPositive: TColor = clGreen;
  clDataNegative: TColor = clRed;
  clDataWarning: TColor = $000080C0;
  clDataMuted: TColor = clGray;

implementation

function Luma(C: TColor): Integer;
var
  RGB: LongInt;
begin
  RGB := ColorToRGB(C);
  Result := (Red(RGB) * 299 + Green(RGB) * 587 + Blue(RGB) * 114) div 1000;
end;

initialization
  if Luma(clWindow) < 128 then
  begin
    clDataPositive := $0060C860;
    clDataNegative := $006060F0;
    clDataWarning := $0040B0F0;
    clDataMuted := $00909090;
  end
  else
  begin
    clDataPositive := $00308030;
    clDataNegative := $003030C0;
    clDataWarning := $000080C0;
    clDataMuted := $00707070;
  end;
end.
