unit CardsScene;

{$mode delphi}

interface

{ This unit holds the cards demo scene. It does not use StdCtrls, so names
  such as TLabel and TCheckBox refer to the Codebot widgets. }

uses
  Classes, SysUtils, Math,
  Codebot.System,
  Codebot.Platform,
  Codebot.Animation,
  Codebot.Graphics.Types,
  Codebot.Geometry,
  Codebot.OpenGL,
  Codebot.Render.Contexts,
  Codebot.Render.Buffers,
  Codebot.Render.Textures,
  Codebot.Render.Shaders,
  Codebot.Render.Graphics,
  Codebot.Hardware,
  Codebot.Render.Scenes,
  Codebot.Render.Widgets,
  Codebot.Render.Widgets.Themes,
  Codebot.Render.Widgets.Custom,
  Codebot.Render.Scenes.Widgets;

type
  TCardRank = 1..13;
  TCardSuit = (suitDiamond, suitClub, suitHeart, suitSpade);

{ TCardSprite is one card of the deck. Its values are changed by animations.

  X and Y are the place of the card relative to the center of the scene. The
  card is turned about the z axis, which points out of the screen, by RotZ
  added to Angle, in degrees. RotY is how far the card is turned over, in
  degrees. At zero the back of the card is seen and at 180 its face is seen.

  OriginY is the point the card is placed and turned about, as a part of the
  height of the card from its top. A half is the middle of the card, and a
  larger value is a point below the card which the card swings around.

  Z raises the card in the stack of cards and Lift raises it towards the
  viewer while it is turned over. }

  TCardSprite = class
  public
    Rank: TCardRank;
    Suit: TCardSuit;
    Flipped: Boolean;
    X, Y, Z, Lift: Float;
    RotZ, RotY, Angle: Float;
    OriginY: Float;
    Scale: Float;
    function Name: string;
  end;

{ TAnimation changes one value from what it is when the animation starts to
  a finishing value }

  TAnimation = record
    Prop: PFloat;
    Start, Finish: Float;
    Started: Boolean;
    Time, Duration: Double;
    Easing: TEasing;
    { The card to notify when the animation is complete }
    Card: TCardSprite;
  end;

  TCardEvent = procedure(Card: TCardSprite) of object;

{ TAnimator steps a list of animations. Adding an animation for a value
  replaces the animations the value already has, unless the animation is
  appended, in which case it starts when those animations have finished. }

  TAnimator = class
  private
    FItems: array of TAnimation;
    FNow: Double;
    FOnComplete: TCardEvent;
  public
    procedure Add(var Prop: Float; Target: Float; Span: Double; Ease: TEasing;
      Append: Boolean = False; Delay: Double = 0; Card: TCardSprite = nil);
    procedure Remove(var Prop: Float);
    procedure Clear;
    { Step moves time forward to Now and updates the values being animated }
    procedure Step(Now: Double);
    function Playing: Boolean;
    property OnComplete: TCardEvent read FOnComplete write FOnComplete;
  end;

  TCardArrangement = (arrangeShuffle, arrangeFan, arrangeHearts, arrangeRows);

{ TCardsDemoScene is the dealing cards example from the Bare Game library.

  A deck of fifty two cards is shuffled into a stack in the middle of a
  table, and can then be dealt in different ways:

    F5 shuffles the cards into a stack with their backs showing
    F6 deals the cards in four rows of thirteen
    F7 deals the cards to four players around the table, as in hearts
    F8 deals the cards into a fan
    F9 turns every card over
    F10 changes the style of the card faces

  The dialog has buttons which do the same, and also chooses the back of the
  cards and the table from the images in the assets cards folder.

  Moving the mouse over a card makes it larger, or raises it from the fan,
  and shows its name if it is face up. A card can be dragged with the left
  mouse button. Cards do not respond to the mouse while they are being dealt.

  The table, the name of a card, and the dialog are drawn with the canvas.
  The cards are drawn in three dimensions between them, each as a textured
  rectangle with a shader program. The view is a perspective placed so that
  one unit is one pixel on the table, and so a card turns over in space and
  comes towards the viewer as it is lifted. }

  TCardsDemoScene = class(TWidgetScene)
  private
    FThemes: array[0..5] of TTheme;
    FTable: IBitmap;
    FProgram: TShaderProgram;
    FMatrixLocation: Integer;
    { A rectangle for the back of a card, and one with its texture reversed
      for the face, which is seen from behind the rectangle }
    FBackQuad: TTexVertexBuffer;
    FFaceQuad: TTexVertexBuffer;
    { The textures are owned by the render context and are loaded when they
      are first used }
    FFaces: array[0..5, TCardRank, TCardSuit] of TTexture;
    FBacks: array[0..20] of TTexture;
    FShadow: TTexture;
    FTintLocation: Integer;
    FCutoffLocation: Integer;
    FBack: Integer;
    FStyle: Integer;
    FDeck: TList;
    FArrangement: TCardArrangement;
    { The story holds the animations of a deal, and the animations hold the
      ones caused by the mouse and by cards turning over }
    FStory: TAnimator;
    FAnimations: TAnimator;
    { The bank which loops the shuffle sound while a deal is playing }
    FShuffleBank: TAudioBank;
    FDealing: Boolean;
    FHot: TCardSprite;
    FDrag: TCardSprite;
    FTipText: string;
    FTipAlpha: Float;
    FMouse: TPointF;
    FMouseOver: Boolean;
    FVignette: IRadialGradientBrush;
    FChanging: Boolean;
    FStyleBox: TSpinBox;
    FBackBox: TSpinBox;
    FTableBox: TSpinBox;
    FThemeBox: TSpinBox;
    FFullScreenBox: TCheckBox;
    function Card(Index: Integer): TCardSprite;
    function CardMatrix(Sprite: TCardSprite): TMatrix4x4;
    function ShadowMatrix(Sprite: TCardSprite): TMatrix4x4;
    function CardContains(Sprite: TCardSprite; const P: TPointF): Boolean;
    function CardAt(const P: TPointF): TCardSprite;
    function FaceUp(Sprite: TCardSprite): Boolean;
    function LoadTexture(const Name: string): TTexture;
    function FaceTexture(Sprite: TCardSprite): TTexture;
    function BackTexture: TTexture;
    procedure MoveTop(Sprite: TCardSprite);
    procedure Flip(Sprite: TCardSprite; Span: Double);
    procedure FlipDeal(Sprite: TCardSprite);
    procedure LoadTable(Index: Integer);
    procedure BuildProgram;
    procedure BuildShadow;
    procedure BuildDeck;
    procedure BuildDialog;
    procedure LoadSounds;
    procedure DealSound;
    procedure Shuffle;
    procedure DealRows;
    procedure DealHearts;
    procedure DealFan;
    procedure DealFlip;
    procedure NextStyle;
    procedure HotChange(Sprite: TCardSprite);
    procedure HotTrack;
    procedure DrawTable;
    procedure DrawShadows;
    procedure DrawCards;
    procedure DrawTip;
    procedure DrawVignette;
    procedure DealClick(Sender: TObject);
    procedure StyleChange(Sender: TObject);
    procedure BackChange(Sender: TObject);
    procedure TableChange(Sender: TObject);
    procedure ThemeChange(Sender: TObject);
    procedure FullScreenChange(Sender: TObject);
    procedure FullScreenSync;
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
  end;

implementation

const
  SuitNames: array[TCardSuit] of string =
    ('Diamonds', 'Clubs', 'Hearts', 'Spades');
  RankNames: array[TCardRank] of string =
    ('Ace', '2', '3', '4', '5', '6', '7', '8', '9', '10', 'Jack', 'Queen', 'King');
  { The letter of a suit in the name of a card image }
  SuitLetters: array[TCardSuit] of string = ('d', 'c', 'h', 's');
  { The images of the backs of cards and of tables in the assets cards
    folder, and the names they are given in the dialog }
  BackFiles: array[0..20] of string = ('card.back', 'classic.blue',
    'classic.brown', 'classic.green', 'classic.red', 'cross.blue',
    'cross.brown', 'cross.green', 'cross.red', 'rhombus.blue',
    'rhombus.brown', 'rhombus.green', 'rhombus.red', 'spider.blue',
    'butterflies', 'cat', 'dog', 'rose', 'lawrence', 'monet', 'renoir');
  BackNames: array[0..20] of string = ('Original', 'Classic Blue',
    'Classic Brown', 'Classic Green', 'Classic Red', 'Cross Blue',
    'Cross Brown', 'Cross Green', 'Cross Red', 'Rhombus Blue',
    'Rhombus Brown', 'Rhombus Green', 'Rhombus Red', 'Spider Blue',
    'Butterflies', 'Cat', 'Dog', 'Rose', 'Lawrence', 'Monet', 'Renoir');
  TableFiles: array[0..5] of string = ('green.felt', 'blue.felt', 'red.felt',
    'dark.wood', 'light.wood', 'parquet');
  TableNames: array[0..5] of string = ('Green Felt', 'Blue Felt', 'Red Felt',
    'Dark Wood', 'Light Wood', 'Parquet');
  { The names of the styles of card faces, in the order the styles are
    numbered in the names of the card images }
  StyleNames: array[0..5] of string = ('Modern', 'Classic', 'Caricatures',
    'Large Print', 'Large Print Classic', 'Large Print Modern');
  ThemeNames: array[0..5] of string = ('Arc Dark', 'Chicago', 'Graphite',
    'Experience', 'Vista', 'Cupertino');
  { The number of styles of card faces }
  StyleCount = 6;
  { The size of a card image }
  CardWidth = 146;
  CardHeight = 198;
  { The scale of a card, and of the card under the mouse }
  ScaleNormal = 0.8;
  ScaleHot = 1;
  { The distance between each card in a stack, and how far a stacked card is
    moved for each unit it is raised }
  StackDelta = 0.2;
  StackRaise = 0.0075;
  StackShift = StackDelta / StackRaise;
  { How far a card is lifted towards the viewer to turn over }
  LiftHeight = 120;
  { The field of view of the perspective in degrees }
  FieldOfView = 45;
  { The shadow of a card is a soft dark rectangle a little larger than the
    card. ShadowMargin is how far it reaches past each edge as a part of the
    size of the card, and ShadowAlpha is how dark it is. }
  ShadowMargin = 0.1;
  ShadowAlpha = 0.3;
  { How far the shadow of a card resting on the table is moved right and down,
    and how much further it is moved when the card is fully lifted }
  ShadowOffsetX = 2;
  ShadowOffsetY = 3;
  ShadowLiftX = 14;
  ShadowLiftY = 20;
  { The distance below the center of the scene which a fan swings about, the
    origin of a card in a fan, and of the card under the mouse in a fan }
  FanDistance = 800;
  FanOrigin = 6;
  FanOriginHot = 6.25;
  { The angle between the cards in a fan }
  FanAngle = 1.4;
  { The tags of the buttons in the dialog }
  TagShuffle = 0;
  TagRows = 1;
  TagHearts = 2;
  TagFan = 3;
  TagFlip = 4;

{ The shader program draws a textured rectangle. The position and texture
  coordinate of the buffer are attributes 0 and 1. The color of the texture
  is multiplied by a tint, and nothing is drawn where the alpha of the
  texture is below a cutoff. A #version line matching render.inc is added
  when the shaders are compiled. }

const
  VertexShader =
    'layout(location = 0) in vec3 position;'#10 +
    'layout(location = 1) in vec2 uv;'#10 +
    'uniform mat4 mvp;'#10 +
    'out vec2 coord;'#10 +
    'void main() {'#10 +
    '  coord = uv;'#10 +
    '  gl_Position = mvp * vec4(position, 1.0);'#10 +
    '}'#10;

  FragmentShader =
    'uniform sampler2D tex;'#10 +
    'uniform vec4 tint;'#10 +
    'uniform float cutoff;'#10 +
    'in vec2 coord;'#10 +
    'out vec4 fragColor;'#10 +
    'void main() {'#10 +
    '  vec4 color = texture(tex, coord);'#10 +
    '  if (color.a < cutoff) discard;'#10 +
    '  fragColor = color * tint;'#10 +
    '}'#10;

{ TCardSprite }

function TCardSprite.Name: string;
begin
  Result := Format('%s of %s', [RankNames[Rank], SuitNames[Suit]]);
end;

{ TAnimator }

procedure TAnimator.Add(var Prop: Float; Target: Float; Span: Double; Ease: TEasing;
  Append: Boolean = False; Delay: Double = 0; Card: TCardSprite = nil);
var
  A: TAnimation;
  I: Integer;
begin
  A.Prop := @Prop;
  A.Start := 0;
  A.Finish := Target;
  A.Started := False;
  A.Time := FNow + Delay;
  A.Duration := Span;
  A.Easing := Ease;
  A.Card := Card;
  if Append then
  begin
    { Start after the last animation the value already has }
    for I := 0 to High(FItems) do
      if (FItems[I].Prop = A.Prop) and (FItems[I].Time + FItems[I].Duration > A.Time) then
        A.Time := FItems[I].Time + FItems[I].Duration;
  end
  else
    Remove(Prop);
  SetLength(FItems, Length(FItems) + 1);
  FItems[High(FItems)] := A;
end;

procedure TAnimator.Remove(var Prop: Float);
var
  I, J: Integer;
begin
  J := 0;
  for I := 0 to High(FItems) do
    if FItems[I].Prop <> @Prop then
    begin
      FItems[J] := FItems[I];
      Inc(J);
    end;
  SetLength(FItems, J);
end;

procedure TAnimator.Clear;
begin
  FItems := nil;
end;

{ The cards of the animations which complete are notified after every
  animation has been stepped, as a notified card may add animations }

procedure TAnimator.Step(Now: Double);
var
  Complete: array of TCardSprite;
  I, J: Integer;
begin
  FNow := Now;
  Complete := nil;
  J := 0;
  for I := 0 to High(FItems) do
  begin
    if Now >= FItems[I].Time then
    begin
      if not FItems[I].Started then
      begin
        FItems[I].Start := FItems[I].Prop^;
        FItems[I].Started := True;
      end;
      if (FItems[I].Duration <= 0) or (Now >= FItems[I].Time + FItems[I].Duration) then
      begin
        FItems[I].Prop^ := FItems[I].Finish;
        if FItems[I].Card <> nil then
        begin
          SetLength(Complete, Length(Complete) + 1);
          Complete[High(Complete)] := FItems[I].Card;
        end;
        Continue;
      end;
      FItems[I].Prop^ := Interpolate(FItems[I].Easing, (Now - FItems[I].Time) /
        FItems[I].Duration, FItems[I].Start, FItems[I].Finish);
    end;
    FItems[J] := FItems[I];
    Inc(J);
  end;
  SetLength(FItems, J);
  if Assigned(FOnComplete) then
    for I := 0 to High(Complete) do
      FOnComplete(Complete[I]);
end;

function TAnimator.Playing: Boolean;
begin
  Result := Length(FItems) > 0;
end;

{ TCardsDemoScene }

function TCardsDemoScene.DefaultTheme: TTheme;
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

procedure TCardsDemoScene.Initialize;
begin
  inherited Initialize;
  Randomize;
  Context.SetClearColor(0, 0.3, 0.1, 1);
  FStory := TAnimator.Create;
  FStory.OnComplete := FlipDeal;
  FAnimations := TAnimator.Create;
  FVignette := NewBrush(NewRectF(0, 0, 100, 100));
  FVignette.NearStop.Color := NewColorF(0, 0, 0, 0);
  FVignette.NearStop.Offset := 0.5;
  FVignette.FarStop.Color := NewColorF(0, 0, 0, 0.25);
  FVignette.FarStop.Offset := 1;
  FStyle := 2;
  FBack := 0;
  BuildProgram;
  BuildShadow;
  LoadTable(0);
  BuildDeck;
  BuildDialog;
  LoadSounds;
  Shuffle;
end;

{ The shuffle sound is kept in a bank of its own, where it loops without
  end. The demo runs without sound if the sound cannot be loaded. }

procedure TCardsDemoScene.LoadSounds;
var
  Source: TAudioSource;
begin
  try
    Source := Audio.Source('shuffle');
    if Source = nil then
      Source := Audio.Add('shuffle', Context.GetAssetFile('sounds/shuffle.wav'));
    FShuffleBank := Audio.Banks[0];
    FShuffleBank.Reserved := True;
    FShuffleBank.Load(Source);
    FShuffleBank.LoopCount := 0;
    Audio.Paused := False;
  except
    FShuffleBank := nil;
  end;
end;

{ The shuffle sound fades in when the cards of a deal start to move and
  fades out when they have all arrived }

procedure TCardsDemoScene.DealSound;
var
  Dealing: Boolean;
begin
  Dealing := FStory.Playing;
  if Dealing = FDealing then
    Exit;
  FDealing := Dealing;
  if FShuffleBank = nil then
    Exit;
  if FDealing then
    FShuffleBank.FadeIn(0.5)
  else
    FShuffleBank.FadeOut(0.2);
end;

procedure TCardsDemoScene.Finalize;
var
  I: Integer;
begin
  { The widgets are freed by the inherited Finalize before their theme }
  inherited Finalize;
  if FShuffleBank <> nil then
    FShuffleBank.Unload;
  FShuffleBank := nil;
  for I := Low(FThemes) to High(FThemes) do
    FreeAndNil(FThemes[I]);
  { The animators refer to the values of the cards, so they are freed first }
  FreeAndNil(FStory);
  FreeAndNil(FAnimations);
  if FDeck <> nil then
    for I := 0 to FDeck.Count - 1 do
      Card(I).Free;
  FreeAndNil(FDeck);
  FreeAndNil(FBackQuad);
  FreeAndNil(FFaceQuad);
  FreeAndNil(FProgram);
  FTable := nil;
  FVignette := nil;
end;

{ BuildProgram creates the shader program and the two rectangles used to
  draw every card. A rectangle is one unit wide and high about its center,
  and is sized and placed by the matrix of a card. The top of an image is at
  zero in its texture coordinates. }

procedure TCardsDemoScene.BuildProgram;
begin
  FProgram := TShaderProgram.CreateFromSource(VertexShader, FragmentShader);
  if not FProgram.Valid then
    raise Exception.Create(FProgram.ErrorString);
  Ctx.GetUniform(FProgram.Handle, 'mvp', FMatrixLocation);
  Ctx.GetUniform(FProgram.Handle, 'tint', FTintLocation);
  Ctx.GetUniform(FProgram.Handle, 'cutoff', FCutoffLocation);
  FBackQuad := TTexVertexBuffer.Create;
  FBackQuad.SetProgram(FProgram.Handle);
  FBackQuad.BeginBuffer(vertQuads, 4);
  FBackQuad.Add(-0.5, -0.5, 0, 0, 1);
  FBackQuad.Add(0.5, -0.5, 0, 1, 1);
  FBackQuad.Add(0.5, 0.5, 0, 1, 0);
  FBackQuad.Add(-0.5, 0.5, 0, 0, 0);
  FBackQuad.EndBuffer;
  FFaceQuad := TTexVertexBuffer.Create;
  FFaceQuad.SetProgram(FProgram.Handle);
  FFaceQuad.BeginBuffer(vertQuads, 4);
  FFaceQuad.Add(-0.5, -0.5, 0, 1, 1);
  FFaceQuad.Add(0.5, -0.5, 0, 0, 1);
  FFaceQuad.Add(0.5, 0.5, 0, 0, 0);
  FFaceQuad.Add(-0.5, 0.5, 0, 1, 0);
  FFaceQuad.EndBuffer;
end;

{ BuildShadow makes the texture of the shadow of a card. The texture is
  black, and its alpha is full over the area of a card with rounded corners
  and fades smoothly to nothing across the margin around it, which gives the
  shadow its fuzzy edge. The shadow is drawn larger than a card by the margin
  on every side, so the card area is in the middle of the texture. }

procedure TCardsDemoScene.BuildShadow;
const
  Size = 128;
  Corner = 0.06;
var
  Pixels: array of Byte;
  Inner, DX, DY, D, A: Float;
  X, Y: Integer;
begin
  SetLength(Pixels, Size * Size * 4);
  { The edges of the card area as a distance from the middle of the texture,
    where the edge of the texture is at a half }
  Inner := 0.5 / (1 + ShadowMargin * 2);
  for Y := 0 to Size - 1 do
    for X := 0 to Size - 1 do
    begin
      { The distance outside of the card area with its corners rounded }
      DX := Abs((X + 0.5) / Size - 0.5) - (Inner - Corner);
      DY := Abs((Y + 0.5) / Size - 0.5) - (Inner - Corner);
      if DX < 0 then
        DX := 0;
      if DY < 0 then
        DY := 0;
      D := Sqrt(DX * DX + DY * DY) - Corner;
      if D <= 0 then
        A := 1
      else
      begin
        A := 1 - D / (0.5 - Inner);
        if A < 0 then
          A := 0;
        { A smooth curve at both ends of the fade }
        A := A * A * (3 - 2 * A);
      end;
      Pixels[(Y * Size + X) * 4] := 0;
      Pixels[(Y * Size + X) * 4 + 1] := 0;
      Pixels[(Y * Size + X) * 4 + 2] := 0;
      Pixels[(Y * Size + X) * 4 + 3] := Round(A * 255);
    end;
  FShadow := TTexture.Create;
  FShadow.LoadFromData(Size, Size, @Pixels[0]);
  FShadow.MagFilter := tfLinear;
  FShadow.MinFilter := tfLinear;
end;

{ A texture is loaded from an image in the assets cards folder. The cards are
  drawn smaller than their images and at angles, so the texture is smoothed
  and given mipmaps. }

function TCardsDemoScene.LoadTexture(const Name: string): TTexture;
begin
  Result := TTexture.Create;
  Result.LoadFromFile(Context.GetAssetFile('cards/' + Name + '.png'));
  Result.MagFilter := tfLinear;
  Result.MinFilter := tfLinear;
  Result.GenerateMipmaps;
end;

{ The faces of the cards are images named by rank, suit, and style }

function TCardsDemoScene.FaceTexture(Sprite: TCardSprite): TTexture;
begin
  Result := FFaces[FStyle, Sprite.Rank, Sprite.Suit];
  if Result = nil then
  begin
    Result := LoadTexture(Format('%d.%s.%d', [Sprite.Rank, SuitLetters[Sprite.Suit], FStyle]));
    FFaces[FStyle, Sprite.Rank, Sprite.Suit] := Result;
  end;
end;

function TCardsDemoScene.BackTexture: TTexture;
begin
  Result := FBacks[FBack];
  if Result = nil then
  begin
    Result := LoadTexture(BackFiles[FBack]);
    FBacks[FBack] := Result;
  end;
end;

procedure TCardsDemoScene.LoadTable(Index: Integer);
begin
  if (Index < Low(TableNames)) or (Index > High(TableNames)) then
    Exit;
  FTable := Canvas.LoadBitmap(TableFiles[Index],
    Context.GetAssetFile('cards/' + TableFiles[Index] + '.jpg'));
end;

{ The deck starts as a stack with each card a little above and to the right
  of the one below it }

procedure TCardsDemoScene.BuildDeck;
var
  Sprite: TCardSprite;
  R: TCardRank;
  S: TCardSuit;
  I: Float;
begin
  FDeck := TList.Create;
  I := 0;
  for R := Low(TCardRank) to High(TCardRank) do
    for S := Low(TCardSuit) to High(TCardSuit) do
    begin
      Sprite := TCardSprite.Create;
      Sprite.Rank := R;
      Sprite.Suit := S;
      Sprite.X := I;
      Sprite.Y := -I;
      Sprite.OriginY := 0.5;
      Sprite.Scale := ScaleNormal;
      FDeck.Add(Sprite);
      I := I + StackDelta;
    end;
end;

procedure TCardsDemoScene.BuildDialog;

  procedure AddButton(Box: TWidget; const Caption: string; Deal: Integer);
  var
    Button: TPushButton;
  begin
    Button := Box.Add<TPushButton>;
    Button.Text := Caption;
    Button.Tag := Deal;
    Button.OnClick := DealClick;
  end;

var
  Dialog: TWindow;
  Styles, Backs, Tables, Themes: StringArray;
  Row: THBox;
  I: Integer;
begin
  FChanging := True;
  try
    Dialog := Widget.Add<TWindow>;
    with Dialog do
    begin
      Text := 'Dealing Cards';
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
          Text := 'Shuffle and deal a deck of cards. Move the mouse over a ' +
            'card to see its name, and drag a card to move it.';
        end;
      end;
      Row := This.Add<THBox>;
      AddButton(Row, 'Shuffle (F5)', TagShuffle);
      AddButton(Row, 'Flip (F9)', TagFlip);
      Row := This.Add<THBox>;
      AddButton(Row, 'Rows (F6)', TagRows);
      AddButton(Row, 'Hearts (F7)', TagHearts);
      AddButton(Row, 'Fan (F8)', TagFan);
      with This.Add<TLabel> do
        Text := 'Card faces (F10):';
      for I := Low(StyleNames) to High(StyleNames) do
        Styles.Push(StyleNames[I]);
      with This.Add<TSpinBox>(FStyleBox) do
      begin
        Indent := 1;
        Width := 280;
        Items := Styles;
        ItemIndex := FStyle;
        OnChange := StyleChange;
      end;
      with This.Add<TLabel> do
        Text := 'Card backs:';
      for I := Low(BackNames) to High(BackNames) do
        Backs.Push(BackNames[I]);
      with This.Add<TSpinBox>(FBackBox) do
      begin
        Indent := 1;
        Width := 280;
        Items := Backs;
        ItemIndex := 0;
        OnChange := BackChange;
      end;
      with This.Add<TLabel> do
        Text := 'Table:';
      for I := Low(TableNames) to High(TableNames) do
        Tables.Push(TableNames[I]);
      with This.Add<TSpinBox>(FTableBox) do
      begin
        Indent := 1;
        Width := 280;
        Items := Tables;
        ItemIndex := 0;
        OnChange := TableChange;
      end;
      for I := Low(ThemeNames) to High(ThemeNames) do
        Themes.Push(ThemeNames[I]);
      with This.Add<TLabel> do
        Text := 'Theme:';
      with This.Add<TSpinBox>(FThemeBox) do
      begin
        Indent := 1;
        Width := 280;
        Items := Themes;
        ItemIndex := 0;
        Hint := 'Press and choose a theme for the widgets';
        OnChange := ThemeChange;
      end;
      with This.Add<TCheckBox>(FFullScreenBox) do
      begin
        Indent := 1;
        Text := 'Full screen (F1)';
        Checked := (Host.Window <> nil) and Host.Window.Fullscreen;
        OnChange := FullScreenChange;
      end;
      with This.Add<TLabel> do
        Text := 'Performance:';
      with This.Add<TPerformanceGraph> do
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
    Dialog.Pack;
    Dialog.X := 20;
    Dialog.Y := 20;
  finally
    FChanging := False;
  end;
end;

function TCardsDemoScene.Card(Index: Integer): TCardSprite;
begin
  Result := TCardSprite(FDeck[Index]);
end;

{ The face of a card is seen once it is turned past edge on }

function TCardsDemoScene.FaceUp(Sprite: TCardSprite): Boolean;
begin
  Result := Cos(Sprite.RotY * Pi / 180) < 0;
end;

{ CardMatrix is the projection, view, and model matrix of a card. It turns
  the points of a rectangle one unit wide and high into the view.

  The view is moved back from the table by the distance at which the height
  of the perspective is the height of the scene, so that one unit is one
  pixel on the table and the center of the scene is at zero. Up is positive
  in the view, so the place of a card and its angles are negated.

  Each operation is multiplied on the right. The card is sized, turned over
  about its own center, moved away from its origin, turned about the z axis
  around that origin, and then moved to its place. }

function TCardsDemoScene.CardMatrix(Sprite: TCardSprite): TMatrix4x4;
var
  H: Integer;
  Distance: Float;
begin
  H := Max(Height, 1);
  Distance := H / 2 / Tan(FieldOfView * Pi / 360);
  Result.Perspective(FieldOfView, Width / H, Distance / 10, Distance * 4);
  Result.Translate(0, 0, -Distance);
  Result.Translate(Sprite.X + Sprite.Z * StackShift,
    -(Sprite.Y - Sprite.Z * StackShift), Sprite.Lift * LiftHeight);
  Result.Rotate(0, 0, -(Sprite.RotZ + Sprite.Angle));
  Result.Translate(0, (Sprite.OriginY - 0.5) * CardHeight * Sprite.Scale, 0);
  Result.Rotate(0, Sprite.RotY, 0);
  Result.Scale(CardWidth * Sprite.Scale, CardHeight * Sprite.Scale, 1);
end;

{ ShadowMatrix is the matrix of the shadow of a card. The shadow lies on the
  table behind the cards, a little to the right and below its card, and is
  larger than the card by its margin. A card which is lifted casts its shadow
  further away. The shadow is placed like the card but stays on the table, so
  it narrows as the card turns over. }

function TCardsDemoScene.ShadowMatrix(Sprite: TCardSprite): TMatrix4x4;
var
  H: Integer;
  Distance, Grow: Float;
begin
  H := Max(Height, 1);
  Distance := H / 2 / Tan(FieldOfView * Pi / 360);
  Grow := 1 + ShadowMargin * 2;
  Result.Perspective(FieldOfView, Width / H, Distance / 10, Distance * 4);
  Result.Translate(0, 0, -Distance);
  Result.Translate(Sprite.X + Sprite.Z * StackShift + ShadowOffsetX +
    Sprite.Lift * ShadowLiftX, -(Sprite.Y - Sprite.Z * StackShift + ShadowOffsetY +
    Sprite.Lift * ShadowLiftY), 0);
  Result.Rotate(0, 0, -(Sprite.RotZ + Sprite.Angle));
  Result.Translate(0, (Sprite.OriginY - 0.5) * CardHeight * Sprite.Scale, 0);
  Result.Rotate(0, Sprite.RotY, 0);
  Result.Scale(CardWidth * Sprite.Scale * Grow, CardHeight * Sprite.Scale * Grow, 1);
end;

{ CardContains is true if a point in the scene is over a card. The corners
  of the card are projected into the scene, and the point is inside them if
  it is on the same side of each of the four edges. }

function TCardsDemoScene.CardContains(Sprite: TCardSprite; const P: TPointF): Boolean;
const
  Corners: array[0..3, 0..1] of Float = ((-0.5, -0.5), (0.5, -0.5), (0.5, 0.5), (-0.5, 0.5));
var
  M: TMatrix4x4;
  C: array[0..3] of TVec2;
  Side: Float;
  Positive, Negative: Boolean;
  I, J: Integer;
begin
  Result := False;
  M := CardMatrix(Sprite);
  for I := 0 to 3 do
    if not M.Project(Vec(Corners[I, 0], Corners[I, 1], 0), Width, Height, C[I]) then
      Exit;
  Positive := False;
  Negative := False;
  for I := 0 to 3 do
  begin
    J := (I + 1) mod 4;
    Side := (C[J].X - C[I].X) * (P.Y - C[I].Y) - (C[J].Y - C[I].Y) * (P.X - C[I].X);
    if Side > 0 then
      Positive := True
    else if Side < 0 then
      Negative := True;
  end;
  { A card seen edge on has no sides and cannot contain the point }
  Result := Positive xor Negative;
end;

{ The card at a point in the scene, or nil if there is none. The cards drawn
  last are on top, so they are searched first. }

function TCardsDemoScene.CardAt(const P: TPointF): TCardSprite;
var
  I: Integer;
begin
  for I := FDeck.Count - 1 downto 0 do
  begin
    Result := Card(I);
    if CardContains(Result, P) then
      Exit;
  end;
  Result := nil;
end;

{ The last card in the deck is drawn over the others }

procedure TCardsDemoScene.MoveTop(Sprite: TCardSprite);
begin
  FDeck.Remove(Sprite);
  FDeck.Add(Sprite);
end;

{ Flip turns a card over. The card is lifted for the first half of the turn
  and put down again for the second half. }

procedure TCardsDemoScene.Flip(Sprite: TCardSprite; Span: Double);
var
  Easy: TEasing;
begin
  Easy := Easings['Easy'];
  Sprite.Flipped := not Sprite.Flipped;
  FAnimations.Add(Sprite.Lift, 1, Span / 2, Easy);
  FAnimations.Add(Sprite.Lift, 0, Span / 2, Easy, True);
  if Sprite.Flipped then
    FAnimations.Add(Sprite.RotY, 180, Span, Easy)
  else
    FAnimations.Add(Sprite.RotY, 0, Span, Easy);
end;

{ FlipDeal is called when a card leaves the stack during a deal. The card is
  moved over the cards already dealt and is turned face up. }

procedure TCardsDemoScene.FlipDeal(Sprite: TCardSprite);
begin
  MoveTop(Sprite);
  Flip(Sprite, 0.5);
end;

{ Shuffle mixes the order of the cards and gathers them into a stack with
  their backs showing }

procedure TCardsDemoScene.Shuffle;
const
  Delay = 0.5;
var
  Easy, Boing: TEasing;
  Sprite: TCardSprite;
  I, J: Integer;
begin
  if FStory.Playing then
    Exit;
  Easy := Easings['Easy'];
  Boing := Easings['Boing'];
  FArrangement := arrangeShuffle;
  J := FDeck.Count - 1;
  for I := 0 to J do
    FDeck.Exchange(I, Random(J));
  for I := 0 to J do
  begin
    Sprite := Card(I);
    Sprite.Flipped := True;
    Flip(Sprite, 0.1);
    FStory.Add(Sprite.OriginY, 0.5, 0.2, Easy);
    FStory.Add(Sprite.X, 0, Delay, Boing);
    FStory.Add(Sprite.Y, 0, Delay, Boing);
    FStory.Add(Sprite.RotZ, 0, Delay, Boing);
    FStory.Add(Sprite.Angle, 0, Delay, Boing);
    FStory.Add(Sprite.Z, I * StackRaise, Delay, Boing);
  end;
end;

{ DealFan gathers the cards and then swings them out into a fan. Each card is
  placed far below the center of the scene and is drawn far above its origin,
  so that turning the card swings it around that point. }

procedure TCardsDemoScene.DealFan;
var
  Easy: TEasing;
  Sprite: TCardSprite;
  I: Integer;
begin
  if FStory.Playing then
    Exit;
  Easy := Easings['Easy'];
  FStory.Clear;
  FArrangement := arrangeFan;
  for I := 0 to FDeck.Count - 1 do
  begin
    Sprite := Card(FDeck.Count - I - 1);
    Sprite.Z := 0;
    Sprite.Scale := ScaleNormal;
    FStory.Add(Sprite.RotZ, 0, 0.5, Easy);
    FStory.Add(Sprite.Angle, 0, 0.5, Easy);
    FStory.Add(Sprite.Angle, (51 * FanAngle) / 2 - I * FanAngle, 0.25, Easy, True);
    FStory.Add(Sprite.X, 0, 0.5, Easy);
    FStory.Add(Sprite.Y, 0, 0.5, Easy);
    FStory.Add(Sprite.Y, FanDistance, 0.25, Easy, True);
    FStory.Add(Sprite.OriginY, FanOrigin, 0.25, Easy, False, 0.5);
  end;
end;

{ DealHearts deals the cards one at a time to four players, one on each side
  of the table, with the cards of the players at the sides turned to face
  them. A card is turned face up as it leaves the stack. }

procedure TCardsDemoScene.DealHearts;

  function PointFromIndex(Index: Integer): TPointF;
  const
    Offset = 100;
    BorderH = 300;
    BorderV = 100;
  begin
    Result := NewPointF(0, 0);
    case Index mod 4 of
      0:
        begin
          Result.X := BorderH + (Width - BorderH * 2) / 12 * (Index div 4);
          Result.Y := Offset;
        end;
      1:
        begin
          Result.X := Width - Offset;
          Result.Y := BorderV + (Height - BorderV * 2) / 12 * (Index div 4);
        end;
      2:
        begin
          Result.X := BorderH + (Width - BorderH * 2) / 12 * (Index div 4);
          Result.Y := Height - Offset;
        end;
      3:
        begin
          Result.X := Offset;
          Result.Y := BorderV + (Height - BorderV * 2) / 12 * (Index div 4);
        end;
    end;
    Result.X := Round(Result.X - Width / 2);
    Result.Y := Round(Result.Y - Height / 2);
  end;

  function RotationFromIndex(Index: Integer): Float;
  begin
    case Index mod 4 of
      1: Result := -90;
      3: Result := 90;
    else
      Result := 0;
    end;
  end;

const
  Delay = 0.05;
  FlipDelay = 0.1;
var
  Easy: TEasing;
  Sprite: TCardSprite;
  P: TPointF;
  I: Integer;
begin
  if FStory.Playing then
    Exit;
  Easy := Easings['Easy'];
  FStory.Clear;
  FArrangement := arrangeHearts;
  for I := 0 to FDeck.Count - 1 do
  begin
    Sprite := Card(FDeck.Count - I - 1);
    Sprite.Flipped := False;
    P := PointFromIndex(I);
    FStory.Add(Sprite.OriginY, 0.5, 0.2, Easy);
    FStory.Add(Sprite.Angle, 0, 0.2, Easy);
    FStory.Add(Sprite.X, I * StackDelta, I * Delay, Easy);
    FStory.Add(Sprite.Y, -I * StackDelta, I * Delay, Easy);
    FStory.Add(Sprite.X, P.X, 0.7, Easy, True);
    FStory.Add(Sprite.Y, P.Y, 0.7, Easy, True);
    FStory.Add(Sprite.RotZ, 0, I * Delay + FlipDelay, Easy, False, 0, Sprite);
    FStory.Add(Sprite.RotZ, RotationFromIndex(I), 0.7, Easy, True);
  end;
end;

{ DealRows deals the cards one at a time into four rows of thirteen. A card
  is turned face up as it leaves the stack. }

procedure TCardsDemoScene.DealRows;

  function PointFromIndex(Index: Integer): TPointF;
  const
    BorderH = 100;
    BorderV = 100;
  begin
    Result.X := BorderH + (Width - BorderH * 2) / 12 * (Index mod 13);
    Result.Y := BorderH + (Height - BorderV * 2) / 3 * (Index div 13);
    Result.X := Round(Result.X - Width / 2);
    Result.Y := Round(Result.Y - Height / 2);
  end;

const
  Delay = 0.05;
  FlipDelay = 0.1;
var
  Easy: TEasing;
  Sprite: TCardSprite;
  P: TPointF;
  I: Integer;
begin
  if FStory.Playing then
    Exit;
  Easy := Easings['Easy'];
  FStory.Clear;
  FArrangement := arrangeRows;
  for I := 0 to FDeck.Count - 1 do
  begin
    Sprite := Card(FDeck.Count - I - 1);
    Sprite.Flipped := False;
    P := PointFromIndex(I);
    FStory.Add(Sprite.OriginY, 0.5, 0.2, Easy);
    FStory.Add(Sprite.Angle, 0, 0.2, Easy);
    FStory.Add(Sprite.X, I * StackDelta, I * Delay, Easy);
    FStory.Add(Sprite.Y, -I * StackDelta, I * Delay, Easy);
    FStory.Add(Sprite.X, P.X, 0.7, Easy, True);
    FStory.Add(Sprite.Y, P.Y, 0.7, Easy, True);
    FStory.Add(Sprite.RotZ, 0, I * Delay + FlipDelay, Easy, False, 0, Sprite);
  end;
end;

{ DealFlip turns every card over, one after the other }

procedure TCardsDemoScene.DealFlip;
const
  Delay = 0.01;
var
  Easy: TEasing;
  Sprite: TCardSprite;
  I: Integer;
begin
  if FStory.Playing then
    Exit;
  Easy := Easings['Easy'];
  FStory.Clear;
  for I := 0 to FDeck.Count - 1 do
  begin
    Sprite := Card(FDeck.Count - I - 1);
    Sprite.Flipped := Sprite.RotY <= 90;
    if Sprite.Flipped then
      FStory.Add(Sprite.RotY, 180, I * Delay, Easy)
    else
      FStory.Add(Sprite.RotY, 0, I * Delay, Easy);
  end;
end;

procedure TCardsDemoScene.NextStyle;
begin
  FStyle := (FStyle + 1) mod StyleCount;
  FChanging := True;
  try
    FStyleBox.ItemIndex := FStyle;
  finally
    FChanging := False;
  end;
end;

{ HotChange makes a card the card under the mouse, or no card if it is nil.
  The card which was under the mouse shrinks back, or drops back into the
  fan, and its name is hidden. The new card grows, or rises from the fan,
  and its name is shown if it is face up. }

procedure TCardsDemoScene.HotChange(Sprite: TCardSprite);
const
  Span = 0.2;
var
  Easy, Extend: TEasing;
begin
  if Sprite = FHot then
    Exit;
  Easy := Easings['Easy'];
  Extend := Easings['Extend'];
  if FHot <> nil then
  begin
    FAnimations.Remove(FTipAlpha);
    FTipAlpha := 0;
    if FArrangement = arrangeFan then
      FAnimations.Add(FHot.OriginY, FanOrigin, Span, Easy)
    else
      FAnimations.Add(FHot.Scale, ScaleNormal, Span, Extend);
  end;
  FHot := Sprite;
  if FHot = nil then
    Exit;
  if FArrangement = arrangeFan then
    FAnimations.Add(FHot.OriginY, FanOriginHot, Span, Easy)
  else
    FAnimations.Add(FHot.Scale, ScaleHot, Span, Extend);
  if FaceUp(FHot) then
  begin
    FTipText := FHot.Name;
    FAnimations.Add(FTipAlpha, 1, 0.25, Easy);
  end;
end;

{ HotTrack makes the card under the mouse hot. No card is hot while the cards
  are being dealt, and the hot card is not changed while a card is dragged. }

procedure TCardsDemoScene.HotTrack;
begin
  if FDrag <> nil then
    Exit;
  if FStory.Playing or (not FMouseOver) then
    HotChange(nil)
  else
    HotChange(CardAt(FMouse));
end;

{ The table image is scaled to cover the scene and centered }

procedure TCardsDemoScene.DrawTable;
var
  Scale, W, H: Float;
begin
  if (FTable = nil) or (FTable.Width = 0) or (FTable.Height = 0) then
    Exit;
  Scale := Width / FTable.Width;
  if Height / FTable.Height > Scale then
    Scale := Height / FTable.Height;
  W := FTable.Width * Scale;
  H := FTable.Height * Scale;
  Canvas.DrawImage(FTable, FTable.ClientRect,
    NewRectF((Width - W) / 2, (Height - H) / 2, W, H));
end;

{ The shadows of all of the cards are drawn first, behind every card, so a
  shadow only darkens the table and never another card.

  Shadows overlap where cards overlap, and fifty two of them in a stack would
  add up to a black edge. The stencil buffer is used to stop that. A shadow
  is only drawn where no shadow has been drawn yet, so each part of the
  table is darkened once. The shadows are drawn in passes, the darkest parts
  of every shadow first and the faintest parts last, so that where shadows
  overlap the darker one is kept.

  The canvas also uses the stencil buffer, so it is cleared when the shadows
  are done. }

procedure TCardsDemoScene.DrawShadows;
const
  { The alpha of the shadow texture below which each pass draws nothing }
  Passes: array[0..3] of Float = (0.75, 0.5, 0.25, 0.02);
var
  Sprite: TCardSprite;
  I, J: Integer;
begin
  glClear(GL_STENCIL_BUFFER_BIT);
  glEnable(GL_STENCIL_TEST);
  glStencilFunc(GL_EQUAL, 0, $FF);
  glStencilOp(GL_KEEP, GL_KEEP, GL_INCR);
  FShadow.Push;
  for J := Low(Passes) to High(Passes) do
  begin
    Ctx.SetUniform(FCutoffLocation, Passes[J]);
    for I := 0 to FDeck.Count - 1 do
    begin
      Sprite := Card(I);
      { A shadow is lighter while its card is lifted, as a shadow spreads
        out when its card is further from the table }
      Ctx.SetUniform(FMatrixLocation, ShadowMatrix(Sprite));
      Ctx.SetUniform(FTintLocation, 1, 1, 1, ShadowAlpha * (1 - Sprite.Lift * 0.4));
      FBackQuad.Draw;
    end;
  end;
  FShadow.Pop;
  glDisable(GL_STENCIL_TEST);
  glStencilFunc(GL_ALWAYS, 0, $FF);
  glStencilOp(GL_KEEP, GL_KEEP, GL_KEEP);
  glClear(GL_STENCIL_BUFFER_BIT);
end;

{ The cards are drawn from the bottom of the deck to the top without a depth
  test, so a card later in the deck covers the cards before it wherever it
  is. A card is seen from both sides, so faces are not culled, and the corners
  of the card images are clear, so the cards are blended.

  The canvas changes some of this state when it draws, so it is set here
  each frame and the state the render context expects is put back after. }

procedure TCardsDemoScene.DrawCards;
var
  Sprite: TCardSprite;
  Texture: TTexture;
  Quad: TTexVertexBuffer;
  I: Integer;
begin
  glViewport(0, 0, Width, Max(Height, 1));
  glDisable(GL_DEPTH_TEST);
  glDisable(GL_CULL_FACE);
  glEnable(GL_BLEND);
  FProgram.Push;
  DrawShadows;
  { The buffer activates the program again while drawing, so the uniforms
    set here stay in effect }
  Ctx.SetUniform(FTintLocation, 1, 1, 1, 1);
  Ctx.SetUniform(FCutoffLocation, 0.004);
  for I := 0 to FDeck.Count - 1 do
  begin
    Sprite := Card(I);
    if FaceUp(Sprite) then
    begin
      Texture := FaceTexture(Sprite);
      Quad := FFaceQuad;
    end
    else
    begin
      Texture := BackTexture;
      Quad := FBackQuad;
    end;
    Ctx.SetUniform(FMatrixLocation, CardMatrix(Sprite));
    Texture.Push;
    Quad.Draw;
    Texture.Pop;
  end;
  FProgram.Pop;
  glEnable(GL_CULL_FACE);
  glEnable(GL_DEPTH_TEST);
end;

{ The name of the hot card is drawn in a rounded box above the card, or below
  it if the box would be above the top of the scene. The box is placed from
  the top of the card as it is seen in the scene, so it follows a card which
  is turned in a fan. }

procedure TCardsDemoScene.DrawTip;
const
  Pad = 8;
  Space = 26;
  BoxHeight = 30;
var
  M: TMatrix4x4;
  P: TVec2;
  S, W: Float;
begin
  if (FHot = nil) or (FTipAlpha <= 0) or (Font = nil) then
    Exit;
  M := CardMatrix(FHot);
  { The space above the card as a part of the height of the card }
  S := 0.5 + Space / (CardHeight * FHot.Scale);
  if not M.Project(Vec(0, S, 0), Width, Height, P) then
    Exit;
  if P.Y < BoxHeight then
    if not M.Project(Vec(0, -S, 0), Width, Height, P) then
      Exit;
  Font.Size := 17;
  Font.Align := fontCenter;
  Font.Layout := fontMiddle;
  W := Canvas.MeasureText(Font, FTipText).X + Pad * 2;
  if P.X < W / 2 + Pad then
    P.X := W / 2 + Pad
  else if P.X > Width - W / 2 - Pad then
    P.X := Width - W / 2 - Pad;
  Canvas.RoundRect(P.X - W / 2, P.Y - BoxHeight / 2, W, BoxHeight, 6);
  Canvas.Fill(NewColorF(1, 1, 0.85, FTipAlpha));
  Font.Color := NewColorF(0, 0, 0, FTipAlpha);
  Canvas.DrawText(Font, FTipText, P.X, P.Y);
end;

{ The edges of the scene are darkened by a radial brush which is clear in the
  middle. The brush is made taller and shorter over time, which moves the
  darkness in and out at the top and bottom of the scene. }

procedure TCardsDemoScene.DrawVignette;
var
  H: Float;
begin
  H := Height * (1.6 + 0.3 * Sin(Time * Pi / 4));
  FVignette.Rect := NewRectF(-Width * 0.3, (Height - H) / 2, Width * 1.6, H);
  Canvas.Rect(0, 0, Width, Height);
  Canvas.Fill(FVignette);
end;

procedure TCardsDemoScene.DealClick(Sender: TObject);
begin
  case (Sender as TWidget).Tag of
    TagShuffle: Shuffle;
    TagRows: DealRows;
    TagHearts: DealHearts;
    TagFan: DealFan;
    TagFlip: DealFlip;
  end;
end;

procedure TCardsDemoScene.StyleChange(Sender: TObject);
begin
  if FChanging or (FStyleBox.ItemIndex < 0) then
    Exit;
  FStyle := FStyleBox.ItemIndex;
end;

procedure TCardsDemoScene.BackChange(Sender: TObject);
begin
  if (not FChanging) and (FBackBox.ItemIndex > -1) then
    FBack := FBackBox.ItemIndex;
end;

procedure TCardsDemoScene.TableChange(Sender: TObject);
begin
  if not FChanging then
    LoadTable(FTableBox.ItemIndex);
end;

procedure TCardsDemoScene.ThemeChange(Sender: TObject);
begin
  if FChanging or (FThemeBox.ItemIndex < 0) then
    Exit;
  Widget.Theme := FThemes[FThemeBox.ItemIndex];
end;

{ The window is the form holding the graphics box with the LCL or the SDL
  window with the SDL application }

procedure TCardsDemoScene.FullScreenChange(Sender: TObject);
begin
  if FChanging then
    Exit;
  if Host.Window <> nil then
    Host.Window.Fullscreen := (Sender as TCheckBox).Checked;
end;

{ The window can enter or leave full screen without the check box, such as
  when F1 is pressed, so the check box is made to match the window }

procedure TCardsDemoScene.FullScreenSync;
var
  Value: Boolean;
begin
  if (Host.Window = nil) or (FFullScreenBox = nil) then
    Exit;
  Value := Host.Window.Fullscreen;
  if FFullScreenBox.Checked = Value then
    Exit;
  FChanging := True;
  try
    FFullScreenBox.Checked := Value;
  finally
    FChanging := False;
  end;
end;

procedure TCardsDemoScene.CloseClick(Sender: TObject);
begin
  if Host.Window <> nil then
    Host.Window.Close;
end;

procedure TCardsDemoScene.Render;
var
  Buffer: IBackBuffer;
begin
  inherited Render;
  { The animations are stepped first so a card told to turn over by the story
    begins its turn at the time of this frame }
  FAnimations.Step(Time);
  FStory.Step(Time);
  DealSound;
  HotTrack;
  FullScreenSync;
  { The table is drawn in a canvas frame, the cards are drawn over it in
    three dimensions, and the name of a card and the darkened edges are drawn
    over the cards in a second canvas frame, under the widgets }
  Buffer := Canvas as IBackBuffer;
  Buffer.Flip(Width, Height);
  try
    DrawTable;
  finally
    Buffer.Flip(Width, Height);
  end;
  DrawCards;
  Buffer.Flip(Width, Height);
  try
    DrawTip;
    DrawVignette;
  finally
    Buffer.Flip(Width, Height);
  end;
  WidgetsRender;
end;

procedure TCardsDemoScene.DoKeyDown(var Args: TSceneKeyArgs);
begin
  inherited DoKeyDown(Args);
  if Args.Handled then
    Exit;
  case Args.Key of
    { F1 is handled here so it works the same with the LCL and with SDL. The
      check box follows the window in FullScreenSync. }
    VK_F1:
      if Host.Window <> nil then
        Host.Window.Fullscreen := not Host.Window.Fullscreen;
    VK_F5: Shuffle;
    VK_F6: DealRows;
    VK_F7: DealHearts;
    VK_F8: DealFan;
    VK_F9: DealFlip;
    VK_F10: NextStyle;
  else
    Exit;
  end;
  Args.Handled := True;
end;

{ Pressing the left button on the hot card begins dragging it, and moves it
  over the other cards }

procedure TCardsDemoScene.DoMouseDown(var Args: TSceneMouseArgs);
begin
  inherited DoMouseDown(Args);
  if Args.Handled or (Args.Button <> buttonLeft) or (FHot = nil) then
    Exit;
  FDrag := FHot;
  MoveTop(FDrag);
  FMouse := NewPointF(Args.X, Args.Y);
  Args.Handled := True;
end;

procedure TCardsDemoScene.DoMouseMove(var Args: TSceneMouseArgs);
begin
  inherited DoMouseMove(Args);
  FMouseOver := not Args.Handled;
  if FDrag <> nil then
  begin
    FDrag.X := FDrag.X + Args.X - FMouse.X;
    FDrag.Y := FDrag.Y + Args.Y - FMouse.Y;
  end;
  FMouse := NewPointF(Args.X, Args.Y);
end;

{ A card which was turned when it was dealt is turned upright when it is
  dropped, except in a fan }

procedure TCardsDemoScene.DoMouseUp(var Args: TSceneMouseArgs);
begin
  inherited DoMouseUp(Args);
  if (FDrag = nil) or (Args.Button <> buttonLeft) then
    Exit;
  if FArrangement <> arrangeFan then
    FAnimations.Add(FDrag.RotZ, 0, 0.2, Easings['Extend']);
  FDrag := nil;
end;

end.
