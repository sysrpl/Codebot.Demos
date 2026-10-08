unit DemoScene;

{$mode delphi}

{ The video dialog uses TVideoWidget, which is only in codebot_render when
  videowidget is defined in its render.inc. Remove this define if it is not
  defined there, and the dialog will say that video is not included. }

{$define videowidget}

interface

{ This unit holds the widget scene. It does not use StdCtrls, so names such
  as TLabel, TCheckBox, and TPushButton refer to the Codebot widgets. }

uses
  Classes, SysUtils,
  Codebot.System,
  Codebot.Platform,
  Codebot.Graphics.Types,
  Codebot.Render.Graphics,
  Codebot.OpenGL,
  Codebot.Render.Scenes,
  Codebot.Render.Widgets,
  Codebot.Render.Widgets.Themes,
  Codebot.Render.Widgets.Custom,
  {$ifdef videowidget}
  Codebot.Render.Widgets.Video,
  {$endif}
  Codebot.Render.Scenes.Widgets,
  MaterialFont;

{ TDemoScene shows dialogs of widgets over a wallpaper.

  A bar of buttons is docked at the top of the scene. The numbered buttons
  each show or hide one of the dialogs, and the buttons after them switch
  vertical sync, switch full screen, show a performance graph below the bar,
  and exit.

  The first dialog holds the common controls, a round check box group which
  switches the theme, and buttons which open the file and picture dialogs of
  Codebot.Platform. With SDL those are made from widgets, and with the LCL
  they are the dialogs of the desktop. A picture which is opened becomes the
  wallpaper. The second holds a memo. The third holds a combo
  box, a list box, and a label which draws markdown, with a button to open a
  markdown file and draw it in the label. The fourth is a viewer
  of the material design icons, with a list of their names beside a scroll
  grid of the icons, and can be resized by the grip in its corner. The fifth
  plays a video. Under the video are glyph buttons to open a video file with
  a file dialog and to play, pause, and stop it, with a slider to their right
  which follows the video and seeks when it is dragged. Below them is a box
  combo box to choose an effect for the video, listing by name the fragment
  shaders in the effects folder of the assets, with no effect first. The dialog has a grip
  to resize it. Hiding the dialog pauses the video.
  A dialog can be dragged by its title bar and is hidden by its close button.

  The keys 1 to 5 show or hide a dialog unless an edit or memo is being typed
  in, F2 switches vertical sync, F3 switches full screen, F4 shows the
  performance graph, and Escape exits.

  The current dialog can be transformed with the keyboard as in SvgDemo:
  Control with Up and Down scales it, Control with Left and Right rotates it,
  and Control and Alt (or Control and Shift) with Left and Right skews it. The
  current dialog is the modal window if there is one, such as a file dialog,
  and the active window otherwise. Each dialog has a transform of its own,
  which is the Matrix of its window, and the changes are eased in over a few
  frames. }

const
  DialogCount = 5;
  { The index of the dialog which plays a video }
  VideoDialog = 4;

{ TDialogTransform is the transform of one window and what it is easing
  towards. Pivot is the point the window is transformed about, and Offset
  is a shift which keeps the window where it was when the pivot last
  changed. }


type
  TDialogTransform = record
    Window: TWindow;
    Matrix: IMatrix;
    Scale, ScaleTo: Float;
    Rotation, RotationTo: Float;
    Skew, SkewTo: Float;
    Pivot: TPointF;
    Offset: TPointF;
  end;

  TDemoScene = class(TWidgetScene)
  private
    FThemes: array[0..5] of TTheme;
    FStyles: array[0..5] of TCheckBox;
    FDialogs: array[0..DialogCount - 1] of TWindow;
    FDialogButtons: array[0..DialogCount - 1] of TGlyphButton;
    { The time each dialog was last docked to a sector of the scene }
    FDockTime: array[0..DialogCount - 1] of Double;
    FSync: TGlyphButton;
    FFullscreen: TGlyphButton;
    FGraph: TGlyphButton;
    FStats: TPerformanceGraph;
    FValueLabel: TLabel;
    FMemo: TMemo;
    FList: TListBox;
    FCombo: TSpinBox;
    FListLabel: TLabel;
    FMarkDown: TMarkDownLabel;
    { The names and the utf8 text of the material design icons }
    FIconNames: StringArray;
    FIconGlyphs: StringArray;
    FIconFont: IFont;
    FIconList: TListBox;
    FGrid: TScrollGrid;
    FGridLabel: TLabel;
    FCellWidth: TSlider;
    FCellHeight: TSlider;
    FWallpaper: IBitmap;
    FWallpaperCount: Integer;
    FChanging: Boolean;
    FSyncing: Boolean;
    { The transforms of the windows which have been transformed }
    {$ifdef videowidget}
    FVideo: TVideoWidget;
    FVideoSlider: TSlider;
    FMuteButton: TGlyphButton;
    FVolumeSlider: TSlider;
    { True while the video which is open has no sound, and the length of the
      video when that was last checked }
    FVideoNoSound: Boolean;
    FVideoSoundLength: Double;
    FEffectBox: TSpinBox;
    { The shader files of the effects, in the order of the items of the
      effect box after its first item, which is no effect }
    FEffectFiles: StringArray;
    FEffectError: string;
    FVideoSyncing: Boolean;
    {$endif}
    FTransforms: array of TDialogTransform;
    FFrameTime: Double;
    function CurrentWindow: TWindow;
    function FindTransform(Window: TWindow): Integer;
    procedure TransformPivot(var T: TDialogTransform);
    procedure TransformWindows;
    procedure BuildToolbar;
    procedure BuildControls;
    procedure BuildNotes;
    procedure BuildLists;
    procedure BuildGrid;
    procedure BuildVideo;
    {$ifdef videowidget}
    procedure UpdateVideo;
    procedure VideoLayout;
    procedure VideoResize(Sender: TObject);
    procedure VideoOpenClick(Sender: TObject);
    procedure VideoDialogClose(Dialog: IDialog);
    procedure VideoPlayClick(Sender: TObject);
    procedure VideoPauseClick(Sender: TObject);
    procedure VideoStopClick(Sender: TObject);
    procedure VideoSeek(Sender: TObject);
    procedure VideoMuteClick(Sender: TObject);
    procedure VideoVolume(Sender: TObject);
    procedure VideoSoundChanged;
    procedure LoadEffects;
    procedure EffectChange(Sender: TObject);
    {$endif}
    procedure ShowDialog(Index: Integer; Show: Boolean);
    procedure UpdateSyncButton;
    procedure UpdateFullscreenButton;
    procedure DrawWallpaper;
    procedure DialogClick(Sender: TObject);
    procedure DialogClose(Sender: TObject);
    procedure DialogCloseClick(Sender: TObject);
    procedure SyncClick(Sender: TObject);
    procedure FullscreenClick(Sender: TObject);
    procedure GraphClick(Sender: TObject);
    procedure ExitClick(Sender: TObject);
    procedure StyleChange(Sender: TObject);
    procedure HintChange(Sender: TObject);
    procedure WrapChange(Sender: TObject);
    procedure ListChange(Sender: TObject);
    procedure ComboChange(Sender: TObject);
    procedure LoadIcons;
    function IconIndex: Integer;
    procedure SelectIcon(Index: Integer);
    procedure ArrangeGrid;
    procedure GridChange(Sender: TObject);
    procedure GridDrawCell(Sender: TObject; Surface: ICanvas; Row, Col: Integer;
      const Rect: TRectF);
    procedure IconListChange(Sender: TObject);
    procedure CellSizeChange(Sender: TObject);
    procedure GridResize(Sender: TObject);
    procedure MessageClick(Sender: TObject);
    procedure OpenClick(Sender: TObject);
    procedure SaveClick(Sender: TObject);
    procedure PictureClick(Sender: TObject);
    procedure FileDialogClose(Dialog: IDialog);
    procedure PictureDialogClose(Dialog: IDialog);
    procedure MarkDownClick(Sender: TObject);
    procedure MarkDownDialogClose(Dialog: IDialog);
    procedure WidgetKeyDown(Sender: TObject; var Args: TSceneKeyArgs);
    procedure WidgetKeyUp(Sender: TObject; var Args: TSceneKeyArgs);
    function Typing: Boolean;
  protected
    function DefaultTheme: TTheme; override;
  public
    procedure Initialize; override;
    procedure Finalize; override;
    procedure Render; override;
    procedure DoKeyDown(var Args: TSceneKeyArgs); override;
  end;

implementation

const
  StyleNames: array[0..5] of string = ('Arc Dark', 'Chicago', 'Graphite',
    'Experience', 'Vista', 'Cupertino');
  { The width of the edit, slider, spin box, and memo. A dialog is as wide as
    its widest row, so the same width is used to make the rows of a dialog
    reach equally far across it. }
  ControlWidth = 300;
  { The title, the glyph of the button, and the sector of the scene each
    dialog is shown in. The sectors are numbered from 1 at the top left to 9
    at the bottom right, so 4, 5, and 6 are the left, middle, and right,
    8 is the bottom middle, and 3 is the top right. }
  DialogTitles: array[0..DialogCount - 1] of string = ('Controls', 'Notes',
    'Lists and Markdown', 'Material Icons', 'Video');
  DialogGlyphs: array[0..DialogCount - 1] of string = ('󰲠', '󰲢', '󰲤', '󰲦', '󰲨');
  DialogSectors: array[0..DialogCount - 1] of Integer = (5, 4, 6, 8, 3);
  { The size of the video when its dialog is first shown }
  VideoWidth = 480;
  VideoHeight = 270;
  { The width of the slider which sets how loud the video is }
  VolumeWidth = 80;
  { Material design icons for the mute button of the video }
  GlyphVolumeOn = #$F3#$B0#$95#$BE;
  GlyphVolumeOff = #$F3#$B0#$96#$81;
  GlyphVolumeNone = #$F3#$B0#$9D#$9F;
  MuteHint = 'Turn the sound of the video off or on';
  { A dialog is held in its sector for this long after it is shown, and is
    then released so it can be dragged }
  DockTime = 0.25;
  { How far one key press scales, rotates, and skews a dialog, and how quickly
    the change is eased in }
  ScaleStep = 0.1;
  RotateStep = Pi / 12;
  SkewStep = 0.1;
  EaseSpeed = 14;
  { The width of the list of icon names beside the grid of icons }
  IconListWidth = 220;
  ListItems: array[0..11] of string = ('Apple', 'Banana', 'Cherry', 'Date',
    'Elderberry', 'Fig', 'Grape', 'Honeydew', 'Kiwi', 'Lemon', 'Mango',
    'Nectarine');
  MarkDownText =
    '## Markdown label'#10 +
    'This label draws **bold**, *italic*, ***bold italic***, and `code` ' +
    'text, and wraps it to a width.'#10#10 +
    '- Bullets and numbered lists'#10 +
    '- [Links](https://cross.codebot.org) are underlined'#10#10 +
    '> Block quotes are set apart.'#10#10 +
    '```'#10 +
    'Label.Text := ''# Hello'';'#10 +
    '```';

{ TDemoScene }

function TDemoScene.DefaultTheme: TTheme;
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

procedure TDemoScene.Initialize;
begin
  inherited Initialize;
  Context.SetClearColor(0.2, 0.22, 0.26, 1);
  FWallpaper := Canvas.LoadBitmap('wallpaper', Context.GetAssetFile('textures/wallpaper.jpg'));
  LoadIcons;
  FChanging := True;
  try
    BuildToolbar;
    BuildControls;
    BuildNotes;
    BuildLists;
    BuildGrid;
    BuildVideo;
  finally
    FChanging := False;
  end;
  UpdateSyncButton;
  UpdateFullscreenButton;
  Widget.OnKeyDown := WidgetKeyDown;
  Widget.OnKeyUp := WidgetKeyUp;
  { The first dialog is shown when the scene starts }
  FDialogButtons[0].Click;
end;

procedure TDemoScene.Finalize;
var
  I: Integer;
begin
  { The widgets are freed by the inherited Finalize before their themes }
  inherited Finalize;
  for I := Low(FThemes) to High(FThemes) do
    FreeAndNil(FThemes[I]);
  FTransforms := nil;
  FIconFont := nil;
  FWallpaper := nil;
end;

{ The bar is docked at the top middle of the scene. It holds a row of buttons
  with the performance graph below the row, which is hidden until its button
  is pressed. }

procedure TDemoScene.BuildToolbar;
var
  I: Integer;
begin
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
        for I := Low(FDialogs) to High(FDialogs) do
          with This.Add<TGlyphButton>(FDialogButtons[I]) do
          begin
            CanToggle := True;
            Text := DialogGlyphs[I];
            Tag := I;
            Hint := Format('Show the %s dialog %d', [DialogTitles[I], I + 1]);
            OnClick := DialogClick;
          end;
        This.Add<TSpacer>;
        with This.Add<TGlyphButton>(FSync) do
        begin
          CanToggle := True;
          Down := not Host.VSync;
          OnClick := SyncClick;
        end;
        with This.Add<TGlyphButton>(FFullscreen) do
        begin
          CanToggle := True;
          Down := (Host.Window <> nil) and Host.Window.Fullscreen;
          OnClick := FullscreenClick;
        end;
        with This.Add<TGlyphButton>(FGraph) do
        begin
          CanToggle := True;
          Text := '󰄧';
          Hint := 'Show performance information F4';
          OnClick := GraphClick;
        end;
        This.Add<TSpacer>;
        with This.Add<TGlyphButton> do
        begin
          Text := '󰅚';
          Hint := 'Exit this program ESC';
          OnClick := ExitClick;
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
end;

{ The first dialog holds the common controls }

procedure TDemoScene.BuildControls;
var
  Sizes: StringArray;
  Column, I: Integer;
begin
  with Widget.Add<TWindow>(FDialogs[0]) do
  begin
    Text := DialogTitles[0];
    Tag := 0;
    Visible := False;
    OnClose := DialogClose;
    with This.Add<THBox> do
    begin
      Align := alignCenter;
      with This.Add<TGlyphImage> do
        Text := '󰋽';
      with This.Add<TLabel> do
      begin
        MaxWidth := 250;
        Text := 'These widgets are drawn with the canvas in a widget ' +
          'scene. Drag a dialog by its title bar to move it.';
      end;
    end;
    with This.Add<TLabel> do
      Text := 'Name:';
    with This.Add<TEdit> do
    begin
      Indent := 1;
      Width := ControlWidth;
      Text := 'Type, select, copy, cut, and paste here';
      Hint := 'Shift and the arrow keys select, Control moves by words';
    end;
    with This.Add<TLabel> do
      Text := 'Style:';
    { The styles are a radio group in two columns of three }
    with This.Add<THBox> do
    begin
      Indent := 1;
      Margin := 0;
      for Column := 0 to 1 do
        with This.Add<TVBox> do
        begin
          Margin := 0;
          for I := Column * 3 to Column * 3 + 2 do
            with This.Add<TCheckBox>(FStyles[I]) do
            begin
              Round := True;
              Margin := 4;
              Tag := I;
              Text := StyleNames[I];
              Checked := I = 0;
              OnChange := StyleChange;
            end;
        end;
    end;
    with This.Add<TLabel> do
      Text := 'Options:';
    with This.Add<TCheckBox> do
    begin
      Indent := 1;
      Text := 'Show hints';
      Checked := True;
      OnChange := HintChange;
    end;
    with This.Add<TLabel>(FValueLabel) do
    begin
      Indent := 1;
      AssociateText := 'Value: %.0f';
    end;
    with This.Add<TSlider> do
    begin
      Indent := 1;
      Width := ControlWidth;
      Min := 0;
      Max := 100;
      Step := 1;
      Position := 50;
      Associate := FValueLabel;
      Hint := 'Drag the grip to change the value';
    end;
    { A spin box of the slide kind is dragged left and right to choose }
    Sizes.Push('Small');
    Sizes.Push('Medium');
    Sizes.Push('Large');
    with This.Add<TSpinBox> do
    begin
      Indent := 1;
      Width := ControlWidth;
      Kind := spinSlide;
      Prefix := 'Size: ';
      Items := Sizes;
      ItemIndex := 1;
      Hint := 'Drag left or right to choose a size';
    end;
    with This.Add<TLabel> do
      Text := 'Dialogs:';
    with This.Add<THBox> do
    begin
      Indent := 1;
      Margin := 0;
      with This.Add<TPushButton> do
      begin
        Text := 'Open';
        Hint := 'Choose files with an open dialog';
        OnClick := OpenClick;
      end;
      with This.Add<TPushButton> do
      begin
        Text := 'Save';
        Hint := 'Choose a file name with a save dialog';
        OnClick := SaveClick;
      end;
      with This.Add<TPushButton> do
      begin
        Text := 'Wallpaper';
        Hint := 'Choose a picture to use as the wallpaper';
        OnClick := PictureClick;
      end;
    end;
    with This.Add<THBox> do
    begin
      Align := alignCenter;
      with This.Add<TPushButton> do
      begin
        Text := 'Message';
        Hint := 'Open a message dialog';
        OnClick := MessageClick;
      end;
      with This.Add<TPushButton> do
      begin
        Text := 'Close';
        Tag := 0;
        Hint := 'Close this dialog';
        OnClick := DialogCloseClick;
      end;
    end;
  end;
end;

{ The second dialog holds a memo }

procedure TDemoScene.BuildNotes;
begin
  with Widget.Add<TWindow>(FDialogs[1]) do
  begin
    Text := DialogTitles[1];
    Tag := 1;
    Visible := False;
    OnClose := DialogClose;
    with This.Add<TLabel> do
      Text := 'Notes:';
    with This.Add<TMemo>(FMemo) do
    begin
      Indent := 1;
      Width := ControlWidth;
      Height := 160;
      ScrollBars := True;
      Lines.BeginUpdate;
      Lines.Add('This memo holds several lines of text and wraps long lines at the edge when word wrapping is on.');
      Lines.Add('');
      Lines.Add('Select with the mouse or with Shift and the arrow keys.');
      Lines.Add('Page Up and Page Down move by a page, and select with Shift.');
      Lines.Add('Copy, cut, and paste work as they do in an edit.');
      Lines.Add('');
      Lines.Add('Scroll with the mouse wheel or by dragging the scroll bar.');
      Lines.Add('Turn off word wrapping to get a horizontal scroll bar too.');
      Lines.EndUpdate;
    end;
    with This.Add<TCheckBox> do
    begin
      Indent := 1;
      Text := 'Wrap words in the notes';
      Checked := True;
      OnChange := WrapChange;
    end;
    with This.Add<TPushButton> do
    begin
      Align := alignCenter;
      Text := 'Close';
      Tag := 1;
      Hint := 'Close this dialog';
      OnClick := DialogCloseClick;
    end;
  end;
end;

{ The third dialog holds a combo box and a list box of the same items, a
  label naming the item chosen, and a label which draws markdown.

  The combo box is a spin box of the drop down kind. Pressing it drops a list
  of its items to choose from, and with the focus the left and right keys
  step through them. Choosing an item in the combo box or in the list box
  chooses the same item in the other. }

procedure TDemoScene.BuildLists;
var
  Items: StringArray;
  I: Integer;
begin
  for I := Low(ListItems) to High(ListItems) do
    Items.Push(ListItems[I]);
  with Widget.Add<TWindow>(FDialogs[2]) do
  begin
    Text := DialogTitles[2];
    Tag := 2;
    Visible := False;
    OnClose := DialogClose;
    with This.Add<TLabel> do
      Text := 'Combo box:';
    with This.Add<TSpinBox>(FCombo) do
    begin
      Indent := 1;
      Width := ControlWidth;
      Kind := spinDropDown;
      Hint := 'Press to drop down the list, or use the left and right keys';
      OnChange := ComboChange;
    end;
    with This.Add<TLabel> do
      Text := 'List box:';
    with This.Add<TListBox>(FList) do
    begin
      Indent := 1;
      Width := ControlWidth;
      Height := 130;
      Hint := 'Click an item, or use the arrow keys and the mouse wheel';
      OnChange := ListChange;
    end;
    with This.Add<TLabel>(FListLabel) do
    begin
      Indent := 1;
      Text := ' ';
    end;
    with This.Add<TMarkDownLabel>(FMarkDown) do
    begin
      Indent := 1;
      MaxWidth := ControlWidth;
      Text := MarkDownText;
    end;
    with This.Add<THBox> do
    begin
      Align := alignCenter;
      with This.Add<TPushButton> do
      begin
        Text := 'Markdown';
        Hint := 'Open a markdown file and draw it in the label';
        OnClick := MarkDownClick;
      end;
      with This.Add<TPushButton> do
      begin
        Text := 'Close';
        Tag := 2;
        Hint := 'Close this dialog';
        OnClick := DialogCloseClick;
      end;
    end;
  end;
  FCombo.Items := Items;
  FList.Items := Items;
  FList.ItemIndex := 0;
  ListChange(nil);
end;

{ LoadIcons reads the material design icons from the MaterialFont unit, which
  names each icon and gives its code point, such as 'account $F0004'. The
  code point is turned into the utf8 text which draws the icon.

  The icon font is loaded under its own name. The themes use the same font
  file for their glyphs, and a font keeps its own size and color, so sharing
  theirs would change how the themes draw. }

procedure TDemoScene.LoadIcons;

  function CodeToText(Code: LongWord): string;
  begin
    if Code < $80 then
      Result := Chr(Code)
    else if Code < $800 then
      Result := Chr($C0 or (Code shr 6)) + Chr($80 or (Code and $3F))
    else if Code < $10000 then
      Result := Chr($E0 or (Code shr 12)) + Chr($80 or ((Code shr 6) and $3F)) +
        Chr($80 or (Code and $3F))
    else
      Result := Chr($F0 or (Code shr 18)) + Chr($80 or ((Code shr 12) and $3F)) +
        Chr($80 or ((Code shr 6) and $3F)) + Chr($80 or (Code and $3F));
  end;

var
  S: string;
  I, P: Integer;
begin
  for I := Low(MaterialGlyphs) to High(MaterialGlyphs) do
  begin
    S := MaterialGlyphs[I];
    P := Pos(' ', S);
    if P < 1 then
      Continue;
    FIconNames.Push(Copy(S, 1, P - 1));
    FIconGlyphs.Push(CodeToText(StrToIntDef(Copy(S, P + 1, Length(S)), 32)));
  end;
  FIconFont := Canvas.LoadFont('icons',
    Context.GetAssetFile('fonts/materialdesignicons-webfont.ttf'));
end;

{ The fourth dialog is a viewer of the material design icons, in the manner
  of the Material Design Icon Viewer program.

  A list box of the icon names is beside a scroll grid of the icons. The
  selected name and the selected cell are the same icon, so choosing one
  chooses the other and scrolls it into view. The grid does not draw its own
  cells. It calls GridDrawCell for each cell which can be seen.

  Two sliders set the width and height of the cells. The grid only has as
  many columns as fit across it, so it never scrolls sideways, and has as
  many rows as are needed to hold every icon.

  The dialog can be resized by the grip in its bottom right corner. The grip
  resizes the grid, and the dialog is packed around it. }

procedure TDemoScene.BuildGrid;
begin
  with Widget.Add<TWindow>(FDialogs[3]) do
  begin
    Text := DialogTitles[3];
    Tag := 3;
    Visible := False;
    OnClose := DialogClose;
    OnResize := GridResize;
    with This.Add<THBox> do
    begin
      Margin := 0;
      with This.Add<TListBox>(FIconList) do
      begin
        Width := IconListWidth;
        Height := 280;
        Hint := 'Click or drag to choose an icon by its name';
        OnChange := IconListChange;
      end;
      with This.Add<TScrollGrid>(FGrid) do
      begin
        Width := 420;
        Height := 280;
        Hint := 'Click or drag to choose an icon, or use the arrow keys';
        OnDrawCell := GridDrawCell;
        OnChange := GridChange;
      end;
    end;
    with This.Add<TLabel>(FGridLabel) do
      Text := ' ';
    with This.Add<THBox> do
    begin
      Margin := 0;
      with This.Add<TLabel> do
        Text := 'Cell width:';
      with This.Add<TSlider>(FCellWidth) do
      begin
        Width := 180;
        Min := 32;
        Max := 128;
        Step := 2;
        Position := 56;
        Hint := 'Change the width of the cells in the grid';
        OnChange := CellSizeChange;
      end;
      with This.Add<TLabel> do
        Text := 'Cell height:';
      with This.Add<TSlider>(FCellHeight) do
      begin
        Width := 180;
        Min := 32;
        Max := 128;
        Step := 2;
        Position := 56;
        Hint := 'Change the height of the cells in the grid';
        OnChange := CellSizeChange;
      end;
    end;
    with This.Add<TPushButton> do
    begin
      Align := alignCenter;
      Text := 'Close';
      Tag := 3;
      Hint := 'Close this dialog';
      OnClick := DialogCloseClick;
    end;
  end;
  FDialogs[3].SizeWidget := FGrid;
  FDialogs[3].Sizeable := True;
  FIconList.Items := FIconNames;
  ArrangeGrid;
  SelectIcon(0);
end;

{ The fifth dialog plays a video. The video widget draws the video, and is
  the widget resized by the grip of the dialog. Under it is a row of glyph
  buttons with the slider to their right, which is kept ending where the
  video does.

  The open button shows a file dialog to choose a video, which is played when
  it is chosen. The slider runs from zero to the length of the video in
  seconds. It follows the video as it plays, and dragging it seeks. }

procedure TDemoScene.BuildVideo;
begin
  with Widget.Add<TWindow>(FDialogs[VideoDialog]) do
  begin
    Text := DialogTitles[VideoDialog];
    Tag := VideoDialog;
    Visible := False;
    OnClose := DialogClose;
    {$ifdef videowidget}
    OnResize := VideoResize;
    with This.Add<TVideoWidget>(FVideo) do
    begin
      Width := VideoWidth;
      Height := VideoHeight;
    end;
    { The buttons are to the left of the slider, which takes the rest of the
      width of the video }
    with This.Add<THBox> do
    begin
      Margin := 0;
      with This.Add<TGlyphButton> do
      begin
        Align := alignCenter;
        Text := '󰝰';
        Hint := 'Choose a video file to play';
        OnClick := VideoOpenClick;
      end;
      with This.Add<TGlyphButton> do
      begin
        Align := alignCenter;
        Text := '󰐊';
        Hint := 'Play the video, or continue it if it is paused';
        OnClick := VideoPlayClick;
      end;
      with This.Add<TGlyphButton> do
      begin
        Align := alignCenter;
        Text := '󰏤';
        Hint := 'Hold the video where it is';
        OnClick := VideoPauseClick;
      end;
      with This.Add<TGlyphButton> do
      begin
        Align := alignCenter;
        Text := '󰓛';
        Hint := 'Stop the video';
        OnClick := VideoStopClick;
      end;
      { The mute button stays down while the sound is off, and the slider
        beside it sets how loud the sound is }
      with This.Add<TGlyphButton>(FMuteButton) do
      begin
        Align := alignCenter;
        Text := GlyphVolumeOn;
        CanToggle := True;
        Hint := MuteHint;
        OnClick := VideoMuteClick;
      end;
      with This.Add<TSlider>(FVolumeSlider) do
      begin
        Align := alignCenter;
        Width := VolumeWidth;
        Min := 0;
        Max := 1;
        Step := 0;
        Position := 1;
        Hint := 'Drag to change how loud the video is';
        OnChange := VideoVolume;
      end;
      with This.Add<TSlider>(FVideoSlider) do
      begin
        Align := alignCenter;
        Width := VideoWidth - 200 - VolumeWidth - 40;
        Min := 0;
        Max := 1;
        Step := 0;
        Position := 0;
        Hint := 'Drag to move to another part of the video';
        OnChange := VideoSeek;
      end;
    end;
    { The effects are the fragment shaders in the effects folder of the
      assets, listed by name in a combo box with no effect first. There are
      many, so the list of the box scrolls. }
    with This.Add<TSpinBox>(FEffectBox) do
    begin
      Width := VideoWidth;
      Kind := spinDropScroll;
      Hint := 'Choose an effect for the video';
      OnChange := EffectChange;
    end;
    {$else}
    with This.Add<TLabel> do
    begin
      MaxWidth := ControlWidth;
      Text := 'Video is not included. Define videowidget in render.inc of ' +
        'codebot_render and at the top of this unit to include it.';
    end;
    {$endif}
  end;
  {$ifdef videowidget}
  FDialogs[VideoDialog].SizeWidget := FVideo;
  FDialogs[VideoDialog].Sizeable := True;
  LoadEffects;
  {$endif}
end;

{$ifdef videowidget}
{ UpdateVideo is called every frame. It makes the slider follow the video.
  The slider is left alone while it is being dragged, and FVideoSyncing stops
  the change made here from seeking. }

procedure TDemoScene.UpdateVideo;
var
  Duration: Double;
begin
  if not FDialogs[VideoDialog].Visible then
    Exit;
  VideoLayout;
  { An effect which does not compile is reported once }
  if FVideo.EffectError <> FEffectError then
  begin
    FEffectError := FVideo.EffectError;
    if FEffectError <> '' then
      Widget.MessageBox('The effect could not be used:'#10 + FEffectError);
  end;
  { The length of a video is known once it has been loaded, and changes when
    another video is loaded or the video is stopped. The video is asked if
    it has sound only then, not every frame. }
  Duration := FVideo.Duration;
  if Duration <> FVideoSoundLength then
  begin
    FVideoSoundLength := Duration;
    FVideoNoSound := (Duration > 0) and (not FVideo.HasAudio);
    VideoSoundChanged;
  end;
  if (FVideo.FileName = '') or (wsPressed in FVideoSlider.State) then
    Exit;
  FVideoSyncing := True;
  try
    if Duration > 0 then
      FVideoSlider.Max := Duration
    else
      FVideoSlider.Max := 1;
    FVideoSlider.Position := FVideo.Position;
  finally
    FVideoSyncing := False;
  end;
end;

{ VideoLayout makes the slider end where the video does. The slider is after
  the buttons in a box, and where it starts is known once the dialog has
  been packed, which happens when the dialog is drawn. }

procedure TDemoScene.VideoLayout;
var
  W: Float;
begin
  W := FVideo.Width + FVideo.Margin - FVideoSlider.X;
  if W < 50 then
    W := 50;
  if Abs(W - FVideoSlider.Width) > 0.5 then
    FVideoSlider.Width := W;
  FEffectBox.Width := FVideo.Width;
end;

{ VideoResize is called as the size grip of the dialog resizes the video }

procedure TDemoScene.VideoResize(Sender: TObject);
begin
  VideoLayout;
end;

{ The folder where the user keeps videos, which is Videos in the home folder
  on Linux and Windows and Movies on macOS. The home folder is used if there
  is no such folder. }

function VideosFolder: string;
begin
  {$ifdef darwin}
  Result := GetUserDir + 'Movies';
  {$else}
  Result := GetUserDir + 'Videos';
  {$endif}
  if not DirectoryExists(Result) then
    Result := ExcludeTrailingPathDelimiter(GetUserDir);
end;

{ The dialog opens in the folder of the video which is open, or in the videos
  folder of the user when no video has been opened }

procedure TDemoScene.VideoOpenClick(Sender: TObject);
var
  Dialog: IFileDialog;
begin
  Dialog := NewFileDialog(fdOpen);
  Dialog.Title := 'Open a Video';
  Dialog.Filter := 'Video files|*.mp4;*.mkv;*.avi|All files|*';
  if FVideo.FileName <> '' then
    Dialog.InitialDir := ExtractFilePath(FVideo.FileName)
  else
    Dialog.InitialDir := VideosFolder;
  Dialog.Execute(VideoDialogClose);
end;

{ The video which was chosen is played. Stopping first plays it from the
  beginning even if it is the video which was already open. }

procedure TDemoScene.VideoDialogClose(Dialog: IDialog);
begin
  if not Dialog.Accepted then
    Exit;
  FVideo.Stop;
  FVideo.FileName := (Dialog as IFileDialog).FileName;
  FVideo.Play;
end;

procedure TDemoScene.VideoPlayClick(Sender: TObject);
begin
  if FVideo.FileName = '' then
    VideoOpenClick(Sender)
  else
    FVideo.Play;
end;

procedure TDemoScene.VideoPauseClick(Sender: TObject);
begin
  FVideo.Pause;
end;

procedure TDemoScene.VideoStopClick(Sender: TObject);
begin
  FVideo.Stop;
end;

{ LoadEffects lists the shaders in the effects folder, which is beside the
  textures folder of the assets. Each has its name in a comment on a line
  such as "// name: Grayscale". The video widget draws an effect in one pass
  from the picture of the video alone, so shaders which need a second
  texture are left out. When OpenGL ES is selected in render.inc, as it is
  on the Raspberry Pi, the copies in the effects-gles folder are used. }

procedure TDemoScene.LoadEffects;
const
  EffectsFolder: array[Boolean] of string = ('effects', 'effects-gles');
var
  Search: TSearchRec;
  Names: StringArray;
  Folder, Source, Name: string;
  A, B, I, J: Integer;
begin
  Folder := ExtractFilePath(ExcludeTrailingPathDelimiter(ExtractFilePath(
    Context.GetAssetFile('textures/wallpaper.jpg')))) +
    EffectsFolder[OpenGLEmbedded] + PathDelim;
  if SysUtils.FindFirst(Folder + '*.frag', SysUtils.faAnyFile, Search) = 0 then
  try
    repeat
      try
        Source := FileReadStr(Folder + Search.Name);
      except
        Continue;
      end;
      if Pos('iChannel1', Source) > 0 then
        Continue;
      Name := ChangeFileExt(Search.Name, '');
      A := Pos('// name:', Source);
      if A > 0 then
      begin
        A := A + Length('// name:');
        B := A;
        while (B <= Length(Source)) and (Source[B] <> #10) and (Source[B] <> #13) do
          Inc(B);
        if Trim(Copy(Source, A, B - A)) <> '' then
          Name := Trim(Copy(Source, A, B - A));
      end;
      Names.Push(Name);
      FEffectFiles.Push(Folder + Search.Name);
    until SysUtils.FindNext(Search) <> 0;
  finally
    SysUtils.FindClose(Search);
  end;
  { Sort the effects by name, keeping each file with its name }
  for I := 1 to Names.Length - 1 do
  begin
    J := I;
    while (J > 0) and (CompareText(Names[J], Names[J - 1]) < 0) do
    begin
      Name := Names[J];
      Names[J] := Names[J - 1];
      Names[J - 1] := Name;
      Name := FEffectFiles[J];
      FEffectFiles[J] := FEffectFiles[J - 1];
      FEffectFiles[J - 1] := Name;
      Dec(J);
    end;
  end;
  { No effect is the first item of the box, before the effects }
  Names.Push('');
  for I := Names.Length - 1 downto 1 do
    Names[I] := Names[I - 1];
  Names[0] := 'No effect';
  FVideoSyncing := True;
  try
    FEffectBox.Items := Names;
    FEffectBox.ItemIndex := 0;
  finally
    FVideoSyncing := False;
  end;
end;

procedure TDemoScene.EffectChange(Sender: TObject);
var
  I: Integer;
begin
  if FVideoSyncing then
    Exit;
  I := FEffectBox.ItemIndex - 1;
  if (I < 0) or (I > FEffectFiles.Length - 1) then
    FVideo.Effect := ''
  else
  try
    FVideo.Effect := FileReadStr(FEffectFiles[I]);
  except
    FVideo.Effect := '';
  end;
end;

procedure TDemoScene.VideoSeek(Sender: TObject);
begin
  if not FVideoSyncing then
    FVideo.Position := FVideoSlider.Position;
end;

{ The button has already changed between up and down when it is clicked }

procedure TDemoScene.VideoMuteClick(Sender: TObject);
begin
  FVideo.Muted := FMuteButton.Down;
  VideoSoundChanged;
end;

{ The mute button shows if the sound is on or off, or that the video has no
  sound, in which case the volume slider is disabled }

procedure TDemoScene.VideoSoundChanged;
begin
  FVolumeSlider.Enabled := not FVideoNoSound;
  if FVideoNoSound then
  begin
    FMuteButton.Text := GlyphVolumeNone;
    FMuteButton.Hint := 'This video has no sound';
  end
  else
  begin
    if FMuteButton.Down then
      FMuteButton.Text := GlyphVolumeOff
    else
      FMuteButton.Text := GlyphVolumeOn;
    FMuteButton.Hint := MuteHint;
  end;
end;

procedure TDemoScene.VideoVolume(Sender: TObject);
begin
  FVideo.Volume := FVolumeSlider.Position;
end;
{$endif}

{ The index of the icon in the selected cell, or -1 if there is none }

function TDemoScene.IconIndex: Integer;
begin
  if (FGrid.Row < 0) or (FGrid.Col < 0) or (FGrid.ColCount < 1) then
    Exit(-1);
  Result := FGrid.Row * FGrid.ColCount + FGrid.Col;
  if Result > FIconNames.Length - 1 then
    Result := -1;
end;

{ SelectIcon chooses an icon in the grid and in the list, and names it in the
  label. FSyncing stops the changes made here from being passed back. }

procedure TDemoScene.SelectIcon(Index: Integer);
begin
  if FSyncing or (FGrid.ColCount < 1) or (FIconNames.Length = 0) then
    Exit;
  if Index < 0 then
    Index := 0;
  if Index > FIconNames.Length - 1 then
    Index := FIconNames.Length - 1;
  FSyncing := True;
  try
    FGrid.Select(Index mod FGrid.ColCount, Index div FGrid.ColCount);
    FIconList.ItemIndex := Index;
    FIconList.ScrollToItem(Index);
    FGridLabel.Text := Format('Icon %d of %d: %s', [Index + 1, FIconNames.Length,
      MaterialGlyphs[Index]]);
  finally
    FSyncing := False;
  end;
end;

{ ArrangeGrid gives the grid as many columns as fit across it, leaving room
  for the vertical scroll bar, and the rows needed to hold every icon. The
  icon which was selected is selected again, as its cell moves when the
  number of columns changes. }

procedure TDemoScene.ArrangeGrid;
var
  Index, Cols: Integer;
begin
  Index := IconIndex;
  FGrid.ColWidth := FCellWidth.Position;
  FGrid.RowHeight := FCellHeight.Position;
  Cols := Trunc((FGrid.Width - 4 - ScrollBarSize) / FGrid.ColWidth);
  if Cols < 1 then
    Cols := 1;
  FSyncing := True;
  try
    FGrid.ColCount := Cols;
    FGrid.RowCount := (FIconNames.Length + Cols - 1) div Cols;
  finally
    FSyncing := False;
  end;
  SelectIcon(Index);
end;

{ The last row of the grid can have empty cells after the last icon. A click
  on one of those selects the last icon. }

procedure TDemoScene.GridChange(Sender: TObject);
begin
  if FSyncing then
    Exit;
  if (FGrid.Row < 0) or (FGrid.Col < 0) then
    Exit;
  SelectIcon(FGrid.Row * FGrid.ColCount + FGrid.Col);
end;

procedure TDemoScene.IconListChange(Sender: TObject);
begin
  if not FSyncing then
    SelectIcon(FIconList.ItemIndex);
end;

procedure TDemoScene.CellSizeChange(Sender: TObject);
begin
  if not FChanging then
    ArrangeGrid;
end;

{ GridResize is called as the size grip of the dialog resizes the grid. The
  list is kept the same height as the grid. }

procedure TDemoScene.GridResize(Sender: TObject);
begin
  FIconList.Height := FGrid.Height;
  ArrangeGrid;
end;

{ GridDrawCell draws one cell of the grid. Rect is where the cell is on the
  canvas, and drawing is clipped to it. The icon of the cell is drawn in its
  center, sized to fit the smaller of the width and height of the cell, in
  the text color of a list box so it can be seen in every theme. }

procedure TDemoScene.GridDrawCell(Sender: TObject; Surface: ICanvas; Row, Col: Integer;
  const Rect: TRectF);
var
  Grid: TScrollGrid;
  Index: Integer;
  Size: Float;
begin
  Grid := Sender as TScrollGrid;
  Index := Row * Grid.ColCount + Col;
  if (Index > FIconGlyphs.Length - 1) or (FIconFont = nil) then
    Exit;
  Size := Rect.Width;
  if Rect.Height < Size then
    Size := Rect.Height;
  { The grid draws no box of its own, so the selected cell is highlighted
    here with the selection colors of a list box }
  if Grid.Selected(Row, Col) then
  begin
    Surface.Rect(Rect);
    Surface.Fill(Grid.SelectColor);
    FIconFont.Color := Grid.SelectTextColor;
  end
  else
    FIconFont.Color := Grid.TextColor;
  FIconFont.Size := Size * 0.6;
  FIconFont.Align := fontCenter;
  FIconFont.Layout := fontMiddle;
  Surface.DrawText(FIconFont, FIconGlyphs[Index], Rect.X + Rect.Width / 2,
    Rect.Y + Rect.Height / 2);
end;

{ ShowDialog shows or hides a dialog and presses or releases its button.

  A dialog is shown in its sector of the scene. A widget in a sector cannot
  be moved, so the sector is cleared a moment later in Render, which leaves
  the dialog where it is and lets it be dragged. }

procedure TDemoScene.ShowDialog(Index: Integer; Show: Boolean);
begin
  FDialogButtons[Index].Down := Show;
  if Show then
  begin
    FDialogButtons[Index].Hint := Format('Hide the %s dialog %d', [DialogTitles[Index], Index + 1]);
    FDialogs[Index].Sector := DialogSectors[Index];
    FDockTime[Index] := Time;
    FDialogs[Index].Activate;
  end
  else
  begin
    FDialogButtons[Index].Hint := Format('Show the %s dialog %d', [DialogTitles[Index], Index + 1]);
    FDialogs[Index].Hide;
    {$ifdef videowidget}
    { The sound of a video would keep playing while its dialog is hidden }
    if Index = VideoDialog then
      FVideo.Pause;
    {$endif}
  end;
end;

{ A dialog button is down while its dialog is shown }

procedure TDemoScene.DialogClick(Sender: TObject);
var
  Button: TGlyphButton;
begin
  Button := Sender as TGlyphButton;
  ShowDialog(Button.Tag, Button.Down);
end;

{ DialogClose is called when a dialog is closed by its close button. The
  dialog hides itself afterwards. }

procedure TDemoScene.DialogClose(Sender: TObject);
begin
  ShowDialog((Sender as TWidget).Tag, False);
end;

{ The tag of the Close push button in a dialog is the index of the dialog }

procedure TDemoScene.DialogCloseClick(Sender: TObject);
begin
  ShowDialog((Sender as TWidget).Tag, False);
end;

{ The sync button is down while vertical sync is off }

procedure TDemoScene.SyncClick(Sender: TObject);
begin
  Host.VSync := not FSync.Down;
  UpdateSyncButton;
end;

procedure TDemoScene.UpdateSyncButton;
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

{ The window is the form holding the graphics box with the LCL or the SDL
  window with the SDL application }

procedure TDemoScene.FullscreenClick(Sender: TObject);
begin
  if Host.Window <> nil then
    Host.Window.Fullscreen := FFullscreen.Down;
  UpdateFullscreenButton;
end;

procedure TDemoScene.UpdateFullscreenButton;
begin
  if FFullscreen.Down then
  begin
    FFullscreen.Text := '󰊔';
    FFullscreen.Hint := 'Switch to windowed mode F3';
  end
  else
  begin
    FFullscreen.Text := '󰊓';
    FFullscreen.Hint := 'Switch to fullscreen mode F3';
  end;
end;

procedure TDemoScene.GraphClick(Sender: TObject);
begin
  FStats.Visible := FGraph.Down;
  if FGraph.Down then
    FGraph.Hint := 'Hide performance information F4'
  else
    FGraph.Hint := 'Show performance information F4';
end;

procedure TDemoScene.ExitClick(Sender: TObject);
begin
  if Host.Window <> nil then
    Host.Window.Close;
end;

procedure TDemoScene.StyleChange(Sender: TObject);
var
  Style: TCheckBox;
  I: Integer;
begin
  if FChanging then
    Exit;
  FChanging := True;
  try
    { Only one style is checked, so clicking the checked one keeps it checked }
    Style := Sender as TCheckBox;
    for I := Low(FStyles) to High(FStyles) do
      FStyles[I].Checked := FStyles[I] = Style;
    Widget.Theme := FThemes[Style.Tag];
  finally
    FChanging := False;
  end;
end;

procedure TDemoScene.HintChange(Sender: TObject);
begin
  Widget.ShowHint := (Sender as TCheckBox).Checked;
end;

procedure TDemoScene.WrapChange(Sender: TObject);
begin
  FMemo.WordWrap := (Sender as TCheckBox).Checked;
end;

{ The combo box is made to show the item chosen in the list box. FSyncing
  stops the change made here from being passed back to the list box. }

procedure TDemoScene.ListChange(Sender: TObject);
begin
  if (FList.ItemIndex < 0) or (FList.ItemIndex > High(ListItems)) then
    FListLabel.Text := 'Nothing is chosen'
  else
    FListLabel.Text := Format('You chose %s, item %d of %d', [ListItems[FList.ItemIndex],
      FList.ItemIndex + 1, Length(ListItems)]);
  if FSyncing then
    Exit;
  FSyncing := True;
  try
    FCombo.ItemIndex := FList.ItemIndex;
  finally
    FSyncing := False;
  end;
end;

{ The list box is made to show the item chosen in the combo box }

procedure TDemoScene.ComboChange(Sender: TObject);
begin
  if FSyncing or (FCombo.ItemIndex < 0) then
    Exit;
  FSyncing := True;
  try
    FList.ItemIndex := FCombo.ItemIndex;
    FList.ScrollToItem(FList.ItemIndex);
  finally
    FSyncing := False;
  end;
end;

procedure TDemoScene.MessageClick(Sender: TObject);
begin
  Widget.MessageBox('This is a message dialog. It can be dragged too.');
end;

{ The dialogs return at once and call their close event when the user is done,
  so the scene keeps running while one is open }

procedure TDemoScene.OpenClick(Sender: TObject);
var
  Dialog: IFileDialog;
begin
  Dialog := NewFileDialog(fdOpen);
  Dialog.Title := 'Open Files';
  Dialog.Filter := 'Pascal files|*.pas;*.pp;*.lpr;*.inc|Text files|*.txt;*.md|All files|*';
  Dialog.MultiSelect := True;
  Dialog.Execute(FileDialogClose);
end;

procedure TDemoScene.SaveClick(Sender: TObject);
var
  Dialog: IFileDialog;
begin
  Dialog := NewFileDialog(fdSave);
  Dialog.Title := 'Save a File';
  Dialog.Filter := 'Text files|*.txt|All files|*';
  Dialog.DefaultExt := 'txt';
  Dialog.FileName := 'notes.txt';
  Dialog.Execute(FileDialogClose);
end;

procedure TDemoScene.PictureClick(Sender: TObject);
var
  Dialog: IPictureDialog;
begin
  Dialog := NewPictureDialog(fdOpen);
  Dialog.Title := 'Choose a Wallpaper';
  Dialog.InitialDir := ExtractFilePath(Context.GetAssetFile('textures/wallpaper.jpg'));
  Dialog.Execute(PictureDialogClose);
end;

{ Nothing is opened or saved by the demo. It only tells what was chosen. }

procedure TDemoScene.FileDialogClose(Dialog: IDialog);
var
  Files: StringArray;
  S: string;
  I: Integer;
begin
  if not Dialog.Accepted then
    Exit;
  Files := (Dialog as IFileDialog).Files;
  S := '';
  for I := 0 to Files.Length - 1 do
  begin
    if I = 5 then
    begin
      S := S + #10 + Format('and %d more', [Files.Length - I]);
      Break;
    end;
    if S <> '' then
      S := S + #10;
    S := S + Files[I];
  end;
  Widget.MessageBox('You chose:'#10 + S);
end;

{ The wallpaper is given a new name each time, as bitmaps are kept by name }

procedure TDemoScene.PictureDialogClose(Dialog: IDialog);
var
  Bitmap: IBitmap;
begin
  if not Dialog.Accepted then
    Exit;
  Inc(FWallpaperCount);
  try
    Bitmap := Canvas.LoadBitmap('wallpaper' + IntToStr(FWallpaperCount),
      (Dialog as IFileDialog).FileName);
  except
    Bitmap := nil;
  end;
  if (Bitmap = nil) or (Bitmap.Width = 0) or (Bitmap.Height = 0) then
  begin
    Widget.MessageBox('That picture could not be loaded.');
    Exit;
  end;
  FWallpaper := Bitmap;
end;

procedure TDemoScene.MarkDownClick(Sender: TObject);
var
  Dialog: IFileDialog;
begin
  Dialog := NewFileDialog(fdOpen);
  Dialog.Title := 'Open a Markdown File';
  Dialog.Filter := 'Markdown files|*.md;*.markdown|Text files|*.txt|All files|*';
  Dialog.Execute(MarkDownDialogClose);
end;

{ The label grows to fit its text and the dialog grows with it, so only the
  start of a long file is drawn. The text is cut at the end of a line. }

procedure TDemoScene.MarkDownDialogClose(Dialog: IDialog);
const
  MaxLength = 1500;
var
  S: string;
  I: Integer;
begin
  if not Dialog.Accepted then
    Exit;
  try
    S := FileReadStr((Dialog as IFileDialog).FileName);
  except
    Widget.MessageBox('That file could not be read.');
    Exit;
  end;
  S := StringReplace(S, #13#10, #10, [rfReplaceAll]);
  if Length(S) > MaxLength then
  begin
    I := MaxLength;
    while (I > 1) and (S[I] <> #10) do
      Dec(I);
    S := Copy(S, 1, I) + #10'...';
  end;
  if Trim(S) = '' then
    S := '*The file is empty.*';
  FMarkDown.Text := S;
end;

{ Typing is true while an edit or memo has the input focus, when the number
  keys are text and not shortcuts }

function TDemoScene.Typing: Boolean;
begin
  Result := (Widget.Selected is TEdit) or (Widget.Selected is TMemo);
end;

{ The shortcut keys are taken when they are pressed and acted on when they
  are released }

procedure TDemoScene.WidgetKeyDown(Sender: TObject; var Args: TSceneKeyArgs);
begin
  { A modal window, such as a file dialog, takes every key }
  if Widget.ModalWindow <> nil then
    Exit;
  case Args.Key of
    VK_1..VK_5:
      if not Typing then
        Args.Handled := True;
    VK_F2..VK_F4, VK_ESCAPE: Args.Handled := True;
  end;
end;

procedure TDemoScene.WidgetKeyUp(Sender: TObject; var Args: TSceneKeyArgs);
begin
  if Widget.ModalWindow <> nil then
    Exit;
  case Args.Key of
    VK_1..VK_5:
      begin
        if Typing then
          Exit;
        FDialogButtons[Args.Key - VK_1].Click;
      end;
    VK_F2: FSync.Click;
    VK_F3: FFullscreen.Click;
    VK_F4: FGraph.Click;
    VK_ESCAPE: ExitClick(nil);
  else
    Exit;
  end;
  Args.Handled := True;
end;

{ The current dialog is the modal window if there is one, and the active
  window otherwise }

function TDemoScene.CurrentWindow: TWindow;
begin
  Result := Widget.ModalWindow;
  if Result = nil then
    Result := Widget.ActiveWindow;
  if (Result <> nil) and (not Result.Visible) then
    Result := nil;
end;

{ Find the transform of a window, adding one with no change if it has none }

function TDemoScene.FindTransform(Window: TWindow): Integer;
var
  I: Integer;
begin
  for I := 0 to High(FTransforms) do
    if FTransforms[I].Window = Window then
      Exit(I);
  Result := Length(FTransforms);
  SetLength(FTransforms, Result + 1);
  FTransforms[Result] := Default(TDialogTransform);
  FTransforms[Result].Window := Window;
  FTransforms[Result].Matrix := NewMatrix;
  FTransforms[Result].Scale := 1;
  FTransforms[Result].ScaleTo := 1;
  Window.Matrix := FTransforms[Result].Matrix;
end;

{ TransformPivot moves the pivot to the center of the window. It is called
  when a transform key is pressed, so the window turns about its own center.

  The pivot must not follow the window at other times. If it did, dragging
  the window would move the pivot, which would change where the mouse maps
  to, which would move the window again, and it would fly away.

  Moving the pivot from A to B changes where the window is drawn by
  (A - B) - L(A - B), where L is the current skew, scale, and rotation. That
  amount is added to the offset so the window stays where it is. }

procedure TDemoScene.TransformPivot(var T: TDialogTransform);
var
  Linear: IMatrix;
  Center, D, L: TPointF;
begin
  Center.X := T.Window.X + T.Window.Width / 2;
  Center.Y := T.Window.Y + T.Window.Height / 2;
  D.X := T.Pivot.X - Center.X;
  D.Y := T.Pivot.Y - Center.Y;
  Linear := NewMatrix;
  Linear.SkewX(T.Skew);
  Linear.Scale(T.Scale, T.Scale);
  Linear.Rotate(T.Rotation);
  L := Linear.Multiply(D);
  T.Offset.X := T.Offset.X + D.X - L.X;
  T.Offset.Y := T.Offset.Y + D.Y - L.Y;
  T.Pivot := Center;
end;

{ TransformWindows eases the scale, rotation, and skew of each transformed
  window towards the values set with the keyboard and builds the matrix of
  the window from them. The main widget maps the mouse back through the
  matrix, so a window works and drags the same when it is transformed.

  A window made by the widgets, such as a file dialog, is freed when it
  closes. The transform of a window which is no longer a child of the main
  widget is removed without touching the window. }

procedure TDemoScene.TransformWindows;
var
  Ease: Float;
  Found: Boolean;
  I, J: Integer;
begin
  Ease := (Time - FFrameTime) * EaseSpeed;
  FFrameTime := Time;
  if (Ease > 1) or (Ease < 0) then
    Ease := 1;
  for I := High(FTransforms) downto 0 do
  begin
    Found := False;
    for J := 0 to Widget.ChildCount - 1 do
      if Widget.Child[J] = FTransforms[I].Window then
      begin
        Found := True;
        Break;
      end;
    if not Found then
    begin
      FTransforms[I] := FTransforms[High(FTransforms)];
      SetLength(FTransforms, Length(FTransforms) - 1);
      Continue;
    end;
    with FTransforms[I] do
    begin
      Scale := Scale + (ScaleTo - Scale) * Ease;
      Rotation := Rotation + (RotationTo - Rotation) * Ease;
      Skew := Skew + (SkewTo - Skew) * Ease;
      Matrix.Identity;
      Matrix.Translate(-Pivot.X, -Pivot.Y);
      Matrix.SkewX(Skew);
      Matrix.Scale(Scale, Scale);
      Matrix.Rotate(Rotation);
      Matrix.Translate(Pivot.X + Offset.X, Pivot.Y + Offset.Y);
    end;
  end;
end;

{ Control with the arrow keys transforms the current dialog, and is taken
  before the widgets see the key. Shift skews as well as Alt, because desktops
  often use Control+Alt+Left and Right to switch workspaces. }

procedure TDemoScene.DoKeyDown(var Args: TSceneKeyArgs);
var
  Window: TWindow;
  I: Integer;
begin
  Window := nil;
  if skCtrl in Args.Shift then
    case Args.Key of
      VK_UP, VK_DOWN, VK_LEFT, VK_RIGHT: Window := CurrentWindow;
    end;
  if Window = nil then
  begin
    inherited DoKeyDown(Args);
    Exit;
  end;
  Args.Handled := True;
  I := FindTransform(Window);
  case Args.Key of
    VK_UP:
      begin
        FTransforms[I].ScaleTo := FTransforms[I].ScaleTo + ScaleStep;
        if FTransforms[I].ScaleTo > 3 then
          FTransforms[I].ScaleTo := 3;
      end;
    VK_DOWN:
      begin
        FTransforms[I].ScaleTo := FTransforms[I].ScaleTo - ScaleStep;
        if FTransforms[I].ScaleTo < 0.3 then
          FTransforms[I].ScaleTo := 0.3;
      end;
    VK_LEFT:
      if (skAlt in Args.Shift) or (skShift in Args.Shift) then
        FTransforms[I].SkewTo := FTransforms[I].SkewTo - SkewStep
      else
        FTransforms[I].RotationTo := FTransforms[I].RotationTo - RotateStep;
    VK_RIGHT:
      if (skAlt in Args.Shift) or (skShift in Args.Shift) then
        FTransforms[I].SkewTo := FTransforms[I].SkewTo + SkewStep
      else
        FTransforms[I].RotationTo := FTransforms[I].RotationTo + RotateStep;
  end;
  if FTransforms[I].SkewTo > 1 then
    FTransforms[I].SkewTo := 1;
  if FTransforms[I].SkewTo < -1 then
    FTransforms[I].SkewTo := -1;
  { Turn about the center of the window as it is now. The targets were
    changed above but the values being eased are not, so the window does not
    jump. }
  TransformPivot(FTransforms[I]);
end;

{ DrawWallpaper scales the wallpaper to cover the scene, keeping its aspect
  ratio and centering it. It is drawn in its own canvas frame before the
  widgets are drawn in theirs. }

procedure TDemoScene.DrawWallpaper;
var
  Buffer: IBackBuffer;
  Scale, W, H: Float;
begin
  if (FWallpaper = nil) or (FWallpaper.Width = 0) or (FWallpaper.Height = 0) then
    Exit;
  Scale := Width / FWallpaper.Width;
  if Height / FWallpaper.Height > Scale then
    Scale := Height / FWallpaper.Height;
  W := FWallpaper.Width * Scale;
  H := FWallpaper.Height * Scale;
  Buffer := Canvas as IBackBuffer;
  Buffer.Flip(Width, Height);
  try
    Canvas.DrawImage(FWallpaper, FWallpaper.ClientRect,
      NewRectF((Width - W) / 2, (Height - H) / 2, W, H));
  finally
    Buffer.Flip(Width, Height);
  end;
end;

procedure TDemoScene.Render;
var
  Value: Boolean;
  I: Integer;
begin
  inherited Render;
  { The window can enter or leave full screen without the button, such as
    when F1 is pressed with SDL, so the button is made to match the window }
  if Host.Window <> nil then
  begin
    Value := Host.Window.Fullscreen;
    if FFullscreen.Down <> Value then
    begin
      FFullscreen.Down := Value;
      UpdateFullscreenButton;
    end;
  end;
  DrawWallpaper;
  TransformWindows;
  {$ifdef videowidget}
  UpdateVideo;
  {$endif}
  WidgetsRender;
  { Release the dialogs which have been shown in their sector }
  for I := Low(FDialogs) to High(FDialogs) do
    if (FDialogs[I].Sector <> 0) and (Time - FDockTime[I] > DockTime) then
      FDialogs[I].Sector := 0;
end;

end.
