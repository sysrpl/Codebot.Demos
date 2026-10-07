unit MachineScene;

{$mode delphi}

interface

{ This unit holds the machine demo scene, which was written for Tiny Sim as
  Play.SvgPhysics. Codebot.Physics is listed after Codebot.Geometry so that
  TPolygon refers to the physics polygon shape. }

uses
  Classes, SysUtils,
  Codebot.System,
  Codebot.Platform,
  Codebot.Graphics.Types,
  Codebot.Geometry,
  Codebot.Render.Graphics,
  Codebot.Render.SVG,
  Codebot.Hardware,
  Codebot.Render.Scenes,
  Codebot.Render.Scenes.Widgets,
  Codebot.Interop.Chipmunk2D,
  Codebot.Physics,
  Codebot.Render.Scenes.Physics;

{ The shapes of the svg document carry physics properties of their own,
  which the svg parser of Codebot.Render.SVG keeps as custom attributes.
  They can be written as attributes of a shape, inside its style attribute,
  or in a rule of the style sheet for its class, and a shape without one
  takes it from the group it is in.

    body         static, dynamic, kinematic, pivot or motor
    density      the weight of the shape for its size
    elasticity   how much the shape bounces
    friction     how much the shape resists sliding
    category     the collision categories the shape belongs to
    mask         the collision categories the shape collides with

  A body of dynamic or kinematic moves freely, and any other does not move.

  A line or a circle with a joint attribute is not a body. It joins two
  bodies instead, which are named by the id of their shapes with the
  attributes a and b. Without a the joint acts on the body before it in the
  document, and without b it acts on the frame of the machine. Angles are
  given in degrees.

    pivot           a circle, the bodies turn about its center
    pin             a line, a rod which keeps its two ends apart
    slide           a line, a rope which can be no longer than max and no
                    shorter than min, where max is the length of the line
                    if it is not given
    groove          a line, a track on a along which the point of b at the
                    middle of the line slides
    spring          a line, a spring with a rest length, stiffness and damping
    rotary-spring   turns b back to an angle of rest from a, with a
                    stiffness and damping
    limit           keeps the angle of b from a between min and max
    ratchet         lets the bodies turn one way only, in steps of ratchet
    gear            keeps the angle of a at ratio times the angle of b
    motor           turns the bodies against each other at rate, in radians
                    a second

  Any joint can have a force, the most it can apply, and a collide of no,
  which lets its two bodies pass through each other. }

type
  { The physics properties of a shape }
  TPhysicsProps = record
    Body: string;
    Density: Float;
    Elasticity: Float;
    Friction: Float;
    Category: LongWord;
    Mask: LongWord;
  end;

{ TMachineScene turns an svg document into a machine made of physics bodies.

  Each path of the document becomes a body made of line segments, with its
  curves flattened into short segments. A path with a body of static does
  not move, and the first of those is the frame of the machine. Each circle
  becomes a body with a circle shape, except for two kinds which act on the
  path before them in the document: a circle with a body of pivot is pinned
  to that path at its center, and one with a body of motor turns that path
  against the frame.

  The machine is drawn in chalk on a blueprint. Bodies can be dragged with
  the mouse, the number keys pick a document, F5 loads the document again,
  and Escape exits. }

  TMachineScene = class(TPhysicsScene)
  private
    FPaper: IBitmapBrush;
    FChalkBitmap: IBitmapBrush;
    FChalk: IPen;
    FDocument: Integer;
    procedure LoadDocument;
    procedure Reload;
  protected
    function DrawCustomBody(Body: TBody): Boolean; override;
    function DrawCustomJoint(Joint: TJoint): Boolean; override;
  public
    procedure Initialize; override;
    procedure Finalize; override;
    procedure Render; override;
    procedure DoKeyDown(var Args: TSceneKeyArgs); override;
  end;

implementation

uses
  Math;

const
  { The documents of the demo, which are picked with the number keys }
  Documents: array[0..1] of string = ('machine.svg', 'workshop.svg');

  { The user data of the bodies made from the document, which are the ones
    the scene draws }
  Machine = Pointer(1);

{ Read the physics properties of a shape from its custom attributes }

function PhysicsProps(Node: TSvgNode): TPhysicsProps;
var
  S: string;
begin
  Result.Body := Node.Attribute('body', 'kinematic');
  Result.Density := Node.AttributeFloat('density', 1);
  Result.Elasticity := Node.AttributeFloat('elasticity', 0.5);
  Result.Friction := Node.AttributeFloat('friction', 0.75);
  Result.Category := High(LongWord);
  Result.Mask := High(LongWord);
  S := Node.Attribute('category');
  if S <> '' then
    Result.Category := StrToMask(S);
  S := Node.Attribute('mask');
  if S <> '' then
    Result.Mask := StrToMask(S);
end;

{ TMachineScene }

procedure TMachineScene.Initialize;
begin
  inherited Initialize;
  FChalkBitmap := NewBrush(Canvas.LoadBitmap('chalk',
    Context.GetAssetFile('textures/white-crayon.png')));
  FChalk := NewPen;
  FChalk.Brush := FChalkBitmap;
  FChalk.LineCap := capRound;
  FChalk.LineJoin := joinRound;
  FChalk.Width := 4;
  FPaper := NewBrush(Canvas.LoadBitmap('blueprint',
    Context.GetAssetFile('textures/blueprint.png')));
  GrabBodies := True;
  { The step thread starts after Initialize, so the space is built without
    locking it }
  LoadDocument;
end;

procedure TMachineScene.Finalize;
begin
  FPaper := nil;
  inherited Finalize;
end;

procedure TMachineScene.DoKeyDown(var Args: TSceneKeyArgs);
begin
  inherited DoKeyDown(Args);
  if Args.Handled then
    Exit;
  case Args.Key of
    VK_F5:
      begin
        Reload;
        Args.Handled := True;
      end;
    Ord('1')..Ord('9'):
      if Args.Key - Ord('1') <= High(Documents) then
      begin
        FDocument := Args.Key - Ord('1');
        Reload;
        Args.Handled := True;
      end;
    VK_ESCAPE:
      begin
        if Host.Window <> nil then
          Host.Window.Close;
        Args.Handled := True;
      end;
  end;
end;

{ Build the machine again in a new space }

procedure TMachineScene.Reload;
begin
  ResetSpace;
  Lock;
  try
    LoadDocument;
  finally
    Unlock;
  end;
end;

function IsDynamic(const Body: string): Boolean;
begin
  Result := (Body = 'dynamic') or (Body = 'kinematic');
end;

{ LoadDocument reads the svg document and adds a body to the space for each
  of its shapes, then a joint for each shape with a joint attribute. The
  joints are added last, as a joint can name a body which follows it in the
  document. }

procedure TMachineScene.LoadDocument;
type
  TPendingJoint = record
    Node: TSvgNode;
    Before: TBody;
  end;
var
  Ground: TBody;
  Last: TBody;
  Names: array of string;
  Bodies: array of TBody;
  Pending: array of TPendingJoint;

  { Remember a body by the id of its shape }
  procedure NameBody(Node: TSvgNode; const Body: TBody);
  var
    I: Integer;
  begin
    if Node.Id = '' then
      Exit;
    I := Length(Names);
    SetLength(Names, I + 1);
    SetLength(Bodies, I + 1);
    Names[I] := Node.Id;
    Bodies[I] := Body;
  end;

  function FindBody(const Name: string; const Fallback: TBody): TBody;
  var
    I: Integer;
  begin
    Result := Fallback;
    if Name = '' then
      Exit;
    for I := 0 to Length(Names) - 1 do
      if Names[I] = Name then
        Exit(Bodies[I]);
  end;

  { Add the body of a shape. The first static body made from a path is the
    frame of the machine. }
  function AddBody(Node: TSvgNode; const Style: TPhysicsProps): TBody;
  begin
    if IsDynamic(Style.Body) then
      Result := Space.NewBody
    else
    begin
      Result := Space.NewStaticBody;
      if Ground.IsNil and (Node is TSvgPath) then
        Ground := Result;
    end;
    Result.UserData := Machine;
    NameBody(Node, Result);
    Last := Result;
  end;

  procedure AddSegment(Node: TSvgNode; const Style: TPhysicsProps;
    const Body: TBody; const P0, P1: TVec2);
  var
    S: TShape;
  begin
    S := Body.NewSegment(P0, P1, Node.Style.StrokeWidth * 1.25);
    S.Density := Style.Density;
    S.Elasticity := Style.Elasticity;
    S.Friction := Style.Friction;
    S.Category := Style.Category;
    S.Mask := Style.Mask;
  end;

  procedure AddCircle(Circle: TSvgCircle);
  var
    Style: TPhysicsProps;
    Body: TBody;
    Shape: TShape;
    Center: TVec2;
  begin
    Style := PhysicsProps(Circle);
    { A motor turns the path before it against the frame of the machine }
    if Style.Body = 'motor' then
    begin
      if (not Ground.IsNil) and (not Last.IsNil) then
        Space.NewMotor(Ground, Last, -0.5);
      Exit;
    end;
    Center := Vec2(Circle.X, Circle.Y);
    if Style.Body = 'pivot' then
    begin
      Body := Space.NewStaticBody;
      Body.UserData := Machine;
    end
    else
      Body := AddBody(Circle, Style);
    Shape := Body.NewCircle(Circle.R, Center);
    Shape.Density := Style.Density;
    Shape.Elasticity := Style.Elasticity;
    Shape.Friction := Style.Friction;
    Shape.Category := Style.Category;
    Shape.Mask := Style.Mask;
    { A pivot pins the path before it at the center of the circle }
    if (Style.Body = 'pivot') and (not Last.IsNil) then
      Space.NewPivot(Last, Body, Center);
  end;

  procedure AddPath(Path: TSvgPath);
  var
    Style: TPhysicsProps;
    Body: TBody;
    C: TSvgCommand;
    S0, P0, P1: TVec2;

    { A curve is flattened into segments. The curves of a ball are cut into
      fewer segments, as there are many balls. }
    procedure AddBezier(const Bezier: TBezier2);
    var
      Curve: TCurve2;
      I: Integer;
    begin
      if Path.ClassId = 'ball' then
        Curve := Bezier.Flatten(6)
      else
        Curve := Bezier.Flatten;
      for I := 1 to Length(Curve.P) - 1 do
        AddSegment(Path, Style, Body, Curve.P[I - 1], Curve.P[I]);
    end;

  var
    Bezier: TBezier2;
    Q: TVec2;
  begin
    Style := PhysicsProps(Path);
    Body := AddBody(Path, Style);
    P0 := Vec2(0, 0);
    S0 := P0;
    for C in Path.Commands do
    begin
      P1 := Vec2(C.X, C.Y);
      case C.Action of
        svgMove:
          S0 := P1;
        svgLine, svgHLine, svgVLine:
          AddSegment(Path, Style, Body, P0, P1);
        svgCubic:
          begin
            Bezier.P0 := P0;
            Bezier.P1 := Vec2(C.X1, C.Y1);
            Bezier.P2 := Vec2(C.X2, C.Y2);
            Bezier.P3 := P1;
            AddBezier(Bezier);
          end;
        svgQuadratic:
          begin
            { A quadratic curve as a cubic one }
            Q := Vec2(C.X1, C.Y1);
            Bezier.P0 := P0;
            Bezier.P1 := Vec2(P0.X + (Q.X - P0.X) * 2 / 3, P0.Y + (Q.Y - P0.Y) * 2 / 3);
            Bezier.P2 := Vec2(P1.X + (Q.X - P1.X) * 2 / 3, P1.Y + (Q.Y - P1.Y) * 2 / 3);
            Bezier.P3 := P1;
            AddBezier(Bezier);
          end;
        svgClose:
          begin
            P1 := S0;
            AddSegment(Path, Style, Body, P0, P1);
          end;
      end;
      P0 := P1;
    end;
  end;

  procedure AddLine(Line: TSvgLine);
  var
    Style: TPhysicsProps;
  begin
    Style := PhysicsProps(Line);
    AddSegment(Line, Style, AddBody(Line, Style), Vec2(Line.X1, Line.Y1),
      Vec2(Line.X2, Line.Y2));
  end;

  { A rectangle is the four segments of its outline }
  procedure AddRect(Rect: TSvgRect);
  var
    Style: TPhysicsProps;
    Body: TBody;
    A, B, C, D: TVec2;
  begin
    Style := PhysicsProps(Rect);
    Body := AddBody(Rect, Style);
    A := Vec2(Rect.X, Rect.Y);
    B := Vec2(Rect.X + Rect.W, Rect.Y);
    C := Vec2(Rect.X + Rect.W, Rect.Y + Rect.H);
    D := Vec2(Rect.X, Rect.Y + Rect.H);
    AddSegment(Rect, Style, Body, A, B);
    AddSegment(Rect, Style, Body, B, C);
    AddSegment(Rect, Style, Body, C, D);
    AddSegment(Rect, Style, Body, D, A);
  end;

  { The outline of a polygon is closed and that of a polyline is not }
  procedure AddPolyline(Poly: TSvgPolyline);
  var
    Style: TPhysicsProps;
    Body: TBody;
    I, N: Integer;
  begin
    Style := PhysicsProps(Poly);
    Body := AddBody(Poly, Style);
    N := Poly.Points.Length;
    for I := 1 to N - 1 do
      AddSegment(Poly, Style, Body,
        Vec2(Poly.Points.Items[I - 1].X, Poly.Points.Items[I - 1].Y),
        Vec2(Poly.Points.Items[I].X, Poly.Points.Items[I].Y));
    if (Poly is TSvgPolygon) and (N > 2) then
      AddSegment(Poly, Style, Body,
        Vec2(Poly.Points.Items[N - 1].X, Poly.Points.Items[N - 1].Y),
        Vec2(Poly.Points.Items[0].X, Poly.Points.Items[0].Y));
  end;

  { Add the joint described by a line or a circle. The bodies have not moved
    since they were made, so the points of the document are also points of
    the bodies. }
  procedure AddJoint(Node: TSvgNode; const Before: TBody);
  var
    Kind: string;
    A, B: TBody;
    P0, P1: TVec2;
    J: TJoint;
    Len: Float;
  begin
    Kind := Node.Attribute('joint', '', False);
    A := FindBody(Node.Attribute('a', '', False), Before);
    if Ground.IsNil then
      B := FindBody(Node.Attribute('b', '', False), Space.Ground)
    else
      B := FindBody(Node.Attribute('b', '', False), Ground);
    if A.IsNil or B.IsNil then
      Exit;
    P0 := Vec2(0, 0);
    if Node is TSvgLine then
    begin
      P0 := Vec2(TSvgLine(Node).X1, TSvgLine(Node).Y1);
      P1 := Vec2(TSvgLine(Node).X2, TSvgLine(Node).Y2);
    end
    else
    begin
      if Node is TSvgCircle then
        P0 := Vec2(TSvgCircle(Node).X, TSvgCircle(Node).Y);
      P1 := P0;
    end;
    Len := Sqrt(Sqr(P1.X - P0.X) + Sqr(P1.Y - P0.Y));
    if Kind = 'pivot' then
      J := Space.NewPivot(A, B, P0)
    else if Kind = 'pin' then
      J := Space.NewPin(A, B, P0, P1)
    else if Kind = 'slide' then
      J := Space.NewSlide(A, B, P0, P1, Node.AttributeFloat('min', 0, False),
        Node.AttributeFloat('max', Len, False))
    else if Kind = 'groove' then
      J := Space.NewGroove(A, B, P0, P1,
        Vec2((P0.X + P1.X) / 2, (P0.Y + P1.Y) / 2))
    else if Kind = 'spring' then
      J := Space.NewDampedSpring(A, B, P0, P1,
        Node.AttributeFloat('rest', Len, False),
        Node.AttributeFloat('stiffness', 50000, False),
        Node.AttributeFloat('damping', 500, False))
    else if Kind = 'rotary-spring' then
      J := Space.NewDampedRotarySpring(A, B,
        DegToRad(Node.AttributeFloat('rest', 0, False)),
        Node.AttributeFloat('stiffness', 10000000, False),
        Node.AttributeFloat('damping', 100000, False))
    else if Kind = 'limit' then
      J := Space.NewRotaryLimit(A, B,
        DegToRad(Node.AttributeFloat('min', 0, False)),
        DegToRad(Node.AttributeFloat('max', 0, False)))
    else if Kind = 'ratchet' then
      J := Space.NewRatchet(A, B, 0,
        DegToRad(Node.AttributeFloat('ratchet', 30, False)))
    else if Kind = 'gear' then
      J := Space.NewGear(A, B, 0, Node.AttributeFloat('ratio', 1, False))
    else if Kind = 'motor' then
      J := Space.NewMotor(A, B, Node.AttributeFloat('rate', 1, False))
    else
      Exit;
    if Node.HasAttribute('force', False) then
      J.MaxForce := Node.AttributeFloat('force', 0, False);
    if Node.Attribute('collide', '', False) = 'no' then
      J.CollideBodies := False;
  end;

  procedure AddBodies(Nodes: TSvgCollection);
  var
    N: TSvgNode;
    I: Integer;
  begin
    for N in Nodes do
      if N is TSvgCollection then
        AddBodies(N as TSvgCollection)
      else if N.HasAttribute('joint', False) then
      begin
        I := Length(Pending);
        SetLength(Pending, I + 1);
        Pending[I].Node := N;
        Pending[I].Before := Last;
      end
      else if N is TSvgPath then
        AddPath(N as TSvgPath)
      else if N is TSvgCircle then
        AddCircle(N as TSvgCircle)
      else if N is TSvgLine then
        AddLine(N as TSvgLine)
      else if N is TSvgRect then
        AddRect(N as TSvgRect)
      else if N is TSvgPolyline then
        AddPolyline(N as TSvgPolyline);
  end;

var
  D: TSvgDocument;
  I: Integer;
begin
  Ground := Default(TBody);
  Last := Default(TBody);
  Names := nil;
  Bodies := nil;
  Pending := nil;
  Space.Gravity := Vec2(0, 1000);
  D := NewSvgDocument;
  try
    D.ParseFile(Context.GetAssetFile('svg/' + Documents[FDocument]));
    AddBodies(D);
    for I := 0 to Length(Pending) - 1 do
      AddJoint(Pending[I].Node, Pending[I].Before);
  finally
    D.Free;
  end;
end;

{ DrawCustomBody is called while DrawPhysics draws in studio coordinates
  with the space locked. The bodies of the machine are drawn in chalk, and
  no others are drawn. }

function TMachineScene.DrawCustomBody(Body: TBody): Boolean;
var
  S: TShape;
  P: TPointF;
begin
  Result := True;
  if Body.UserData <> Machine then
    Exit;
  for S in Body.Shapes do
    case S.Kind of
      shapeCircle:
        begin
          P := Body.BodyToWorld(S.AsCircle.Offset);
          Canvas.Circle(P.X, P.Y, S.AsCircle.Radius);
          { A spoke shows a wheel turning }
          if (S.AsCircle.Radius >= 25) and (Body.Kind = bodyDynamic) then
          begin
            Canvas.MoveTo(P.X, P.Y);
            P := Body.BodyToWorld(Vec2(S.AsCircle.Offset.X + S.AsCircle.Radius,
              S.AsCircle.Offset.Y));
            Canvas.LineTo(P.X, P.Y);
          end;
        end;
      shapeSegment:
        begin
          P := Body.BodyToWorld(S.AsSegment.A);
          Canvas.MoveTo(P.X, P.Y);
          P := Body.BodyToWorld(S.AsSegment.B);
          Canvas.LineTo(P.X, P.Y);
        end;
    end;
  { The chalk texture moves and turns with the body }
  P := Body.Position;
  FChalkBitmap.Offset := P;
  FChalkBitmap.Angle := Body.Angle;
  Canvas.BlendMode := blendLighten;
  Canvas.Stroke(FChalk);
  Canvas.BlendMode := blendAlpha;
end;

{ DrawCustomJoint draws the joints which hold bodies at a point or along a
  line. The joint which drags a body with the mouse is left to DrawPhysics,
  and the joints which act on angles alone are not drawn. }

function TMachineScene.DrawCustomJoint(Joint: TJoint): Boolean;
const
  Coils = 10;
  CoilSize = 9;
var
  A, B: TPointF;
  DX, DY, D, T, Side: Float;
  I: Integer;
begin
  Result := not Joint.IsGrab;
  if not Result then
    Exit;
  case Joint.Kind of
    jointPivot:
      begin
        A := Joint.A.BodyToWorld(Joint.AsPivot.PinA);
        Canvas.Circle(A.X, A.Y, 5);
      end;
    jointPin:
      begin
        A := Joint.A.BodyToWorld(Joint.AsPin.PinA);
        B := Joint.B.BodyToWorld(Joint.AsPin.PinB);
        Canvas.Circle(A.X, A.Y, 5);
        Canvas.Circle(B.X, B.Y, 5);
        Canvas.MoveTo(A.X, A.Y);
        Canvas.LineTo(B.X, B.Y);
      end;
    jointSlide:
      begin
        A := Joint.A.BodyToWorld(Joint.AsSlide.PinA);
        B := Joint.B.BodyToWorld(Joint.AsSlide.PinB);
        Canvas.MoveTo(A.X, A.Y);
        Canvas.LineTo(B.X, B.Y);
      end;
    jointGroove:
      begin
        A := Joint.A.BodyToWorld(Joint.AsGroove.GrooveA);
        B := Joint.A.BodyToWorld(Joint.AsGroove.GrooveB);
        Canvas.MoveTo(A.X, A.Y);
        Canvas.LineTo(B.X, B.Y);
        A := Joint.B.BodyToWorld(Joint.AsGroove.PinB);
        Canvas.Circle(A.X, A.Y, 5);
      end;
    jointDampedSpring:
      begin
        { A spring is a line which goes from side to side }
        A := Joint.A.BodyToWorld(Joint.AsDampedSpring.PinA);
        B := Joint.B.BodyToWorld(Joint.AsDampedSpring.PinB);
        DX := B.X - A.X;
        DY := B.Y - A.Y;
        D := Sqrt(DX * DX + DY * DY);
        if D < 1 then
          Exit;
        Canvas.MoveTo(A.X, A.Y);
        Side := CoilSize;
        for I := 0 to Coils * 2 - 1 do
        begin
          T := (I + 1) / (Coils * 2 + 1);
          Canvas.LineTo(A.X + DX * T - DY / D * Side, A.Y + DY * T + DX / D * Side);
          Side := -Side;
        end;
        Canvas.LineTo(B.X, B.Y);
      end;
  else
    Exit;
  end;
  A.X := 0;
  A.Y := 0;
  FChalkBitmap.Offset := A;
  FChalkBitmap.Angle := 0;
  Canvas.BlendMode := blendLighten;
  Canvas.Stroke(FChalk);
  Canvas.BlendMode := blendAlpha;
end;

{ The blueprint is drawn in a canvas frame, and the machine over it in the
  frame of DrawPhysics }

procedure TMachineScene.Render;
var
  Buffer: IBackBuffer;
begin
  inherited Render;
  Buffer := Canvas as IBackBuffer;
  Buffer.Flip(Width, Height);
  try
    ScaleToStudio;
    Canvas.BlendMode := blendAlpha;
    Canvas.Rect(0, 0, StudioWidth, StudioHeight);
    Canvas.Fill(FPaper);
  finally
    Buffer.Flip(Width, Height);
  end;
  DrawPhysics;
  WidgetsRender;
end;

end.
