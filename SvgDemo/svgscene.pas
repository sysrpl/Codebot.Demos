unit SvgScene;

{$mode delphi}

interface

{ This unit holds the SVG demo scene. It does not use StdCtrls, so names such
  as TLabel and TCheckBox refer to the Codebot widgets. }

uses
  Classes, SysUtils,
  Codebot.System,
  Codebot.Platform,
  Codebot.Graphics.Types,
  Codebot.Render.Graphics,
  Codebot.Hardware,
  Codebot.Render.Scenes,
  Codebot.Render.SVG,
  Codebot.Render.Widgets,
  Codebot.Render.Widgets.Themes,
  Codebot.Render.Widgets.Custom,
  Codebot.Render.Scenes.Widgets;

{ TSvgDemoScene combines the two SVG demos from Tiny.Sim.

  The document view shows one SVG document at a time. Drag with the left
  mouse button to pan, drag with the right button to rotate, and turn the
  wheel to zoom.

  The icon grid shows a folder of SVG icons in rows, sized by a slider. The
  icons are parsed a few at a time while the scene is running.

  Both views share the rendering options: fills and strokes, outlines, path
  nodes, a transparent background, and animation. Left and Right, or the
  Prior and Next buttons, step through the documents or icons.

  The dialog also chooses the widget theme from a drop down list and switches
  the form in and out of full screen.

  The dialog itself can be transformed with the keyboard: Control with Up and
  Down scales it, Control with Left and Right rotates it, and Control and Alt
  (or Control and Shift) with Left and Right skews it. The changes are eased in over a few frames. }

type
  TSvgView = (viewDocument, viewGrid);
  TSvgDrag = (dragNone, dragPan, dragRotate);

  TSvgDemoScene = class(TWidgetScene)
  private
    FView: TSvgView;
    FDocuments: TStringList;
    FDocumentIndex: Integer;
    FDocument: TSvgRender;
    FIconFiles: TStringList;
    FIcons: array of TSvgRender;
    FIconCount: Integer;
    FIconIndex: Integer;
    FChecker: IBitmapBrush;
    FTitle: ILinearGradientBrush;
    FPan: TPointF;
    FZoom: Float;
    FRotate: Float;
    FDrag: TSvgDrag;
    FChanging: Boolean;
    FViews: array[TSvgView] of TCheckBox;
    FInfoLabel: TLabel;
    FSizeLabel: TLabel;
    FSizeSlider: TSlider;
    FFillBox: TCheckBox;
    FOutlineBox: TCheckBox;
    FNodeBox: TCheckBox;
    FBackgroundBox: TCheckBox;
    FAnimateBox: TCheckBox;
    FGraph: TPerformanceGraph;
    FThemes: array[0..5] of TTheme;
    FThemeBox: TSpinBox;
    FDialog: TWindow;
    { The transform of the widgets and what it is easing towards }
    FScale, FScaleTo: Float;
    FRotation, FRotationTo: Float;
    FSkew, FSkewTo: Float;
    FFrameTime: Double;
    { The point the dialog is transformed about, and a shift which keeps the
      dialog where it was when the pivot last changed }
    FPivot: TPointF;
    FOffset: TPointF;
    function TransformLinear: IMatrix;
    procedure TransformPivot;
    procedure TransformWidgets;
    procedure FindFiles(const Folder: string; Files: TStringList);
    procedure BuildChecker;
    procedure BuildDialog;
    procedure LoadIcons;
    procedure SelectDocument(Index: Integer);
    procedure StepDocument(Delta: Integer);
    procedure UpdateInfo;
    procedure DrawDocument(Options: TSvgRenderOptions);
    procedure DrawGrid(Options: TSvgRenderOptions);
    procedure DrawTitle;
    procedure ViewChange(Sender: TObject);
    procedure StepClick(Sender: TObject);
    procedure SizeChange(Sender: TObject);
    procedure ThemeChange(Sender: TObject);
    procedure FullScreenChange(Sender: TObject);
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
    procedure DoMouseWheel(var Args: TSceneWheelArgs); override;
  end;

implementation

const
  ViewNames: array[TSvgView] of string = ('Document', 'Icon grid');
  ThemeNames: array[0..5] of string = ('Arc Dark', 'Chicago', 'Graphite',
    'Experience', 'Vista', 'Cupertino');
  { The height of the strip across the top which names what is shown }
  TitleHeight = 42;
  { The width of a document at a zoom of one }
  DocumentSize = 256;
  { The longest time spent parsing icons in one frame }
  LoadTime = 0.006;
  { How far one key press scales, rotates, and skews the dialog }
  ScaleStep = 0.1;
  RotateStep = Pi / 12;
  SkewStep = 0.1;
  { How quickly the dialog moves to its new transform }
  EaseSpeed = 14;

{ TSvgDemoScene }

function TSvgDemoScene.DefaultTheme: TTheme;
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

procedure TSvgDemoScene.Initialize;
var
  Root: string;
begin
  inherited Initialize;
  Context.SetClearColor(1, 1, 1, 1);
  { The svg folders are beside the fonts folder in the assets }
  Root := ExtractFilePath(ExcludeTrailingPathDelimiter(ExtractFilePath(
    Context.GetAssetFile('fonts/roboto.ttf'))));
  FDocuments := TStringList.Create;
  FIconFiles := TStringList.Create;
  FindFiles(Root + 'svg' + PathDelim + 'vectors' + PathDelim, FDocuments);
  FindFiles(Root + 'svg' + PathDelim + 'icons' + PathDelim, FIconFiles);
  SetLength(FIcons, FIconFiles.Count);
  FScale := 1;
  FScaleTo := 1;
  FDocument := TSvgRender.Create(Canvas);
  FTitle := NewBrush(NewPointF(0, 0), NewPointF(0, TitleHeight));
  FTitle.NearStop.Color := ARGB($FFFFFFFF);
  FTitle.FarStop.Color := ARGB($FFC0C0C0);
  BuildChecker;
  BuildDialog;
  SelectDocument(0);
end;

procedure TSvgDemoScene.Finalize;
var
  I: Integer;
begin
  { The widgets are freed by the inherited Finalize before their themes }
  inherited Finalize;
  for I := Low(FThemes) to High(FThemes) do
    FreeAndNil(FThemes[I]);
  FDocument.Free;
  for I := 0 to High(FIcons) do
    FIcons[I].Free;
  FIcons := nil;
  FDocuments.Free;
  FIconFiles.Free;
  FChecker := nil;
  FTitle := nil;
end;

procedure TSvgDemoScene.FindFiles(const Folder: string; Files: TStringList);
var
  Search: TSearchRec;
begin
  if FindFirst(Folder + '*.svg', faAnyFile, Search) = 0 then
  try
    repeat
      if Search.Attr and faDirectory = 0 then
        Files.Add(Folder + Search.Name);
    until FindNext(Search) <> 0;
  finally
    FindClose(Search);
  end;
  Files.Sort;
end;

{ The transparent background is a small bitmap of gray and white squares
  which is repeated by a bitmap brush }

procedure TSvgDemoScene.BuildChecker;
var
  B: IRenderBitmap;
begin
  Canvas.Matrix.Push;
  Canvas.Matrix.Identity;
  B := Canvas.NewBitmap('checker', 32, 32);
  B.Bind;
  Canvas.Rect(0, 0, 32, 32);
  Canvas.Fill(ARGB($FFFFFFFF));
  Canvas.Rect(0, 0, 16, 16);
  Canvas.Fill(ARGB($FFD0D0D0));
  Canvas.Rect(16, 16, 16, 16);
  Canvas.Fill(ARGB($FFD0D0D0));
  B.Unbind;
  Canvas.Matrix.Pop;
  FChecker := NewBrush(B);
end;

procedure TSvgDemoScene.BuildDialog;
var
  Dialog: TWindow;
  Names: StringArray;
  V: TSvgView;
  I: Integer;
begin
  FChanging := True;
  try
    Dialog := Widget.Add<TWindow>;
    FDialog := Dialog;
    with Dialog do
    begin
      Text := 'SVG Demo';
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
          Text := 'This program parses SVG documents and draws them with ' +
            'the canvas. Drag to pan, drag with the right button to ' +
            'rotate, and use the wheel to zoom a document.';
        end;
      end;
      with This.Add<TLabel> do
        Text := 'View:';
      with This.Add<THBox> do
      begin
        Indent := 1;
        Margin := 0;
        for V := Low(TSvgView) to High(TSvgView) do
          with This.Add<TCheckBox>(FViews[V]) do
          begin
            Round := True;
            Margin := 4;
            Tag := Ord(V);
            Text := ViewNames[V];
            Checked := V = FView;
            OnChange := ViewChange;
          end;
      end;
      with This.Add<TLabel> do
        Text := 'Theme:';
      for I := Low(ThemeNames) to High(ThemeNames) do
        Names.Push(ThemeNames[I]);
      with This.Add<TSpinBox>(FThemeBox) do
      begin
        Indent := 1;
        Width := 280;
        Items := Names;
        ItemIndex := 0;
        Hint := 'Press and choose a theme for the widgets';
        OnChange := ThemeChange;
      end;
      with This.Add<THBox> do
      begin
        Align := alignCenter;
        with This.Add<TPushButton> do
        begin
          Tag := -1;
          Text := 'Prior';
          OnClick := StepClick;
        end;
        with This.Add<TPushButton> do
        begin
          Tag := 1;
          Text := 'Next';
          OnClick := StepClick;
        end;
      end;
      with This.Add<TLabel>(FSizeLabel) do
        Text := ' ';
      with This.Add<TSlider>(FSizeSlider) do
      begin
        Indent := 1;
        Width := 280;
        Min := 48;
        Max := 400;
        Step := 1;
        Position := 120;
        OnChange := SizeChange;
      end;
      with This.Add<TLabel>(FInfoLabel) do
      begin
        MaxWidth := 280;
        Text := ' ';
      end;
      with This.Add<TLabel> do
        Text := 'Rendering options:';
      with This.Add<TCheckBox>(FFillBox) do
      begin
        Indent := 1;
        Text := 'Draw strokes and fills';
        Checked := True;
      end;
      with This.Add<TCheckBox>(FOutlineBox) do
      begin
        Indent := 1;
        Text := 'Draw vector outlines';
      end;
      with This.Add<TCheckBox>(FNodeBox) do
      begin
        Indent := 1;
        Text := 'Draw nodes';
      end;
      with This.Add<TCheckBox>(FBackgroundBox) do
      begin
        Indent := 1;
        Text := 'Transparent background';
      end;
      with This.Add<TCheckBox>(FAnimateBox) do
      begin
        Indent := 1;
        Text := 'Animated scale and rotation';
      end;
      with This.Add<TCheckBox> do
      begin
        Indent := 1;
        Text := 'Full screen';
        Checked := (Host.Window <> nil) and Host.Window.Fullscreen;
        OnChange := FullScreenChange;
      end;
      with This.Add<TLabel> do
        Text := 'Performance:';
      with This.Add<TPerformanceGraph>(FGraph) do
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
    SizeChange(nil);
    Dialog.Pack;
    Dialog.X := 20;
    Dialog.Y := TitleHeight + 20;
  finally
    FChanging := False;
  end;
end;

{ Icons are parsed on the render thread a few at a time, stopping when the
  time allowed for one frame is used up }

procedure TSvgDemoScene.LoadIcons;
var
  Start: Double;
begin
  if FIconCount >= FIconFiles.Count then
    Exit;
  Start := TimeQuery;
  repeat
    FIcons[FIconCount] := TSvgRender.Create(Canvas);
    FIcons[FIconCount].ParseFile(FIconFiles[FIconCount]);
    Inc(FIconCount);
  until (FIconCount >= FIconFiles.Count) or (TimeQuery - Start > LoadTime);
  if FView = viewGrid then
    UpdateInfo;
end;

procedure TSvgDemoScene.SelectDocument(Index: Integer);
begin
  if FDocuments.Count = 0 then
  begin
    UpdateInfo;
    Exit;
  end;
  if Index < 0 then
    Index := FDocuments.Count - 1
  else if Index > FDocuments.Count - 1 then
    Index := 0;
  FDocumentIndex := Index;
  FDocument.ParseFile(FDocuments[FDocumentIndex]);
  { A new document starts centered, upright, and at the normal zoom }
  FPan := NewPointF(0, 0);
  FZoom := 0;
  FRotate := 0;
  UpdateInfo;
end;

{ StepDocument moves to the next or prior document, or shifts the icons in the grid }

procedure TSvgDemoScene.StepDocument(Delta: Integer);
begin
  if FView = viewDocument then
    SelectDocument(FDocumentIndex + Delta)
  else if FIconCount > 0 then
  begin
    FIconIndex := (FIconIndex + Delta) mod FIconCount;
    if FIconIndex < 0 then
      FIconIndex := FIconIndex + FIconCount;
    UpdateInfo;
  end;
end;

procedure TSvgDemoScene.UpdateInfo;
var
  R: TRectF;
  S: string;
begin
  if FInfoLabel = nil then
    Exit;
  if FView = viewGrid then
    S := Format('Showing %d of %d icons.', [FIconCount, FIconFiles.Count])
  else if FDocuments.Count = 0 then
    S := 'No documents were found in the assets svg/vectors folder.'
  else
  begin
    R := FDocument.ViewBox;
    S := Format('This document is %d bytes in size with %d command nodes.'#10 +
      'View box: %.1f %.1f %.1f %.1f', [FDocument.DocumentSize, FDocument.NodeCount,
      R.X, R.Y, R.Width, R.Height]);
  end;
  FInfoLabel.Text := S;
end;

procedure TSvgDemoScene.ViewChange(Sender: TObject);
var
  Box: TCheckBox;
  V: TSvgView;
begin
  if FChanging then
    Exit;
  FChanging := True;
  try
    { Only one view is checked, so clicking the checked one keeps it checked }
    Box := Sender as TCheckBox;
    for V := Low(TSvgView) to High(TSvgView) do
      FViews[V].Checked := FViews[V] = Box;
    FView := TSvgView(Integer(Box.Tag));
    FDrag := dragNone;
    UpdateInfo;
  finally
    FChanging := False;
  end;
end;

procedure TSvgDemoScene.StepClick(Sender: TObject);
begin
  StepDocument((Sender as TWidget).Tag);
end;

procedure TSvgDemoScene.SizeChange(Sender: TObject);
begin
  FSizeLabel.Text := Format('Icon size in the grid: %d pixels', [Round(FSizeSlider.Position)]);
end;

procedure TSvgDemoScene.ThemeChange(Sender: TObject);
begin
  if FChanging or (FThemeBox.ItemIndex < 0) then
    Exit;
  Widget.Theme := FThemes[FThemeBox.ItemIndex];
end;

{ The window is the form holding the graphics box with the LCL or the SDL
  window with the SDL application }

procedure TSvgDemoScene.FullScreenChange(Sender: TObject);
begin
  if Host.Window <> nil then
    Host.Window.Fullscreen := (Sender as TCheckBox).Checked;
end;

procedure TSvgDemoScene.CloseClick(Sender: TObject);
begin
  if Host.Window <> nil then
    Host.Window.Close;
end;

{ One document in the middle of the scene. When animated it turns and
  breathes in and out, otherwise it follows the pan, zoom, and rotation set
  with the mouse. }

procedure TSvgDemoScene.DrawDocument(Options: TSvgRenderOptions);
var
  Scale: Float;
begin
  if FDocuments.Count = 0 then
    Exit;
  if FAnimateBox.Checked then
  begin
    Scale := 4 + Sin(Time / 2) * 3;
    FDocument.DrawAt(Width / 2, Height / 2, Scale, Time, DocumentSize, Options, 4 / Scale);
  end
  else
  begin
    Scale := 3 + FZoom;
    if Scale < 0.1 then
      Scale := 0.1;
    FDocument.DrawAt(Width / 2 + FPan.X, Height / 2 + FPan.Y, Scale, FRotate,
      DocumentSize, Options, 4 / Scale);
  end;
end;

{ Rows of icons, as many across as fit, centered in the scene }

procedure TSvgDemoScene.DrawGrid(Options: TSvgRenderOptions);
var
  Size, Columns, Offset, X, Y, I: Integer;
  Angle, IconSize: Float;
begin
  if FIconCount = 0 then
    Exit;
  Size := Round(FSizeSlider.Position);
  Columns := Width div Size;
  if Columns < 1 then
    Columns := 1;
  Offset := (Width - Columns * Size) div 2;
  if FAnimateBox.Checked then
    Angle := Time
  else
    Angle := 0;
  IconSize := Size * 0.75;
  for I := 0 to FIconCount - 1 do
  begin
    X := I mod Columns * Size + Size div 2 + Offset;
    Y := I div Columns * Size + Size div 2 + TitleHeight + 8;
    if Y - Size > Height then
      Break;
    FIcons[(I + FIconIndex) mod FIconCount].DrawAt(X, Y, 1, Angle, IconSize, Options, 0.5);
  end;
end;

{ A strip across the top which names the document or counts the icons }

procedure TSvgDemoScene.DrawTitle;
var
  S: string;
begin
  Canvas.Rect(0, 0, Width, TitleHeight);
  Canvas.Fill(FTitle);
  Canvas.Rect(0, TitleHeight, Width, 1);
  Canvas.Fill(ARGB($FF303030));
  if Font = nil then
    Exit;
  if FView = viewGrid then
    S := Format('Icon grid / %d of %d icons', [FIconCount, FIconFiles.Count])
  else if FDocuments.Count > 0 then
    S := Format('%s / document %d of %d', [ExtractFileName(FDocuments[FDocumentIndex]),
      FDocumentIndex + 1, FDocuments.Count])
  else
    S := 'No documents';
  Font.Size := 22;
  Font.Color := ARGB($FF000000);
  Font.Align := fontLeft;
  Font.Layout := fontMiddle;
  Canvas.DrawText(Font, S, 12, TitleHeight / 2);
end;

{ The skew, scale, and rotation of the widgets without any movement }

function TSvgDemoScene.TransformLinear: IMatrix;
begin
  Result := NewMatrix;
  Result.SkewX(FSkew);
  Result.Scale(FScale, FScale);
  Result.Rotate(FRotation);
end;

{ TransformPivot moves the pivot to the center of the dialog. It is called
  when a transform key is pressed, so the dialog turns about its own center.

  The pivot must not follow the dialog at other times. If it did, dragging
  the dialog would move the pivot, which would change where the mouse maps
  to, which would move the dialog again, and it would fly away.

  Moving the pivot from A to B changes where everything is drawn by
  (A - B) - L(A - B), where L is the current skew, scale, and rotation. That
  amount is added to the offset so the dialog stays where it is. }

procedure TSvgDemoScene.TransformPivot;
var
  Center, D, L: TPointF;
begin
  Center.X := FDialog.X + FDialog.Width / 2;
  Center.Y := FDialog.Y + FDialog.Height / 2;
  D.X := FPivot.X - Center.X;
  D.Y := FPivot.Y - Center.Y;
  L := TransformLinear.Multiply(D);
  FOffset.X := FOffset.X + D.X - L.X;
  FOffset.Y := FOffset.Y + D.Y - L.Y;
  FPivot := Center;
end;

{ TransformWidgets eases the scale, rotation, and skew towards the values set
  with the keyboard and builds the widget matrix from them. Mouse input is
  mapped back through the same matrix by the widget scene, so the dialog
  works and drags the same when it is transformed. }

procedure TSvgDemoScene.TransformWidgets;
var
  Ease: Float;
begin
  Ease := (Time - FFrameTime) * EaseSpeed;
  FFrameTime := Time;
  if (Ease > 1) or (Ease < 0) then
    Ease := 1;
  FScale := FScale + (FScaleTo - FScale) * Ease;
  FRotation := FRotation + (FRotationTo - FRotation) * Ease;
  FSkew := FSkew + (FSkewTo - FSkew) * Ease;
  WidgetMatrix.Identity;
  WidgetMatrix.Translate(-FPivot.X, -FPivot.Y);
  WidgetMatrix.SkewX(FSkew);
  WidgetMatrix.Scale(FScale, FScale);
  WidgetMatrix.Rotate(FRotation);
  WidgetMatrix.Translate(FPivot.X + FOffset.X, FPivot.Y + FOffset.Y);
end;

procedure TSvgDemoScene.Render;
var
  Buffer: IBackBuffer;
  Options: TSvgRenderOptions;
begin
  inherited Render;
  LoadIcons;
  Options := [];
  if FFillBox.Checked then
    Include(Options, renderColor);
  if FOutlineBox.Checked then
    Include(Options, renderOutlines);
  if FNodeBox.Checked then
    Include(Options, renderNodes);
  { The documents are drawn in their own canvas frame, under the widgets }
  Buffer := Canvas as IBackBuffer;
  Buffer.Flip(Width, Height);
  try
    Canvas.Rect(0, 0, Width, Height);
    if FBackgroundBox.Checked then
      Canvas.Fill(FChecker)
    else
      Canvas.Fill(ARGB($FFFFFFFF));
    if FView = viewDocument then
      DrawDocument(Options)
    else
      DrawGrid(Options);
    DrawTitle;
  finally
    Buffer.Flip(Width, Height);
  end;
  TransformWidgets;
  WidgetsRender;
end;

procedure TSvgDemoScene.DoKeyDown(var Args: TSceneKeyArgs);
begin
  { Control with the arrow keys transforms the dialog, and is taken before
    the widgets see the key. Shift skews as well as Alt, because desktops
    often use Control+Alt+Left and Right to switch workspaces. }
  if skCtrl in Args.Shift then
  begin
    Args.Handled := True;
    case Args.Key of
      VK_UP:
        begin
          FScaleTo := FScaleTo + ScaleStep;
          if FScaleTo > 3 then
            FScaleTo := 3;
        end;
      VK_DOWN:
        begin
          FScaleTo := FScaleTo - ScaleStep;
          if FScaleTo < 0.3 then
            FScaleTo := 0.3;
        end;
      VK_LEFT:
        if (skAlt in Args.Shift) or (skShift in Args.Shift) then
          FSkewTo := FSkewTo - SkewStep
        else
          FRotationTo := FRotationTo - RotateStep;
      VK_RIGHT:
        if (skAlt in Args.Shift) or (skShift in Args.Shift) then
          FSkewTo := FSkewTo + SkewStep
        else
          FRotationTo := FRotationTo + RotateStep;
    else
      Args.Handled := False;
    end;
    if FSkewTo > 1 then
      FSkewTo := 1;
    if FSkewTo < -1 then
      FSkewTo := -1;
    if Args.Handled then
    begin
      { Turn about the center of the dialog as it is now. The targets were
        changed above but the values being eased are not, so the dialog does
        not jump. }
      TransformPivot;
      Exit;
    end;
  end;
  inherited DoKeyDown(Args);
  if Args.Handled then
    Exit;
  if Args.Key = VK_LEFT then
    StepDocument(-1)
  else if Args.Key = VK_RIGHT then
    StepDocument(1)
  else
    Exit;
  Args.Handled := True;
end;

{ Mouse input which no widget handled moves the document }

procedure TSvgDemoScene.DoMouseDown(var Args: TSceneMouseArgs);
begin
  inherited DoMouseDown(Args);
  if Args.Handled or (FView <> viewDocument) then
    Exit;
  if Args.Button = buttonLeft then
    FDrag := dragPan
  else if Args.Button = buttonRight then
    FDrag := dragRotate;
end;

procedure TSvgDemoScene.DoMouseMove(var Args: TSceneMouseArgs);
begin
  inherited DoMouseMove(Args);
  case FDrag of
    dragPan:
      begin
        FPan.X := FPan.X + Args.XRel;
        FPan.Y := FPan.Y + Args.YRel;
      end;
    dragRotate: FRotate := FRotate + Args.XRel / 100;
  end;
end;

procedure TSvgDemoScene.DoMouseUp(var Args: TSceneMouseArgs);
begin
  inherited DoMouseUp(Args);
  FDrag := dragNone;
end;

procedure TSvgDemoScene.DoMouseWheel(var Args: TSceneWheelArgs);
begin
  inherited DoMouseWheel(Args);
  if Args.Handled or (FView <> viewDocument) then
    Exit;
  FZoom := FZoom + Args.Delta * 0.25;
  if FZoom < -2.9 then
    FZoom := -2.9;
  Args.Handled := True;
end;

end.
