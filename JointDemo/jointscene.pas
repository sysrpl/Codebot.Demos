unit JointScene;

{$mode delphi}

interface

{ This unit holds the joint demo scene. It does not use StdCtrls, so names such
  as TLabel and TCheckBox refer to the Codebot widgets. Codebot.Physics is
  listed after Codebot.Geometry so that TPolygon refers to the physics polygon
  shape. }

uses
  Classes, SysUtils, Math,
  Codebot.System,
  Codebot.Graphics.Types,
  Codebot.Geometry,
  Codebot.Render.Graphics,
  Codebot.Render.Scenes,
  Codebot.Render.Widgets,
  Codebot.Render.Widgets.Themes,
  Codebot.Render.Widgets.Custom,
  Codebot.Render.Scenes.Widgets,
  Codebot.Physics,
  Codebot.Render.Scenes.Physics;

{ TJointScene shows how the Chipmunk2D joints work. It is ported from the
  chimpball project of Tiny.Sim.

  Each setup holds one kind of joint, which is chosen from the dialog. The
  joints are drawn as pins, rails, springs, and angle gauges so their anchors
  and limits can be seen, and the code which creates the setup is shown at the
  bottom. Drag any dynamic body with the left mouse button. }

type
  TJointSetup = procedure of object;

  { TInfoPanel is a container which keeps the size it is given. The theme
    draws it as a panel because its parent is the main widget. }

  TInfoPanel = class(TContainerWidget)
  end;

  TJointScene = class(TPhysicsScene)
  private
    FSetups: array of record
      Name: string;
      Build: TJointSetup;
      Code: string;
      Info: string;
    end;
    FSetupIndex: Integer;
    FJointPen: IPen;
    FCodeFont: IFont;
    FThemes: array[0..5] of TTheme;
    FDialog: TWindow;
    FSetupBox: TSpinBox;
    FThemeBox: TSpinBox;
    FPauseBox: TCheckBox;
    FInfoPanel: TInfoPanel;
    FInfoLabel: TMarkDownLabel;
    procedure AddSetup(const Name: string; Build: TJointSetup; const Code, Info: string);
    procedure SelectSetup(Index: Integer);
    procedure BuildDialog;
    procedure BuildInfoPanel;
    procedure PlaceInfoPanel;
    { The setups }
    procedure GenerateBox;
    function NewSpinner(X, Y: Float): TBody;
    function NewWheel(X, Y, Radius: Float): TBody;
    function NewPendulum(X, Y: Float): TBody;
    function NewChain(Wheel: TBody; const Start: TVec2; Links: Integer): TBody;
    procedure PinJointSetup;
    procedure SlideJointSetup;
    procedure PivotJointSetup;
    procedure GrooveJointSetup;
    procedure DampedSpringSetup;
    procedure DampedRotarySpringSetup;
    procedure RotaryLimitSetup;
    procedure RatchetSetup;
    procedure GearSetup;
    procedure MotorSetup;
    { Joint drawing }
    function ViewScale: Float;
    procedure LocalMatrix(const P: TVec2; Angle: Float);
    procedure StrokeJoint(const Color: TColorF; Width: Float; Preserve: Boolean = False);
    procedure DrawHand(Length: Float);
    procedure DrawPin(const V: TVec2);
    procedure DrawPinJoint(Joint: TPinJoint);
    procedure DrawSlideJoint(Joint: TSlideJoint);
    procedure DrawGrooveJoint(Joint: TGrooveJoint);
    procedure DrawDampedSpring(Joint: TDampedSpringJoint);
    procedure DrawDampedRotarySpring(Joint: TDampedRotarySpringJoint);
    procedure DrawRotaryLimit(Joint: TRotaryLimitJoint);
    procedure DrawRatchet(Joint: TRatchetJoint);
    procedure DrawGear(Body: TBody; Radius: Float; Teeth: Integer; Offset: Float);
    procedure DrawGearJoint(Joint: TGearJoint);
    procedure DrawSpin(Body: TBody);
    procedure DrawMotor(Joint: TMotorJoint);
    procedure DrawCode;
    { Dialog events }
    procedure SetupChange(Sender: TObject);
    procedure ThemeChange(Sender: TObject);
    procedure RestartClick(Sender: TObject);
    procedure PauseChange(Sender: TObject);
    procedure CloseClick(Sender: TObject);
  protected
    function DefaultTheme: TTheme; override;
    function PointToStudio(X, Y: Float): TVec2; override;
    procedure ScaleToStudio; override;
    function DrawCustomBody(Body: TBody): Boolean; override;
    function DrawCustomJoint(Joint: TJoint): Boolean; override;
  public
    procedure Initialize; override;
    procedure Finalize; override;
    procedure Render; override;
  end;

implementation

const
  { Shapes in the same group do not collide with each other }
  ChainGroup = Pointer(1);
  ThemeNames: array[0..5] of string = ('Arc Dark', 'Chicago', 'Graphite',
    'Experience', 'Vista', 'Cupertino');

{ The code shown for each setup. It matches the setup methods below. }

  PinJointCode =
    '{ A pendulum held at a fixed distance from a pin on the ground }'#10 +
    'B := Space.NewBody;'#10 +
    'B.Position := Vec2(0, -50);'#10 +
    'B.Angle := -Pi / 8;'#10 +
    'B.NewBox(10, 300);'#10 +
    'S := B.NewCircle(50, Vec2(0, 150));'#10 +
    'S.Density := 1.5;'#10 +
    'J := Space.NewPin(Space.Ground, B, Vec2(0, -250), Vec2(0, -150)).AsPin;'#10 +
    'J.Distance := 75;';

  SlideJointCode =
    '{ A pendulum which may slide between 50 and 125 from a pin on the ground }'#10 +
    'B := Space.NewBody;'#10 +
    'B.Position := Vec2(0, -500);'#10 +
    'B.Angle := Pi + 0.01;'#10 +
    'B.NewBox(10, 250);'#10 +
    'B.NewCircle(50, Vec2(0, 100));'#10 +
    'Space.NewSlide(Space.Ground, B, Vec2(0, -250), Vec2(0, -125), 50, 125);';

  PivotJointCode =
    '{ A pendulum which turns around a pivot on the ground }'#10 +
    'B := Space.NewBody;'#10 +
    'B.Position := Vec2(0, -75);'#10 +
    'B.NewBox(10, 250);'#10 +
    'B.NewCircle(50, Vec2(0, 100));'#10 +
    'Space.NewPivot(Space.Ground, B, Vec2(0, -200));';

  GrooveJointCode =
    '{ A pendulum whose pivot slides along a groove on the ground }'#10 +
    'B := Space.NewBody;'#10 +
    'B.Position := Vec2(0, -75);'#10 +
    'B.NewBox(10, 250);'#10 +
    'B.NewCircle(50, Vec2(0, 100));'#10 +
    'J := Space.NewGroove(Space.Ground, B, Vec2(-75, -200),'#10 +
    '  Vec2(75, -200), Vec2(0, -125));'#10 +
    'J.ErrorBias := Power(0.25, 60);';

  DampedSpringCode =
    '{ A box hanging from the ground on a spring with a rest length of 100 }'#10 +
    'B := Space.NewBody;'#10 +
    'B.Position := Vec2(250, -75);'#10 +
    'B.NewBox(200, 100, 20);'#10 +
    'Space.NewDampedSpring(Space.Ground, B, Vec2(0, -200),'#10 +
    '  Vec2(-100, -50), 100, 300000, 10000);';

  DampedRotarySpringCode =
    '{ A spinner which springs back to its rest angle on the ground }'#10 +
    'B := NewSpinner(0, 0);'#10 +
    'Space.NewDampedRotarySpring(Space.Ground, B, 0, 3e9, 5e7);'#10 +
    'B.ApplyImpulseAtBody(Vec2(-8000000, 0), Vec2(0, 160));';

  RotaryLimitCode =
    '{ A pendulum which can only swing an eighth of a turn either way }'#10 +
    'B := NewPendulum(0, -200);'#10 +
    'Space.NewRotaryLimit(Space.Ground, B, -Pi / 4, Pi / 4);'#10 +
    'B.ApplyImpulseAtBody(Vec2(-8000000, 0), Vec2(0, 300));';

  RatchetCode =
    '{ A winch. A heavy ball hangs from the saw tooth wheel on a chain. Drag the }'#10 +
    '{ wheel to wind up the chain and let go. The ratchet stops the wheel at the }'#10 +
    '{ next tooth, so the ball cannot pull the chain back down. }'#10 +
    'Wheel := NewWheel(0, -250, 150);'#10 +
    'Space.NewRatchet(Space.Ground, Wheel, 0, Pi / 8);'#10 +
    'Link := NewChain(Wheel, Vec2(-150, -250), 10);'#10 +
    'Ball := Space.NewBody;'#10 +
    'Ball.Position := Vec2(-150, 120);'#10 +
    'S := Ball.NewCircle(70);'#10 +
    'S.Density := 4;'#10 +
    'S.Group := ChainGroup;'#10 +
    'Space.NewPivot(Link, Ball, Vec2(-150, 50));'#10 +
    'Wheel.ApplyImpulseAtBody(Vec2(-30000000, 0), Vec2(0, 150));';

  GearCode =
    '{ Two wheels which turn opposite ways, the larger at half the speed }'#10 +
    'A := NewWheel(-180, 0, 100);'#10 +
    'B := NewWheel(180, 0, 220);'#10 +
    'Space.NewGear(A, B, 0, -2);'#10 +
    'A.ApplyImpulseAtBody(Vec2(0, 30000000), Vec2(100, 0));';

  MotorCode =
    '{ A spinner turned by a motor at half a turn per second }'#10 +
    'B := NewSpinner(0, 0);'#10 +
    'Space.NewMotor(Space.Ground, B, Pi);';


{ The explanation shown in the panel at the right for each setup, written in
  markdown }

  PinJointInfo =
    '# Pin joint'#10#10 +
    'A pin joint keeps an anchor on one body at a **fixed distance** from an ' +
    'anchor on another body. It works like a rigid rod with a hinge at each ' +
    'end.'#10#10 +
    '## In this demo'#10#10 +
    '- The first anchor is on the ground at `0, -250`'#10 +
    '- The second anchor is at the top of the pendulum, `150` above its center'#10 +
    '- The distance is measured when the joint is made, then set to `75`'#10#10 +
    '## What to watch'#10#10 +
    'The pendulum swings around the pin on the end of the rod, and it can ' +
    'also turn around its own anchor, so it moves like a *double pendulum*. ' +
    'Drag it with the mouse and the rod never stretches or shrinks.';

  SlideJointInfo =
    '# Slide joint'#10#10 +
    'A slide joint is a pin joint whose distance may be anywhere between a ' +
    '**minimum** and a **maximum**. With a minimum of zero it works like a ' +
    'rope or a chain.'#10#10 +
    '## In this demo'#10#10 +
    '- The pendulum starts upside down above its anchor at `0, -250`'#10 +
    '- Its anchor is at its end, `125` from its center'#10 +
    '- The distance may be from `50` to `125`'#10#10 +
    '## What to watch'#10#10 +
    'The pendulum falls and is caught when the distance reaches `125`. The ' +
    'rail shows the allowed range. Push the pendulum up with the mouse and ' +
    'it moves freely until the anchors are `50` apart.';

  PivotJointInfo =
    '# Pivot joint'#10#10 +
    'A pivot joint holds two bodies together at **one point**, like a hinge ' +
    'or an axle. The bodies turn around the point, but it never comes apart.'#10#10 +
    '## In this demo'#10#10 +
    '- The pivot is on the ground at `0, -200`, the top of the pendulum'#10 +
    '- The pivot is given in world coordinates, and the joint works out ' +
    'where that point is on each body'#10#10 +
    '## What to watch'#10#10 +
    'The pendulum is pushed to start and swings around the pivot. Drag it ' +
    'all the way around with the mouse and the top stays on the pivot.';

  GrooveJointInfo =
    '# Groove joint'#10#10 +
    'A groove joint is a pivot joint whose pivot **slides along a groove** ' +
    'on the first body.'#10#10 +
    '## In this demo'#10#10 +
    '- The groove is on the ground from `-75, -200` to `75, -200`'#10 +
    '- The anchor is at the top of the pendulum, `125` above its center'#10 +
    '- The *error bias* corrects `75%` of any error every 1/60th of a second'#10#10 +
    '## What to watch'#10#10 +
    'The top of the pendulum slides along the groove as it swings, and it ' +
    'stops at each end. Drag the pendulum sideways and the top follows.';

  DampedSpringInfo =
    '# Damped spring'#10#10 +
    'A damped spring pulls or pushes two anchors toward a **rest length**. ' +
    'The further they are from it, the harder it pulls.'#10#10 +
    '- **Stiffness** is how strong the spring is'#10 +
    '- **Damping** slows it so it does not bounce forever'#10#10 +
    '## In this demo'#10#10 +
    '- One anchor is on the ground at `0, -200`'#10 +
    '- The other is at the top left corner of the box'#10 +
    '- Rest length `100`, stiffness `300000`, damping `10000`'#10#10 +
    '## What to watch'#10#10 +
    'The box drops and swings below the anchor. The rod shows the rest ' +
    'length and the coil shows the actual length. Pull the box away and let ' +
    'go.';

  DampedRotarySpringInfo =
    '# Damped rotary spring'#10#10 +
    'A damped rotary spring works on the **angle** between two bodies ' +
    'instead of the distance. It turns them toward a *rest angle*, like the ' +
    'spring in a clock or a door hinge.'#10#10 +
    '## In this demo'#10#10 +
    '- The spinner turns on a pivot at the center, `0, 0`'#10 +
    '- The spring joins it to the ground'#10 +
    '- Rest angle `0`, stiffness `3e9`, damping `5e7`'#10#10 +
    '## What to watch'#10#10 +
    'The spinner is given a turn. The spring slows it, turns it back, and it ' +
    'settles at the rest angle. The hand shows the rest angle and the wedge ' +
    'shows how far away the spinner is.';

  RotaryLimitInfo =
    '# Rotary limit'#10#10 +
    'A rotary limit keeps the angle between two bodies between a **minimum** ' +
    'and a **maximum**, like an elbow or a door stop.'#10#10 +
    '## In this demo'#10#10 +
    '- The pendulum hangs from a pivot at `0, -200`'#10 +
    '- The limit joins it to the ground from `-Pi / 4` to `Pi / 4`'#10 +
    '- That is an eighth of a turn either side of straight down'#10#10 +
    '## What to watch'#10#10 +
    'The pendulum swings and stops at the ends of the range. The gauge shows ' +
    'the range and the hand shows the angle of the pendulum.';

  RatchetInfo =
    '# Ratchet joint'#10#10 +
    'A ratchet lets two bodies turn against each other **one way only**, ' +
    'like a socket wrench or a winch. One way it clicks past a stop, and ' +
    'the other way it is caught at the last stop.'#10#10 +
    '## In this demo'#10#10 +
    '- The wheel turns on a pivot at `0, -250`'#10 +
    '- The ratchet joins it to the ground with a stop every `Pi / 8`'#10 +
    '- The sixteen stops are drawn as saw teeth, and the yellow *pawl* ' +
    'falls into them'#10 +
    '- A heavy ball hangs from the rim on a chain'#10#10 +
    '## What to watch'#10#10 +
    'The wheel winds up some chain. When the ball pulls it back, the pawl ' +
    'catches the next tooth and the ball stays up. Drag the wheel or ball to ' +
    'wind up more.';

  GearInfo =
    '# Gear joint'#10#10 +
    'A gear joint keeps the turning speeds of two bodies at a **fixed ' +
    'ratio**, like meshed gears, even though they do not touch.'#10#10 +
    '## In this demo'#10#10 +
    '- The small wheel is at `-180, 0` and the large wheel at `180, 0`'#10 +
    '- The ratio is `-2`, so the large wheel turns at half the speed'#10 +
    '- The *minus sign* turns them in opposite directions'#10#10 +
    '## What to watch'#10#10 +
    'Turn either wheel with the mouse and the other follows. The teeth are ' +
    'only drawn to show the joint, it does not need them.';

  MotorInfo =
    '# Simple motor'#10#10 +
    'A simple motor keeps two bodies turning against each other at a **set ' +
    'rate**. It pushes as hard as it needs to unless its force is limited.'#10#10 +
    '## In this demo'#10#10 +
    '- The spinner turns on a pivot at the center, `0, 0`'#10 +
    '- The motor joins it to the ground with a rate of `Pi`, half a turn a ' +
    'second'#10 +
    '- The arrow shows which way it turns'#10#10 +
    '## What to watch'#10#10 +
    'Grab the spinner to feel the motor push against you. Let go and it ' +
    'returns to its steady speed.';

{ TJointScene }

procedure TJointScene.Initialize;
begin
  inherited Initialize;
  Context.SetClearColor(0.12, 0.12, 0.14, 1);
  GrabBodies := True;
  FJointPen := NewPen;
  FJointPen.LineCap := capRound;
  FJointPen.LineJoin := joinRound;
  try
    FCodeFont := Canvas.LoadFont('code', Context.GetAssetFile('fonts/DejaVuSansMono.ttf'));
  except
    FCodeFont := Font;
  end;
  AddSetup('Pin joint', PinJointSetup, PinJointCode,
    PinJointInfo);
  AddSetup('Slide joint', SlideJointSetup, SlideJointCode,
    SlideJointInfo);
  AddSetup('Pivot joint', PivotJointSetup, PivotJointCode,
    PivotJointInfo);
  AddSetup('Groove joint', GrooveJointSetup, GrooveJointCode,
    GrooveJointInfo);
  AddSetup('Damped spring', DampedSpringSetup, DampedSpringCode,
    DampedSpringInfo);
  AddSetup('Damped rotary spring', DampedRotarySpringSetup, DampedRotarySpringCode,
    DampedRotarySpringInfo);
  AddSetup('Rotary limit', RotaryLimitSetup, RotaryLimitCode,
    RotaryLimitInfo);
  AddSetup('Ratchet joint', RatchetSetup, RatchetCode,
    RatchetInfo);
  AddSetup('Gear joint', GearSetup, GearCode,
    GearInfo);
  AddSetup('Simple motor', MotorSetup, MotorCode,
    MotorInfo);
  BuildDialog;
  BuildInfoPanel;
  SelectSetup(0);
end;

procedure TJointScene.Finalize;
var
  I: Integer;
begin
  FJointPen := nil;
  FCodeFont := nil;
  { The widgets are freed by the inherited Finalize before their themes }
  inherited Finalize;
  for I := Low(FThemes) to High(FThemes) do
    FreeAndNil(FThemes[I]);
end;

function TJointScene.DefaultTheme: TTheme;
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

procedure TJointScene.AddSetup(const Name: string; Build: TJointSetup; const Code, Info: string);
var
  I: Integer;
begin
  I := Length(FSetups);
  SetLength(FSetups, I + 1);
  FSetups[I].Name := Name;
  FSetups[I].Build := Build;
  FSetups[I].Code := Code;
  FSetups[I].Info := Info;
end;

{ A setup is built in a new space while the step thread is locked out }

procedure TJointScene.SelectSetup(Index: Integer);
begin
  if (Index < 0) or (Index > High(FSetups)) then
    Exit;
  FSetupIndex := Index;
  if FInfoLabel <> nil then
    FInfoLabel.Text := FSetups[Index].Info;
  Lock;
  try
    ResetSpace;
    GenerateBox;
    FSetups[Index].Build;
  finally
    Unlock;
  end;
end;

procedure TJointScene.BuildDialog;
var
  Names, Themes: StringArray;
  I: Integer;
begin
  for I := 0 to High(FSetups) do
    Names.Push(FSetups[I].Name);
  for I := Low(ThemeNames) to High(ThemeNames) do
    Themes.Push(ThemeNames[I]);
  FDialog := Widget.Add<TWindow>;
  with FDialog do
  begin
    Text := 'Joints';
    Fade := 0.1;
    OnClose := CloseClick;
    with This.Add<TLabel> do
    begin
      MaxWidth := 280;
      Text := 'Choose a joint to see how it connects two bodies. Drag ' +
        'bodies with the left mouse button.';
    end;
    with This.Add<TLabel> do
      Text := 'Joint:';
    with This.Add<TSpinBox>(FSetupBox) do
    begin
      Indent := 1;
      Width := 280;
      Items := Names;
      ItemIndex := 0;
      OnChange := SetupChange;
    end;
    with This.Add<TLabel> do
      Text := 'Theme:';
    with This.Add<TSpinBox>(FThemeBox) do
    begin
      Indent := 1;
      Width := 280;
      Items := Themes;
      ItemIndex := 0;
      OnChange := ThemeChange;
    end;
    with This.Add<TCheckBox>(FPauseBox) do
    begin
      Text := 'Pause physics';
      Checked := False;
      OnChange := PauseChange;
    end;
    with This.Add<THBox> do
    begin
      Align := alignCenter;
      with This.Add<TPushButton> do
      begin
        Text := 'Restart';
        OnClick := RestartClick;
      end;
      with This.Add<TPushButton> do
      begin
        Text := 'Close';
        OnClick := CloseClick;
      end;
    end;
  end;
end;

{ The info panel floats docked to the right of the scene, with the markdown
  label centered in it. PlaceInfoPanel keeps it docked when the scene is
  resized. }

const
  InfoWidth = 400;
  InfoEdge = 20;
  InfoMargin = 10;

procedure TJointScene.BuildInfoPanel;
begin
  FInfoPanel := Widget.Add<TInfoPanel>;
  FInfoPanel.Width := InfoWidth;
  FInfoLabel := FInfoPanel.Add<TMarkDownLabel>;
  FInfoLabel.MaxWidth := InfoWidth - InfoMargin * 2;
end;

procedure TJointScene.PlaceInfoPanel;
var
  H, Y: Float;
begin
  H := Height - InfoEdge * 2;
  if H < InfoMargin * 2 then
    H := InfoMargin * 2;
  FInfoPanel.X := Width - InfoWidth - InfoEdge;
  FInfoPanel.Y := InfoEdge;
  FInfoPanel.Width := InfoWidth;
  FInfoPanel.Height := H;
  { The label is centered, but its top stays inside the margin when the text
    is taller than the panel }
  Y := Round((H - FInfoLabel.Height) / 2);
  if Y < InfoMargin then
    Y := InfoMargin;
  FInfoLabel.X := InfoMargin;
  FInfoLabel.Y := Y;
end;

{ The origin of the studio is the center of the scene, so the setups are
  placed around 0, 0. Bodies are given their position and angle before their
  shapes are added. The walls are at the edges of the studio and are not
  drawn. }

procedure TJointScene.GenerateBox;
const
  W = StudioWidth / 2;
  H = StudioHeight / 2;
begin
  Space.Gravity := Vec2(0, 200);
  Space.SleepTimeThreshold := 1;
  Space.Damping := 0.95;
  Space.Ground.NewSegment(Vec2(-W, H), Vec2(W, H), 5);
  Space.Ground.NewSegment(Vec2(-W, -H - 1000), Vec2(-W, H), 5);
  Space.Ground.NewSegment(Vec2(W, -H - 1000), Vec2(W, H), 5);
end;

{ A bar with a ball at each end which turns around a pivot at its center, so
  gravity does not turn it }

function TJointScene.NewSpinner(X, Y: Float): TBody;
begin
  Result := Space.NewBody;
  Result.Position := Vec2(X, Y);
  Result.NewBox(14, 400);
  Result.NewCircle(45, Vec2(0, 160));
  Result.NewCircle(45, Vec2(0, -160));
  Space.NewPivot(Space.Ground, Result, Vec2(X, Y));
end;

{ A pendulum with its body origin at the pivot, so it hangs straight down at
  an angle of zero. Its rod and weight are placed below the origin. }

function TJointScene.NewPendulum(X, Y: Float): TBody;
begin
  Result := Space.NewBody;
  Result.Position := Vec2(X, Y);
  Result.NewBox(0, 150, 14, 300);
  Result.NewCircle(50, Vec2(0, 300));
  Space.NewPivot(Space.Ground, Result, Vec2(X, Y));
end;

{ A chain hanging straight down from a point on a wheel. The links are in
  ChainGroup so they do not collide with each other, but they collide with the
  wheel so the chain winds around it. The last link is returned. }

function TJointScene.NewChain(Wheel: TBody; const Start: TVec2; Links: Integer): TBody;
const
  LinkLength = 30;
var
  Prior: TBody;
  S: TShape;
  J: TJoint;
  I: Integer;
begin
  Prior := Wheel;
  Result := Wheel;
  for I := 0 to Links - 1 do
  begin
    Result := Space.NewBody;
    Result.Position := Vec2(Start.X, Start.Y + I * LinkLength + LinkLength / 2);
    S := Result.NewSegment(Vec2(0, -LinkLength / 2), Vec2(0, LinkLength / 2), 6);
    S.Group := ChainGroup;
    J := Space.NewPivot(Prior, Result, Vec2(Start.X, Start.Y + I * LinkLength));
    { The first link is pinned to the rim and should not push against it }
    if Prior = Wheel then
      J.CollideBodies := False;
    Prior := Result;
  end;
end;

{ A wheel which turns around a pivot at its center }

function TJointScene.NewWheel(X, Y, Radius: Float): TBody;
begin
  Result := Space.NewBody;
  Result.Position := Vec2(X, Y);
  Result.NewCircle(Radius);
  Space.NewPivot(Space.Ground, Result, Vec2(X, Y));
end;

procedure TJointScene.PinJointSetup;
var
  B: TBody;
  S: TShape;
  J: TPinJoint;
begin
  B := Space.NewBody;
  B.Position := Vec2(0, -50);
  B.Angle := -Pi / 8;
  B.NewBox(10, 300);
  S := B.NewCircle(50, Vec2(0, 150));
  S.Density := 1.5;
  J := Space.NewPin(Space.Ground, B, Vec2(0, -250), Vec2(0, -150)).AsPin;
  J.Distance := 75;
  B.ApplyImpulseAtBody(Vec2(4000000, 0), Vec2(-100, 200));
end;

procedure TJointScene.SlideJointSetup;
var
  B: TBody;
begin
  B := Space.NewBody;
  B.Position := Vec2(0, -500);
  B.Angle := Pi + 0.01;
  B.NewBox(10, 250);
  B.NewCircle(50, Vec2(0, 100));
  Space.NewSlide(Space.Ground, B, Vec2(0, -250), Vec2(0, -125), 50, 125);
end;

procedure TJointScene.PivotJointSetup;
var
  B: TBody;
begin
  B := Space.NewBody;
  B.Position := Vec2(0, -75);
  B.NewBox(10, 250);
  B.NewCircle(50, Vec2(0, 100));
  Space.NewPivot(Space.Ground, B, Vec2(0, -200));
  B.ApplyImpulseAtBody(Vec2(1600000, 0), Vec2(-100, 200));
end;

procedure TJointScene.GrooveJointSetup;
var
  B: TBody;
  J: TJoint;
begin
  B := Space.NewBody;
  B.Position := Vec2(0, -75);
  B.NewBox(10, 250);
  B.NewCircle(50, Vec2(0, 100));
  J := Space.NewGroove(Space.Ground, B, Vec2(-75, -200),
    Vec2(75, -200), Vec2(0, -125));
  { Correct 75% of the error every 1/60th of a second }
  J.ErrorBias := Power(0.25, 60);
  B.ApplyImpulseAtBody(Vec2(500000, 0), Vec2(-100, 600));
end;

procedure TJointScene.DampedSpringSetup;
var
  B: TBody;
begin
  B := Space.NewBody;
  B.Position := Vec2(250, -75);
  B.NewBox(200, 100, 20);
  Space.NewDampedSpring(Space.Ground, B, Vec2(0, -200),
    Vec2(-100, -50), 100, 300000, 10000);
end;

{ The rotary joints connect one spinner to the ground, so the joint acts on
  the angle of the spinner. The spinner is given a spin to start. }

procedure TJointScene.DampedRotarySpringSetup;
var
  B: TBody;
begin
  B := NewSpinner(0, 0);
  Space.NewDampedRotarySpring(Space.Ground, B, 0, 3e9, 5e7);
  B.ApplyImpulseAtBody(Vec2(-8000000, 0), Vec2(0, 160));
end;

{ The rotary limit stops the pendulum an eighth of a turn either side of
  hanging straight down }

procedure TJointScene.RotaryLimitSetup;
var
  B: TBody;
begin
  B := NewPendulum(0, -200);
  Space.NewRotaryLimit(Space.Ground, B, -Pi / 4, Pi / 4);
  B.ApplyImpulseAtBody(Vec2(-8000000, 0), Vec2(0, 300));
end;

{ The ratchet works like a winch. A ball hangs from the rim of the wheel on a
  chain and pulls the wheel back, and the ratchet catches the wheel at the
  next tooth. The wheel is given a turn to wind up some of the chain. }

procedure TJointScene.RatchetSetup;
var
  Wheel, Link, Ball: TBody;
  S: TShape;
begin
  Wheel := NewWheel(0, -250, 150);
  Space.NewRatchet(Space.Ground, Wheel, 0, Pi / 8);
  Link := NewChain(Wheel, Vec2(-150, -250), 10);
  Ball := Space.NewBody;
  Ball.Position := Vec2(-150, 120);
  S := Ball.NewCircle(70);
  S.Density := 4;
  S.Group := ChainGroup;
  Space.NewPivot(Link, Ball, Vec2(-150, 50));
  Wheel.ApplyImpulseAtBody(Vec2(-30000000, 0), Vec2(0, 150));
end;

{ Two wheels meshed like gears. A negative ratio turns them in opposite
  directions, and a ratio of -2 turns the second wheel, which is twice the
  size of the first, at half the speed. }

procedure TJointScene.GearSetup;
var
  A, B: TBody;
begin
  A := NewWheel(-180, 0, 100);
  B := NewWheel(180, 0, 220);
  Space.NewGear(A, B, 0, -2);
  A.ApplyImpulseAtBody(Vec2(0, 30000000), Vec2(100, 0));
end;

{ A motor turns the spinner at half a turn per second. Hold it with the mouse
  to feel the motor push. }

procedure TJointScene.MotorSetup;
var
  B: TBody;
begin
  B := NewSpinner(0, 0);
  Space.NewMotor(Space.Ground, B, Pi);
end;

{ The studio is scaled evenly to fit inside the scene with its origin at the
  center of the scene, so the setups stay in the center when the window is
  resized }

function TJointScene.ViewScale: Float;
begin
  Result := Min(Width / StudioWidth, Height / StudioHeight);
  if Result <= 0 then
    Result := 1;
end;

function TJointScene.PointToStudio(X, Y: Float): TVec2;
var
  S: Float;
begin
  S := ViewScale;
  Result.X := (X - Width / 2) / S;
  Result.Y := (Y - Height / 2) / S;
end;

{ Joint drawing happens in studio coordinates. LocalMatrix draws rotated
  around a point, and ScaleToStudio returns to studio coordinates. The canvas
  applies each transform after the ones before it, so the studio scale and
  the move to the center are applied last. }

procedure TJointScene.ScaleToStudio;
var
  S: Float;
begin
  S := ViewScale;
  Canvas.Matrix.Identity;
  Canvas.Matrix.Scale(S, S);
  Canvas.Matrix.Translate(Width / 2, Height / 2);
end;

procedure TJointScene.LocalMatrix(const P: TVec2; Angle: Float);
var
  S: Float;
begin
  S := ViewScale;
  Canvas.Matrix.Identity;
  Canvas.Matrix.Rotate(Angle);
  Canvas.Matrix.Translate(P.X, P.Y);
  Canvas.Matrix.Scale(S, S);
  Canvas.Matrix.Translate(Width / 2, Height / 2);
end;

procedure TJointScene.StrokeJoint(const Color: TColorF; Width: Float; Preserve: Boolean = False);
begin
  FJointPen.Color := Color;
  FJointPen.Width := Width;
  Canvas.Stroke(FJointPen, Preserve);
end;

{ A hand points straight down in the current local matrix }

procedure TJointScene.DrawHand(Length: Float);
begin
  Canvas.MoveTo(0, 0);
  Canvas.LineTo(0, Length);
  StrokeJoint(NewColorB(0, 0, 0), 12, True);
  StrokeJoint(NewColorB(255, 255, 255), 9, True);
  StrokeJoint(NewColorB(0, 0, 0), 5);
end;

{ A pin is drawn as rings of black and white }

procedure TJointScene.DrawPin(const V: TVec2);
begin
  Canvas.Circle(V.X, V.Y, 10);
  Canvas.Fill(NewColorB(0, 0, 0));
  Canvas.Circle(V.X, V.Y, 8);
  Canvas.Fill(NewColorB(255, 255, 255));
  Canvas.Circle(V.X, V.Y, 6);
  Canvas.Fill(NewColorB(0, 0, 0));
  Canvas.Circle(V.X, V.Y, 2);
  Canvas.Fill(NewColorB(255, 255, 255));
end;

procedure TJointScene.DrawPinJoint(Joint: TPinJoint);
var
  A, B: TVec2;
begin
  A := Joint.Base.A.BodyToWorld(Joint.PinA);
  B := Joint.Base.B.BodyToWorld(Joint.PinB);
  Canvas.MoveTo(A.X, A.Y);
  Canvas.LineTo(B.X, B.Y);
  StrokeJoint(NewColorB(0, 0, 0), 14, True);
  StrokeJoint(NewColorB(255, 255, 255), 10, True);
  StrokeJoint(NewColorB(0, 0, 0), 6);
  DrawPin(A);
  DrawPin(B);
end;

{ A slide joint is drawn as a rail from the first anchor to the maximum
  distance, with the allowed range marked inside it }

procedure TJointScene.DrawSlideJoint(Joint: TSlideJoint);
var
  A, B, C, U: TVec2;
  D: Float;
begin
  A := Joint.Base.A.BodyToWorld(Joint.PinA);
  B := Joint.Base.B.BodyToWorld(Joint.PinB);
  U := B - A;
  D := U.Distance;
  if D > 0 then
    U := U / D;
  C := A + U * Joint.Max;
  Canvas.MoveTo(A.X, A.Y);
  Canvas.LineTo(C.X, C.Y);
  StrokeJoint(NewColorB(0, 0, 0), 28, True);
  StrokeJoint(NewColorB(255, 255, 255), 24, True);
  StrokeJoint(NewColorB(0, 0, 0), 20);
  C := A + U * Joint.Min;
  Canvas.MoveTo(C.X, C.Y);
  C := A + U * Joint.Max;
  Canvas.LineTo(C.X, C.Y);
  StrokeJoint(NewColorB(255, 255, 255), 10, True);
  StrokeJoint(NewColorB(0, 0, 0), 6);
  DrawPin(A);
  DrawPin(B);
end;

{ A groove joint is drawn as a rail on the first body with the anchor of the
  second body inside it }

procedure TJointScene.DrawGrooveJoint(Joint: TGrooveJoint);
var
  A, B: TVec2;
begin
  A := Joint.Base.A.BodyToWorld(Joint.GrooveA);
  B := Joint.Base.A.BodyToWorld(Joint.GrooveB);
  Canvas.MoveTo(A.X, A.Y);
  Canvas.LineTo(B.X, B.Y);
  StrokeJoint(NewColorB(0, 0, 0), 28, True);
  StrokeJoint(NewColorB(255, 255, 255), 24, True);
  StrokeJoint(NewColorB(0, 0, 0), 20);
  DrawPin(Joint.Base.B.BodyToWorld(Joint.PinB));
end;

{ A damped spring is drawn as a coil around a rod of its rest length, along
  the line from the first anchor to the second }

procedure TJointScene.DrawDampedSpring(Joint: TDampedSpringJoint);
const
  SpringWidth = 10;
var
  A, B: TVec2;
  D, L: Float;
  I, J: Integer;
begin
  A := Joint.Base.A.BodyToWorld(Joint.PinA);
  B := Joint.Base.B.BodyToWorld(Joint.PinB);
  LocalMatrix(A, ArcTan2(B.Y - A.Y, B.X - A.X));
  D := A.Distance(B);
  J := Round(Joint.RestLength / 10);
  if J mod 2 = 0 then
    Inc(J);
  L := (D - 40) / J;
  { The back of the coil }
  for I := 1 to J - 1 do
    if Odd(I) then
      Canvas.MoveTo(20 + I * L, SpringWidth)
    else
      Canvas.LineTo(20 + I * L, -SpringWidth);
  Canvas.LineTo(D - 20, 0);
  Canvas.LineTo(D, 0);
  StrokeJoint(NewColorB(0, 0, 0), 9, True);
  StrokeJoint(NewColorB(255, 255, 255), 5);
  { The rod }
  Canvas.MoveTo(0, 0);
  Canvas.LineTo(Joint.RestLength, 0);
  StrokeJoint(NewColorB(0, 0, 0), 10, True);
  StrokeJoint(NewColorB(255, 255, 255), 8, True);
  StrokeJoint(NewColorB(0, 0, 0), 4);
  { The front of the coil }
  Canvas.MoveTo(0, 0);
  Canvas.LineTo(20, 0);
  for I := 1 to J - 1 do
    if Odd(I) then
      Canvas.LineTo(20 + I * L, SpringWidth)
    else
      Canvas.MoveTo(20 + I * L, -SpringWidth);
  Canvas.LineTo(D - 20, 0);
  Canvas.LineTo(D, 0);
  StrokeJoint(NewColorB(0, 0, 0), 9, True);
  StrokeJoint(NewColorB(255, 255, 255), 5);
  DrawPin(Vec2(0, 0));
  DrawPin(Vec2(D, 0));
  ScaleToStudio;
end;

{ A damped rotary spring is drawn at the second body as a wedge between the
  angles of the two bodies, with a hand showing the rest angle }

procedure TJointScene.DrawDampedRotarySpring(Joint: TDampedRotarySpringJoint);
const
  Radius = 150;
var
  P: TVec2;
  D, T: Float;
begin
  D := Joint.Base.A.Angle;
  P := Joint.Base.B.BodyToWorld(Vec2(0, 0));
  { The direction of the second body in the frame of the first }
  T := Joint.Base.B.Angle - D;
  LocalMatrix(P, D);
  Canvas.MoveTo(0, 0);
  Canvas.LineTo(0, Radius);
  Canvas.LineTo(-Radius * Sin(T), Radius * Cos(T));
  Canvas.ClosePath;
  Canvas.Fill(NewColorF(1, 1, 1, 0.25), True);
  StrokeJoint(NewColorB(0, 0, 0), 5, True);
  StrokeJoint(NewColorB(255, 255, 255), 2);
  LocalMatrix(P, D + Joint.RestAngle);
  DrawHand(Radius + 20);
  ScaleToStudio;
end;

{ A rotary limit is drawn at the second body as a gauge of the allowed range
  in the frame of the first body, with a hand showing the second body }

procedure TJointScene.DrawRotaryLimit(Joint: TRotaryLimitJoint);
const
  Radius = 150;
var
  P: TVec2;
  I: Integer;
begin
  P := Joint.Base.B.BodyToWorld(Vec2(0, 0));
  LocalMatrix(P, Joint.Base.A.Angle);
  { Straight down is a quarter turn in canvas angles }
  Canvas.MoveTo(0, 0);
  Canvas.Arc(0, 0, Radius, Joint.Min + Pi / 2, Joint.Max + Pi / 2, True);
  Canvas.ClosePath;
  Canvas.Fill(NewColorF(1, 1, 1, 0.25), True);
  StrokeJoint(NewColorB(0, 0, 0), 5, True);
  StrokeJoint(NewColorB(255, 255, 255), 2);
  for I := 0 to Radius div 15 - 1 do
  begin
    Canvas.MoveTo(0, I * 15);
    Canvas.LineTo(0, I * 15 + 8);
  end;
  StrokeJoint(NewColorB(0, 0, 0), 5, True);
  StrokeJoint(NewColorB(255, 255, 255), 2);
  LocalMatrix(P, Joint.Base.B.Angle);
  DrawHand(Radius + 20);
  ScaleToStudio;
end;

{ A ratchet is drawn as a wheel of saw teeth turning with the second body and
  a pawl fixed to the first body at the top of the wheel. The ratchet stops
  the bodies at angles of Phase plus a whole number of Ratchet, so the teeth
  are placed to be under the pawl at those angles. The wheel turns freely when
  the sloped side of the teeth slides under the pawl. }

procedure TJointScene.DrawRatchet(Joint: TRatchetJoint);
const
  MaxTeeth = 64;
  Depth = 18;
var
  B: TBody;
  S: TShape;
  P, Tip, Base: TVec2;
  Pawl, Step, A, R: Float;
  I, N: Integer;
begin
  if Joint.Ratchet = 0 then
    Exit;
  B := Joint.Base.B;
  P := B.Position;
  { The wheel is the largest circle of the body }
  R := 0;
  for S in B.Shapes do
    if (S.Kind = shapeCircle) and (S.AsCircle.Radius > R) then
      R := S.AsCircle.Radius;
  if R = 0 then
    R := 120;
  N := Round(2 * Pi / Abs(Joint.Ratchet));
  if N > MaxTeeth then
    N := MaxTeeth;
  Step := 2 * Pi / N;
  if Joint.Ratchet < 0 then
    Step := -Step;
  { The pawl points straight up from the center in the frame of the first
    body, which is a quarter turn back in canvas angles }
  Pawl := -Pi / 2 + Joint.Base.A.Angle;
  { The teeth are in the frame of the wheel. Each tooth rises along a slope
    and drops back at the angle of a stop. }
  LocalMatrix(P, B.Angle);
  for I := 0 to N - 1 do
  begin
    A := Pawl - Joint.Base.A.Angle - Joint.Phase - I * Step;
    if I = 0 then
      Canvas.MoveTo(R * Cos(A), R * Sin(A))
    else
      Canvas.LineTo(R * Cos(A), R * Sin(A));
    Canvas.LineTo((R + Depth) * Cos(A - Step), (R + Depth) * Sin(A - Step));
    Canvas.LineTo(R * Cos(A - Step), R * Sin(A - Step));
  end;
  Canvas.ClosePath;
  Canvas.Fill(NewColorF(1, 1, 1, 0.2), True);
  StrokeJoint(NewColorB(0, 0, 0), 6, True);
  StrokeJoint(NewColorB(255, 255, 255), 2);
  { The pawl rests on the tooth under it from a pin above and to the side }
  ScaleToStudio;
  Tip := P + Vec2(Cos(Pawl), Sin(Pawl)) * (R + Depth / 2);
  Base := P + Vec2(Cos(Pawl - Step * 2), Sin(Pawl - Step * 2)) * (R + Depth * 4);
  Canvas.MoveTo(Base.X, Base.Y);
  Canvas.LineTo(Tip.X, Tip.Y);
  StrokeJoint(NewColorB(0, 0, 0), 14, True);
  StrokeJoint(NewColorB(240, 200, 60), 8);
  DrawPin(Base);
end;

{ A gear outline turning with a body. Offset turns the teeth by a fraction of
  a tooth so two gears can mesh. }

procedure TJointScene.DrawGear(Body: TBody; Radius: Float; Teeth: Integer; Offset: Float);
const
  Depth = 8;
var
  Step, A: Float;
  I: Integer;

  procedure AddPoint(Angle, R: Float; First: Boolean = False);
  begin
    if First then
      Canvas.MoveTo(R * Cos(Angle), R * Sin(Angle))
    else
      Canvas.LineTo(R * Cos(Angle), R * Sin(Angle));
  end;

begin
  if Teeth < 3 then
    Exit;
  LocalMatrix(Body.Position, Body.Angle);
  Step := 2 * Pi / Teeth;
  for I := 0 to Teeth - 1 do
  begin
    A := (I + Offset) * Step;
    AddPoint(A - Step * 0.3, Radius - Depth, I = 0);
    AddPoint(A - Step * 0.15, Radius + Depth);
    AddPoint(A + Step * 0.15, Radius + Depth);
    AddPoint(A + Step * 0.3, Radius - Depth);
  end;
  Canvas.ClosePath;
  StrokeJoint(NewColorB(0, 0, 0), 5, True);
  StrokeJoint(NewColorB(255, 255, 255), 2);
  ScaleToStudio;
end;

{ Each body of a gear joint is drawn as a gear around its first circle. The
  teeth are the same size, so the number of teeth follows the radius, and the
  teeth of the second gear are offset by half a tooth to mesh. }

procedure TJointScene.DrawGearJoint(Joint: TGearJoint);

  function GearRadius(Body: TBody): Float;
  begin
    if (not Body.Shape.IsNil) and (Body.Shape.Kind = shapeCircle) then
      Result := Body.Shape.AsCircle.Radius + 20
    else
      Result := 100;
  end;

var
  R: Float;
begin
  R := GearRadius(Joint.Base.A);
  DrawGear(Joint.Base.A, R, Round(R / 10), 0);
  R := GearRadius(Joint.Base.B);
  DrawGear(Joint.Base.B, R, Round(R / 10), 0.5);
end;

{ A curved arrow around a body shows which way it is turning }

procedure TJointScene.DrawSpin(Body: TBody);
const
  Radius = 235;
  Sweep = 1.5 * Pi;
var
  S, E: Float;
  Tip, Side, Ahead: TVec2;
begin
  if (Body.Kind <> bodyDynamic) or (Abs(Body.AngularVelocity) < 0.01) then
    Exit;
  if Body.AngularVelocity > 0 then
    S := 1
  else
    S := -1;
  LocalMatrix(Body.Position, Body.Angle);
  E := S * Sweep;
  Canvas.Arc(0, 0, Radius, 0, E, S > 0);
  StrokeJoint(NewColorB(0, 0, 0), 8, True);
  StrokeJoint(NewColorB(255, 255, 255), 4);
  { The arrow head points along the direction of the turn }
  Side := Vec2(Cos(E), Sin(E));
  Ahead := Vec2(-Sin(E) * S, Cos(E) * S);
  Tip := Side * Radius + Ahead * 24;
  Canvas.MoveTo(Tip.X, Tip.Y);
  Canvas.LineTo(Side.X * (Radius + 14), Side.Y * (Radius + 14));
  Canvas.LineTo(Side.X * (Radius - 14), Side.Y * (Radius - 14));
  Canvas.ClosePath;
  Canvas.Fill(NewColorB(255, 255, 255), True);
  StrokeJoint(NewColorB(0, 0, 0), 2);
  ScaleToStudio;
end;

procedure TJointScene.DrawMotor(Joint: TMotorJoint);
begin
  DrawSpin(Joint.Base.A);
  DrawSpin(Joint.Base.B);
end;

{ The ground holds the walls, which are not drawn }

function TJointScene.DrawCustomBody(Body: TBody): Boolean;
begin
  Result := Body = Space.Ground;
end;

{ DrawCustomJoint is called by DrawPhysics with the space locked and the
  canvas in studio coordinates. The mouse grab joint is left to the physics
  scene. }

function TJointScene.DrawCustomJoint(Joint: TJoint): Boolean;
begin
  Result := not Joint.IsGrab;
  if not Result then
    Exit;
  case Joint.Kind of
    jointPin: DrawPinJoint(Joint.AsPin);
    jointSlide: DrawSlideJoint(Joint.AsSlide);
    jointPivot: DrawPin(Joint.A.BodyToWorld(Joint.AsPivot.PinA));
    jointGroove: DrawGrooveJoint(Joint.AsGroove);
    jointDampedSpring: DrawDampedSpring(Joint.AsDampedSpring);
    jointDampedRotarySpring: DrawDampedRotarySpring(Joint.AsDampedRotarySpring);
    jointRotaryLimit: DrawRotaryLimit(Joint.AsRotaryLimit);
    jointRatchet: DrawRatchet(Joint.AsRatchet);
    jointGear: DrawGearJoint(Joint.AsGear);
    jointMotor: DrawMotor(Joint.AsMotor);
  else
    Result := False;
  end;
end;

{ The code of the selected setup is shown in a panel at the bottom center of
  the scene in screen pixels. Comment lines are shown in a softer color. }

procedure TJointScene.DrawCode;
const
  Margin = 16;
  Padding = 14;
var
  Buffer: IBackBuffer;
  Lines: TStringList;
  LineHeight, W, H, X, Y: Float;
  I: Integer;
begin
  if (FCodeFont = nil) or (FSetupIndex > High(FSetups)) then
    Exit;
  Lines := TStringList.Create;
  try
    Lines.Text := FSetups[FSetupIndex].Code;
    if Lines.Count = 0 then
      Exit;
    Buffer := Canvas as IBackBuffer;
    Buffer.Flip(Width, Height);
    try
      Canvas.Matrix.Identity;
      FCodeFont.Size := 15;
      FCodeFont.Align := fontLeft;
      FCodeFont.Layout := fontTop;
      LineHeight := FCodeFont.Size * 1.4;
      W := 0;
      for I := 0 to Lines.Count - 1 do
        W := Max(W, Canvas.MeasureText(FCodeFont, Lines[I]).X);
      W := W + Padding * 2;
      H := Lines.Count * LineHeight + Padding * 2;
      X := Round((Width - W) / 2);
      Y := Round(Height - H - Margin);
      Canvas.RoundRect(X, Y, W, H, 8);
      Canvas.Fill(NewColorF(0, 0, 0, 0.6));
      for I := 0 to Lines.Count - 1 do
      begin
        if (Lines[I] <> '') and (Lines[I][1] = '{') then
          FCodeFont.Color := NewColorB(120, 190, 120)
        else
          FCodeFont.Color := NewColorB(230, 230, 230);
        Canvas.DrawText(FCodeFont, Lines[I], X + Padding, Y + Padding + I * LineHeight);
      end;
    finally
      Buffer.Flip(Width, Height);
    end;
  finally
    Lines.Free;
  end;
end;

procedure TJointScene.SetupChange(Sender: TObject);
begin
  SelectSetup(FSetupBox.ItemIndex);
end;

procedure TJointScene.ThemeChange(Sender: TObject);
begin
  if (FThemeBox.ItemIndex < Low(FThemes)) or (FThemeBox.ItemIndex > High(FThemes)) then
    Exit;
  Widget.Theme := FThemes[FThemeBox.ItemIndex];
end;

procedure TJointScene.RestartClick(Sender: TObject);
begin
  SelectSetup(FSetupIndex);
end;

procedure TJointScene.PauseChange(Sender: TObject);
begin
  Paused := FPauseBox.Checked;
end;

{ Closing the dialog closes the window, which is the form holding the
  graphics box with the LCL or the SDL window with the SDL application }

procedure TJointScene.CloseClick(Sender: TObject);
begin
  if Host.Window <> nil then
    Host.Window.Close;
end;

procedure TJointScene.Render;
begin
  { The inherited Render clears the background }
  inherited Render;
  DrawPhysics;
  DrawCode;
  PlaceInfoPanel;
  WidgetsRender;
end;

end.
