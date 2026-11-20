unit UINumFmt;

{$mode objfpc}{$H+}

interface

{ Масштабы хранения по spec/MODEL.md. }
const
  ScaleQty = 100000000;   // 1e8
  ScalePrice = 100000000; // 1e8
  ScaleRate = 100000000;  // 1e8
  ScaleFee = 10000;       // 1e4

{ Форматирование для показа. Знак валюты не выводится: валюта одна на весь
  экран и видна в тулбаре. }
function FmtQty(Value: Int64): string;
function FmtPrice(Value: Int64): string;
function FmtRate(Value: Int64): string;
function FmtMoney(Value: Double): string;
function FmtPnl(Value: Double): string;

implementation

uses
  SysUtils;

function FmtQty(Value: Int64): string;
begin
  Result := FormatFloat('#,##0.########', Value / ScaleQty);
end;

function FmtPrice(Value: Int64): string;
begin
  Result := FormatFloat('#,##0.00########', Value / ScalePrice);
end;

function FmtRate(Value: Int64): string;
begin
  Result := FormatFloat('#,##0.00####', Value / ScaleRate);
end;

function FmtMoney(Value: Double): string;
begin
  Result := FormatFloat('#,##0.00', Value);
end;

function FmtPnl(Value: Double): string;
begin
  Result := FormatFloat('#,##0.00', Value);
  if Value > 0 then
    Result := '+' + Result;
end;

end.
