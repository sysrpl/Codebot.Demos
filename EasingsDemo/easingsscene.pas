unit EasingsScene;

{$mode delphi}

interface

{ This unit holds the easings demo scene. It does not use StdCtrls, so names
  such as TLabel and TCheckBox refer to the Codebot widgets. }

uses
  Classes, SysUtils,
  Codebot.System,
  Codebot.Platform,
  Codebot.Animation,
  Codebot.Graphics.Types,
  Codebot.Render.Graphics,
  Codebot.Hardware,
  Codebot.Render.Scenes,
  Codebot.Render.Widgets,
  Codebot.Render.Widgets.Themes,
  Codebot.Render.Widgets.Custom,
  Codebot.Render.Scenes.Widgets;

{ TTween moves a value from where it starts to where it finishes over a
  duration using an easing. A tween which has not been started has the value
  of Finish. }

type
  TTween = record
    Start, Finish: Float;
    Time, Duration: Double;
    Easing: TEasing;
    { Set the value with no movement }
    procedure Reset(Value: Float);
    { Move from the current value to a target, beginning at the time Now }
    procedure Move(Target: Float; Now, Span: Double; Ease: TEasing);
    function Value(Now: Double): Float;
    function Playing(Now: Double): Boolean;
  end;

{ TGridItem is one easing in the grid. X and Y are the center of the item
  relative to the center of the scene. }

  TGridItem = record
    Name: string;
    Easing: TEasing;
    Reversed: Boolean;
    X, Y: TTween;
    Scale: TTween;
    { The opacity of the button drawn behind the item }
    Alpha: TTween;
    { Line is how far the curve of the item is blended towards a straight
      line. While the item is hot it loops back and forth from LineTime. }
    Line: TTween;
    LineLoop: Boolean;
    LineTime: Double;
  end;

{ TEasingsDemoScene is the easings grid example from the Bare Game library.

  Every easing registered with Codebot.Animation is an item in a grid drawn
  over a background image. An item graphs its easing and names it.

  Moving the mouse over an item makes it hot. A hot item grows to full size
  using its own easing, a button fades in behind it, its curve bends back and
  forth towards a straight line, and a block above the graph is moved from
  left to right by the easing every two seconds.

  An item can be dragged with the left mouse button. A dragged item is moved
  to the end of the grid, and the items ease into their places when the
  button is released.

  F4 rotates the grid by 45 degrees, F5 starts or stops the grid spinning,
  and F6 reverses the easings. The grid turns about the z axis, which is the
  axis pointing out of the screen, so it turns in the plane of the screen
  about its center. The dialog has a button and check boxes which do the
  same. }

  TEasingsDemoScene = class(TWidgetScene)
  private
    FThemes: array[0..5] of TTheme;
    FBackground: IBitmap;
    FItems: array of TGridItem;
    FHot: Integer;
    FDrag: Integer;
    FMouse: TPointF;
    FMouseOver: Boolean;
    FAngle: TTween;
    FAngleTo: Float;
    FSpin: TTween;
    FSpinning: Boolean;
    FSpinTime: Double;
    FSize: TPointI;
    FChanging: Boolean;
    FSpinBox: TCheckBox;
    FReverseBox: TCheckBox;
    FThemeBox: TSpinBox;
    FFullScreenBox: TCheckBox;
    function SpinAngle: Float;
    function GridMatrix: IMatrix;
    function ItemMatrix(Index: Integer): IMatrix;
    function ItemAt(const P: TPointF): Integer;
    function LineValue(Index: Integer): Float;
    procedure Arrange(Span: Double);
    procedure BuildItems;
    procedure BuildDialog;
    procedure HotChange(Index: Integer);
    procedure HotTrack;
    procedure Rotate;
    procedure Spin;
    procedure Reverse;
    procedure DrawBackground;
    procedure DrawItem(Index: Integer);
    procedure RotateClick(Sender: TObject);
    procedure SpinChange(Sender: TObject);
    procedure ReverseChange(Sender: TObject);
    procedure ThemeChange(Sender: TObject);
    procedure FullScreenChange(Sender: TObject);
    procedure FullScreenSync;
    procedure CloseClick(Sender: TObject);
  protected
    function DefaultTheme: TTheme; override;
  public
    procedure Initialize; override;
    procedure Finalize; override;
    procedure Render; override;
    procedure DoKeyDown(var Args: TSceneKeyArgs); override;
    procedure DoMouseDown(var Args: TSceneMouseArgs); override;
    procedure DoMouseMove(var Args: TSceneMouseArgs); override;
    procedure DoMouseUp(var Args: TSceneMouseArgs); override;
  end;

implementation

const
  { The size of an item and the space between items }
  GridX = 200;
  GridY = 160;
  BorderX = 14;
  BorderY = 30;
  { The scale of an item, and of a hot item }
  ScaleNormal = 0.8;
  ScaleHot = 1;
  { The opacity of the button behind a hot item, and the opacity above which
    the block of an item is drawn }
  AlphaHot = 0.5;
  AlphaBlock = 0.21;
  { The time taken for the block of a hot item to cross its graph }
  BlockTime = 2;
  { The time taken for the curve of a hot item to bend one way }
  LineTime = 0.75;
  { The time taken for the grid to spin around once }
  SpinTime = 18;
  ColorBlack = $FF000000;
  ColorGreen = $FF008000;
  ThemeNames: array[0..5] of string = ('Arc Dark', 'Chicago', 'Graphite',
    'Experience', 'Vista', 'Cupertino');

{ These easings are added to the defaults by the demo }

function Smooth(Percent: Float): Float;
begin
  if Percent < 0.5 then
  begin
    Percent := 0.5 - Percent;
    Percent := Percent * 2;
    Result := (1 - Percent * Percent * Percent) / 2;
  end
  else
  begin
    Percent := 0.5 - Percent;
    Percent := Percent * 2;
    Result := (Percent * Percent * Percent) / -2 + 0.5;
  end;
end;

function DropSlomo(Percent: Float): Float;
begin
  Percent := 1 - Percent;
  Result := 1 - (Percent * 2 - 1) * Percent;
end;

function Slap(Percent: Float): Float;
var
  P: Float;
begin
  P := Percent * 0.8;
  P := P * P;
  P := 1 - P;
  P := Sin(P * 8 * Pi + Pi) * 1.5;
  Percent := 1 - Percent;
  Percent := Percent * Percent * Percent;
  Percent := 1 - Percent;
  Result := P * (1 - Percent) + Percent;
end;

{ TTween }

procedure TTween.Reset(Value: Float);
begin
  Start := Value;
  Finish := Value;
  Duration := 0;
end;

procedure TTween.Move(Target: Float; Now, Span: Double; Ease: TEasing);
begin
  Start := Value(Now);
  Finish := Target;
  Time := Now;
  Duration := Span;
  Easing := Ease;
end;

function TTween.Value(Now: Double): Float;
begin
  if Playing(Now) then
    Result := Interpolate(Easing, (Now - Time) / Duration, Start, Finish)
  else
    Result := Finish;
end;

function TTween.Playing(Now: Double): Boolean;
begin
  Result := (Duration > 0) and (Now < Time + Duration);
end;

{ TEasingsDemoScene }

function TEasingsDemoScene.DefaultTheme: TTheme;
begin
  if FThemes[0] = nil then
  begin
    FThemes[0] := NewTheme(Canvas, TArcDarkTheme);
    FThemes[1] := NewTheme(Canvas, TChicagoTheme);
    FThemes[2] := NewTheme(Canvas, TGraphiteTheme);
    FThemes[3] := NewTheme(Canvas, TExperienceTheme);
    FThemes[4] := NewTheme(Canvas, TVistaTheme);
    FThemes[5] := NewTheme(Canvas, TCupertinoTheme);
  end;
  Result := FThemes[0];
end;

procedure TEasingsDemoScene.Initialize;
begin
  inherited Initialize;
  Context.SetClearColor(1, 1, 1, 1);
  Easings['Smooth'] := @Smooth;
  Easings['DropSlomo'] := @DropSlomo;
  Easings['Slap'] := @Slap;
  FBackground := Canvas.LoadBitmap('background',
    Context.GetAssetFile('textures/flowers.jpg'));
  FHot := -1;
  FDrag := -1;
  BuildItems;
  BuildDialog;
end;

procedure TEasingsDemoScene.Finalize;
var
  I: Integer;
begin
  { The widgets are freed by the inherited Finalize before their themes }
  inherited Finalize;
  for I := Low(FThemes) to High(FThemes) do
    FreeAndNil(FThemes[I]);
  FItems := nil;
  FBackground := nil;
end;

procedure TEasingsDemoScene.BuildItems;
var
  I: Integer;
begin
  SetLength(FItems, Easings.Count);
  for I := 0 to High(FItems) do
  begin
    FItems[I].Name := Easings.Items[I].Key;
    FItems[I].Easing := Easings.Items[I].Value;
    FItems[I].Scale.Reset(ScaleNormal);
  end;
end;

procedure TEasingsDemoScene.BuildDialog;
var
  Dialog: TWindow;
  Themes: StringArray;
  I: Integer;
begin
  FChanging := True;
  try
    for I := Low(ThemeNames) to High(ThemeNames) do
      Themes.Push(ThemeNames[I]);
    Dialog := Widget.Add<TWindow>;
    with Dialog do
    begin
      Text := 'Easings Grid';
      Fade := 0.1;
      OnClose := CloseClick;
      with This.Add<THBox> do
      begin
        Align := alignCenter;
        with This.Add<TGlyphImage> do
          Text := '󰋽';
        with This.Add<TLabel> do
        begin
          MaxWidth := 250;
          Text := 'Move the mouse over an easing to try it. Drag an easing ' +
            'to move it to the end of the grid.';
        end;
      end;
      with This.Add<TPushButton> do
      begin
        Indent := 1;
        Text := 'Rotate the grid (F4)';
        OnClick := RotateClick;
      end;
      with This.Add<TCheckBox>(FSpinBox) do
      begin
        Indent := 1;
        Text := 'Spin the grid (F5)';
        OnChange := SpinChange;
      end;
      with This.Add<TCheckBox>(FReverseBox) do
      begin
        Indent := 1;
        Text := 'Reverse the easings (F6)';
        OnChange := ReverseChange;
      end;
      with This.Add<TLabel> do
        Text := 'Theme:';
      with This.Add<TSpinBox>(FThemeBox) do
      begin
        Indent := 1;
        Width := 280;
        Items := Themes;
        ItemIndex := 0;
        Hint := 'Press and choose a theme for the widgets';
        OnChange := ThemeChange;
      end;
      with This.Add<TCheckBox>(FFullScreenBox) do
      begin
        Indent := 1;
        Text := 'Full screen (F1)';
        Checked := (Host.Window <> nil) and Host.Window.Fullscreen;
        OnChange := FullScreenChange;
      end;
      with This.Add<TLabel> do
        Text := 'Performance:';
      with This.Add<TPerformanceGraph> do
      begin
        Indent := 1;
        Width := 280;
        Height := 80;
        FrameMeasure := 1 / 10;
        Step := 4;
      end;
      with This.Add<TPushButton> do
      begin
        Align := alignCenter;
        Text := 'Close';
        OnClick := CloseClick;
      end;
    end;
    Dialog.Pack;
    Dialog.X := 20;
    Dialog.Y := 20;
  finally
    FChanging := False;
  end;
end;

{ Arrange gives each item its place in the grid in the order the items are
  kept. As many columns as fit across the scene are used, and the grid is
  centered in the scene both across and down. The items ease into place over
  a span of time, or are placed at once if the span is zero.

  The places are relative to the center of the scene, which is the point the
  grid turns about. }

procedure TEasingsDemoScene.Arrange(Span: Double);
var
  Easy: TEasing;
  Columns, Rows, I: Integer;
  X, Y: Float;
begin
  if Length(FItems) = 0 then
    Exit;
  Easy := Easings['Easy'];
  Columns := (Width + BorderX) div (GridX + BorderX);
  if Columns < 1 then
    Columns := 1;
  if Columns > Length(FItems) then
    Columns := Length(FItems);
  Rows := (Length(FItems) + Columns - 1) div Columns;
  for I := 0 to High(FItems) do
  begin
    { The center of the item, with the middle of the grid at zero }
    X := (I mod Columns - (Columns - 1) / 2) * (GridX + BorderX);
    Y := (I div Columns - (Rows - 1) / 2) * (GridY + BorderY);
    if Span > 0 then
    begin
      FItems[I].X.Move(X, Time, Span, Easy);
      FItems[I].Y.Move(Y, Time, Span, Easy);
    end
    else
    begin
      FItems[I].X.Reset(X);
      FItems[I].Y.Reset(Y);
    end;
  end;
end;

{ The angle the grid has spun about the z axis. While spinning it grows with
  time, and when the spinning stops it eases back to zero. }

function TEasingsDemoScene.SpinAngle: Float;
begin
  if FSpinning then
    Result := Frac((Time - FSpinTime) / SpinTime) * 2 * Pi
  else
    Result := FSpin.Value(Time);
end;

{ GridMatrix turns points relative to the center of the scene into points in
  the scene. The grid is turned about the z axis by the angle it was rotated
  to with F4 added to the angle it has spun, and is then moved to the center
  of the scene. }

function TEasingsDemoScene.GridMatrix: IMatrix;
begin
  Result := NewMatrix;
  Result.Rotate(FAngle.Value(Time) * Pi / 180 + SpinAngle);
  Result.Translate(Width / 2, Height / 2);
end;

{ ItemMatrix turns points relative to the center of an item into points in
  the scene }

function TEasingsDemoScene.ItemMatrix(Index: Integer): IMatrix;
var
  S: Float;
begin
  S := FItems[Index].Scale.Value(Time);
  Result := NewMatrix;
  Result.Scale(S, S);
  Result.Translate(FItems[Index].X.Value(Time), FItems[Index].Y.Value(Time));
  Result.Transform(GridMatrix);
end;

{ The item at a point in the scene, or -1 if there is none. The items drawn
  last are on top, so they are searched first. }

function TEasingsDemoScene.ItemAt(const P: TPointF): Integer;
var
  L: TPointF;
  I: Integer;
begin
  for I := High(FItems) downto 0 do
  begin
    L := ItemMatrix(I).Inverse.Multiply(P);
    if (Abs(L.X) <= GridX / 2) and (Abs(L.Y) <= GridY / 2) then
      Exit(I);
  end;
  Result := -1;
end;

function TEasingsDemoScene.LineValue(Index: Integer): Float;
var
  T: Double;
begin
  if not FItems[Index].LineLoop then
    Exit(FItems[Index].Line.Value(Time));
  { Each pass of the loop runs the opposite way to the one before it }
  T := (Time - FItems[Index].LineTime) / LineTime;
  Result := Frac(T);
  if Odd(Trunc(T)) then
    Result := 1 - Result;
  Result := Interpolate(Easings['Easy'], Result);
end;

{ HotChange makes an item hot, or no item hot if the index is -1. The item
  which was hot shrinks back, and the item which becomes hot grows using its
  own easing. }

procedure TEasingsDemoScene.HotChange(Index: Integer);
const
  Span = 0.2;
begin
  if Index = FHot then
    Exit;
  if FHot > -1 then
  begin
    FItems[FHot].Alpha.Move(0, Time, Span, FItems[FHot].Easing);
    FItems[FHot].Scale.Move(ScaleNormal, Time, Span, Easings['Extend']);
    FItems[FHot].Line.Reset(LineValue(FHot));
    FItems[FHot].Line.Move(0, Time, Span, Easings['Linear']);
    FItems[FHot].LineLoop := False;
  end;
  FHot := Index;
  if FHot > -1 then
  begin
    FItems[FHot].Alpha.Move(AlphaHot, Time, Span, Easings['Easy']);
    FItems[FHot].Scale.Move(ScaleHot, Time, Span, FItems[FHot].Easing);
    FItems[FHot].LineLoop := True;
    FItems[FHot].LineTime := Time;
  end;
end;

{ HotTrack makes the item under the mouse hot. The hot item is not changed
  while an item is dragged, nor while the item losing or gaining the mouse is
  still changing size, which stops items from flickering as they grow under
  the mouse. }

procedure TEasingsDemoScene.HotTrack;
var
  I: Integer;
begin
  if FDrag > -1 then
    Exit;
  if FMouseOver then
    I := ItemAt(FMouse)
  else
    I := -1;
  if I = FHot then
    Exit;
  if (FHot > -1) and FItems[FHot].Scale.Playing(Time) then
    Exit;
  if (I > -1) and FItems[I].Scale.Playing(Time) then
    Exit;
  HotChange(I);
end;

procedure TEasingsDemoScene.Rotate;
begin
  FAngleTo := FAngleTo + 45;
  FAngle.Move(FAngleTo, Time, 0.4, Easings['Easy']);
end;

procedure TEasingsDemoScene.Spin;
begin
  if FSpinning then
  begin
    { Ease back to facing the front by the shorter way around }
    FSpin.Reset(SpinAngle);
    if FSpin.Finish > Pi then
      FSpin.Reset(FSpin.Finish - 2 * Pi);
    FSpin.Move(0, Time, 0.2, Easings['Easy']);
    FSpinning := False;
  end
  else
  begin
    FSpinning := True;
    FSpinTime := Time;
  end;
  FChanging := True;
  try
    FSpinBox.Checked := FSpinning;
  finally
    FChanging := False;
  end;
end;

procedure TEasingsDemoScene.Reverse;
var
  I: Integer;
begin
  for I := 0 to High(FItems) do
    FItems[I].Reversed := not FItems[I].Reversed;
  FChanging := True;
  try
    FReverseBox.Checked := (Length(FItems) > 0) and FItems[0].Reversed;
  finally
    FChanging := False;
  end;
end;

procedure TEasingsDemoScene.RotateClick(Sender: TObject);
begin
  Rotate;
end;

procedure TEasingsDemoScene.SpinChange(Sender: TObject);
begin
  if not FChanging then
    Spin;
end;

procedure TEasingsDemoScene.ReverseChange(Sender: TObject);
begin
  if not FChanging then
    Reverse;
end;

procedure TEasingsDemoScene.ThemeChange(Sender: TObject);
begin
  if FChanging or (FThemeBox.ItemIndex < 0) then
    Exit;
  Widget.Theme := FThemes[FThemeBox.ItemIndex];
end;

{ The window is the form holding the graphics box with the LCL or the SDL
  window with the SDL application }

procedure TEasingsDemoScene.FullScreenChange(Sender: TObject);
begin
  if FChanging then
    Exit;
  if Host.Window <> nil then
    Host.Window.Fullscreen := (Sender as TCheckBox).Checked;
end;

{ The window can enter or leave full screen without the check box, such as
  when F1 is pressed, so the check box is made to match the window }

procedure TEasingsDemoScene.FullScreenSync;
var
  Value: Boolean;
begin
  if (Host.Window = nil) or (FFullScreenBox = nil) then
    Exit;
  Value := Host.Window.Fullscreen;
  if FFullScreenBox.Checked = Value then
    Exit;
  FChanging := True;
  try
    FFullScreenBox.Checked := Value;
  finally
    FChanging := False;
  end;
end;

procedure TEasingsDemoScene.CloseClick(Sender: TObject);
begin
  if Host.Window <> nil then
    Host.Window.Close;
end;

{ The background image is scaled to cover the scene and centered, and is
  lightened by a white layer so the items can be seen over it }

procedure TEasingsDemoScene.DrawBackground;
var
  Scale, W, H: Float;
begin
  if (FBackground <> nil) and (FBackground.Width > 0) and (FBackground.Height > 0) then
  begin
    Scale := Width / FBackground.Width;
    if Height / FBackground.Height > Scale then
      Scale := Height / FBackground.Height;
    W := FBackground.Width * Scale;
    H := FBackground.Height * Scale;
    Canvas.DrawImage(FBackground, FBackground.ClientRect,
      NewRectF((Width - W) / 2, (Height - H) / 2, W, H));
  end;
  Canvas.Rect(0, 0, Width, Height);
  Canvas.Fill(NewColorF(1, 1, 1, 0.5));
end;

{ An item is drawn about its center using its matrix. The graph has its
  origin at the bottom left and its end at the top right, each marked by a
  dot. The block of a hot item is drawn on the top edge of the item. }

procedure TEasingsDemoScene.DrawItem(Index: Integer);
const
  Dot = 3;
  Block = 24;
var
  Linear: TEasing;
  M: IMatrix;
  O, S: TPointF;
  Alpha, Line, Y1, Y2, X: Float;
  I, Count: Integer;
begin
  Linear := Easings['Linear'];
  M := ItemMatrix(Index);
  M.Transform(Canvas.Matrix);
  Canvas.Matrix.Push;
  Canvas.Matrix := M;
  try
    { The button behind the item }
    Alpha := FItems[Index].Alpha.Value(Time);
    if Alpha > 0 then
    begin
      Canvas.RoundRect(-GridX / 2, -GridY / 2, GridX, GridY, 8);
      Canvas.Fill(NewColorF(1, 1, 1, Alpha));
    end;
    O := NewPointF(BorderX - GridX / 2, GridY / 2 - BorderY);
    S := NewPointF(GridX - BorderX * 2, GridY - BorderY * 2);
    { The axes along the bottom and right of the graph }
    Canvas.MoveTo(O.X, O.Y);
    Canvas.LineTo(O.X + S.X, O.Y);
    Canvas.LineTo(O.X + S.X, O.Y - S.Y);
    Canvas.Stroke(ARGB(ColorGreen), 1.2);
    Canvas.Circle(O.X, O.Y, Dot);
    Canvas.Fill(ARGB(ColorBlack));
    Canvas.Circle(O.X + S.X, O.Y - S.Y, Dot);
    Canvas.Fill(ARGB(ColorBlack));
    { The curve of the easing blended towards a straight line }
    Line := LineValue(Index);
    if Line < 0 then
      Line := 0
    else if Line > 1 then
      Line := 1;
    Count := Round(S.X);
    Canvas.MoveTo(O.X, O.Y);
    for I := 1 to Count do
    begin
      Y1 := Interpolate(FItems[Index].Easing, I / S.X, 0, -S.Y, FItems[Index].Reversed);
      Y2 := Interpolate(Linear, I / S.X, 0, -S.Y);
      Canvas.LineTo(O.X + I, O.Y + Y1 * (1 - Line) + Y2 * Line);
    end;
    Canvas.Stroke(ARGB(ColorBlack), 1.5);
    { The block moved across the graph by the easing }
    if Alpha > AlphaBlock then
    begin
      X := Interpolate(FItems[Index].Easing, Frac(Time / BlockTime), 0, S.X,
        FItems[Index].Reversed);
      Canvas.Rect(O.X + X - Block / 2, O.Y - S.Y - BorderY - Block / 2, Block, Block);
      Alpha := Alpha / AlphaHot;
      if Alpha > 1 then
        Alpha := 1;
      Canvas.Fill(NewColorF(0, 0, 0, Alpha));
    end;
    if Font <> nil then
    begin
      Font.Size := 16;
      Font.Color := ARGB(ColorBlack);
      Font.Align := fontCenter;
      Font.Layout := fontMiddle;
      Canvas.DrawText(Font, FItems[Index].Name, 0, GridY / 2 - 15);
    end;
  finally
    Canvas.Matrix.Pop;
  end;
end;

procedure TEasingsDemoScene.Render;
var
  Buffer: IBackBuffer;
  I: Integer;
begin
  inherited Render;
  { The items are placed again when the size of the scene changes }
  if (Width <> FSize.X) or (Height <> FSize.Y) then
  begin
    FSize.X := Width;
    FSize.Y := Height;
    Arrange(0);
  end;
  HotTrack;
  FullScreenSync;
  { The grid is drawn in its own canvas frame, under the widgets }
  Buffer := Canvas as IBackBuffer;
  Buffer.Flip(Width, Height);
  try
    DrawBackground;
    for I := 0 to High(FItems) do
      DrawItem(I);
  finally
    Buffer.Flip(Width, Height);
  end;
  WidgetsRender;
end;

procedure TEasingsDemoScene.DoKeyDown(var Args: TSceneKeyArgs);
begin
  inherited DoKeyDown(Args);
  if Args.Handled then
    Exit;
  case Args.Key of
    { F1 is handled here so it works the same with the LCL and with SDL. The
      check box follows the window in FullScreenSync. }
    VK_F1:
      if Host.Window <> nil then
        Host.Window.Fullscreen := not Host.Window.Fullscreen;
    VK_F4: Rotate;
    VK_F5: Spin;
    VK_F6: Reverse;
  else
    Exit;
  end;
  Args.Handled := True;
end;

{ Pressing the left button on the hot item begins dragging it. The item is
  moved to the end of the items, which draws it over the others. }

procedure TEasingsDemoScene.DoMouseDown(var Args: TSceneMouseArgs);
var
  Item: TGridItem;
  I: Integer;
begin
  inherited DoMouseDown(Args);
  if Args.Handled or (Args.Button <> buttonLeft) or (FHot < 0) then
    Exit;
  Item := FItems[FHot];
  for I := FHot to High(FItems) - 1 do
    FItems[I] := FItems[I + 1];
  FItems[High(FItems)] := Item;
  FHot := High(FItems);
  FDrag := FHot;
  FMouse := NewPointF(Args.X, Args.Y);
  Args.Handled := True;
end;

{ A dragged item follows the mouse. The movement of the mouse is turned into
  the movement within the grid, so that the item stays under the mouse when
  the grid is rotated or spinning. }

procedure TEasingsDemoScene.DoMouseMove(var Args: TSceneMouseArgs);
var
  M: IMatrix;
  A, B: TPointF;
begin
  inherited DoMouseMove(Args);
  FMouseOver := not Args.Handled;
  if FDrag > -1 then
  begin
    M := GridMatrix.Inverse;
    A := M.Multiply(FMouse);
    B := M.Multiply(NewPointF(Args.X, Args.Y));
    FItems[FDrag].X.Reset(FItems[FDrag].X.Value(Time) + B.X - A.X);
    FItems[FDrag].Y.Reset(FItems[FDrag].Y.Value(Time) + B.Y - A.Y);
  end;
  FMouse := NewPointF(Args.X, Args.Y);
end;

procedure TEasingsDemoScene.DoMouseUp(var Args: TSceneMouseArgs);
begin
  inherited DoMouseUp(Args);
  if (FDrag > -1) and (Args.Button = buttonLeft) then
  begin
    FDrag := -1;
    Arrange(0.5);
  end;
end;

end.
