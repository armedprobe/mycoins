unit UIMain;

{$mode objfpc}{$H+}{$codepage utf8}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, ComCtrls,
  Menus, ExtCtrls, LCLType, laz.VirtualTrees,
  UIPalette, UINumFmt, UIMainData;

type
  TNodeKind = (nkCoin, nkOp);

  PNodeRec = ^TNodeRec;
  TNodeRec = record
    Kind: TNodeKind;
    Coin: Integer;   // индекс в FPortfolio
    Op: Integer;     // индекс в FPortfolio[Coin].Ops, только для nkOp
  end;

  TFormMain = class(TForm)
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
    vstMain: TLazVirtualStringTree;
    sbMain: TStatusBar;
    procedure FormCreate(Sender: TObject);
    procedure btnRefreshClick(Sender: TObject);
    procedure mnuQuitClick(Sender: TObject);
    procedure NotImplemented(Sender: TObject);
    procedure vstMainGetText(Sender: TBaseVirtualTree; Node: PVirtualNode;
      Column: TColumnIndex; TextType: TVSTTextType; var CellText: string);
    procedure vstMainPaintText(Sender: TBaseVirtualTree;
      const TargetCanvas: TCanvas; Node: PVirtualNode; Column: TColumnIndex;
      TextType: TVSTTextType);
    procedure vstMainBeforeCellPaint(Sender: TBaseVirtualTree;
      TargetCanvas: TCanvas; Node: PVirtualNode; Column: TColumnIndex;
      CellPaintMode: TVTCellPaintMode; CellRect: TRect; var ContentRect: TRect);
    procedure vstMainFocusChanged(Sender: TBaseVirtualTree; Node: PVirtualNode;
      Column: TColumnIndex);
    procedure vstMainDblClick(Sender: TObject);
    procedure vstMainKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
  private
    FPortfolio: TPortfolioRows;
    function NodeRec(Node: PVirtualNode): PNodeRec;
    procedure Reload;
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

{$R *.lfm}

function TFormMain.NodeRec(Node: PVirtualNode): PNodeRec;
begin
  Result := vstMain.GetNodeData(Node);
end;

procedure TFormMain.FormCreate(Sender: TObject);
begin
  vstMain.NodeDataSize := SizeOf(TNodeRec);
  vstMain.Colors.UnfocusedSelectionColor := clHighlight;
  vstMain.Colors.UnfocusedSelectionBorderColor := clHighlight;
  Reload;
  ActiveControl := vstMain;
end;

procedure TFormMain.Reload;
var
  CoinNode, OpNode: PVirtualNode;
  Rec: PNodeRec;
  I, J: Integer;
begin
  FPortfolio := MockPortfolio;

  vstMain.BeginUpdate;
  try
    vstMain.Clear;
    for I := 0 to High(FPortfolio) do
    begin
      CoinNode := vstMain.AddChild(nil);
      Rec := NodeRec(CoinNode);
      Rec^.Kind := nkCoin;
      Rec^.Coin := I;
      Rec^.Op := -1;

      for J := 0 to High(FPortfolio[I].Ops) do
      begin
        OpNode := vstMain.AddChild(CoinNode);
        Rec := NodeRec(OpNode);
        Rec^.Kind := nkOp;
        Rec^.Coin := I;
        Rec^.Op := J;
      end;
    end;

    CoinNode := vstMain.GetFirst;
    if CoinNode <> nil then
    begin
      vstMain.Expanded[CoinNode] := True;
      vstMain.FocusedNode := CoinNode;
      vstMain.Selected[CoinNode] := True;
    end;
  finally
    vstMain.EndUpdate;
  end;

  UpdateStatus;
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

procedure TFormMain.btnRefreshClick(Sender: TObject);
begin
  Reload;
end;

procedure TFormMain.mnuQuitClick(Sender: TObject);
begin
  Close;
end;

procedure TFormMain.NotImplemented(Sender: TObject);
var
  S: string;
begin
  if Sender is TMenuItem then
    S := TMenuItem(Sender).Caption
  else if Sender is TButton then
    S := TButton(Sender).Caption
  else
    S := '';
  Say('Ещё не реализовано: ' + StringReplace(S, '&', '', [rfReplaceAll]));
end;

procedure TFormMain.Say(const Msg: string);
begin
  sbMain.SimpleText := Msg;
end;

procedure TFormMain.vstMainGetText(Sender: TBaseVirtualTree;
  Node: PVirtualNode; Column: TColumnIndex; TextType: TVSTTextType;
  var CellText: string);
var
  Rec: PNodeRec;
  Coin: TPortfolioRow;
  Op: TOpRow;
begin
  Rec := NodeRec(Node);
  case Rec^.Kind of
    nkCoin:
      begin
        Coin := FPortfolio[Rec^.Coin];
        case Column of
          ColTitle: CellText := Coin.Name + '  ' + UpperCase(Coin.Symbol);
          ColQty: CellText := FmtQty(Coin.Qty);
          ColPrice: CellText := FmtMoney(Coin.Price);
          ColAmount, ColFee, ColRate: CellText := Dash;
          ColValue: CellText := FmtMoney(Coin.Value);
          ColPnl: CellText := FmtPnl(Coin.PnL);
        end;
      end;
    nkOp:
      begin
        Op := FPortfolio[Rec^.Coin].Ops[Rec^.Op];
        case Column of
          ColTitle:
            begin
              if Op.Kind = okBuy then
                CellText := Op.OccurredOn + '   Покупка'
              else
                CellText := Op.OccurredOn + '   Продажа';
            end;
          ColQty: CellText := FmtQty(Op.Qty);
          ColPrice: CellText := FmtPrice(Op.Price);
          ColAmount: CellText := FmtMoney(Op.Amount);
          ColFee: CellText := FmtMoney(Op.Fee / ScaleFee);
          ColRate: CellText := FmtRate(Op.Rate);
          ColValue: CellText := Dash;
          ColPnl:
            begin
              if Op.Kind = okSell then
                CellText := FmtPnl(Op.PnL)
              else
                CellText := Dash;
            end;
        end;
      end;
  end;
end;

procedure TFormMain.vstMainPaintText(Sender: TBaseVirtualTree;
  const TargetCanvas: TCanvas; Node: PVirtualNode; Column: TColumnIndex;
  TextType: TVSTTextType);
var
  Rec: PNodeRec;
  PnL: Double;
  HasPnL: Boolean;
begin
  if vstMain.Selected[Node] then
  begin
    TargetCanvas.Font.Color := clHighlightText;
    Exit;
  end;

  TargetCanvas.Font.Color := vstMain.Font.Color;
  if Column <> ColPnl then
    Exit;

  Rec := NodeRec(Node);
  HasPnL := False;
  PnL := 0;
  if Rec^.Kind = nkCoin then
  begin
    PnL := FPortfolio[Rec^.Coin].PnL;
    HasPnL := True;
  end
  else if Rec^.Kind = nkOp then
  begin
    PnL := FPortfolio[Rec^.Coin].Ops[Rec^.Op].PnL;
    HasPnL := FPortfolio[Rec^.Coin].Ops[Rec^.Op].Kind = okSell;
  end;

  if not HasPnL then
    TargetCanvas.Font.Color := clDataMuted
  else if PnL > 0 then
    TargetCanvas.Font.Color := clDataPositive
  else if PnL < 0 then
    TargetCanvas.Font.Color := clDataNegative
  else
    TargetCanvas.Font.Color := clDataMuted;
end;

procedure TFormMain.vstMainFocusChanged(Sender: TBaseVirtualTree;
  Node: PVirtualNode; Column: TColumnIndex);
begin
  btnDelete.Enabled := (Node <> nil) and (NodeRec(Node)^.Kind = nkOp);
end;

procedure TFormMain.vstMainBeforeCellPaint(Sender: TBaseVirtualTree;
  TargetCanvas: TCanvas; Node: PVirtualNode; Column: TColumnIndex;
  CellPaintMode: TVTCellPaintMode; CellRect: TRect; var ContentRect: TRect);
begin
  if (CellPaintMode = cpmPaint) and (NodeRec(Node)^.Kind = nkCoin) then
  begin
    TargetCanvas.Brush.Color := clBtnFace;
    TargetCanvas.FillRect(CellRect);
  end;
end;

procedure TFormMain.vstMainDblClick(Sender: TObject);
var
  Node: PVirtualNode;
begin
  Node := vstMain.FocusedNode;
  if (Node <> nil) and (NodeRec(Node)^.Kind = nkOp) then
    Say('Ещё не реализовано: правка операции');
end;

procedure TFormMain.vstMainKeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
  case Key of
    VK_INSERT:
      NotImplemented(btnBuy);
    VK_DELETE:
      if btnDelete.Enabled then
        NotImplemented(btnDelete);
  end;
end;

end.
