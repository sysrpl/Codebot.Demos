unit CubeScene;

{$mode delphi}

interface

{ TCubeScene draws a spinning cube with a shader program and a vertex buffer,
  then draws an overlay on top of it with the canvas: the edges and corners of
  the cube, a meter showing the spin, and a wave along the bottom.

  Drag with the left mouse button to turn the cube. It stops spinning while it
  is dragged. }

uses
  Classes, SysUtils, Math,
  Codebot.System,
  Codebot.Graphics.Types,
  Codebot.Geometry,
  Codebot.OpenGL,
  Codebot.Render.Contexts,
  Codebot.Render.Buffers,
  Codebot.Render.Graphics,
  Codebot.Render.Shaders,
  Codebot.Hardware,
  Codebot.Render.Scenes;

type
  TCubeScene = class(TScene)
  private
    FProgram: TShaderProgram;
    FBuffer: TColorVertexBuffer;
    FMatrixLocation: Integer;
    FDragging: Boolean;
    FAngleX: Single;
    FAngleY: Single;
    FSpin: Single;
    FLastTime: Double;
    procedure DrawOverlay(const MVP: TMatrix4x4; Spin: Single);
  public
    procedure Initialize; override;
    procedure Finalize; override;
    procedure Render; override;
    procedure DoMouseDown(var Args: TSceneMouseArgs); override;
    procedure DoMouseMove(var Args: TSceneMouseArgs); override;
    procedure DoMouseUp(var Args: TSceneMouseArgs); override;
  end;

implementation

{ The shader program colors each face. The position and color of the buffer
  are attributes 0 and 1. A #version line matching render.inc is added when
  the shaders are compiled. }

const
  VertexShader =
    'layout(location = 0) in vec3 position;'#10 +
    'layout(location = 1) in vec4 color;'#10 +
    'uniform mat4 mvp;'#10 +
    'out vec4 faceColor;'#10 +
    'void main() {'#10 +
    '  faceColor = color;'#10 +
    '  gl_Position = mvp * vec4(position, 1.0);'#10 +
    '}'#10;

  FragmentShader =
    'in vec4 faceColor;'#10 +
    'out vec4 fragColor;'#10 +
    'void main() {'#10 +
    '  fragColor = faceColor;'#10 +
    '}'#10;

const
  { The eight corners of the cube }
  Corners: array[0..7, 0..2] of GLfloat = (
    (-1, -1, -1), ( 1, -1, -1), ( 1,  1, -1), (-1,  1, -1),
    (-1, -1,  1), ( 1, -1,  1), ( 1,  1,  1), (-1,  1,  1));

  { Each face is a quad made from four corners }
  Faces: array[0..5, 0..3] of Integer = (
    (4, 5, 6, 7),  { front }
    (1, 0, 3, 2),  { back }
    (0, 4, 7, 3),  { left }
    (5, 1, 2, 6),  { right }
    (7, 6, 2, 3),  { top }
    (0, 1, 5, 4)); { bottom }

  FaceColors: array[0..5, 0..2] of GLfloat = (
    (1.0, 0.2, 0.2),  { red }
    (0.2, 1.0, 0.2),  { green }
    (0.2, 0.4, 1.0),  { blue }
    (1.0, 1.0, 0.2),  { yellow }
    (1.0, 0.2, 1.0),  { magenta }
    (0.2, 1.0, 1.0)); { cyan }

  { Degrees per second the cube spins when it is not being dragged }
  SpinSpeed = 45;

  { The twelve edges of the cube as pairs of corners }
  Edges: array[0..11, 0..1] of Integer = (
    (0, 1), (1, 2), (2, 3), (3, 0),
    (4, 5), (5, 6), (6, 7), (7, 4),
    (0, 4), (1, 5), (2, 6), (3, 7));

{ TCubeScene }

{ Initialize runs with the context current, so the shader program and buffer
  are created here }

procedure TCubeScene.Initialize;
var
  Face, I: Integer;
  C: TVec3;
begin
  inherited Initialize;
  FProgram := TShaderProgram.CreateFromSource(VertexShader, FragmentShader);
  if not FProgram.Valid then
    raise Exception.Create(FProgram.ErrorString);
  Ctx.GetUniform(FProgram.Handle, 'mvp', FMatrixLocation);
  { Each face is a quad of four corners sharing the face color }
  FBuffer := TColorVertexBuffer.Create;
  FBuffer.SetProgram(FProgram.Handle);
  FBuffer.BeginBuffer(vertQuads, 24);
  for Face := 0 to 5 do
    for I := 0 to 3 do
    begin
      C := Vec(Corners[Faces[Face, I], 0], Corners[Faces[Face, I], 1],
        Corners[Faces[Face, I], 2]);
      FBuffer.Add(C, Vec(FaceColors[Face, 0], FaceColors[Face, 1],
        FaceColors[Face, 2], 1));
    end;
  FBuffer.EndBuffer;
end;

procedure TCubeScene.Finalize;
begin
  FBuffer.Free;
  FProgram.Free;
  inherited Finalize;
end;

function WaveY(X: Single; Height: Integer; Phase: Single): Single;
begin
  Result := Height - 40 - Sin(X / 60 + Phase) * 14 - Sin(X / 23 - Phase * 2) * 5;
end;

{ Draw an overlay on top of the cube using the canvas of the host }

procedure TCubeScene.DrawOverlay(const MVP: TMatrix4x4; Spin: Single);
var
  Buffer: IBackBuffer;
  Points: array[0..7] of TVec2;
  Visible: array[0..7] of Boolean;
  Pen: IPen;
  Brush: ILinearGradientBrush;
  I, A, B: Integer;
  Phase, Meter: Single;
begin
  if Canvas = nil then
    Exit;
  for I := 0 to 7 do
    Visible[I] := MVP.Project(Vec(Corners[I, 0], Corners[I, 1], Corners[I, 2]),
      Width, Height, Points[I]);
  { The first flip begins a frame of canvas drawing and the second ends it }
  Buffer := Canvas as IBackBuffer;
  Buffer.Flip(Width, Height);
  try
    { Wireframe lines along the edges of the cube }
    for I := 0 to 11 do
    begin
      A := Edges[I, 0];
      B := Edges[I, 1];
      if Visible[A] and Visible[B] then
      begin
        Canvas.MoveTo(Points[A].X, Points[A].Y);
        Canvas.LineTo(Points[B].X, Points[B].Y);
      end;
    end;
    Pen := NewPen(NewColorB(255, 255, 255, 200), 2.5);
    Pen.LineCap := capRound;
    Canvas.Stroke(Pen);
    { Filled dots on the corners of the cube }
    for I := 0 to 7 do
      if Visible[I] then
        Canvas.Circle(Points[I].X, Points[I].Y, 6);
    Canvas.Fill(NewColorB(255, 255, 255, 230), True);
    Canvas.Stroke(NewColorB(20, 20, 30), 1.5);
    { A translucent panel with a meter showing the spin angle }
    Canvas.RoundRect(19, 20, 220, 60, 10);
    Canvas.Fill(NewColorB(0, 0, 0, 80));
    Canvas.RoundRect(16, 16, 220, 60, 10);
    Brush := NewBrush(NewPointF(16, 16), NewPointF(16, 76));
    Brush.NearStop.Color := NewColorB(70, 80, 110, 200);
    Brush.FarStop.Color := NewColorB(30, 35, 50, 200);
    Canvas.Fill(Brush, True);
    Canvas.Stroke(NewColorB(255, 255, 255, 60), 1);
    Canvas.RoundRect(30, 38, 192, 16, 8);
    Canvas.Fill(NewColorB(0, 0, 0, 120));
    Meter := Frac(Spin / 360);
    if Meter < 0 then
      Meter := Meter + 1;
    Canvas.RoundRect(30, 38, 16 + 176 * Meter, 16, 8);
    Brush := NewBrush(NewPointF(30, 0), NewPointF(222, 0));
    Brush.NearStop.Color := NewColorB(255, 80, 80);
    Brush.FarStop.Color := NewColorB(80, 160, 255);
    Canvas.Fill(Brush);
    { An animated wave along the bottom, filled underneath and stroked on top }
    Phase := Spin * Pi / 180;
    Canvas.MoveTo(0, Height);
    I := 0;
    while I <= Width do
    begin
      Canvas.LineTo(I, WaveY(I, Height, Phase));
      Inc(I, 8);
    end;
    Canvas.LineTo(Width, Height);
    Canvas.ClosePath;
    Brush := NewBrush(NewPointF(0, Height - 70), NewPointF(0, Height));
    Brush.NearStop.Color := NewColorB(80, 160, 255, 140);
    Brush.FarStop.Color := NewColorB(80, 160, 255, 0);
    Canvas.Fill(Brush);
    I := 0;
    while I <= Width do
    begin
      if I = 0 then
        Canvas.MoveTo(I, WaveY(I, Height, Phase))
      else
        Canvas.LineTo(I, WaveY(I, Height, Phase));
      Inc(I, 8);
    end;
    Pen := NewPen(NewColorB(140, 200, 255), 3);
    Pen.LineJoin := joinRound;
    Canvas.Stroke(Pen);
  finally
    Buffer.Flip(Width, Height);
  end;
end;

procedure TCubeScene.Render;
var
  H: Integer;
  MVP: TMatrix4x4;
begin
  if not FDragging then
    FSpin := FSpin + (Time - FLastTime) * SpinSpeed;
  FLastTime := Time;
  H := Max(Height, 1);
  glViewport(0, 0, Width, H);
  glClearColor(0.1, 0.1, 0.15, 1);
  { The canvas uses the stencil buffer, so it is cleared along with the others }
  glClear(GL_COLOR_BUFFER_BIT or GL_DEPTH_BUFFER_BIT or GL_STENCIL_BUFFER_BIT);
  { The canvas changes some state when it draws, so restore the cube state }
  glEnable(GL_DEPTH_TEST);
  glDisable(GL_BLEND);
  { Each operation is multiplied on the right, building projection * view *
    model. Rotate takes degrees and roXYZ applies X before Y }
  MVP.Perspective(45, Width / H, 0.1, 100);
  MVP.Translate(0, 0, -6);
  MVP.Rotate(FAngleX, FAngleY + FSpin, 0, roXYZ);
  { The buffer activates the program again while drawing, so the uniform set
    here stays in effect }
  FProgram.Push;
  Ctx.SetUniform(FMatrixLocation, MVP);
  FBuffer.Draw;
  FProgram.Pop;
  DrawOverlay(MVP, FAngleY + FSpin);
end;

procedure TCubeScene.DoMouseDown(var Args: TSceneMouseArgs);
begin
  if Args.Button = buttonLeft then
  begin
    FDragging := True;
    Args.Handled := True;
  end;
end;

procedure TCubeScene.DoMouseMove(var Args: TSceneMouseArgs);
begin
  if not FDragging then
    Exit;
  FAngleY := FAngleY + Args.XRel * 0.5;
  FAngleX := FAngleX + Args.YRel * 0.5;
  Args.Handled := True;
end;

procedure TCubeScene.DoMouseUp(var Args: TSceneMouseArgs);
begin
  if Args.Button = buttonLeft then
    FDragging := False;
end;

end.
