unit PhysicsScene;

{$mode delphi}

interface

{ This unit holds the physics demo scene. It does not use StdCtrls, so names
  such as TLabel and TCheckBox refer to the Codebot widgets. Codebot.Physics
  is listed after Codebot.Geometry so that TPolygon refers to the physics
  polygon shape. }

uses
  Classes, SysUtils,
  Codebot.System,
  Codebot.Graphics.Types,
  Codebot.Geometry,
  Codebot.Render.Graphics,
  Codebot.Render.Scenes,
  Codebot.Render.Widgets,
  Codebot.Render.Widgets.Themes,
  Codebot.Render.Widgets.Custom,
  Codebot.Render.Scenes.Widgets,
  Codebot.Interop.Chipmunk2D,
  Codebot.Physics,
  Codebot.Render.Scenes.Physics;

{ TPhysicsDemoScene tests the physics scene. The space is stepped 150 times a
  second on the step thread while the scene renders on the render thread.

  The scene has a pyramid of boxes, a chain hanging from a pivot, two balls
  joined by a spring, and a bar turned by a motor. Drag any dynamic body with
  the left mouse button. Bodies fall asleep after resting for half a second
  and are drawn in gray.

  The dialog adds balls and boxes, resets the scene, pauses the physics, and
  shows the number of bodies, joints, and collisions. Collisions are counted
  by a collision event, which runs on the step thread. }

type
  TPhysicsDemoScene = class(TPhysicsScene)
  private
    FBodies: TArrayList<TBody>;
    FCollisions: Integer;
    FInfoTime: Double;
    FDialog: TWindow;
    FPauseBox: TCheckBox;
    FInfoLabel: TLabel;
    FGraph: TPerformanceGraph;
    procedure BuildDialog;
    procedure BuildWorld;
    procedure ReleaseWorld;
    function NewBall(X, Y, Radius: Float): TBody;
    function NewCrate(X, Y, Size: Float): TBody;
    procedure AddPyramid;
    procedure AddChain;
    procedure AddSpring;
    procedure AddMotor;
    procedure UpdateInfo;
    function CollisionBegin(const Arbiter: TArbiter; const S: TSpace): Boolean;
    procedure AddBallsClick(Sender: TObject);
    procedure AddBoxesClick(Sender: TObject);
    procedure ResetClick(Sender: TObject);
    procedure PauseChange(Sender: TObject);
    procedure CloseClick(Sender: TObject);
  protected
    function DrawCustomJoint(Joint: TJoint): Boolean; override;
  public
    procedure Initialize; override;
    procedure Finalize; override;
    procedure Render; override;
  end;

implementation

const
  { The top of the ground wall made by GenerateStudioWalls }
  GroundTop = StudioHeight - 20;

{ TPhysicsDemoScene }

procedure TPhysicsDemoScene.Initialize;
var
  Events: TCollisionEvents;
begin
  inherited Initialize;
  Context.SetClearColor(0.12, 0.12, 0.14, 1);
  GrabBodies := True;
  { The step thread starts after Initialize, so the space is built without
    locking it }
  Space.Gravity := Vec2(0, 1000);
  Space.Iterations := 20;
  Space.SleepTimeThreshold := 0.5;
  GenerateStudioWalls;
  Events := Default(TCollisionEvents);
  Events.OnBegin := CollisionBegin;
  Space.AddDefaultCollisionEvents(Events);
  BuildWorld;
  BuildDialog;
end;

procedure TPhysicsDemoScene.Finalize;
begin
  { The space and the bodies in it are freed by the physics scene }
  FBodies.Clear;
  inherited Finalize;
end;

procedure TPhysicsDemoScene.BuildDialog;
begin
  FDialog := Widget.Add<TWindow>;
  with FDialog do
  begin
    Text := 'Physics Demo';
    Fade := 0.1;
    OnClose := CloseClick;
    with This.Add<TLabel> do
    begin
      MaxWidth := 280;
      Text := 'Chipmunk2D runs on a step thread 150 times a second. ' +
        'Drag bodies with the left mouse button. Resting bodies fall ' +
        'asleep and turn gray.';
    end;
    with This.Add<THBox> do
    begin
      Align := alignCenter;
      with This.Add<TPushButton> do
      begin
        Text := 'Add balls';
        OnClick := AddBallsClick;
      end;
      with This.Add<TPushButton> do
      begin
        Text := 'Add boxes';
        OnClick := AddBoxesClick;
      end;
      with This.Add<TPushButton> do
      begin
        Text := 'Reset';
        OnClick := ResetClick;
      end;
    end;
    with This.Add<TCheckBox>(FPauseBox) do
    begin
      Text := 'Pause physics';
      Checked := False;
      OnChange := PauseChange;
    end;
    with This.Add<TLabel>(FInfoLabel) do
    begin
      MaxWidth := 280;
      Text := ' ';
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
end;

{ Bodies are created at their position before their shapes are added, so the
  shapes are placed relative to the body }

function TPhysicsDemoScene.NewBall(X, Y, Radius: Float): TBody;
begin
  Result := Space.NewBody;
  Result.Position := Vec2(X, Y);
  with Result.NewCircle(Radius) do
  begin
    Friction := 0.7;
    Elasticity := 0.6;
  end;
  FBodies.Push(Result);
end;

function TPhysicsDemoScene.NewCrate(X, Y, Size: Float): TBody;
begin
  Result := Space.NewBody;
  Result.Position := Vec2(X, Y);
  with Result.NewBox(Size, Size, 2) do
  begin
    Friction := 0.8;
    Elasticity := 0.1;
  end;
  FBodies.Push(Result);
end;

procedure TPhysicsDemoScene.AddPyramid;
const
  Rows = 7;
  Size = 60;
  PyramidLeft = 1200;
var
  Row, Col: Integer;
begin
  for Row := 0 to Rows - 1 do
    for Col := 0 to Rows - Row - 1 do
      NewCrate(PyramidLeft + Col * Size + Row * Size / 2, GroundTop - Size / 2 - Row * Size, Size);
end;

{ A chain of balls hanging from a pivot on the ground body. Each pivot is
  placed in world coordinates halfway between two links. }

procedure TPhysicsDemoScene.AddChain;
const
  Links = 10;
  Radius = 12;
  Gap = 34;
  AnchorX = 500;
  AnchorY = 120;
var
  Prior, Link: TBody;
  I: Integer;
begin
  Prior := Space.Ground;
  for I := 0 to Links - 1 do
  begin
    Link := NewBall(AnchorX + (I + 1) * Gap, AnchorY, Radius);
    Space.NewPivot(Prior, Link, Vec2(AnchorX + I * Gap + Gap / 2, AnchorY));
    Prior := Link;
  end;
  { The last link is heavier so the chain swings }
  NewBall(AnchorX + (Links + 1) * Gap + 20, AnchorY, 40);
  Space.NewPivot(Prior, FBodies.Last, Vec2(AnchorX + Links * Gap + Gap / 2, AnchorY));
end;

{ Two balls joined by a spring. The masses are large because the shapes have
  a density of 1 and are measured in pixels, so the spring is stiff. }

procedure TPhysicsDemoScene.AddSpring;
var
  A, B: TBody;
begin
  A := NewBall(200, 300, 30);
  B := NewBall(400, 300, 30);
  Space.NewDampedSpring(A, B, VectZero, VectZero, 150, 60000, 2000);
end;

{ A bar turned around a pivot by a motor connected to the ground body }

procedure TPhysicsDemoScene.AddMotor;
var
  Bar: TBody;
begin
  Bar := Space.NewBody;
  Bar.Position := Vec2(900, 700);
  with Bar.NewBox(300, 24, 2) do
  begin
    Friction := 0.8;
    Elasticity := 0.2;
  end;
  FBodies.Push(Bar);
  Space.NewPivot(Space.Ground, Bar, Vec2(900, 700));
  Space.NewMotor(Space.Ground, Bar, 1.5);
end;

procedure TPhysicsDemoScene.BuildWorld;
begin
  AddPyramid;
  AddChain;
  AddSpring;
  AddMotor;
end;

{ Freeing a body also frees its shapes and the joints connected to it }

procedure TPhysicsDemoScene.ReleaseWorld;
var
  I: Integer;
begin
  ReleaseGrab;
  for I := 0 to FBodies.Length - 1 do
    FBodies.Items[I].Free;
  FBodies.Clear;
end;

{ Collision events run on the step thread with the space locked }

function TPhysicsDemoScene.CollisionBegin(const Arbiter: TArbiter; const S: TSpace): Boolean;
begin
  Inc(FCollisions);
  Result := True;
end;

procedure TPhysicsDemoScene.AddBallsClick(Sender: TObject);
var
  I: Integer;
begin
  Lock;
  try
    for I := 1 to 10 do
      NewBall(300 + Random(1300), -100 - Random(400), 15 + Random(25));
  finally
    Unlock;
  end;
end;

procedure TPhysicsDemoScene.AddBoxesClick(Sender: TObject);
var
  I: Integer;
begin
  Lock;
  try
    for I := 1 to 10 do
      NewCrate(300 + Random(1300), -100 - Random(400), 30 + Random(40));
  finally
    Unlock;
  end;
end;

procedure TPhysicsDemoScene.ResetClick(Sender: TObject);
begin
  Lock;
  try
    ReleaseWorld;
    BuildWorld;
    FCollisions := 0;
  finally
    Unlock;
  end;
end;

procedure TPhysicsDemoScene.PauseChange(Sender: TObject);
begin
  Paused := FPauseBox.Checked;
end;

{ Closing the dialog closes the window, which is the form holding the
  graphics box with the LCL or the SDL window with the SDL application }

procedure TPhysicsDemoScene.CloseClick(Sender: TObject);
begin
  if Host.Window <> nil then
    Host.Window.Close;
end;

{ Pivot joints are drawn as small dots and other joints, including the pivot
  joint which drags a body with the mouse, are drawn by the physics scene.
  DrawCustomJoint is called while DrawPhysics draws in studio coordinates. }

function TPhysicsDemoScene.DrawCustomJoint(Joint: TJoint): Boolean;
var
  P: TVec2;
begin
  Result := (Joint.Kind = jointPivot) and not Joint.IsGrab;
  if not Result then
    Exit;
  P := Joint.A.BodyToWorld(Joint.AsPivot.PinA);
  Canvas.Circle(P.X, P.Y, 5);
  Canvas.Fill(NewColorB(240, 200, 60));
end;

procedure TPhysicsDemoScene.UpdateInfo;
var
  Body: TBody;
  Joint: TJoint;
  Bodies, Sleeping, Joints: Integer;
begin
  { The label is updated a few times a second }
  if Time - FInfoTime < 0.25 then
    Exit;
  FInfoTime := Time;
  Bodies := 0;
  Sleeping := 0;
  Joints := 0;
  Lock;
  try
    for Body in Space.Bodies do
    begin
      Inc(Bodies);
      if Body.IsSleeping then
        Inc(Sleeping);
    end;
    for Joint in Space.Joints do
      Inc(Joints);
  finally
    Unlock;
  end;
  FInfoLabel.Text := Format('Bodies: %d, sleeping: %d, joints: %d, collisions: %d',
    [Bodies, Sleeping, Joints, FCollisions]);
end;

procedure TPhysicsDemoScene.Render;
begin
  { The inherited Render clears the background }
  inherited Render;
  UpdateInfo;
  DrawPhysics;
  WidgetsRender;
end;

end.
