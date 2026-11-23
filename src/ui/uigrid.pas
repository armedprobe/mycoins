unit UIGrid;

{$mode objfpc}{$H+}{$codepage utf8}
{ Sender/Shift у обработчиков событий не используются: сигнатура навязана LCL/VST. }
{$warn 5024 off}

{ Грид-карточка главного экрана: TLazVirtualStringTree внутри рамки и панель
  постраничного вывода под ним.

  Дерево, раскрытие, сортировку, выделение и клавиатуру даёт VST; свои здесь
  только отрисовка шапки, плашки P&L, фоны строк и страницы. Скролла нет:
  страница — срез плоского списка видимых строк по высоте окна, всё вне
  среза отфильтровано (IsFiltered). Если срез начинается с вложенной строки,
  её родитель остаётся неотфильтрованным и повторяется первой строкой:
  vsFiltered не затрагивает детей.

  Данных контрол не знает: владелец задаёт число строк первого уровня, число
  вложенных и содержимое ячеек событиями. }

interface

uses
  Classes, SysUtils, Types, Controls, Graphics, Forms, Menus, StdCtrls, ExtCtrls,
  Math, LazUTF8, LCLType, laz.VirtualTrees, UIPalette;

type
  TGridStyle = (gsNormal, gsMuted, gsPositive, gsNegative);
  TGridCellKind = (gkText, gkBadge);

  { Строка грида. Item — строка первого уровня, Sub — вложенная строка внутри
    неё или -1 для самой строки первого уровня. Индексы — в модели владельца,
    сортировка их не меняет. }
  TGridRow = record
    Item: Integer;
    Sub: Integer;
  end;
  PGridRow = ^TGridRow;

  TGridGetSubCountEvent = procedure(Sender: TObject; AItem: Integer;
    var ACount: Integer) of object;
  TGridGetCellEvent = procedure(Sender: TObject; const ARow: TGridRow;
    ACol: Integer; var AText: string; var AStyle: TGridStyle) of object;
  TGridCompareEvent = procedure(Sender: TObject; const A, B: TGridRow;
    ACol: Integer; var AResult: Integer) of object;

  TGridColumnDefault = record
    Width: Integer;
    Kind: TGridCellKind;
  end;

  TGridCard = class(TCustomPanel)
  private
    FTree: TLazVirtualStringTree;
    FFooter: TPanel;
    FInfo: TLabel;
    FPrev: TLabel;
    FNext: TLabel;
    FMenu: TPopupMenu;
    FMenuHide: TMenuItem;
    FMenuUnsort: TMenuItem;
    FMenuCol: Integer;
    FDefaults: array of TGridColumnDefault;
    FVis: array of PVirtualNode;
    FPageStart: array of Integer;
    FPage: Integer;
    FWheel: Integer;
    FLoading: Boolean;
    FPruning: Boolean;
    FOnGetSubCount: TGridGetSubCountEvent;
    FOnGetCell: TGridGetCellEvent;
    FOnCompare: TGridCompareEvent;

    function Px(AValue: Integer): Integer;
    function RowOf(ANode: PVirtualNode): PGridRow;
    function ColIdOf(AColumn: TColumnIndex): Integer;
    function CellText(ANode: PVirtualNode; AColumn: TColumnIndex;
      out AStyle: TGridStyle): string;
    function IsBadge(AColumn: TColumnIndex; AStyle: TGridStyle): Boolean;
    function FitText(ACanvas: TCanvas; const AText: string; AMaxWidth: Integer): string;
    function NewMenuItem(const ACaption: string; ATag: Integer): TMenuItem;
    function FindNode(const ARow: TGridRow): PVirtualNode;

    function Capacity: Integer;
    function GetPageCount: Integer;
    function PageFirst: Integer;
    function PageLast: Integer;
    function IndexOfVis(ANode: PVirtualNode): Integer;
    function PageOfIndex(AIndex: Integer): Integer;
    function CurrentAnchor: PVirtualNode;
    procedure Repaginate(AAnchor: PVirtualNode);
    procedure ApplyPage;
    procedure GoPage(APage: Integer; AMoveFocus: Boolean);
    procedure FocusRow(ANode: PVirtualNode; AShift: TShiftState);
    procedure PruneSelection;
    procedure UpdateFooter;
    procedure SortBy(AColumn: TColumnIndex; ADir: TSortDirection);
    procedure ResetColumns;

    procedure TreeInitNode(Sender: TBaseVirtualTree; ParentNode, Node: PVirtualNode;
      var InitialStates: TVirtualNodeInitStates);
    procedure TreeInitChildren(Sender: TBaseVirtualTree; Node: PVirtualNode;
      var ChildCount: Cardinal);
    procedure TreeGetText(Sender: TBaseVirtualTree; Node: PVirtualNode;
      Column: TColumnIndex; TextType: TVSTTextType; var AText: String);
    procedure TreePaintText(Sender: TBaseVirtualTree; const TargetCanvas: TCanvas;
      Node: PVirtualNode; Column: TColumnIndex; TextType: TVSTTextType);
    procedure TreeDrawText(Sender: TBaseVirtualTree; TargetCanvas: TCanvas;
      Node: PVirtualNode; Column: TColumnIndex; const AText: String;
      const CellRect: TRect; var DefaultDraw: Boolean);
    procedure TreeMeasureText(Sender: TBaseVirtualTree; TargetCanvas: TCanvas;
      Node: PVirtualNode; Column: TColumnIndex; const AText: String;
      var Extent: Integer);
    procedure TreeBeforeItemErase(Sender: TBaseVirtualTree; TargetCanvas: TCanvas;
      Node: PVirtualNode; const ItemRect: TRect; var ItemColor: TColor;
      var EraseAction: TItemEraseAction);
    procedure TreeBeforeCellPaint(Sender: TBaseVirtualTree; TargetCanvas: TCanvas;
      Node: PVirtualNode; Column: TColumnIndex; CellPaintMode: TVTCellPaintMode;
      CellRect: TRect; var ContentRect: TRect);
    procedure TreeAfterCellPaint(Sender: TBaseVirtualTree; TargetCanvas: TCanvas;
      Node: PVirtualNode; Column: TColumnIndex; const CellRect: TRect);
    procedure TreeAfterItemPaint(Sender: TBaseVirtualTree; TargetCanvas: TCanvas;
      Node: PVirtualNode; const ItemRect: TRect);
    procedure TreeHotChange(Sender: TBaseVirtualTree; OldNode, NewNode: PVirtualNode);
    procedure TreeHeaderQuery(Sender: TVTHeader; var PaintInfo: THeaderPaintInfo;
      var Elements: THeaderPaintElements);
    procedure TreeHeaderDraw(Sender: TVTHeader; var PaintInfo: THeaderPaintInfo;
      const Elements: THeaderPaintElements);
    procedure TreeHeaderClick(Sender: TVTHeader; HitInfo: TVTHeaderHitInfo);
    procedure TreeCompare(Sender: TBaseVirtualTree; Node1, Node2: PVirtualNode;
      Column: TColumnIndex; var Result: Integer);
    procedure TreeExpanded(Sender: TBaseVirtualTree; Node: PVirtualNode);
    procedure TreeCollapsed(Sender: TBaseVirtualTree; Node: PVirtualNode);
    procedure TreeChange(Sender: TBaseVirtualTree; Node: PVirtualNode);
    procedure TreeResize(Sender: TObject);
    procedure TreeKeyAction(Sender: TBaseVirtualTree; var CharCode: Word;
      var Shift: TShiftState; var DoDefault: Boolean);
    procedure TreeKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure TreeDblClick(Sender: TObject);
    procedure TreeMouseWheel(Sender: TObject; Shift: TShiftState; WheelDelta: Integer;
      MousePos: TPoint; var Handled: Boolean);
    function NewLink(const ACaption: string; ARightSpacing: Integer;
      AOnClick: TNotifyEvent): TLabel;
    function LinkEnabled(ALink: TLabel): Boolean;
    procedure PaintLink(ALink: TLabel; AHot: Boolean);
    procedure LinkEnter(Sender: TObject);
    procedure LinkLeave(Sender: TObject);
    procedure PrevClick(Sender: TObject);
    procedure NextClick(Sender: TObject);
    procedure MenuClick(Sender: TObject);
  protected
    procedure DoEnter; override;
  public
    constructor Create(AOwner: TComponent); override;

    procedure AddColumn(AColId: Integer; const ACaption: string; AWidth: Integer;
      AAlignment: TAlignment; AKind: TGridCellKind);
    { Перечитать данные: строк первого уровня ACount. Раскрытые строки, строка
      в фокусе и сортировка сохраняются по индексам модели. }
    procedure LoadItems(ACount: Integer);
    function FocusedRow: TGridRow;
    function SelectedCount: Integer;

    property Page: Integer read FPage;
    property PageCount: Integer read GetPageCount;
  published
    property Align;
    property Anchors;
    property BorderSpacing;
    property Constraints;
    property TabOrder;
    property OnKeyDown;
    property OnDblClick;
    property OnGetSubCount: TGridGetSubCountEvent read FOnGetSubCount write FOnGetSubCount;
    property OnGetCell: TGridGetCellEvent read FOnGetCell write FOnGetCell;
    property OnCompare: TGridCompareEvent read FOnCompare write FOnCompare;
  end;

implementation

const
  LogicalHeaderHeight = 40;
  LogicalFooterHeight = 40;
  LogicalRowHeight = 28;
  LogicalIndent = 16;
  LogicalMinColWidth = 80;
  LogicalBadgeHeight = 20;
  LogicalBadgeRadius = 4;
  LogicalDotZone = 20;
  LogicalLinkGap = 16;
  Ellipsis = #$E2#$80#$A6;  // U+2026, записан байтами UTF-8: литерал стал бы WideString
  WheelStep = 120;
  MenuItemSortAsc = 0;
  MenuItemSortDesc = 1;
  MenuItemHide = 2;
  MenuItemReset = 3;
  MenuItemFit = 4;
  MenuItemUnsort = 5;

{ TGridCard }

constructor TGridCard.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  BevelOuter := bvNone;
  BorderWidth := 1;
  ParentBackground := False;
  Color := clGridLine;
  FMenuCol := -1;

  FFooter := TPanel.Create(Self);
  FFooter.Parent := Self;
  FFooter.Align := alBottom;
  FFooter.Height := Px(LogicalFooterHeight);
  FFooter.BorderSpacing.Top := 1;
  FFooter.BevelOuter := bvNone;
  FFooter.ParentBackground := False;
  FFooter.Color := clGridCard;

  FPrev := NewLink('Назад', Px(LogicalLinkGap), @PrevClick);
  FNext := NewLink('Вперёд', Px(LogicalIndent), @NextClick);

  FInfo := TLabel.Create(Self);
  FInfo.Parent := FFooter;
  FInfo.Align := alLeft;
  FInfo.Layout := tlCenter;
  FInfo.BorderSpacing.Left := Px(LogicalIndent);
  FInfo.Font.Color := clGridMuted;

  FTree := TLazVirtualStringTree.Create(Self);
  FTree.Parent := Self;
  FTree.Align := alClient;
  FTree.BorderStyle := bsNone;
  FTree.Color := clGridCard;
  FTree.NodeDataSize := SizeOf(TGridRow);
  FTree.TreeOptions.AutoOptions := [];
  FTree.TreeOptions.AnimationOptions := [];
  FTree.TreeOptions.MiscOptions := [toFullRepaintOnResize];
  FTree.TreeOptions.PaintOptions := [toHideFocusRect, toShowButtons, toShowRoot];
  FTree.TreeOptions.SelectionOptions := [toFullRowSelect, toMultiSelect];
  FTree.ScrollBarOptions.ScrollBars := ssNone;
  FTree.DefaultNodeHeight := Px(LogicalRowHeight);
  FTree.Indent := Px(LogicalIndent);
  FTree.Margin := Px(LogicalIndent);
  FTree.TextMargin := 0;
  FTree.ButtonStyle := bsTriangle;
  FTree.Colors.FocusedSelectionColor := clGridSelected;
  FTree.Colors.FocusedSelectionBorderColor := clGridSelected;
  FTree.Colors.UnfocusedSelectionColor := clGridSelected;
  FTree.Colors.UnfocusedSelectionBorderColor := clGridSelected;
  FTree.Colors.SelectionTextColor := clGridText;
  FTree.Colors.UnfocusedColor := clGridText;

  FTree.Header.Height := Px(LogicalHeaderHeight);
  FTree.Header.Options := [hoVisible, hoColumnResize, hoOwnerDraw, hoHotTrack,
    hoAutoResize, hoAutoSpring];
  FTree.Header.Background := clGridCard;

  FTree.OnInitNode := @TreeInitNode;
  FTree.OnInitChildren := @TreeInitChildren;
  FTree.OnGetText := @TreeGetText;
  FTree.OnPaintText := @TreePaintText;
  FTree.OnDrawText := @TreeDrawText;
  FTree.OnMeasureTextWidth := @TreeMeasureText;
  FTree.OnBeforeItemErase := @TreeBeforeItemErase;
  FTree.OnBeforeCellPaint := @TreeBeforeCellPaint;
  FTree.OnAfterCellPaint := @TreeAfterCellPaint;
  FTree.OnAfterItemPaint := @TreeAfterItemPaint;
  FTree.OnHotChange := @TreeHotChange;
  FTree.OnHeaderDrawQueryElements := @TreeHeaderQuery;
  FTree.OnAdvancedHeaderDraw := @TreeHeaderDraw;
  FTree.OnHeaderClick := @TreeHeaderClick;
  FTree.OnCompareNodes := @TreeCompare;
  FTree.OnExpanded := @TreeExpanded;
  FTree.OnCollapsed := @TreeCollapsed;
  FTree.OnChange := @TreeChange;
  FTree.OnResize := @TreeResize;
  FTree.OnKeyAction := @TreeKeyAction;
  FTree.OnKeyDown := @TreeKeyDown;
  FTree.OnDblClick := @TreeDblClick;
  FTree.OnMouseWheel := @TreeMouseWheel;

  FMenu := TPopupMenu.Create(Self);
  NewMenuItem('Сортировать по возрастанию', MenuItemSortAsc);
  NewMenuItem('Сортировать по убыванию', MenuItemSortDesc);
  FMenuUnsort := NewMenuItem('Сбросить сортировку', MenuItemUnsort);
  NewMenuItem('-', -1);
  FMenuHide := NewMenuItem('Скрыть колонку', MenuItemHide);
  NewMenuItem('Сбросить набор колонок', MenuItemReset);
  NewMenuItem('Подогнать ширину', MenuItemFit);

  UpdateFooter;
end;

{ Метрики. Логические размеры заданы для 96 DPI и масштабируются системным. }

function TGridCard.Px(AValue: Integer): Integer;
var
  Dpi: Integer;
begin
  Dpi := Screen.PixelsPerInch;
  if Dpi <= 0 then
    Dpi := 96;
  Result := MulDiv(AValue, Dpi, 96);
end;

procedure TGridCard.DoEnter;
begin
  inherited DoEnter;
  if FTree.CanFocus and not FTree.Focused then
    FTree.SetFocus;
end;

function TGridCard.NewMenuItem(const ACaption: string; ATag: Integer): TMenuItem;
begin
  Result := TMenuItem.Create(FMenu);
  Result.Caption := ACaption;
  Result.Tag := ATag;
  if ATag >= 0 then
    Result.OnClick := @MenuClick;
  FMenu.Items.Add(Result);
end;

{ Колонки. ColId хранится в Tag: порядок колонок пользователь не меняет,
  но события отдают номер колонки модели, а не индекс VST. }

procedure TGridCard.AddColumn(AColId: Integer; const ACaption: string;
  AWidth: Integer; AAlignment: TAlignment; AKind: TGridCellKind);
var
  Col: TVirtualTreeColumn;
  N: Integer;
begin
  Col := FTree.Header.Columns.Add;
  Col.Tag := AColId;
  Col.Text := ACaption;
  Col.Width := Px(AWidth);
  Col.MinWidth := Px(LogicalMinColWidth);
  Col.Alignment := AAlignment;
  Col.Options := [coAllowClick, coEnabled, coParentBidiMode, coParentColor,
    coResizable, coVisible, coAllowFocus, coAutoSpring];
  if Col.Index = 0 then
  begin
    FTree.Header.MainColumn := 0;
    FTree.Header.AutoSizeIndex := 0;
  end;

  N := Length(FDefaults);
  SetLength(FDefaults, N + 1);
  FDefaults[N].Width := Col.Width;
  FDefaults[N].Kind := AKind;
end;

function TGridCard.ColIdOf(AColumn: TColumnIndex): Integer;
begin
  Result := FTree.Header.Columns[AColumn].Tag;
end;

procedure TGridCard.ResetColumns;
var
  I: Integer;
  Col: TVirtualTreeColumn;
begin
  for I := 0 to FTree.Header.Columns.Count - 1 do
  begin
    Col := FTree.Header.Columns[I];
    Col.Position := I;
    Col.Width := FDefaults[I].Width;
    Col.Options := Col.Options + [coVisible];
  end;
end;

{ Данные }

function TGridCard.RowOf(ANode: PVirtualNode): PGridRow;
begin
  Result := PGridRow(FTree.GetNodeData(ANode));
end;

procedure TGridCard.LoadItems(ACount: Integer);
var
  OldExpanded: array of Boolean;
  OldFocus: TGridRow;
  Node: PVirtualNode;
begin
  OldExpanded := nil;
  SetLength(OldExpanded, FTree.RootNodeCount);
  Node := FTree.GetFirstChild(nil);
  while Node <> nil do
  begin
    OldExpanded[RowOf(Node)^.Item] := FTree.Expanded[Node];
    Node := FTree.GetNextSibling(Node);
  end;
  OldFocus := FocusedRow;

  FLoading := True;
  FTree.BeginUpdate;
  try
    FTree.Clear;
    FTree.RootNodeCount := Max(0, ACount);
    if FTree.Header.SortColumn > NoColumn then
      FTree.SortTree(FTree.Header.SortColumn, FTree.Header.SortDirection, True);
    Node := FTree.GetFirstChild(nil);
    while Node <> nil do
    begin
      if (RowOf(Node)^.Item <= High(OldExpanded)) and OldExpanded[RowOf(Node)^.Item] then
        FTree.Expanded[Node] := True;
      Node := FTree.GetNextSibling(Node);
    end;
  finally
    FTree.EndUpdate;
    FLoading := False;
  end;

  Node := FindNode(OldFocus);
  if Node = nil then
    Node := FTree.GetFirstChild(nil);
  Repaginate(Node);
  if Node <> nil then
    FocusRow(Node, []);
end;

function TGridCard.FindNode(const ARow: TGridRow): PVirtualNode;
var
  Child: PVirtualNode;
begin
  Result := FTree.GetFirstChild(nil);
  while (Result <> nil) and (RowOf(Result)^.Item <> ARow.Item) do
    Result := FTree.GetNextSibling(Result);
  if (Result = nil) or (ARow.Sub < 0) then
    Exit;
  if not FTree.Expanded[Result] then
    Exit;
  Child := FTree.GetFirstChild(Result);
  while (Child <> nil) and (RowOf(Child)^.Sub <> ARow.Sub) do
    Child := FTree.GetNextSibling(Child);
  if Child <> nil then
    Result := Child;
end;

function TGridCard.FocusedRow: TGridRow;
begin
  Result.Item := -1;
  Result.Sub := -1;
  if FTree.FocusedNode <> nil then
    Result := RowOf(FTree.FocusedNode)^;
end;

function TGridCard.SelectedCount: Integer;
begin
  Result := FTree.SelectedCount;
end;

procedure TGridCard.TreeInitNode(Sender: TBaseVirtualTree; ParentNode,
  Node: PVirtualNode; var InitialStates: TVirtualNodeInitStates);
var
  Row: PGridRow;
  Count: Integer;
begin
  Row := RowOf(Node);
  if ParentNode = nil then
  begin
    Row^.Item := Node^.Index;
    Row^.Sub := -1;
    Count := 0;
    if Assigned(FOnGetSubCount) then
      FOnGetSubCount(Self, Row^.Item, Count);
    if Count > 0 then
      Include(InitialStates, ivsHasChildren);
  end
  else
  begin
    Row^.Item := RowOf(ParentNode)^.Item;
    Row^.Sub := Node^.Index;
  end;
end;

procedure TGridCard.TreeInitChildren(Sender: TBaseVirtualTree; Node: PVirtualNode;
  var ChildCount: Cardinal);
var
  Count: Integer;
begin
  Count := 0;
  if Assigned(FOnGetSubCount) then
    FOnGetSubCount(Self, RowOf(Node)^.Item, Count);
  ChildCount := Max(0, Count);
end;

function TGridCard.CellText(ANode: PVirtualNode; AColumn: TColumnIndex;
  out AStyle: TGridStyle): string;
begin
  Result := '';
  AStyle := gsNormal;
  if (AColumn >= 0) and Assigned(FOnGetCell) then
    FOnGetCell(Self, RowOf(ANode)^, ColIdOf(AColumn), Result, AStyle);
end;

function TGridCard.IsBadge(AColumn: TColumnIndex; AStyle: TGridStyle): Boolean;
begin
  Result := (AColumn >= 0) and (FDefaults[AColumn].Kind = gkBadge)
    and (AStyle in [gsPositive, gsNegative]);
end;

procedure TGridCard.TreeGetText(Sender: TBaseVirtualTree; Node: PVirtualNode;
  Column: TColumnIndex; TextType: TVSTTextType; var AText: String);
var
  Style: TGridStyle;
begin
  AText := CellText(Node, Column, Style);
  if IsBadge(Column, Style) then
    AText := '';
end;

{ Текст рисуем сами: VST решает об обрезании по ширине, измеренной до того, как
  на холст буфера выставлен шрифт дерева, и режет строки, которые влезают.
  Здесь холст уже со шрифтом и цветом из OnPaintText. }
procedure TGridCard.TreeDrawText(Sender: TBaseVirtualTree; TargetCanvas: TCanvas;
  Node: PVirtualNode; Column: TColumnIndex; const AText: String;
  const CellRect: TRect; var DefaultDraw: Boolean);
var
  Style: TGridStyle;
  S: string;
  X: Integer;
begin
  DefaultDraw := False;
  S := CellText(Node, Column, Style);
  if IsBadge(Column, Style) then
    Exit;
  S := FitText(TargetCanvas, S, CellRect.Right - CellRect.Left);
  if (Column >= 0) and (FTree.Header.Columns[Column].Alignment = taRightJustify) then
    X := CellRect.Right - TargetCanvas.TextWidth(S)
  else
    X := CellRect.Left;
  TargetCanvas.Brush.Style := bsClear;
  TargetCanvas.TextOut(X, (CellRect.Top + CellRect.Bottom - TargetCanvas.TextHeight(S)) div 2, S);
end;

{ Плашка рисуется поверх ячейки, VST её текста не видит: ширину для
  «подогнать ширину» добавляем здесь. }
procedure TGridCard.TreeMeasureText(Sender: TBaseVirtualTree; TargetCanvas: TCanvas;
  Node: PVirtualNode; Column: TColumnIndex; const AText: String; var Extent: Integer);
var
  Style: TGridStyle;
  S: string;
begin
  S := CellText(Node, Column, Style);
  if IsBadge(Column, Style) then
    Extent := TargetCanvas.TextWidth(S) + Px(12);
  if FTree.Header.Columns[Column].Alignment = taRightJustify then
    Inc(Extent, Px(LogicalIndent));
end;

{ Отрисовка }

procedure TGridCard.TreePaintText(Sender: TBaseVirtualTree; const TargetCanvas: TCanvas;
  Node: PVirtualNode; Column: TColumnIndex; TextType: TVSTTextType);
var
  Style: TGridStyle;
begin
  CellText(Node, Column, Style);
  if Style = gsMuted then
    TargetCanvas.Font.Color := clGridMuted
  else
    TargetCanvas.Font.Color := clGridText;
end;

procedure TGridCard.TreeBeforeItemErase(Sender: TBaseVirtualTree; TargetCanvas: TCanvas;
  Node: PVirtualNode; const ItemRect: TRect; var ItemColor: TColor;
  var EraseAction: TItemEraseAction);
begin
  if (FTree.GetNodeLevel(Node) = 0) or (Node = FTree.HotNode) then
    ItemColor := clGridHover
  else
    ItemColor := clGridCard;
  EraseAction := eaColor;
end;

{ Отступ 16 справа у колонок с правым выравниванием: VST сам отступает
  только слева (Margin). }
procedure TGridCard.TreeBeforeCellPaint(Sender: TBaseVirtualTree; TargetCanvas: TCanvas;
  Node: PVirtualNode; Column: TColumnIndex; CellPaintMode: TVTCellPaintMode;
  CellRect: TRect; var ContentRect: TRect);
begin
  if (Column >= 0) and (FTree.Header.Columns[Column].Alignment = taRightJustify) then
    Dec(ContentRect.Right, Px(LogicalIndent));
end;

procedure TGridCard.TreeAfterCellPaint(Sender: TBaseVirtualTree; TargetCanvas: TCanvas;
  Node: PVirtualNode; Column: TColumnIndex; const CellRect: TRect);
var
  Style: TGridStyle;
  S: string;
  W, H, CenterY: Integer;
  R: TRect;
begin
  S := CellText(Node, Column, Style);
  if not IsBadge(Column, Style) then
    Exit;
  TargetCanvas.Font := FTree.Font;
  W := TargetCanvas.TextWidth(S) + Px(12);
  H := Px(LogicalBadgeHeight);
  CenterY := (CellRect.Top + CellRect.Bottom) div 2;
  R := Rect(CellRect.Right - Px(LogicalIndent) - W, CenterY - H div 2,
    CellRect.Right - Px(LogicalIndent), CenterY - H div 2 + H);

  TargetCanvas.Brush.Style := bsSolid;
  TargetCanvas.Pen.Style := psClear;
  if Style = gsPositive then
  begin
    TargetCanvas.Brush.Color := clGridPnlUpBg;
    TargetCanvas.Font.Color := clGridPnlUpFg;
  end
  else
  begin
    TargetCanvas.Brush.Color := clGridPnlDownBg;
    TargetCanvas.Font.Color := clGridPnlDownFg;
  end;
  TargetCanvas.RoundRect(R.Left, R.Top, R.Right, R.Bottom,
    Px(LogicalBadgeRadius), Px(LogicalBadgeRadius));
  TargetCanvas.Pen.Style := psSolid;
  TargetCanvas.Brush.Style := bsClear;
  TargetCanvas.TextOut(R.Left + Px(6), CenterY - TargetCanvas.TextHeight(S) div 2, S);
end;

procedure TGridCard.TreeAfterItemPaint(Sender: TBaseVirtualTree; TargetCanvas: TCanvas;
  Node: PVirtualNode; const ItemRect: TRect);
begin
  TargetCanvas.Brush.Style := bsSolid;
  TargetCanvas.Brush.Color := clGridLine;
  TargetCanvas.FillRect(Rect(ItemRect.Left, ItemRect.Bottom - 1, ItemRect.Right,
    ItemRect.Bottom));
end;

{ HotNode VST отслеживает всегда, но перерисовывает строку только с toHotTrack,
  а тот подчёркивает текст. }
procedure TGridCard.TreeHotChange(Sender: TBaseVirtualTree; OldNode,
  NewNode: PVirtualNode);
begin
  if OldNode <> nil then
    FTree.InvalidateNode(OldNode);
  if NewNode <> nil then
    FTree.InvalidateNode(NewNode);
end;

procedure TGridCard.TreeHeaderQuery(Sender: TVTHeader; var PaintInfo: THeaderPaintInfo;
  var Elements: THeaderPaintElements);
begin
  Elements := [hpeBackground, hpeText, hpeSortGlyph];
end;

{ Шапку VST рисует по элементам: фон, текст, глиф сортировки — каждый своим
  вызовом. Стрелка рисуется вместе с текстом, отдельный глиф пропускается. }
procedure TGridCard.TreeHeaderDraw(Sender: TVTHeader; var PaintInfo: THeaderPaintInfo;
  const Elements: THeaderPaintElements);
var
  C: TCanvas;
  R: TRect;
  Col: TVirtualTreeColumn;
  Title: string;
  CenterY, X, K, ArrowW, TextRight: Integer;
  Sorted: Boolean;
  P: array [0..2] of TPoint;
begin
  C := PaintInfo.TargetCanvas;
  R := PaintInfo.PaintRectangle;
  if hpeBackground in Elements then
  begin
    C.Brush.Style := bsSolid;
    C.Brush.Color := clGridCard;
    C.FillRect(R);
    C.Brush.Color := clGridLine;
    C.FillRect(Rect(R.Left, R.Bottom - 1, R.Right, R.Bottom));
  end;
  Col := PaintInfo.Column;
  if (Col = nil) or not (hpeText in Elements) then
    Exit;
  // Перед проходом текста VST сужает прямоугольник на 2 с каждой стороны.
  InflateRect(R, 2, 2);

  C.Font := FTree.Font;
  if PaintInfo.IsHoverIndex then
    C.Font.Color := clGridText
  else
    C.Font.Color := clGridMuted;
  C.Brush.Style := bsClear;
  CenterY := (R.Top + R.Bottom) div 2;
  Sorted := Col.Index = FTree.Header.SortColumn;
  ArrowW := IfThen(Sorted, Px(11), 0);
  Title := FitText(C, Col.Text,
    R.Right - Px(LogicalDotZone) - ArrowW - (R.Left + Px(LogicalIndent)));
  if Col.Alignment = taRightJustify then
  begin
    TextRight := R.Right - Px(LogicalDotZone) - ArrowW;
    X := TextRight - C.TextWidth(Title);
  end
  else
  begin
    X := R.Left + Px(LogicalIndent);
    TextRight := X + C.TextWidth(Title);
  end;
  C.TextOut(X, CenterY - C.TextHeight(Title) div 2, Title);

  if Sorted then
  begin
    X := TextRight + Px(4);
    if FTree.Header.SortDirection = sdAscending then
    begin
      P[0] := Point(X, CenterY + Px(2));
      P[1] := Point(X + Px(7), CenterY + Px(2));
      P[2] := Point(X + Px(3), CenterY - Px(2));
    end
    else
    begin
      P[0] := Point(X, CenterY - Px(2));
      P[1] := Point(X + Px(7), CenterY - Px(2));
      P[2] := Point(X + Px(3), CenterY + Px(2));
    end;
    C.Brush.Style := bsSolid;
    C.Brush.Color := C.Font.Color;
    C.Pen.Style := psClear;
    C.Polygon(P);
    C.Pen.Style := psSolid;
  end;

  C.Brush.Style := bsSolid;
  if PaintInfo.IsHoverIndex then
    C.Brush.Color := clGridMuted
  else
    C.Brush.Color := clGridLine;
  for K := -1 to 1 do
    C.FillRect(Rect(R.Right - Px(11), CenterY + K * Px(5) - Px(1), R.Right - Px(9),
      CenterY + K * Px(5) + Px(1)));
end;

function TGridCard.FitText(ACanvas: TCanvas; const AText: string;
  AMaxWidth: Integer): string;
var
  Len: Integer;
begin
  Result := AText;
  if (AMaxWidth <= 0) or (ACanvas.TextWidth(Result) <= AMaxWidth) then
    Exit;
  Len := UTF8Length(Result);
  while (Len > 0) and (ACanvas.TextWidth(UTF8Copy(Result, 1, Len) + Ellipsis) > AMaxWidth) do
    Dec(Len);
  if Len > 0 then
    Result := UTF8Copy(Result, 1, Len) + Ellipsis
  else
    Result := '';
end;

{ Шапка: сортировка и меню колонки }

procedure TGridCard.TreeHeaderClick(Sender: TVTHeader; HitInfo: TVTHeaderHitInfo);
var
  R: TRect;
  P: TPoint;
begin
  if (HitInfo.Button <> mbLeft) or (HitInfo.Column <= NoColumn) then
    Exit;
  R := FTree.Header.Columns[HitInfo.Column].GetRect;
  if HitInfo.X >= R.Right - Px(LogicalDotZone) then
  begin
    FMenuCol := HitInfo.Column;
    FMenuHide.Enabled := Length(FTree.Header.Columns.GetVisibleColumns) > 1;
    FMenuUnsort.Enabled := FTree.Header.SortColumn > NoColumn;
    P := Mouse.CursorPos;
    FMenu.PopUp(P.X, P.Y);
    Exit;
  end;
  if FTree.Header.SortColumn <> HitInfo.Column then
    SortBy(HitInfo.Column, sdAscending)
  else if FTree.Header.SortDirection = sdAscending then
    SortBy(HitInfo.Column, sdDescending)
  else
    SortBy(NoColumn, sdAscending);
end;

procedure TGridCard.MenuClick(Sender: TObject);
var
  Col: TVirtualTreeColumn;
begin
  if FMenuCol <= NoColumn then
    Exit;
  Col := FTree.Header.Columns[FMenuCol];
  case TMenuItem(Sender).Tag of
    MenuItemSortAsc: SortBy(FMenuCol, sdAscending);
    MenuItemSortDesc: SortBy(FMenuCol, sdDescending);
    MenuItemUnsort: SortBy(NoColumn, sdAscending);
    MenuItemHide:
      if Length(FTree.Header.Columns.GetVisibleColumns) > 1 then
        Col.Options := Col.Options - [coVisible];
    MenuItemReset: ResetColumns;
    MenuItemFit:
      FTree.Header.AutoFitColumns(False, smaUseColumnOption, FMenuCol, FMenuCol);
  end;
end;

procedure TGridCard.SortBy(AColumn: TColumnIndex; ADir: TSortDirection);
begin
  FTree.Header.SortColumn := AColumn;
  FTree.Header.SortDirection := ADir;
  FTree.SortTree(AColumn, ADir, True);
  FPage := 0;
  Repaginate(nil);
  if Length(FVis) > 0 then
    FocusRow(FVis[0], []);
end;

{ Направление сортировки применяет VST; при равенстве — порядок модели,
  чтобы сортировка была детерминированной. NoColumn — сброс: порядок модели. }
procedure TGridCard.TreeCompare(Sender: TBaseVirtualTree; Node1, Node2: PVirtualNode;
  Column: TColumnIndex; var Result: Integer);
var
  A, B: TGridRow;
begin
  A := RowOf(Node1)^;
  B := RowOf(Node2)^;
  Result := 0;
  if Assigned(FOnCompare) and (Column > NoColumn) then
    FOnCompare(Self, A, B, ColIdOf(Column), Result);
  if Result = 0 then
    Result := CompareValue(A.Item, B.Item);
  if Result = 0 then
    Result := CompareValue(A.Sub, B.Sub);
end;

{ Страницы }

function TGridCard.Capacity: Integer;
begin
  Result := Max(1, FTree.ClientHeight div Integer(FTree.DefaultNodeHeight));
end;

function TGridCard.GetPageCount: Integer;
begin
  Result := Max(1, Length(FPageStart));
end;

function TGridCard.PageFirst: Integer;
begin
  if Length(FPageStart) = 0 then
    Result := 0
  else
    Result := FPageStart[FPage];
end;

function TGridCard.PageLast: Integer;
begin
  if FPage < High(FPageStart) then
    Result := FPageStart[FPage + 1]
  else
    Result := Length(FVis);
end;

function TGridCard.IndexOfVis(ANode: PVirtualNode): Integer;
var
  I: Integer;
begin
  for I := 0 to High(FVis) do
    if FVis[I] = ANode then
      Exit(I);
  Result := -1;
end;

function TGridCard.PageOfIndex(AIndex: Integer): Integer;
var
  I: Integer;
begin
  Result := 0;
  for I := 0 to High(FPageStart) do
    if FPageStart[I] <= AIndex then
      Result := I;
end;

function TGridCard.CurrentAnchor: PVirtualNode;
begin
  Result := FTree.FocusedNode;
  if (Result = nil) and (Length(FVis) > 0) then
    Result := FVis[PageFirst];
end;

{ Плоский список видимых строк и начала страниц. Страница, начатая вложенной
  строкой, теряет одно место под повтор родителя. Открывается страница
  с якорем; якорь внутри свёрнутой строки заменяется ею самой. }
procedure TGridCard.Repaginate(AAnchor: PVirtualNode);
var
  Root, Child: PVirtualNode;
  N, I, Slots, Cap, Index: Integer;
begin
  N := 0;
  FVis := nil;
  SetLength(FVis, FTree.TotalCount);
  Root := FTree.GetFirstChild(nil);
  while Root <> nil do
  begin
    FVis[N] := Root;
    Inc(N);
    if FTree.Expanded[Root] then
    begin
      Child := FTree.GetFirstChild(Root);
      while Child <> nil do
      begin
        FVis[N] := Child;
        Inc(N);
        Child := FTree.GetNextSibling(Child);
      end;
    end;
    Root := FTree.GetNextSibling(Root);
  end;
  SetLength(FVis, N);

  Cap := Capacity;
  FPageStart := nil;
  I := 0;
  while I < N do
  begin
    SetLength(FPageStart, Length(FPageStart) + 1);
    FPageStart[High(FPageStart)] := I;
    Slots := Cap;
    if FTree.GetNodeLevel(FVis[I]) > 0 then
      Dec(Slots);
    Inc(I, Max(1, Slots));
  end;

  if (AAnchor <> nil) and (FTree.GetNodeLevel(AAnchor) > 0)
    and not FTree.Expanded[FTree.NodeParent[AAnchor]] then
    AAnchor := FTree.NodeParent[AAnchor];
  Index := IndexOfVis(AAnchor);
  if Index >= 0 then
    FPage := PageOfIndex(Index)
  else
    FPage := EnsureRange(FPage, 0, PageCount - 1);
  ApplyPage;
end;

procedure TGridCard.ApplyPage;
var
  I, First, Last: Integer;
begin
  First := PageFirst;
  Last := PageLast;
  FTree.BeginUpdate;
  try
    for I := 0 to High(FVis) do
      FTree.IsFiltered[FVis[I]] := (I < First) or (I >= Last);
    if (First < Length(FVis)) and (FTree.GetNodeLevel(FVis[First]) > 0) then
      FTree.IsFiltered[FTree.NodeParent[FVis[First]]] := False;
  finally
    FTree.EndUpdate;
  end;
  FTree.OffsetY := 0;
  PruneSelection;
  UpdateFooter;
end;

procedure TGridCard.GoPage(APage: Integer; AMoveFocus: Boolean);
begin
  FPage := EnsureRange(APage, 0, PageCount - 1);
  ApplyPage;
  if AMoveFocus and (Length(FVis) > 0) then
    FTree.FocusedNode := FVis[PageFirst];
  FTree.OffsetY := 0;
end;

procedure TGridCard.FocusRow(ANode: PVirtualNode; AShift: TShiftState);
begin
  if ANode = nil then
    Exit;
  if not (ssShift in AShift) then
    FTree.ClearSelection;
  FTree.FocusedNode := ANode;
  FTree.Selected[ANode] := True;
  FTree.OffsetY := 0;
end;

{ Выделение — только среди строк текущей страницы. Shift-диапазон, начатый на
  другой странице, VST начинает со скрытой строки; её и снимаем. }
procedure TGridCard.PruneSelection;
var
  Node, Next: PVirtualNode;
begin
  if FPruning then
    Exit;
  FPruning := True;
  try
    Node := FTree.GetFirstSelected;
    while Node <> nil do
    begin
      Next := FTree.GetNextSelected(Node);
      if not FTree.FullyVisible[Node] or FTree.IsEffectivelyFiltered[Node] then
        FTree.Selected[Node] := False;
      Node := Next;
    end;
  finally
    FPruning := False;
  end;
end;

procedure TGridCard.UpdateFooter;
var
  First: Integer;
begin
  First := PageFirst + 1;
  if Length(FVis) = 0 then
    First := 0;
  FInfo.Caption := Format('Стр. %d из %d · %d–%d из %d',
    [FPage + 1, PageCount, First, PageLast, Length(FVis)]);
  PaintLink(FPrev, FPrev.MouseInClient);
  PaintLink(FNext, FNext.MouseInClient);
end;

{ Ссылки листания: TLabel, а не TButton. Enabled у TLabel не трогаем —
  на Windows недоступная подпись рисуется системным «вдавленным» серым;
  доступность выводится из номера страницы. }
function TGridCard.NewLink(const ACaption: string; ARightSpacing: Integer;
  AOnClick: TNotifyEvent): TLabel;
begin
  Result := TLabel.Create(Self);
  Result.Parent := FFooter;
  Result.Align := alRight;
  Result.Layout := tlCenter;
  Result.Caption := ACaption;
  Result.BorderSpacing.Right := ARightSpacing;
  Result.OnClick := AOnClick;
  Result.OnMouseEnter := @LinkEnter;
  Result.OnMouseLeave := @LinkLeave;
end;

function TGridCard.LinkEnabled(ALink: TLabel): Boolean;
begin
  if ALink = FPrev then
    Result := FPage > 0
  else
    Result := FPage < PageCount - 1;
end;

procedure TGridCard.PaintLink(ALink: TLabel; AHot: Boolean);
begin
  if not LinkEnabled(ALink) then
  begin
    ALink.Font.Color := clGridLine;
    ALink.Font.Style := [];
    ALink.Cursor := crDefault;
  end
  else if AHot then
  begin
    ALink.Font.Color := clGridText;
    ALink.Font.Style := [fsUnderline];
    ALink.Cursor := crHandPoint;
  end
  else
  begin
    ALink.Font.Color := clGridMuted;
    ALink.Font.Style := [];
    ALink.Cursor := crHandPoint;
  end;
end;

procedure TGridCard.LinkEnter(Sender: TObject);
begin
  PaintLink(TLabel(Sender), True);
end;

procedure TGridCard.LinkLeave(Sender: TObject);
begin
  PaintLink(TLabel(Sender), False);
end;

{ Вложенные строки инициализируются при первом раскрытии, уже после сортировки
  дерева: сортируем их здесь. }
procedure TGridCard.TreeExpanded(Sender: TBaseVirtualTree; Node: PVirtualNode);
begin
  if FTree.Header.SortColumn > NoColumn then
    FTree.Sort(Node, FTree.Header.SortColumn, FTree.Header.SortDirection, True);
  if not FLoading then
    Repaginate(Node);
end;

procedure TGridCard.TreeCollapsed(Sender: TBaseVirtualTree; Node: PVirtualNode);
begin
  if not FLoading then
    Repaginate(Node);
end;

procedure TGridCard.TreeChange(Sender: TBaseVirtualTree; Node: PVirtualNode);
begin
  PruneSelection;
end;

procedure TGridCard.TreeResize(Sender: TObject);
begin
  if not FLoading then
    Repaginate(CurrentAnchor);
end;

{ Клавиши на границе страницы и листание. Остальное — штатная навигация VST:
  отфильтрованные строки она пропускает сама. }
procedure TGridCard.TreeKeyAction(Sender: TBaseVirtualTree; var CharCode: Word;
  var Shift: TShiftState; var DoDefault: Boolean);
var
  Current, Target: PVirtualNode;
begin
  if Length(FVis) = 0 then
    Exit;
  Current := FTree.FocusedNode;
  case CharCode of
    VK_NEXT, VK_PRIOR:
      begin
        if CharCode = VK_NEXT then
          GoPage(FPage + 1, True)
        else
          GoPage(FPage - 1, True);
        FocusRow(FTree.FocusedNode, Shift);
        DoDefault := False;
      end;
    VK_HOME, VK_END:
      if ssCtrl in Shift then
      begin
        if CharCode = VK_HOME then
        begin
          GoPage(0, False);
          Target := FVis[0];
        end
        else
        begin
          GoPage(PageCount - 1, False);
          Target := FVis[High(FVis)];
        end;
        FocusRow(Target, Shift - [ssCtrl]);
        DoDefault := False;
      end;
    VK_DOWN:
      if ssCtrl in Shift then
        DoDefault := False
      else if (Current <> nil) and (Current = FVis[PageLast - 1])
        and (FPage < PageCount - 1) then
      begin
        GoPage(FPage + 1, True);
        FocusRow(FTree.FocusedNode, Shift);
        DoDefault := False;
      end;
    VK_UP:
      if ssCtrl in Shift then
        DoDefault := False
      else if (Current <> nil) and (Current = FTree.GetFirstVisible(nil, True))
        and (FPage > 0) then
      begin
        Target := FVis[PageFirst - 1];
        GoPage(FPage - 1, False);
        FocusRow(Target, Shift);
        DoDefault := False;
      end;
  end;
end;

procedure TGridCard.TreeKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if Assigned(OnKeyDown) then
    OnKeyDown(Self, Key, Shift);
end;

procedure TGridCard.TreeDblClick(Sender: TObject);
begin
  if Assigned(OnDblClick) then
    OnDblClick(Self);
end;

procedure TGridCard.TreeMouseWheel(Sender: TObject; Shift: TShiftState;
  WheelDelta: Integer; MousePos: TPoint; var Handled: Boolean);
begin
  Handled := True;
  Inc(FWheel, WheelDelta);
  while FWheel >= WheelStep do
  begin
    Dec(FWheel, WheelStep);
    GoPage(FPage - 1, True);
  end;
  while FWheel <= -WheelStep do
  begin
    Inc(FWheel, WheelStep);
    GoPage(FPage + 1, True);
  end;
end;

procedure TGridCard.PrevClick(Sender: TObject);
begin
  GoPage(FPage - 1, True);
end;

procedure TGridCard.NextClick(Sender: TObject);
begin
  GoPage(FPage + 1, True);
end;

end.
