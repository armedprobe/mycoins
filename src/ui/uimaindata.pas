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

const
  ScaleQtyMock = 100000000;  // 1e8: количество и цена

type
  TMockCoin = record
    CoinID: string;
    Symbol: string;
    Name: string;
    Price: Double;  // текущая котировка
  end;

const
  { Монеты для объёма: грид должен выводиться на несколько страниц. }
  ExtraCoins: array [0..39] of TMockCoin = (
    (CoinID: 'solana'; Symbol: 'sol'; Name: 'Solana'; Price: 142.30),
    (CoinID: 'ripple'; Symbol: 'xrp'; Name: 'XRP'; Price: 0.62),
    (CoinID: 'cardano'; Symbol: 'ada'; Name: 'Cardano'; Price: 0.45),
    (CoinID: 'dogecoin'; Symbol: 'doge'; Name: 'Dogecoin'; Price: 0.16),
    (CoinID: 'polkadot'; Symbol: 'dot'; Name: 'Polkadot'; Price: 6.80),
    (CoinID: 'tron'; Symbol: 'trx'; Name: 'TRON'; Price: 0.12),
    (CoinID: 'chainlink'; Symbol: 'link'; Name: 'Chainlink'; Price: 14.20),
    (CoinID: 'avalanche-2'; Symbol: 'avax'; Name: 'Avalanche'; Price: 28.50),
    (CoinID: 'shiba-inu'; Symbol: 'shib'; Name: 'Shiba Inu'; Price: 0.0000182),
    (CoinID: 'litecoin'; Symbol: 'ltc'; Name: 'Litecoin'; Price: 72.40),
    (CoinID: 'bitcoin-cash'; Symbol: 'bch'; Name: 'Bitcoin Cash'; Price: 365.00),
    (CoinID: 'stellar'; Symbol: 'xlm'; Name: 'Stellar'; Price: 0.11),
    (CoinID: 'monero'; Symbol: 'xmr'; Name: 'Monero'; Price: 160.00),
    (CoinID: 'cosmos'; Symbol: 'atom'; Name: 'Cosmos Hub'; Price: 6.10),
    (CoinID: 'uniswap'; Symbol: 'uni'; Name: 'Uniswap'; Price: 7.90),
    (CoinID: 'near'; Symbol: 'near'; Name: 'NEAR Protocol'; Price: 5.20),
    (CoinID: 'aptos'; Symbol: 'apt'; Name: 'Aptos'; Price: 8.40),
    (CoinID: 'arbitrum'; Symbol: 'arb'; Name: 'Arbitrum'; Price: 0.78),
    (CoinID: 'optimism'; Symbol: 'op'; Name: 'Optimism'; Price: 1.65),
    (CoinID: 'filecoin'; Symbol: 'fil'; Name: 'Filecoin'; Price: 4.30),
    (CoinID: 'internet-computer'; Symbol: 'icp'; Name: 'Internet Computer'; Price: 9.10),
    (CoinID: 'hedera-hashgraph'; Symbol: 'hbar'; Name: 'Hedera'; Price: 0.075),
    (CoinID: 'vechain'; Symbol: 'vet'; Name: 'VeChain'; Price: 0.025),
    (CoinID: 'algorand'; Symbol: 'algo'; Name: 'Algorand'; Price: 0.18),
    (CoinID: 'aave'; Symbol: 'aave'; Name: 'Aave'; Price: 152.00),
    (CoinID: 'maker'; Symbol: 'mkr'; Name: 'Maker'; Price: 1580.00),
    (CoinID: 'the-graph'; Symbol: 'grt'; Name: 'The Graph'; Price: 0.17),
    (CoinID: 'render-token'; Symbol: 'rndr'; Name: 'Render'; Price: 5.60),
    (CoinID: 'injective-protocol'; Symbol: 'inj'; Name: 'Injective'; Price: 21.30),
    (CoinID: 'sui'; Symbol: 'sui'; Name: 'Sui'; Price: 1.05),
    (CoinID: 'pepe'; Symbol: 'pepe'; Name: 'Pepe'; Price: 0.0000089),
    (CoinID: 'the-sandbox'; Symbol: 'sand'; Name: 'The Sandbox'; Price: 0.29),
    (CoinID: 'decentraland'; Symbol: 'mana'; Name: 'Decentraland'; Price: 0.31),
    (CoinID: 'axie-infinity'; Symbol: 'axs'; Name: 'Axie Infinity'; Price: 5.10),
    (CoinID: 'tezos'; Symbol: 'xtz'; Name: 'Tezos'; Price: 0.68),
    (CoinID: 'eos'; Symbol: 'eos'; Name: 'EOS'; Price: 0.52),
    (CoinID: 'curve-dao-token'; Symbol: 'crv'; Name: 'Curve DAO'; Price: 0.29),
    (CoinID: 'kaspa'; Symbol: 'kas'; Name: 'Kaspa'; Price: 0.13),
    (CoinID: 'toncoin'; Symbol: 'ton'; Name: 'Toncoin'; Price: 5.40),
    (CoinID: 'binancecoin'; Symbol: 'bnb'; Name: 'BNB'; Price: 580.00)
  );

  { Bitcoin: операций на несколько страниц грида в раскрытом виде. }
  BtcCoin: TMockCoin = (CoinID: 'bitcoin'; Symbol: 'btc'; Name: 'Bitcoin'; Price: 96100.00);
  BtcOpCount = 45;

{ Позиция из детерминированного набора операций: покупки по цене ниже/выше
  текущей, каждая третья операция — продажа половины остатка. Сумма сделки —
  порядка 100–1000; количество округлено до 0.01, у дорогих монет — до 0.0001. }
function MakeCoin(const ACoin: TMockCoin; ASeed, AOpCount: Integer): TPortfolioRow;
var
  J: Integer;
  Qty, Bought, Sold, LotStep: Int64;
  BuyPrice, AvgCost, OpPrice, Cost: Double;
  OpDate: string;
begin
  Result.CoinID := ACoin.CoinID;
  Result.Symbol := ACoin.Symbol;
  Result.Name := ACoin.Name;
  Result.Price := ACoin.Price;

  if ACoin.Price >= 1000 then
    LotStep := ScaleQtyMock div 10000
  else
    LotStep := ScaleQtyMock div 100;
  Result.Ops := nil;
  SetLength(Result.Ops, AOpCount);
  Bought := 0;
  Sold := 0;
  Cost := 0;
  for J := 0 to AOpCount - 1 do
  begin
    OpDate := FormatDateTime('yyyy"-"mm"-"dd', EncodeDate(2024, 1, 5) + J * 13 + ASeed mod 10);
    Qty := Round((100 + 90 * ((ASeed + J) mod 10)) / ACoin.Price * ScaleQtyMock / LotStep) * LotStep;
    BuyPrice := ACoin.Price * (0.7 + 0.1 * ((ASeed * 3 + J) mod 7));
    if (J mod 3 = 2) and ((Bought - Sold) div 2 >= LotStep) then
    begin
      Qty := (Bought - Sold) div 2 div LotStep * LotStep;
      AvgCost := Cost / ((Bought - Sold) / ScaleQtyMock);
      OpPrice := BuyPrice * 1.1;
      Result.Ops[J] := MakeOp(okSell, OpDate,
        Qty, Round(OpPrice * ScaleQtyMock), 10000 * (1 + J mod 9), 100000000,
        Qty / ScaleQtyMock * OpPrice, Qty / ScaleQtyMock * (OpPrice - AvgCost));
      Cost := Cost - Qty / ScaleQtyMock * AvgCost;
      Inc(Sold, Qty);
    end
    else
    begin
      Result.Ops[J] := MakeOp(okBuy, OpDate,
        Qty, Round(BuyPrice * ScaleQtyMock), 10000 * (1 + J mod 9), 100000000,
        Qty / ScaleQtyMock * BuyPrice, 0);
      Cost := Cost + Qty / ScaleQtyMock * BuyPrice;
      Inc(Bought, Qty);
    end;
  end;

  Result.Qty := Bought - Sold;
  Result.Cost := Cost;
  Result.Value := Result.Qty / ScaleQtyMock * Result.Price;
  Result.PnL := Result.Value - Result.Cost;
end;

function MockPortfolio: TPortfolioRows;
var
  I, Base: Integer;
begin
  Result := nil;
  SetLength(Result, 3 + Length(ExtraCoins));

  Result[0] := MakeCoin(BtcCoin, 1, BtcOpCount);

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

  Base := 3;
  for I := 0 to High(ExtraCoins) do
    Result[Base + I] := MakeCoin(ExtraCoins[I], I + 5, 1 + (I + 5) mod 6);
end;

end.
