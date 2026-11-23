unit UIPalette;

{$mode objfpc}{$H+}

interface

uses
  Graphics;

{ Семантические цвета. Не тема, а носители данных: P&L, ошибки, предупреждения.
  Значения подбираются при старте по яркости системного clWindow, чтобы тёмная
  тема не давала нечитаемый текст. }

const
  { Палитра грид-карточки (spec/intent-gui-design-1.md). Фиксированные значения:
    карточка всегда светлая, тёмная тема системы на неё не влияет.
    TColor — $00BBGGRR, поэтому литералы записаны в обратном порядке байт. }
  clGridWindow    = $00F7F5F4;  // #F4F5F7 фон окна
  clGridCard      = $00FFFFFF;  // #FFFFFF карточка, шапка, строки
  clGridLine      = $00E7E4E4;  // #E4E4E7 линии, рамка, точки-меню покоя
  clGridText      = $001B1818;  // #18181B основной текст
  clGridMuted     = $007A7171;  // #71717A шапка, отсутствующие значения
  clGridHover     = $00FBFAFA;  // #FAFAFB строка под курсором, строка-группа
  clGridSelected  = $00FFF1E8;  // #E8F1FF выделенная строка
  clGridPnlUpBg   = $00E7FCDC;  // #DCFCE7 фон положительного P&L
  clGridPnlUpFg   = $003D8015;  // #15803D текст положительного P&L
  clGridPnlDownBg = $00E2E2FE;  // #FEE2E2 фон отрицательного P&L
  clGridPnlDownFg = $001C1CB9;  // #B91C1C текст отрицательного P&L

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
