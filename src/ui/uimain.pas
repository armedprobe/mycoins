unit UIMain;

{$mode objfpc}{$H+}{$codepage utf8}
{ Главная форма: тулбар, грид-карточка сделок, статусбар. }

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, ComCtrls,
  Menus, ExtCtrls, ActnList, LCLType, Math,
  UIPalette, UINumFmt, UIGrid, UIMainData;

type
  TFormMain = class(TForm)
    actnList: TActionList;
    actOpenDb: TAction;
    actQuit: TAction;
    actBuy: TAction;
    actSell: TAction;
    actEdit: TAction;
    actDelete: TAction;
    actRefresh: TAction;
    actRefreshRates: TAction;
    actRefreshQuotes: TAction;
    actRefreshCoins: TAction;
    actChangeBase: TAction;
    actAbout: TAction;
    mnuMain: TMainMenu;
    mnuFile: TMenuItem;
    mnuOpenDb: TMenuItem;
    mnuFileSep: TMenuItem;
    mnuQuit: TMenuItem;
    mnuService: TMenuItem;
    mnuRefreshRates: TMenuItem;
    mnuRefreshQuotes: TMenuItem;
    mnuRefreshCoins: TMenuItem;
    mnuServiceSep: TMenuItem;
    mnuRefreshView: TMenuItem;
    mnuHelp: TMenuItem;
    mnuAbout: TMenuItem;
    pnlTop: TPanel;
    btnBuy: TButton;
    btnSell: TButton;
    btnDelete: TButton;
    btnRefresh: TButton;
    lblBase: TLabel;
    cboBase: TComboBox;
    sbMain: TStatusBar;
    { Sender у части обработчиков не нужен: сигнатура навязана LCL. }
    {$warn 5024 off}
    procedure FormCreate(Sender: TObject);
    procedure ActionsUpdate(AAction: TBasicAction; var Handled: Boolean);
    procedure NotImplemented(Sender: TObject);
    procedure RefreshExecute(Sender: TObject);
    procedure QuitExecute(Sender: TObject);
    procedure cboBaseChange(Sender: TObject);
    procedure GridGetSubCount(Sender: TObject; AItem: Integer; var ACount: Integer);
    procedure GridGetCell(Sender: TObject; const ARow: TGridRow; ACol: Integer;
      var AText: string; var AStyle: TGridStyle);
    procedure GridCompare(Sender: TObject; const A, B: TGridRow; ACol: Integer;
      var AResult: Integer);
    procedure GridDblClick(Sender: TObject);
    procedure GridKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
  private
    FGrid: TGridCard;
    FPortfolio: TPortfolioRows;
    procedure PlaceOnMonitorAt(const AValue: string);
    procedure CreateGrid;
    procedure InitColumns;
    procedure Reload;
    procedure SetPnlCell(AValue: Double; out AText: string;
      out AStyle: TGridStyle);
    procedure SetMissingCell(out AText: string; out AStyle: TGridStyle);
    function FocusedRowIsOp: Boolean;
    procedure Say(const Msg: string);
    procedure UpdateStatus;
  public
  end;

const
  ColTitle = 0;
  ColQty = 1;
  ColPrice = 2;
  ColAmount = 3;
  ColFee = 4;
  ColRate = 5;
  ColValue = 6;
  ColPnl = 7;

  Dash = '—';

var
  FormMain: TFormMain;

implementation

const
  OpKindName: array [TOpKind] of string = ('Покупка', 'Продажа');

{$R *.lfm}

procedure TFormMain.FormCreate(Sender: TObject);
begin
  Color := clGridWindow;
  pnlTop.Color := clGridWindow;
  if Application.HasOption('monitor-at') then
    PlaceOnMonitorAt(Application.GetOptionValue('monitor-at'));
  CreateGrid;
  InitColumns;
  Reload;
  ActiveControl := FGrid;
end;

{ --monitor-at=X,Y: центр рабочей области монитора, содержащего точку экрана. }
procedure TFormMain.PlaceOnMonitorAt(const AValue: string);
var
  Comma: Integer;
  P: TPoint;
  Mon: TMonitor;
  Area: TRect;
begin
  Comma := Pos(',', AValue);
  if (Comma = 0)
    or not TryStrToInt(Copy(AValue, 1, Comma - 1), P.X)
    or not TryStrToInt(Copy(AValue, Comma + 1, MaxInt), P.Y) then
    raise EArgumentException.CreateFmt(
      '--monitor-at: ожидается X,Y, получено "%s"', [AValue]);
  Mon := Screen.MonitorFromPoint(P, mdNull);
  if Mon = nil then
    raise EArgumentException.CreateFmt(
      '--monitor-at: точка %d,%d вне мониторов', [P.X, P.Y]);
  Area := Mon.WorkareaRect;
  Position := poDesigned;
  SetBounds(Area.Left + (Area.Width - Width) div 2,
    Area.Top + (Area.Height - Height) div 2, Width, Height);
end;

procedure TFormMain.CreateGrid;
begin
  FGrid := TGridCard.Create(Self);
  FGrid.Parent := Self;
  FGrid.Align := alClient;
  FGrid.BorderSpacing.Left := 16;
  FGrid.BorderSpacing.Top := 16;
  FGrid.BorderSpacing.Right := 16;
  FGrid.BorderSpacing.Bottom := 16;
  FGrid.TabOrder := 1;
  FGrid.OnGetSubCount := @GridGetSubCount;
  FGrid.OnGetCell := @GridGetCell;
  FGrid.OnCompare := @GridCompare;
  FGrid.OnDblClick := @GridDblClick;
  FGrid.OnKeyDown := @GridKeyDown;
end;

procedure TFormMain.InitColumns;
begin
  FGrid.AddColumn(ColTitle, 'Монета / операция', 190, taLeftJustify, gkText);
  FGrid.AddColumn(ColQty, 'Кол-во', 110, taRightJustify, gkText);
  FGrid.AddColumn(ColPrice, 'Цена', 95, taRightJustify, gkText);
  FGrid.AddColumn(ColAmount, 'Сумма', 95, taRightJustify, gkText);
  FGrid.AddColumn(ColFee, 'Комиссия', 95, taRightJustify, gkText);
  FGrid.AddColumn(ColRate, 'Курс', 80, taRightJustify, gkText);
  FGrid.AddColumn(ColValue, 'Стоимость', 100, taRightJustify, gkText);
  FGrid.AddColumn(ColPnl, 'P&L', 110, taRightJustify, gkBadge);
end;

procedure TFormMain.Reload;
begin
  FPortfolio := MockPortfolio;
  FGrid.LoadItems(Length(FPortfolio));
  UpdateStatus;
end;

procedure TFormMain.GridGetSubCount(Sender: TObject; AItem: Integer;
  var ACount: Integer);
begin
  ACount := Length(FPortfolio[AItem].Ops);
end;

{ Порядок по возрастанию: направление применяет грид. }
procedure TFormMain.GridCompare(Sender: TObject; const A, B: TGridRow;
  ACol: Integer; var AResult: Integer);
var
  CoinA, CoinB: TPortfolioRow;
  OpA, OpB: TOpRow;
begin
  if A.Sub < 0 then
  begin
    CoinA := FPortfolio[A.Item];
    CoinB := FPortfolio[B.Item];
    case ACol of
      ColTitle: AResult := CompareText(CoinA.Name, CoinB.Name);
      ColQty: AResult := CompareValue(CoinA.Qty, CoinB.Qty);
      ColPrice: AResult := CompareValue(CoinA.Price, CoinB.Price);
      ColValue: AResult := CompareValue(CoinA.Value, CoinB.Value);
      ColPnl: AResult := CompareValue(CoinA.PnL, CoinB.PnL);
    end;
    Exit;
  end;

  OpA := FPortfolio[A.Item].Ops[A.Sub];
  OpB := FPortfolio[B.Item].Ops[B.Sub];
  case ACol of
    ColTitle:
      begin
        AResult := CompareText(OpA.OccurredOn, OpB.OccurredOn);
        if AResult = 0 then
          AResult := CompareValue(Ord(OpA.Kind), Ord(OpB.Kind));
      end;
    ColQty: AResult := CompareValue(OpA.Qty, OpB.Qty);
    ColPrice: AResult := CompareValue(OpA.Price, OpB.Price);
    ColAmount: AResult := CompareValue(OpA.Amount, OpB.Amount);
    ColFee: AResult := CompareValue(OpA.Fee, OpB.Fee);
    ColRate: AResult := CompareValue(OpA.Rate, OpB.Rate);
    ColPnl: AResult := CompareValue(OpA.PnL, OpB.PnL);
  end;
end;

procedure TFormMain.GridGetCell(Sender: TObject; const ARow: TGridRow;
  ACol: Integer; var AText: string; var AStyle: TGridStyle);
var
  Coin: TPortfolioRow;
  Op: TOpRow;
begin
  Coin := FPortfolio[ARow.Item];
  if ARow.Sub < 0 then
  begin
    case ACol of
      ColTitle: AText := Coin.Name + '   ' + Coin.Symbol;
      ColQty: AText := FmtQty(Coin.Qty);
      ColPrice: AText := FmtMoney(Coin.Price);
      ColAmount, ColFee, ColRate: SetMissingCell(AText, AStyle);
      ColValue: AText := FmtMoney(Coin.Value);
      ColPnl: SetPnlCell(Coin.PnL, AText, AStyle);
    end;
    Exit;
  end;

  Op := Coin.Ops[ARow.Sub];
  case ACol of
    ColTitle: AText := Op.OccurredOn + '   ' + OpKindName[Op.Kind];
    ColQty: AText := FmtQty(Op.Qty);
    ColPrice: AText := FmtPrice(Op.Price);
    ColAmount: AText := FmtMoney(Op.Amount);
    ColFee: AText := FmtMoney(Op.Fee / ScaleFee);
    ColRate: AText := FmtRate(Op.Rate);
    ColValue: SetMissingCell(AText, AStyle);
    ColPnl:
      begin
        if Op.Kind = okSell then
          SetPnlCell(Op.PnL, AText, AStyle)
        else
          SetMissingCell(AText, AStyle);
      end;
  end;
end;

procedure TFormMain.SetPnlCell(AValue: Double; out AText: string;
  out AStyle: TGridStyle);
begin
  AText := FmtPnl(AValue);
  if AValue > 0 then
    AStyle := gsPositive
  else if AValue < 0 then
    AStyle := gsNegative
  else
    AStyle := gsMuted;
end;

procedure TFormMain.SetMissingCell(out AText: string; out AStyle: TGridStyle);
begin
  AText := Dash;
  AStyle := gsMuted;
end;

procedure TFormMain.UpdateStatus;
var
  I: Integer;
  Cost, Value, PnL: Double;
begin
  Cost := 0;
  Value := 0;
  PnL := 0;
  for I := 0 to High(FPortfolio) do
  begin
    Cost := Cost + FPortfolio[I].Cost;
    Value := Value + FPortfolio[I].Value;
    PnL := PnL + FPortfolio[I].PnL;
  end;

  sbMain.SimpleText := Format('Позиций %d · Вложено %s · Стоимость %s · P&L %s',
    [Length(FPortfolio), FmtMoney(Cost), FmtMoney(Value), FmtPnl(PnL)]);
end;

function TFormMain.FocusedRowIsOp: Boolean;
begin
  Result := FGrid.FocusedRow.Sub >= 0;
end;

procedure TFormMain.RefreshExecute(Sender: TObject);
begin
  Reload;
end;

procedure TFormMain.QuitExecute(Sender: TObject);
begin
  Close;
end;

procedure TFormMain.NotImplemented(Sender: TObject);
var
  CmdCaption: string;
begin
  CmdCaption := TCustomAction(Sender).Caption;
  Say(Format('Ещё не реализовано: %s',
    [StringReplace(CmdCaption, '&', '', [rfReplaceAll])]));
end;

{ Доступность команд — единственное место, где она вычисляется: остальное
  берут из действий. Все прочие действия доступны всегда. }
procedure TFormMain.ActionsUpdate(AAction: TBasicAction; var Handled: Boolean);
var
  OnOp: Boolean;
begin
  OnOp := FocusedRowIsOp;
  if AAction = actEdit then
    actEdit.Enabled := OnOp
  else if AAction = actDelete then
    actDelete.Enabled := OnOp;
  Handled := True;
end;

procedure TFormMain.Say(const Msg: string);
begin
  sbMain.SimpleText := Msg;
end;

procedure TFormMain.GridDblClick(Sender: TObject);
begin
  actEdit.Execute;
end;

{ Enter — не ShortCut действия: тот срабатывал бы на всей форме и перехватывал
  нажатие кнопки в фокусе. }
procedure TFormMain.GridKeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
  if (Key = VK_RETURN) and (Shift = []) then
  begin
    actEdit.Execute;
    Key := 0;
  end;
end;

procedure TFormMain.cboBaseChange(Sender: TObject);
begin
  actChangeBase.Execute;
end;

end.
