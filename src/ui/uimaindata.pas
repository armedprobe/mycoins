unit UIMainData;

{$mode objfpc}{$H+}{$codepage utf8}

{ MOCK: временные данные для макета главной формы.
  Заменяется слоем хранилища (src/core) на следующем этапе; форма знает только
  об этих структурах. }

interface

uses
  SysUtils;

type
  TOpKind = (okBuy, okSell);

  TOpRow = record
    Kind: TOpKind;
    OccurredOn: string;   // YYYY-MM-DD
    Qty: Int64;           // 1e8
    Price: Int64;         // 1e8, в валюте сделки
    Fee: Int64;           // 1e4, в валюте сделки
    Rate: Int64;          // 1e8, к базовой валюте
    Amount: Double;       // qty*price, в валюте сделки
    PnL: Double;          // только для продажи, в базовой валюте
  end;

  TOpRows = array of TOpRow;

  TPortfolioRow = record
    CoinID: string;
    Symbol: string;
    Name: string;
    Qty: Int64;           // 1e8
    Cost: Double;         // вложено, в базовой валюте
    Price: Double;        // текущая котировка, в базовой валюте
    Value: Double;        // Qty * Price
    PnL: Double;          // Value - Cost
    Ops: TOpRows;
  end;

  TPortfolioRows = array of TPortfolioRow;

function MockPortfolio: TPortfolioRows;

implementation

function MakeOp(AKind: TOpKind; const ADate: string;
  AQty, APrice, AFee, ARate: Int64; AAmount, APnL: Double): TOpRow;
begin
  Result.Kind := AKind;
  Result.OccurredOn := ADate;
  Result.Qty := AQty;
  Result.Price := APrice;
  Result.Fee := AFee;
  Result.Rate := ARate;
  Result.Amount := AAmount;
  Result.PnL := APnL;
end;

function MockPortfolio: TPortfolioRows;
begin
  SetLength(Result, 3);

  with Result[0] do
  begin
    CoinID := 'bitcoin';
    Symbol := 'btc';
    Name := 'Bitcoin';
    Qty := 12345678;
    Cost := 7886.81;
    Price := 96100.00;
    Value := 11866.02;
    PnL := Value - Cost;
    Ops := [
      MakeOp(okBuy, '2024-03-01', 5000000, 6000000000000, 90000, 100000000, 3000.00, 0),
      MakeOp(okBuy, '2024-05-12', 9345678, 6500000000000, 31200, 100000000, 6074.69, 0),
      MakeOp(okSell, '2024-06-14', 2000000, 7125000000000, 21400, 100000000, 1425.00, 222.86)
    ];
  end;

  with Result[1] do
  begin
    CoinID := 'tether';
    Symbol := 'usdt';
    Name := 'Tether';
    Qty := 25000000000;
    Cost := 250.00;
    Price := 1.00;
    Value := 250.00;
    PnL := Value - Cost;
    Ops := [
      MakeOp(okBuy, '2025-01-10', 25000000000, 100000000, 0, 100000000, 250.00, 0)
    ];
  end;

  with Result[2] do
  begin
    CoinID := 'ethereum';
    Symbol := 'eth';
    Name := 'Ethereum';
    Qty := 150000000;
    Cost := 4500.00;
    Price := 2400.00;
    Value := 3600.00;
    PnL := Value - Cost;
    Ops := [
      MakeOp(okBuy, '2023-11-20', 150000000, 300000000000, 0, 100000000, 4500.00, 0)
    ];
  end;
end;

end.
