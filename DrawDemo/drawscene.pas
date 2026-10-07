unit DrawScene;

{$mode delphi}

interface

{ This unit holds the draw demo scene, which was written for Tiny Sim as
  Play.DrawPhysics. It does not use StdCtrls, so names such as TLabel refer
  to the Codebot widgets. Codebot.Physics is listed after Codebot.Geometry
  so that TPolygon refers to the physics polygon shape. }

uses
  Classes, SysUtils,
  Codebot.System,
  Codebot.Platform,
  Codebot.Graphics.Types,
  Codebot.Geometry,
  Codebot.Render.Graphics,
  Codebot.Hardware,
  Codebot.Render.Scenes,
  Codebot.Render.Widgets,
  Codebot.Render.Widgets.Themes,
  Codebot.Render.Widgets.Custom,
  Codebot.Render.Scenes.Widgets,
  Codebot.Interop.Chipmunk2D,
  Codebot.Physics,
  Codebot.Render.Scenes.Physics;

{ TDrawScene is a scene where users can draw hollow or solid physics objects
  using a simulated crayon style.

  A bar of buttons at the top chooses what the mouse does: draw the outline
  of a shape, draw a solid shape, grab shapes and move them, or erase them.
  Outlines are drawn in blue crayon and solid shapes in red. A shape becomes
  a physics body when the mouse button is released, and falls onto a meadow.

  A solid shape can be concave. The physics only has convex polygons, so the
  shape is cut into triangles, which are all added to one body. The outline
  which was drawn is kept with the body and is what is seen.

  The space is stepped on the step thread while the scene draws and handles
  the mouse on the render thread, so the space is locked while bodies are
  added or removed. }

type
  TDrawing = TArrayList<TVec2>;

  { The outline of a solid shape, in the coordinates of its body. It is the
    user data of the body. }
  TSolidShape = class
  public
    Points: TVec2Array;
  end;

  TDrawScene = class(TPhysicsScene)
  private
    FOutlinePen: IPen;
    FSolidPen: IPen;
    FBlueCrayon: IBitmapBrush;
    FRedCrayon: IBitmapBrush;
    FBackground: IBitmap;
    FGlyph: IFont;
    FDraw: TGlyphButton;
    FFill: TGlyphButton;
    FGrab: TGlyphButton;
    FErase: TGlyphButton;
    FSync: TGlyphButton;
    FFullscreen: TGlyphButton;
    FGraph: TGlyphButton;
    FStats: TPerformanceGraph;
    FDrawing: TDrawing;
    FSolids: TList;
    FIsDrawing: Boolean;
    FIsFilling: Boolean;
    FIsErasing: Boolean;
    procedure GenerateWidgets;
    procedure UpdateCursor(X, Y: Float);
    procedure AddSolid;
    procedure EraseBody(Body: TBody);
    procedure SyncClick(Sender: TObject);
    procedure FullscreenClick(Sender: TObject);
    procedure GraphClick(Sender: TObject);
    procedure ExitClick(Sender: TObject);
  protected
    function DrawCustomBody(Body: TBody): Boolean; override;
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
  { The user data of a body which was drawn as an outline. That of a solid
    body is its TSolidShape. }
  Outline = Pointer(1);
  { A crayon line is stroked twice, thin and then thick }
  Thick = 10;
  Thin = 6;
  { A point is added to a drawing each time the mouse moves this far }
  PointSpacing = 10;

{ TDrawScene }

procedure TDrawScene.Initialize;
begin
  inherited Initialize;
  FSolids := TList.Create;
  { Create our pens and brushes }
  FOutlinePen := NewPen;
  FOutlinePen.LineCap := capRound;
  FOutlinePen.LineJoin := joinRound;
  FOutlinePen.Width := Thick;
  FBlueCrayon := NewBrush(Canvas.LoadBitmap('blue-crayon',
    Context.GetAssetFile('textures/blue-crayon.png')));
  FBlueCrayon.Opacity := 0.5;
  FOutlinePen.Brush := FBlueCrayon;
  FSolidPen := NewPen;
  FSolidPen.LineCap := capRound;
  FSolidPen.LineJoin := joinRound;
  FSolidPen.Width := Thick;
  FRedCrayon := NewBrush(Canvas.LoadBitmap('red-crayon',
    Context.GetAssetFile('textures/red-crayon.png')));
  FRedCrayon.Opacity := 0.5;
  FSolidPen.Brush := FRedCrayon;
  FBackground := Canvas.LoadBitmap('meadow', Context.GetAssetFile('textures/meadow.png'));
  { Generate our user interface controls. The theme loads the glyph font. }
  GenerateWidgets;
  { Generate our cursor }
  FGlyph := Canvas.LoadFont('glyph');
  FGlyph.Color := colorBlack;
  FGlyph.Size := 32;
  FGlyph.Align := fontCenter;
  FGlyph.Layout := fontMiddle;
  { Setup our physics. The step thread starts after Initialize, so the space
    is built without locking it. }
  GenerateStudioWalls;
  Space.Gravity := Vec2(0, 1000);
end;

procedure TDrawScene.Finalize;
var
  I: Integer;
begin
  Mouse.Cursor := cursorDefault;
  FGlyph := nil;
  { The physics scene frees the space and its bodies }
  inherited Finalize;
  for I := 0 to FSolids.Count - 1 do
    TObject(FSolids[I]).Free;
  FreeAndNil(FSolids);
end;

{ AddSolid makes a body from the shape which was drawn. It is called with
  the space locked. The points are in studio coordinates, which are also
  those of the new body, as it is at the origin and has not turned. }

procedure TDrawScene.AddSolid;
var
  Solid: TSolidShape;
  Triangles: TVec2Array;
  B: TBody;
  S: TShape;
  I: Integer;
begin
  Triangles := Triangulate(@FDrawing.Items[0], FDrawing.Length);
  if Length(Triangles) < 3 then
    Exit;
  B := Space.NewBody;
  { Each triangle is a shape of the body }
  I := 0;
  while I < Length(Triangles) do
  begin
    S := B.NewPolygon(@Triangles[I], 3);
    S.Density := 4;
    S.Friction := 0.6;
    S.Elasticity := 0.4;
    S.Category := 1;
    Inc(I, 3);
  end;
  Solid := TSolidShape.Create;
  SetLength(Solid.Points, FDrawing.Length);
  for I := 0 to FDrawing.Length - 1 do
    Solid.Points[I] := FDrawing[I];
  FSolids.Add(Solid);
  B.UserData := Pointer(Solid);
end;

{ EraseBody frees a body and the outline kept with it. It is called with
  the space locked. }

procedure TDrawScene.EraseBody(Body: TBody);
var
  Data: Pointer;
begin
  Data := Body.UserData;
  Body.Free;
  if (Data <> nil) and (Data <> Outline) then
  begin
    FSolids.Remove(Data);
    TObject(Data).Free;
  end;
end;

{ The mouse cursor is hidden unless it is over a widget, as the scene draws
  a cursor of its own }

procedure TDrawScene.UpdateCursor(X, Y: Float);
begin
  if Widget.FindWidget(X, Y) = nil then
    Mouse.Cursor := cursorNone
  else
    Mouse.Cursor := cursorDefault;
end;

procedure TDrawScene.DoKeyDown(var Args: TSceneKeyArgs);
begin
  inherited DoKeyDown(Args);
  if (not Args.Handled) and (Args.Key = VK_ESCAPE) then
  begin
    ExitClick(nil);
    Args.Handled := True;
  end;
end;

procedure TDrawScene.DoMouseDown(var Args: TSceneMouseArgs);
begin
  if (Widget.FindWidget(Args.X, Args.Y) = nil) and (Args.Button = buttonLeft) then
    if FDraw.Down or FFill.Down then
    begin
      { If hollow or solid drawing }
      if FDraw.Down then
        FIsDrawing := True
      else
        FIsFilling := True;
      { Start capturing drawing points }
      FDrawing.Clear;
      FDrawing.Push(PointToStudio(Args.X, Args.Y));
      Args.Handled := True;
    end
    else if FErase.Down then
    begin
      { If erasing }
      FIsErasing := True;
      Args.Handled := True;
    end;
  if not Args.Handled then
    inherited DoMouseDown(Args);
end;

procedure TDrawScene.DoMouseMove(var Args: TSceneMouseArgs);
var
  A, B: TPointF;
  S: TShape;
begin
  if FIsDrawing or FIsFilling then
  begin
    { If hollow or solid drawing }
    A := PointToStudio(Args.X, Args.Y);
    B := FDrawing.Last;
    if A.Distance(B) > PointSpacing then
      FDrawing.Push(A);
    Args.Handled := True;
  end
  else if FIsErasing then
  begin
    { If erasing. A body is freed while the space is locked. }
    A := PointToStudio(Args.X, Args.Y);
    Lock;
    try
      S := ShapeNearPoint(A.X, A.Y, 10);
      if (not S.IsNil) and (S.Body.Kind = bodyDynamic) then
        EraseBody(S.Body);
    finally
      Unlock;
    end;
    Args.Handled := True;
  end;
  UpdateCursor(Args.X, Args.Y);
  if not Args.Handled then
    inherited DoMouseMove(Args);
end;

procedure TDrawScene.DoMouseUp(var Args: TSceneMouseArgs);
var
  B: TBody;
  S: TShape;
  I: Integer;
begin
  if (Args.Button = buttonLeft) and (FIsDrawing or FIsFilling) then
  begin
    if FDrawing.Length > 1 then
    begin
      { If we were drawing then add a body while the space is locked }
      Lock;
      try
        if FIsDrawing then
        begin
          { Add a hollow physics object }
          B := Space.NewBody;
          for I := 1 to FDrawing.Length - 1 do
          begin
            S := B.NewSegment(FDrawing[I - 1], FDrawing[I], 5);
            S.Density := 2;
            S.Friction := 0.6;
            S.Elasticity := 0.4;
            S.Category := 1;
          end;
          B.UserData := Outline;
        end
        else
          { Add a solid physics object }
          AddSolid;
      finally
        Unlock;
      end;
    end;
    FIsDrawing := False;
    FIsFilling := False;
    FDrawing.Clear;
    Args.Handled := True;
  end
  else if (Args.Button = buttonLeft) and FIsErasing then
  begin
    { Else stop erasing }
    FIsErasing := False;
    Args.Handled := True;
  end;
  if not Args.Handled then
    inherited DoMouseUp(Args);
end;

{ The sync button is down while vertical sync is off }

procedure TDrawScene.SyncClick(Sender: TObject);
begin
  Host.VSync := not FSync.Down;
end;

procedure TDrawScene.FullscreenClick(Sender: TObject);
begin
  if Host.Window <> nil then
    Host.Window.Fullscreen := FFullscreen.Down;
end;

procedure TDrawScene.GraphClick(Sender: TObject);
begin
  FStats.Visible := FGraph.Down;
end;

procedure TDrawScene.ExitClick(Sender: TObject);
begin
  if Host.Window <> nil then
    Host.Window.Close;
end;

{ DrawCustomBody is called while DrawPhysics draws in studio coordinates
  with the space locked }

function TDrawScene.DrawCustomBody(Body: TBody): Boolean;
var
  S: TShape;
  Solid: TSolidShape;
  P: TPointF;
  I: Integer;
begin
  { Return true if we want to draw the physics ourselves }
  Result := True;
  { Don't draw ground plane }
  if Body = Space.Ground then
    Exit;
  if Body.UserData = Outline then
  begin
    { Draw the hollow body }
    for S in Body.Shapes do
    begin
      P := Body.BodyToWorld(S.AsSegment.A);
      Canvas.MoveTo(P.X, P.Y);
      P := Body.BodyToWorld(S.AsSegment.B);
      Canvas.LineTo(P.X, P.Y);
    end;
    { The crayon texture moves and turns with the body }
    P := Body.Position;
    FBlueCrayon.Offset := P;
    FBlueCrayon.Angle := Body.Angle;
    FOutlinePen.Width := Thin;
    Canvas.Stroke(FOutlinePen, True);
    FOutlinePen.Width := Thick;
    Canvas.Stroke(FOutlinePen);
  end
  else if Body.UserData <> nil then
  begin
    { Draw the solid body as the outline which was drawn, and not as the
      triangles the physics uses }
    Solid := TSolidShape(Body.UserData);
    for I := 0 to Length(Solid.Points) - 1 do
    begin
      P := Body.BodyToWorld(Solid.Points[I]);
      if I = 0 then
        Canvas.MoveTo(P.X, P.Y)
      else
        Canvas.LineTo(P.X, P.Y);
    end;
    Canvas.ClosePath;
    P := Body.Position;
    FRedCrayon.Offset := P;
    FRedCrayon.Angle := Body.Angle;
    Canvas.Fill(FRedCrayon, True);
    FSolidPen.Width := Thin;
    Canvas.Stroke(FSolidPen, True);
    FSolidPen.Width := Thick;
    Canvas.Stroke(FSolidPen);
  end
  else
    Result := False;
end;

procedure TDrawScene.GenerateWidgets;
begin
  { Generate the toolbar at the top of our window }
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
        with This.Add<TGlyphButton>(FDraw) do
        begin
          CanToggle := True;
          Text := '󰽉';
          Hint := 'Draw shapes outlines';
          Down := True;
          Group := 1;
        end;
        with This.Add<TGlyphButton>(FFill) do
        begin
          CanToggle := True;
          Text := '󱠓';
          Hint := 'Draw solid shapes';
          Group := 1;
        end;
        with This.Add<TGlyphButton>(FGrab) do
        begin
          CanToggle := True;
          Text := '󰆽';
          Hint := 'Grab shapes';
          Group := 1;
        end;
        with This.Add<TGlyphButton>(FErase) do
        begin
          CanToggle := True;
          Text := '󰙂';
          Hint := 'Erase shapes';
          Group := 1;
        end;
        This.Add<TSpacer>;
        with This.Add<TGlyphButton>(FSync) do
        begin
          CanToggle := True;
          Down := not Host.VSync;
          Text := '󰷛';
          Hint := 'Unlock vertical sync';
          OnClick := SyncClick;
        end;
        with This.Add<TGlyphButton>(FFullscreen) do
        begin
          Down := (Host.Window <> nil) and Host.Window.Fullscreen;
          CanToggle := True;
          Text := '󰊓';
          Hint := 'Switch to fullscreen mode';
          OnClick := FullscreenClick;
        end;
        with This.Add<TGlyphButton>(FGraph) do
        begin
          CanToggle := True;
          Text := '󰄧';
          Hint := 'Show performance information';
          OnClick := GraphClick;
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
end;

{ The background is drawn in a canvas frame, the physics objects in a frame
  of their own, and the shape being drawn and the cursor in a third, under
  the widgets }

procedure TDrawScene.Render;
var
  Buffer: IBackBuffer;
  P: TPointF;
  S: string;
  I: Integer;
begin
  inherited Render;
  { Allow the user to move physics objects while the grab button is down }
  GrabBodies := FGrab.Down;
  Buffer := Canvas as IBackBuffer;
  Buffer.Flip(Width, Height);
  try
    { Make the physics rendering fill the entire window }
    ScaleToStudio;
    { Draw the background }
    Canvas.DrawImage(FBackground, 0, 0);
  finally
    Buffer.Flip(Width, Height);
  end;
  { Draw the physics objects }
  DrawPhysics;
  Buffer.Flip(Width, Height);
  try
    ScaleToStudio;
    { If we are drawing something then render it manually }
    if FDrawing.Length > 1 then
    begin
      { Create the path on the canvas }
      for I := 0 to FDrawing.Length - 1 do
        with FDrawing[I] do
          if I = 0 then
            Canvas.MoveTo(X, Y)
          else
            Canvas.LineTo(X, Y);
      if FIsDrawing then
      begin
        { Draw a blue outline for hollow shapes }
        FBlueCrayon.Offset := NewPointF(0, 0);
        FBlueCrayon.Angle := 0;
        FOutlinePen.Width := Thin;
        Canvas.Stroke(FOutlinePen, True);
        FOutlinePen.Width := Thick;
        Canvas.Stroke(FOutlinePen);
      end
      else
      begin
        { Draw a red outline for solid shapes }
        FRedCrayon.Offset := NewPointF(0, 0);
        FRedCrayon.Angle := 0;
        FSolidPen.Width := Thin;
        Canvas.Stroke(FSolidPen, True);
        FSolidPen.Width := Thick;
        Canvas.Stroke(FSolidPen);
      end;
    end;
    P := NewPointF(Host.MouseX, Host.MouseY);
    if Widget.FindWidget(P.X, P.Y) = nil then
    begin
      { Draw a custom cursor based on a glyph }
      if FDraw.Down or FFill.Down then
        S := '󰃣'
      else if FGrab.Down then
        S := FGrab.Text
      else
        S := FErase.Text;
      P := PointToStudio(P.X, P.Y);
      { Make a soft black drop shadow }
      FGlyph.Color := colorBlack;
      FGlyph.Blur := 2;
      Canvas.DrawText(FGlyph, S, P.X, P.Y);
      Canvas.DrawText(FGlyph, S, P.X, P.Y);
      Canvas.DrawText(FGlyph, S, P.X, P.Y);
      { Then draw the cursor in white }
      FGlyph.Color := colorWhite;
      FGlyph.Blur := 0;
      Canvas.DrawText(FGlyph, S, P.X, P.Y);
    end;
  finally
    Buffer.Flip(Width, Height);
  end;
  { Draw the user interface controls }
  WidgetsRender;
end;

end.
