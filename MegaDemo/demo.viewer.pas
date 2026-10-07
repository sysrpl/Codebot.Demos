unit Demo.Viewer;

{$mode delphi}

interface

{ TDemoViewer is the scene which runs the demos. A bar of buttons at the top
  picks a demo, shows information about it, switches full screen, shows a
  performance graph, and exits. The information window describes the demo,
  holds a slider for the value the demo lets you change, and chooses the
  widget theme.

  The keys 1 to 9 pick a demo, F1 shows the information window, F2 switches
  vertical sync, F3 switches full screen, F4 shows the performance graph, and
  Escape exits. }

uses
  SysUtils,
  Codebot.System,
  Codebot.Platform,
  Codebot.Graphics.Types,
  Codebot.Render.Graphics,
  Codebot.Hardware,
  Codebot.Render.Scenes,
  Codebot.Render.Widgets,
  Codebot.Render.Widgets.Themes,
  Codebot.Render.Widgets.Custom,
  Codebot.Render.Scenes.Widgets,
  Demo.Scene,
  Demo.AtomicDots,
  Demo.CrowdWalk,
  Demo.FireSparks,
  Demo.LightBeams,
  Demo.MouseTrack,
  Demo.TextBrush,
  Demo.VectorClock,
  Demo.AsteroidsGame,
  Demo.Synthwave;

var
  DemoClasses: array of TDemoSceneClass = [TAtomicDots, TCrowdWalk, TFireSparks,
    TLightBeams, TMouseTrack, TTextBrush, TVectorClock, TSynthWave, TAsteroidsGame];

type
  TDemoViewer = class(TWidgetScene)
  private
    FActivateTime: Double;
    FDemoScenes: TArrayList<TDemoScene>;
    FCurrent: TDemoScene;
    FInfo: TGlyphButton;
    FSync: TGlyphButton;
    FFullscreen: TGlyphButton;
    FGraph: TGlyphButton;
    FStats: TPerformanceGraph;
    FAbout: TWindow;
    FIcon: TGlyphImage;
    FDescription: TLabel;
    FRangeDescription: TLabel;
    FRangeSlider: TSlider;
    FThemes: array[0..5] of TTheme;
    FThemeBox: TSpinBox;
    FOptionFullscreen: TCheckBox;
    procedure GenerateWidgets;
    procedure SelectScene(Scene: TDemoScene);
    procedure UpdateCursor(X, Y: Float);
    procedure UpdateRangeText;
    procedure SceneClick(Sender: TObject);
    procedure StatsClick(Sender: TObject);
    procedure VSyncClick(Sender: TObject);
    procedure UpdateVSyncButton;
    procedure FullscreenClick(Sender: TObject);
    procedure FullscreenOptionClick(Sender: TObject);
    procedure AboutClick(Sender: TObject);
    procedure AboutClose(Sender: TObject);
    procedure ExitClick(Sender: TObject);
    procedure ThemeChange(Sender: TObject);
    procedure SliderChange(Sender: TObject);
    procedure WidgetKeyDown(Sender: TObject; var Args: TSceneKeyArgs);
    procedure WidgetKeyUp(Sender: TObject; var Args: TSceneKeyArgs);
  protected
    function DefaultTheme: TTheme; override;
  public
    procedure Initialize; override;
    procedure Finalize; override;
    procedure Render; override;
    procedure DoKeyDown(var Args: TSceneKeyArgs); override;
    procedure DoKeyUp(var Args: TSceneKeyArgs); override;
    procedure DoMouseDown(var Args: TSceneMouseArgs); override;
    procedure DoMouseMove(var Args: TSceneMouseArgs); override;
    procedure DoMouseUp(var Args: TSceneMouseArgs); override;
  end;

implementation

{ TDemoViewer }

procedure TDemoViewer.WidgetKeyDown(Sender: TObject; var Args: TSceneKeyArgs);
begin
  case Args.Key of
    VK_1..VK_9, VK_F1..VK_F4, VK_ESCAPE: Args.Handled := True;
  end;
end;

procedure TDemoViewer.WidgetKeyUp(Sender: TObject; var Args: TSceneKeyArgs);
var
  Handled: Boolean;
  I: Integer;
begin
  Handled := True;
  case Args.Key of
    VK_1..VK_9:
      begin
        I := Args.Key - VK_0;
        if I <= FDemoScenes.Length then
          Widget.FindWidget<TWidget>(IntToStr(I)).Click;
      end;
    VK_F1: FInfo.Click;
    VK_F2: FSync.Click;
    VK_F3: FFullscreen.Click;
    VK_F4: FGraph.Click;
    VK_ESCAPE: ExitClick(nil);
  else
    Handled := False;
  end;
  Args.Handled := Handled;
end;

{ A demo which hides the mouse shows it again while it is over a widget }

procedure TDemoViewer.UpdateCursor(X, Y: Float);
begin
  if (FCurrent <> nil) and FCurrent.HideMouse and (Widget.FindWidget(X, Y) = nil) then
    Mouse.Cursor := cursorNone
  else
    Mouse.Cursor := cursorDefault;
end;

procedure TDemoViewer.UpdateRangeText;
var
  R: TRangeInfo;
begin
  R := FCurrent.RangeInfo;
  if R.Step > 0.9 then
    FRangeDescription.Text := R.Description + ': ' + FloatToStr(R.Position, 0)
  else if R.Step > 0.09 then
    FRangeDescription.Text := R.Description + ': ' + FloatToStr(R.Position, 1)
  else
    FRangeDescription.Text := R.Description + ': ' + FloatToStr(R.Position, 2);
end;

procedure TDemoViewer.SliderChange(Sender: TObject);
begin
  if FCurrent = nil then
    Exit;
  FCurrent.RangeInfo.Position := FRangeSlider.Position;
  UpdateRangeText;
end;

{ The demo shown is unloaded before the next is loaded }

procedure TDemoViewer.SelectScene(Scene: TDemoScene);
begin
  if Scene = FCurrent then
    Exit;
  if FCurrent <> nil then
    FCurrent.Unload;
  FCurrent := Scene;
  if FCurrent <> nil then
    FCurrent.Load;
  UpdateCursor(Host.MouseX, Host.MouseY);
end;

procedure TDemoViewer.SceneClick(Sender: TObject);
var
  W: TGlyphButton absolute Sender;
  D: TDemoScene;
  R: TRangeInfo;
begin
  D := FDemoScenes[W.Tag];
  SelectScene(D);
  FAbout.Text := 'About ' + D.Title;
  FIcon.Text := D.Glyph;
  FDescription.Text := D.Description;
  R := D.RangeInfo;
  if R.Min <> R.Max then
  begin
    FRangeDescription.Visible := True;
    FRangeSlider.Visible := True;
    FRangeSlider.OnChange := nil;
    FRangeSlider.Min := R.Min;
    FRangeSlider.Max := R.Max;
    FRangeSlider.Min := R.Min;
    FRangeSlider.Step := R.Step;
    FRangeSlider.Position := R.Position;
    FRangeSlider.OnChange := SliderChange;
    SliderChange(nil);
  end
  else
  begin
    FRangeDescription.Visible := False;
    FRangeSlider.Visible := False;
    FRangeSlider.OnChange := nil;
  end;
end;

procedure TDemoViewer.StatsClick(Sender: TObject);
var
  W: TGlyphButton absolute Sender;
begin
  FStats.Visible := W.Down;
  if W.Down then
    W.Hint := 'Hide performance information F4'
  else
    W.Hint := 'Show performance information F4';
end;

{ The sync button is down while vertical sync is off }

procedure TDemoViewer.VSyncClick(Sender: TObject);
begin
  Host.VSync := not FSync.Down;
  UpdateVSyncButton;
end;

procedure TDemoViewer.UpdateVSyncButton;
begin
  if FSync.Down then
  begin
    FSync.Text := '󰍹';
    FSync.Hint := 'Lock to vertical sync F2';
  end
  else
  begin
    FSync.Text := '󰷛';
    FSync.Hint := 'Unlock vertical sync F2';
  end;
end;

procedure TDemoViewer.FullscreenClick(Sender: TObject);
var
  W: TGlyphButton absolute Sender;
begin
  if Host.Window <> nil then
    Host.Window.Fullscreen := W.Down;
  if W.Down then
  begin
    W.Text := '󰊔';
    W.Hint := 'Switch to windowed mode F3';
  end
  else
  begin
    W.Text := '󰊓';
    W.Hint := 'Switch to fullscreen mode F3';
  end;
  FOptionFullscreen.Checked := W.Down;
  FAbout.Sector := 4;
  FActivateTime := Time;
end;

procedure TDemoViewer.FullscreenOptionClick(Sender: TObject);
begin
  FFullscreen.Click;
end;

procedure TDemoViewer.AboutClick(Sender: TObject);
var
  W: TGlyphButton absolute Sender;
begin
  if W.Down then
  begin
    FAbout.Activate;
    FInfo.Hint := 'Close scene information F1';
  end
  else
  begin
    FAbout.Hide;
    FInfo.Hint := 'Show scene information F1';
  end;
  FAbout.Sector := 4;
  FActivateTime := Time;
end;

procedure TDemoViewer.AboutClose(Sender: TObject);
begin
  FAbout.Hide;
  FInfo.Down := False;
end;

procedure TDemoViewer.ExitClick(Sender: TObject);
begin
  if Host.Window <> nil then
    Host.Window.Close;
end;

procedure TDemoViewer.ThemeChange(Sender: TObject);
begin
  if FThemeBox.ItemIndex > -1 then
    Widget.Theme := FThemes[FThemeBox.ItemIndex];
end;

function TDemoViewer.DefaultTheme: TTheme;
begin
  Result := FThemes[0];
end;

procedure TDemoViewer.GenerateWidgets;
var
  Numbers: array of string = [
    '󰲠',
    '󰲢',
    '󰲤',
    '󰲦',
    '󰲨',
    '󰲪',
    '󰲬',
    '󰲮',
    '󰲰'];
var
  ThemeNames: StringArray;
  I: Integer;
begin
  ThemeNames.Push('Arc Dark');
  ThemeNames.Push('Chicago');
  ThemeNames.Push('Graphite');
  ThemeNames.Push('Experience');
  ThemeNames.Push('Vista');
  ThemeNames.Push('Cupertino');
  with Widget.Add<THBox> do
  begin
    Sector := 2;
    Margin := -5;
    Fade := 0.15;
    with This.Add<TVBox> do
    begin
      Margin := 0;
      with This.Add<THBox> do
      begin
        Align := alignCenter;
        Margin := 0;
        for I := 0 to FDemoScenes.Length - 1 do
          with This.Add<TGlyphButton> do
          begin
            CanToggle := True;
            Text := Numbers[I];
            Group := 1;
            Down := True;
            Tag := I;
            Name := IntToStr(I + 1);
            Hint := 'Switch to scene ' + Name;
            OnClick := SceneClick;
          end;
        This.Add<TSpacer>;
        with This.Add<TGlyphButton>(FInfo) do
        begin
          CanToggle := True;
          Text := '󰆆';
          Hint := 'Show scene information F1';
          OnClick := AboutClick;
        end;
        with This.Add<TGlyphButton>(FSync) do
        begin
          CanToggle := True;
          Down := not Host.VSync;
          OnClick := VSyncClick;
        end;
        with This.Add<TGlyphButton>(FFullscreen) do
        begin
          Down := (Host.Window <> nil) and Host.Window.Fullscreen;
          CanToggle := True;
          Text := '󰊓';
          Hint := 'Switch to fullscreen mode F3';
          OnClick := FullscreenClick;
        end;
        with This.Add<TGlyphButton>(FGraph) do
        begin
          CanToggle := True;
          Text := '󰄧';
          Hint := 'Show performance information F4';
          OnClick := StatsClick;
        end;
        This.Add<TSpacer>;
        with This.Add<TGlyphButton> do
        begin
          Text := '󰅚';
          OnClick := ExitClick;
          Hint := 'Exit this program ESC';
        end;
      end;
      with This.Add<TPerformanceGraph>(FStats) do
      begin
        Align := alignCenter;
        Width := 500;
        Height := 50;
        Margin := 5;
        Visible := False;
      end;
    end;
  end;
  with Widget.Add<TWindow>(FAbout) do
  begin
    Text := 'About';
    Visible := False;
    OnClose := AboutClose;
    with This.Add<THBox> do
    begin
      with This.Add<TGlyphImage>(FIcon) do
        Text := '󰮣';
      with This.Add<TLabel>(FDescription) do
      begin
        MaxWidth := 200;
        Text := 'A description of the scene goes here. It could be a very long paragraph';
      end;
      Margin := 16;
    end;
    with This.Add<TLabel>(FRangeDescription) do
      Text := 'Range description:';
    with This.Add<TSlider>(FRangeSlider) do
    begin
      Width := 285;
    end;
    with This.Add<TLabel> do
      Text := 'Available visual styles:';
    with This.Add<TSpinBox>(FThemeBox) do
    begin
      { The same width as the slider, which fills the window }
      Width := 285;
      Items := ThemeNames;
      Hint := 'Choose a theme for the widgets';
      OnChange := ThemeChange;
    end;
    with This.Add<TLabel> do
      Text := 'Options:';
    with This.Add<TCheckBox>(FOptionFullscreen) do
    begin
      Indent := 1;
      Text := 'Fullscreen';
      OnClick := FullscreenOptionClick;
    end;
    with This.Add<TPushButton> do
    begin
      Align := alignCenter;
      Text := 'Close';
      OnClick := AboutClose;
    end;
  end;
end;

{ The themes are created before the widgets, which are created by the first
  use of Widget. Each demo is loaded once so it can create its resources. }

procedure TDemoViewer.Initialize;
var
  C: TDemoSceneClass;
  S: TDemoScene;
begin
  inherited Initialize;
  FThemes[0] := NewTheme(Canvas, TArcDarkTheme);
  FThemes[1] := NewTheme(Canvas, TChicagoTheme);
  FThemes[2] := NewTheme(Canvas, TGraphiteTheme);
  FThemes[3] := NewTheme(Canvas, TExperienceTheme);
  FThemes[4] := NewTheme(Canvas, TVistaTheme);
  FThemes[5] := NewTheme(Canvas, TCupertinoTheme);
  for C in DemoClasses do
  begin
    S := C.Create;
    S.Load;
    S.Unload;
    FDemoScenes.Push(S);
  end;
  GenerateWidgets;
  UpdateVSyncButton;
  FThemeBox.ItemIndex := 0;
  FOptionFullscreen.Checked := FFullscreen.Down;
  Widget.OnKeyDown := WidgetKeyDown;
  Widget.OnKeyUp := WidgetKeyUp;
  Widget.FindWidget<TWidget>(IntToStr(FDemoScenes.Length - 1)).Click;
end;

{ The widgets are freed by the inherited Finalize before their themes }

procedure TDemoViewer.Finalize;
var
  S: TDemoScene;
  I: Integer;
begin
  SelectScene(nil);
  for S in FDemoScenes do
    S.Free;
  FDemoScenes.Length := 0;
  inherited Finalize;
  for I := Low(FThemes) to High(FThemes) do
    FThemes[I].Free;
end;

{ The demo is drawn in its own canvas frame before the widgets }

procedure TDemoViewer.Render;
var
  Buffer: IBackBuffer;
begin
  inherited Render;
  if FCurrent <> nil then
  begin
    Buffer := Canvas as IBackBuffer;
    Buffer.Flip(Width, Height);
    try
      Canvas.Push;
      try
        Canvas.Matrix.Identity;
        Canvas.BlendMode := blendAlpha;
        FCurrent.Update(Width, Height, Time);
      finally
        Canvas.Pop;
      end;
      Canvas.BlendMode := blendAlpha;
      Canvas.Matrix.Identity;
    finally
      Buffer.Flip(Width, Height);
    end;
  end;
  WidgetsRender;
  if Time - FActivateTime > 0.25 then
    FAbout.Sector := 0;
end;

{ Input reaches the widgets first and is passed on to the demo when no widget
  handles it, or when the demo wants every key }

procedure TDemoViewer.DoKeyDown(var Args: TSceneKeyArgs);
begin
  inherited DoKeyDown(Args);
  if (FCurrent <> nil) and ((not Args.Handled) or FCurrent.WantKeys) then
    FCurrent.DoKeyDown(Args);
end;

procedure TDemoViewer.DoKeyUp(var Args: TSceneKeyArgs);
begin
  inherited DoKeyUp(Args);
  if (FCurrent <> nil) and ((not Args.Handled) or FCurrent.WantKeys) then
    FCurrent.DoKeyUp(Args);
end;

procedure TDemoViewer.DoMouseDown(var Args: TSceneMouseArgs);
begin
  inherited DoMouseDown(Args);
  if (FCurrent <> nil) and (not Args.Handled) then
    FCurrent.DoMouseDown(Args);
end;

procedure TDemoViewer.DoMouseMove(var Args: TSceneMouseArgs);
begin
  inherited DoMouseMove(Args);
  UpdateCursor(Args.X, Args.Y);
  if (FCurrent <> nil) and (not Args.Handled) then
    FCurrent.DoMouseMove(Args);
end;

procedure TDemoViewer.DoMouseUp(var Args: TSceneMouseArgs);
begin
  inherited DoMouseUp(Args);
  if (FCurrent <> nil) and (not Args.Handled) then
    FCurrent.DoMouseUp(Args);
end;

end.
