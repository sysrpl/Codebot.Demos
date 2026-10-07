unit Demo.Scene;

{$mode delphi}

interface

{ Demo.Scene holds TDemoScene, the base class of the demos shown by
  TDemoViewer. The demos were written for Tiny Sim, and this unit gives them
  what they used from it on top of codebot_render: a canvas sized to a studio
  of 1920 by 1080, a fixed rate simulation, the mouse position, keyboard
  input. The Tiny Sim color names and point methods are in
  Codebot.Graphics.Types.

  A demo is not a TScene. The viewer owns every demo and runs the one which is
  selected, calling Update each frame inside a canvas frame. }

uses
  Classes, SysUtils,
  Codebot.System,
  Codebot.Platform,
  Codebot.Graphics.Types,
  Codebot.Render.Graphics,
  Codebot.Hardware,
  Codebot.Render.Scenes;

const
  { Demos draw in a studio of this size, which ScaleToStudio scales to the
    size of the window }
  StudioWidth = 1920;
  StudioHeight = 1080;
  { Simulate calls Step this many times a second }
  SimStepPerSecond = 150;
  SimStep = 1 / SimStepPerSecond;

{ InputPressed returns True when a key goes from up to down. Down holds the
  state of the key from the prior call. }
function InputPressed(var Down: Boolean; Key: Integer): Boolean; overload;
{ InputPressed returns True when a key or a button of the first gamepad goes
  from up to down }
function InputPressed(var Down: Boolean; Key: Integer; Button: TGamepadButton): Boolean; overload;

{ InputAxis returns True while a key is down }
function InputAxis(Key: Integer): Boolean; overload;
{ InputAxis returns True while a key is down or an axis of the first gamepad
  is beyond a limit, which is below the limit when the limit is negative and
  above it otherwise }
function InputAxis(Key: Integer; Axis: TGamepadAxis; Limit: Float): Boolean; overload;

{ TRangeInfo describes the value a demo lets the user change with a slider }

type
  TDemoScene = class;

  TRangeInfo = class
  private
    FDescription: string;
    FPosition: Float;
    FStep: Float;
    FMin: Float;
    FMax: Float;
    FScene: TDemoScene;
    procedure SetPosition(const Value: Float);
  public
    constructor Create(Description: string; Position, Step, Min, Max: Float);
    property Description: string read FDescription;
    property Position: Float read FPosition write SetPosition;
    property Step: Float read FStep;
    property Min: Float read FMin;
    property Max: Float read FMax;
  end;

{ TDemoScene }

  TDemoScene = class
  private
    FRangeInfo: TRangeInfo;
    FWidth: Integer;
    FHeight: Integer;
    FTime: Double;
    FBaseTime: Double;
    FSimulateTime: Double;
    FSimulating: Boolean;
    function GetRangeInfo: TRangeInfo;
    function GetMouseX: Float;
    function GetMouseY: Float;
  protected
    { Canvas and Font belong to the scene host and are set while the demo is
      loaded }
    Canvas: ICanvas;
    Font: IFont;
    function GetTitle: string; virtual;
    function GetDescription: string; virtual;
    function GetGlyph: string; virtual;
    function RangeGenerate: TRangeInfo; virtual;
    procedure RangeChanged(NewPosition: Float); virtual;
    function GetHideMouse: Boolean; virtual;
    { Step is called by Simulate SimStepPerSecond times a second. S is the
      length of a step and T is the time of the step. }
    procedure Step(const S, T: Double); virtual;
    { Logic is called once a frame before Render }
    procedure Logic; virtual;
    { Render draws the demo. Call inherited first. }
    procedure Render(Width, Height: Integer); virtual;
    { Call Simulate from Logic to step the demo at a fixed rate }
    procedure Simulate;
    { A rectangle the size of the studio }
    function ClientRect: TRectF;
    { Scale the canvas so the studio fills the window }
    procedure ScaleToStudio;
    { Convert window coordinates to studio coordinates }
    function PointToStudio(X, Y: Float): TPointF; overload;
    function PointToStudio(const P: TPointF): TPointF; overload;
    { Convert studio coordinates to window coordinates }
    function StudioToPoint(X, Y: Float): TPointF; overload;
    function StudioToPoint(const P: TPointF): TPointF; overload;
  public
    constructor Create; virtual;
    destructor Destroy; override;
    { Load is called when the demo is shown. Call inherited first. }
    procedure Load; virtual;
    { Unload is called when the demo is hidden. Call inherited last. }
    procedure Unload; virtual;
    { Update is called by the viewer once a frame. It calls Logic and then
      Render. }
    procedure Update(Width, Height: Integer; Time: Double);
    { If WantKeys is True the demo gets key events even when the widgets
      handled them }
    function WantKeys: Boolean; virtual;
    procedure DoKeyDown(var Args: TSceneKeyArgs); virtual;
    procedure DoKeyUp(var Args: TSceneKeyArgs); virtual;
    procedure DoMouseDown(var Args: TSceneMouseArgs); virtual;
    procedure DoMouseMove(var Args: TSceneMouseArgs); virtual;
    procedure DoMouseUp(var Args: TSceneMouseArgs); virtual;
    property Title: string read GetTitle;
    property Description: string read GetDescription;
    property Glyph: string read GetGlyph;
    property RangeInfo: TRangeInfo read GetRangeInfo;
    { When HideMouse is True the viewer hides the mouse cursor while it is not
      over a widget }
    property HideMouse: Boolean read GetHideMouse;
    property Width: Integer read FWidth;
    property Height: Integer read FHeight;
    { Seconds since the demo was loaded }
    property Time: Double read FTime;
    { The position of the mouse in window coordinates }
    property MouseX: Float read GetMouseX;
    property MouseY: Float read GetMouseY;
  end;

  TDemoSceneClass = class of TDemoScene;

implementation

function InputPressed(var Down: Boolean; Key: Integer): Boolean;
var
  WasDown: Boolean;
begin
  WasDown := Down;
  Down := IsKeyDown(Key);
  Result := Down and (not WasDown);
end;

function InputPressed(var Down: Boolean; Key: Integer; Button: TGamepadButton): Boolean;
var
  WasDown: Boolean;
begin
  WasDown := Down;
  Down := IsKeyDown(Key) or Joysticks.GamepadDown(0, Button);
  Result := Down and (not WasDown);
end;

function InputAxis(Key: Integer): Boolean;
begin
  Result := IsKeyDown(Key);
end;

function InputAxis(Key: Integer; Axis: TGamepadAxis; Limit: Float): Boolean;
begin
  if IsKeyDown(Key) then
    Exit(True);
  if Limit < 0 then
    Result := Joysticks.GamepadAxis(0, Axis) < Limit
  else
    Result := Joysticks.GamepadAxis(0, Axis) > Limit;
end;

{ TRangeInfo }

constructor TRangeInfo.Create(Description: string; Position, Step, Min,
  Max: Float);
begin
  inherited Create;
  FDescription := Description;
  FPosition := Position;
  FStep := Step;
  FMin := Min;
  FMax := Max;
end;

procedure TRangeInfo.SetPosition(const Value: Float);
begin
  if FPosition = Value then Exit;
  FPosition := Value;
  FScene.RangeChanged(FPosition);
end;

{ TDemoScene }

constructor TDemoScene.Create;
begin
  inherited Create;
end;

destructor TDemoScene.Destroy;
begin
  FRangeInfo.Free;
  inherited Destroy;
end;

function TDemoScene.GetRangeInfo: TRangeInfo;
begin
  if FRangeInfo = nil then
  begin
    FRangeInfo := RangeGenerate;
    FRangeInfo.FScene := Self;
  end;
  Result := FRangeInfo;
end;

function TDemoScene.GetMouseX: Float;
begin
  if SceneHost <> nil then
    Result := SceneHost.MouseX
  else
    Result := 0;
end;

function TDemoScene.GetMouseY: Float;
begin
  if SceneHost <> nil then
    Result := SceneHost.MouseY
  else
    Result := 0;
end;

function TDemoScene.GetTitle: string;
begin
  Result := 'Title';
end;

function TDemoScene.GetDescription: string;
begin
  Result := 'Description';
end;

function TDemoScene.GetGlyph: string;
begin
  Result := '󰄱';
end;

function TDemoScene.RangeGenerate: TRangeInfo;
begin
  Result := TRangeInfo.Create('', 0, 0, 0, 0);
end;

procedure TDemoScene.RangeChanged(NewPosition: Float);
begin
end;

function TDemoScene.GetHideMouse: Boolean;
begin
  Result := False;
end;

function TDemoScene.WantKeys: Boolean;
begin
  Result := False;
end;

procedure TDemoScene.Load;
begin
  if SceneHost <> nil then
  begin
    Canvas := SceneHost.Canvas;
    Font := SceneHost.Font;
  end;
  FTime := 0;
  FBaseTime := -1;
  FSimulating := False;
end;

procedure TDemoScene.Unload;
begin
  Canvas := nil;
  Font := nil;
end;

procedure TDemoScene.Update(Width, Height: Integer; Time: Double);
begin
  if FBaseTime < 0 then
    FBaseTime := Time;
  FTime := Time - FBaseTime;
  FWidth := Width;
  FHeight := Height;
  Logic;
  Render(Width, Height);
end;

procedure TDemoScene.Step(const S, T: Double);
begin
end;

procedure TDemoScene.Logic;
begin
end;

procedure TDemoScene.Render(Width, Height: Integer);
begin
  FWidth := Width;
  FHeight := Height;
end;

{ The steps are timed with the demo Time, so T can be compared with Time }

procedure TDemoScene.Simulate;
var
  T: Double;
begin
  if not FSimulating then
  begin
    FSimulating := True;
    FSimulateTime := FTime;
    Exit;
  end;
  T := FSimulateTime;
  while T + SimStep < FTime do
  begin
    Step(SimStep, T);
    T := T + SimStep;
  end;
  FSimulateTime := T;
end;

function TDemoScene.ClientRect: TRectF;
begin
  Result := NewRectF(StudioWidth, StudioHeight);
end;

procedure TDemoScene.ScaleToStudio;
begin
  Canvas.Matrix.Identity;
  Canvas.Matrix.Scale(FWidth / StudioWidth, FHeight / StudioHeight);
end;

function TDemoScene.PointToStudio(X, Y: Float): TPointF;
begin
  Result.X := X * StudioWidth / FWidth;
  Result.Y := Y * StudioHeight / FHeight;
end;

function TDemoScene.PointToStudio(const P: TPointF): TPointF;
begin
  Result := PointToStudio(P.X, P.Y);
end;

function TDemoScene.StudioToPoint(X, Y: Float): TPointF;
begin
  Result.X := X * FWidth / StudioWidth;
  Result.Y := Y * FHeight / StudioHeight;
end;

function TDemoScene.StudioToPoint(const P: TPointF): TPointF;
begin
  Result := StudioToPoint(P.X, P.Y);
end;

procedure TDemoScene.DoKeyDown(var Args: TSceneKeyArgs);
begin
end;

procedure TDemoScene.DoKeyUp(var Args: TSceneKeyArgs);
begin
end;

procedure TDemoScene.DoMouseDown(var Args: TSceneMouseArgs);
begin
end;

procedure TDemoScene.DoMouseMove(var Args: TSceneMouseArgs);
begin
end;

procedure TDemoScene.DoMouseUp(var Args: TSceneMouseArgs);
begin
end;

end.
