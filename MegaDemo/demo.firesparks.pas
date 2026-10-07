unit Demo.FireSparks;

{$mode delphi}

interface

uses
  SysUtils,
  Codebot.System,
  Codebot.Platform,
  Codebot.Graphics.Types,
  Codebot.Render.Graphics,
  Demo.Scene;

{ TSpark }

type
  PSpark = ^TSpark;
  TSpark = record
    Birth: Double;
    Life: Double;
    Point: TPointF;
    Velocity: Single;
    Radius: Single;
    Color: TColorF;
    Ready: Boolean;
    procedure Generate(P: TPointF; T: Double);
  end;

{ TFireSparks }

  TFireSparks = class(TDemoScene)
  private
    FSparkCount: Integer;
    FSparks: TArrayList<TSpark>;
    FBrush: IRadialGradientBrush;
    FMouse: TPointF;
  protected
    function GetTitle: string; override;
    function GetDescription: string; override;
    function GetGlyph: string; override;
    function RangeGenerate: TRangeInfo; override;
    procedure RangeChanged(NewPosition: Float); override;
    procedure Step(const S, T: Double); override;
    procedure Logic; override;
    procedure Render(Width, Height: Integer); override;
  public
    procedure Load; override;
  end;

implementation

{ TFireSparks }

const
  Ground = 700;
  ColorCount = 4;
  SparkColors: array[0..ColorCount - 1] of TColorB = (
    (Blue: $38; Green: $EE; Red: $FF; Alpha: $FF),
    (Blue: $1A; Green: $C2; Red: $FF; Alpha: $FF),
    (Blue: $75; Green: $BF; Red: $FF; Alpha: $FF),
    (Blue: $FA; Green: $FF; Red: $FF; Alpha: $FF));

procedure TSpark.Generate(P: TPointF; T: Double);
begin
  Birth := T;
  Point := P;
  Point.Y := Point.Y - Random * 10;
  if Point.Y > Ground then
    Point.Y := Ground;
  Life := Random * 1.5 + (Ground - Point.Y) / 200 + 0.5;
  Radius := Random * 10 + 5;
  Velocity := (Random - 0.5) * 300;
  Color := SparkColors[Trunc(Random * ColorCount)];
  Ready := True;
end;

function TFireSparks.GetTitle: string;
begin
  Result := 'Fire Sparks';
end;

function TFireSparks.GetDescription: string;
begin
  Result := 'Move the mouse to create a random shower of fiery sparks. The sparks ' +
    'are reflected and blurred on the ground below.';
end;

function TFireSparks.GetGlyph: string;
begin
  Result := '󱠇';
end;

function TFireSparks.RangeGenerate: TRangeInfo;
begin
  Result := TRangeInfo.Create('Number of sparks', FSparkCount, 1, 50, 500);
end;

procedure TFireSparks.RangeChanged(NewPosition: Float);
var
  D: TPointF;
  I: Integer;
begin
  FSparkCount := Round(NewPosition);
  D := StudioToPoint(MouseX, MouseY);
  FSparks.Length := FSparkCount;
  for I := 0 to FSparkCount - 1 do
  begin
    FSparks.Items[I].Generate(D, Time + Random * 2);
    FSparks.Items[I].Ready := False;
  end;
end;

procedure TFireSparks.Load;
var
  D: TPointF;
  I: Integer;
begin
  inherited Load;
  if FSparkCount = 0 then
  begin
    Randomize;
    D := StudioToPoint(MouseX, MouseY);
    FSparkCount := 200;
    FSparks.Length := FSparkCount;
    FBrush := NewBrush(ClientRect);
    FBrush.FarStop.Color := colorBlack;
  end;
  for I := 0 to FSparkCount - 1 do
  begin
    FSparks.Items[I].Generate(D, 1 + Random * 10);
    FSparks.Items[I].Ready := False;
  end;
end;

function Power(const Base, Exponent: Single): Single;
begin
  if Exponent = 0 then
    Result := 1
  else if (Base = 0) and (Exponent > 0) then
    Result := 0
  else
    Result := Exp(Exponent * Ln(Base));
end;

function Bouncy(Percent: Single): Single;
var
  Scale, Start, Step: Single;
begin
  Result := 1;
  Scale := 5;
  Start := 0.5;
  Step := 0.2;
  if Percent < Start then
  begin
    Result := Percent / Start;
    Result :=  Result * Result;
  end
  else
  while Step > 0.01 do
    if Percent < Start + Step then
    begin
      Step := Step / 2;
      Result := (Percent - (Start + Step)) * Scale;
      Result :=  Result * Result;
      Result := Result + 1 - Power(Step * Scale, 2);
      Break;
    end
    else
    begin
      Start := Start + Step;
      Step := Step * 0.6;
    end;
end;

function Fling(Percent: Single): Single;
begin
  if Percent < 0.2 then
  begin
    Percent := Percent / 0.2;
    Result := -Sin(Percent * Pi / 2) * 0.25;
  end
  else
  begin
    Percent := (Percent - 0.2) / 0.8;
    Percent := Percent * 1.2;
    if Percent > 1 then
      Percent := 1;
    Result := Bouncy(Percent);
    Result := Result - 0.25 * (1 - Result);
  end;
end;

type
  TEasing = function(Percent: Single): Single;

function Interpolate(Easing: TEasing; Percent: Single; Reverse: Boolean = False): Single;
begin
  if Percent < 0 then
    Result := 0
  else if Percent > 1 then
    Result := 1
  else if Reverse then
    Result := 1 - Easing(1 - Percent)
  else
    Result := Easing(Percent);
end;

function Mix(A, B: Single; Easing: TEasing; Percent: Single): Single;
var
  R: Single;
begin
  R := Interpolate(Easing, Percent);
  Result := A * (1 - R) + B * R;
end;

procedure TFireSparks.Step(const S, T: Double);
var
  Spark: PSpark;
  I: Integer;
begin
  for I := 0 to FSparkCount - 1 do
  begin
    Spark := @FSparks.Items[I];
    if Spark.Birth > T then
      Continue;
    if Spark.Birth + Spark.Life > T then
    begin
      if not Spark.Ready then
        Spark.Generate(FMouse, T);
    end
    else
      Spark.Generate(FMouse, T);
  end;
end;

procedure TFireSparks.Logic;
begin
  Simulate;
end;

procedure TFireSparks.Render(Width, Height: Integer);
var
  Spark: PSpark;
  P: TPointF;
  L: Single;
  I: Integer;
  C: TColorF;
begin
  inherited Render(Width, Height);
  FMouse := PointToStudio(MouseX, MouseY);
  ScaleToStudio;
  Canvas.BlendMode := blendAdditive;
  for I := 0 to FSparkCount - 1 do
  begin
    Spark := @FSparks.Items[I];
    if Spark.Birth > Time then
    begin
      Spark.Point := FMouse;
      Continue;
    end;
    if (Spark.Birth + Spark.Life > Time) and Spark.Ready then
    begin
      P := Spark.Point;
      P.X := P.X  + Spark.Velocity * (Time - Spark.Birth);
      L := 1 - (Time - Spark.Birth) / Spark.Life;
      P.Y := Mix(P.Y, Ground, Fling, 1 - L) - Spark.Radius * L;
      L := Spark.Radius * L;
      Canvas.Circle(P.X, P.Y, L);
      Canvas.Fill(Spark.Color);
      P.Y := -(P.Y - Ground) * 0.3 + Ground;
      L := L * 2;
      Canvas.Circle(P.X, P.Y + L, L * 2);
      FBrush.Rect := NewRectF(P.X - L, P.Y, L * 2, L * 2);
      C := Spark.Color;
      C.Alpha := 0.1;
      FBrush.NearStop.Color := C;
      Canvas.Fill(FBrush);
    end;
  end;
end;

end.

