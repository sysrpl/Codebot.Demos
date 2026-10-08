unit ChaseScene;

{$mode delphi}

interface

{ TChaseScene shows a skinned model playing animations with a shadow cast on
  the ground. A panel on the left lists the animations found in the assets
  folder, and choosing one plays it from the start.

  Drag with the left mouse button to orbit the camera and turn the mouse wheel
  to move it closer or farther. }

uses
  Classes, SysUtils, Math,
  Codebot.System,
  Codebot.Geometry,
  Codebot.OpenGL,
  Codebot.Render.Contexts,
  Codebot.Render.Shaders,
  Codebot.Render.Buffers,
  Codebot.Hardware,
  Codebot.Render.Scenes,
  Codebot.Render.Widgets,
  Codebot.Render.Widgets.Custom,
  Codebot.Render.Scenes.Widgets,
  SkinnedModel;

type
  TChaseScene = class(TWidgetScene)
  private
    FProgram: TShaderProgram;
    FShadowProgram: TShaderProgram;
    FGroundProgram: TShaderProgram;
    FModel: TSkinnedModel;
    FShadow: TShadowBuffer;
    FGround: TVertexBuffer;
    { Uniform locations of the model program }
    FBones: Integer;
    FModelMatrix: Integer;
    FLightMatrix: Integer;
    FLightDir: Integer;
    { Uniform locations of the shadow and ground programs }
    FShadowBones: Integer;
    FGroundLightMatrix: Integer;
    { Uniform locations which turn the shadows on and off }
    FShadowsOn: Integer;
    FGroundShadowsOn: Integer;
    FShadowsButton: TGlyphButton;
    { The world matrix which scales the model and stands it on the ground }
    FWorld: TMatrix4x4;
    { The height of the point the camera orbits }
    FFocus: Float;
    { The matrix from world space to light clip space }
    FLight: TMatrix4x4;
    FLightView: TMatrix4x4;
    FLightProjection: TMatrix4x4;
    FYaw: Single;
    FPitch: Single;
    FDistance: Single;
    FDragging: Boolean;
    { The time the current animation started }
    FStart: Double;
    { The file of each item in the animation list, empty for the rest pose }
    FAnimationFiles: TStringList;
    FPanel: TWindow;
    FList: TListBox;
    FFullscreen: TGlyphButton;
    FStats: TPerformanceGraph;
    procedure BuildPanel;
    procedure BuildStats;
    procedure LayoutPanel;
    procedure UpdateLight;
    procedure UpdateFullscreenButton;
    procedure AnimationChange(Sender: TObject);
    procedure FullscreenClick(Sender: TObject);
    procedure ExitClick(Sender: TObject);
    procedure ShadowsClick(Sender: TObject);
  public
    procedure Initialize; override;
    procedure Finalize; override;
    procedure Render; override;
    procedure DoMouseDown(var Args: TSceneMouseArgs); override;
    procedure DoMouseMove(var Args: TSceneMouseArgs); override;
    procedure DoMouseUp(var Args: TSceneMouseArgs); override;
    procedure DoMouseWheel(var Args: TSceneWheelArgs); override;
  end;

implementation

{ The model program draws the skinned model lit by the light with shadows
  from the shadow map. The shadow program draws the model from the light into
  the shadow map. The ground program draws a grid fading out at the edges with
  the shadow of the model. A #version line matching render.inc is added when
  the shaders are compiled. }

{ On the Raspberry Pi the shaders are compiled as OpenGL ES, where sampler2DShadow
  has no default precision and must be given one.

  The shadow map is filtered, so each texture lookup compares four texels and
  blends the results. Elsewhere the shadow is softened by nine lookups a texel
  apart. The Raspberry Pi has too little fill rate for that at 1080p, so it
  uses four lookups half a texel apart, which covers the same area with a
  little less softening. }

const
{$if defined(linux) and (defined(cpuarm) or defined(cpuaarch64))}
  ShadowPrecision = 'precision highp sampler2DShadow;'#10;
  ShadowSamples =
    '  float lit = 0.0;'#10 +
    '  for (int x = 0; x < 2; x++)'#10 +
    '    for (int y = 0; y < 2; y++)'#10 +
    '      lit += texture(shadowMap, vec3(p.xy + (vec2(x, y) - 0.5) * texel, p.z));'#10 +
    '  return lit / 4.0;'#10;
{$else}
  ShadowPrecision = '';
  ShadowSamples =
    '  float lit = 0.0;'#10 +
    '  for (int x = -1; x <= 1; x++)'#10 +
    '    for (int y = -1; y <= 1; y++)'#10 +
    '      lit += texture(shadowMap, vec3(p.xy + vec2(x, y) * texel, p.z));'#10 +
    '  return lit / 9.0;'#10;
{$endif}

  ModelVertexShader =
    'uniform mat4 projection;'#10 +
    'uniform mat4 modelview;'#10 +
    'uniform mat4 model;'#10 +
    'uniform mat4 light;'#10 +
    'uniform mat4 bones[64];'#10 +
    #10 +
    'layout(location = 0) in vec3 xyz;'#10 +
    'layout(location = 1) in vec3 normal;'#10 +
    'layout(location = 2) in vec2 uv;'#10 +
    'layout(location = 3) in vec4 bone;'#10 +
    'layout(location = 4) in vec4 weight;'#10 +
    #10 +
    'out vec2 coord;'#10 +
    'out vec3 worldNormal;'#10 +
    'out vec4 shadowCoord;'#10 +
    #10 +
    'void main() {'#10 +
    '  mat4 skin = bones[int(bone.x)] * weight.x + bones[int(bone.y)] * weight.y +'#10 +
    '    bones[int(bone.z)] * weight.z + bones[int(bone.w)] * weight.w;'#10 +
    '  if (weight.x + weight.y + weight.z + weight.w < 0.0001)'#10 +
    '    skin = mat4(1.0);'#10 +
    '  vec4 position = skin * vec4(xyz, 1.0);'#10 +
    '  worldNormal = mat3(model * skin) * normal;'#10 +
    '  shadowCoord = light * model * position;'#10 +
    '  coord = uv;'#10 +
    '  gl_Position = projection * modelview * position;'#10 +
    '}'#10;

  ModelFragmentShader =
    'uniform sampler2D tex;'#10 +
    ShadowPrecision +
    'uniform sampler2DShadow shadowMap;'#10 +
    'uniform bool shadows;'#10 +
    'uniform vec3 lightDir;'#10 +
    #10 +
    'in vec2 coord;'#10 +
    'in vec3 worldNormal;'#10 +
    'in vec4 shadowCoord;'#10 +
    'out vec4 fragColor;'#10 +
    #10 +
    'float shadow(vec4 c) {'#10 +
    '  if (!shadows)'#10 +
    '    return 1.0;'#10 +
    '  vec3 p = c.xyz / c.w * 0.5 + 0.5;'#10 +
    '  if (p.x < 0.0 || p.x > 1.0 || p.y < 0.0 || p.y > 1.0 || p.z > 1.0)'#10 +
    '    return 1.0;'#10 +
    '  vec2 texel = 1.0 / vec2(textureSize(shadowMap, 0));'#10 +
    ShadowSamples +
    '}'#10 +
    #10 +
    'void main() {'#10 +
    '  float diffuse = max(dot(normalize(worldNormal), lightDir), 0.0);'#10 +
    '  vec4 color = texture(tex, coord);'#10 +
    '  fragColor = vec4(color.rgb * (0.35 + 0.65 * diffuse * shadow(shadowCoord)), color.a);'#10 +
    '}'#10;

  ShadowVertexShader =
    'uniform mat4 projection;'#10 +
    'uniform mat4 modelview;'#10 +
    'uniform mat4 bones[64];'#10 +
    #10 +
    'layout(location = 0) in vec3 xyz;'#10 +
    'layout(location = 1) in vec3 normal;'#10 +
    'layout(location = 2) in vec2 uv;'#10 +
    'layout(location = 3) in vec4 bone;'#10 +
    'layout(location = 4) in vec4 weight;'#10 +
    #10 +
    'void main() {'#10 +
    '  mat4 skin = bones[int(bone.x)] * weight.x + bones[int(bone.y)] * weight.y +'#10 +
    '    bones[int(bone.z)] * weight.z + bones[int(bone.w)] * weight.w;'#10 +
    '  if (weight.x + weight.y + weight.z + weight.w < 0.0001)'#10 +
    '    skin = mat4(1.0);'#10 +
    '  gl_Position = projection * modelview * skin * vec4(xyz, 1.0);'#10 +
    '}'#10;

  ShadowFragmentShader =
    'out vec4 fragColor;'#10 +
    #10 +
    'void main() {'#10 +
    '  fragColor = vec4(1.0);'#10 +
    '}'#10;

  GroundVertexShader =
    'uniform mat4 projection;'#10 +
    'uniform mat4 modelview;'#10 +
    'uniform mat4 light;'#10 +
    #10 +
    'layout(location = 0) in vec3 xyz;'#10 +
    #10 +
    'out vec3 world;'#10 +
    'out vec4 shadowCoord;'#10 +
    #10 +
    'void main() {'#10 +
    '  world = xyz;'#10 +
    '  shadowCoord = light * vec4(xyz, 1.0);'#10 +
    '  gl_Position = projection * modelview * vec4(xyz, 1.0);'#10 +
    '}'#10;

  GroundFragmentShader =
    ShadowPrecision +
    'uniform sampler2DShadow shadowMap;'#10 +
    'uniform bool shadows;'#10 +
    #10 +
    'in vec3 world;'#10 +
    'in vec4 shadowCoord;'#10 +
    'out vec4 fragColor;'#10 +
    #10 +
    'float shadow(vec4 c) {'#10 +
    '  if (!shadows)'#10 +
    '    return 1.0;'#10 +
    '  vec3 p = c.xyz / c.w * 0.5 + 0.5;'#10 +
    '  if (p.x < 0.0 || p.x > 1.0 || p.y < 0.0 || p.y > 1.0 || p.z > 1.0)'#10 +
    '    return 1.0;'#10 +
    '  vec2 texel = 1.0 / vec2(textureSize(shadowMap, 0));'#10 +
    ShadowSamples +
    '}'#10 +
    #10 +
    'float grid(float spacing, float width) {'#10 +
    '  vec2 c = world.xz / spacing;'#10 +
    '  vec2 g = abs(fract(c - 0.5) - 0.5) / fwidth(c);'#10 +
    '  return 1.0 - min(min(g.x, g.y) / width, 1.0);'#10 +
    '}'#10 +
    #10 +
    'void main() {'#10 +
    '  vec3 base = vec3(0.30, 0.31, 0.36);'#10 +
    '  vec3 line = vec3(0.55, 0.57, 0.65);'#10 +
    '  float lines = max(grid(0.25, 1.0) * 0.5, grid(1.0, 1.5));'#10 +
    '  vec3 color = mix(base, line, lines) * mix(0.45, 1.0, shadow(shadowCoord));'#10 +
    '  float fade = 1.0 - smoothstep(5.0, 8.0, length(world.xz));'#10 +
    '  fragColor = vec4(color, fade);'#10 +
    '}'#10;

const
  ModelName = 'models/boy.fbx';
  AnimationFolder = 'animations';
  RestPoseName = 'T-pose';
  { The model is scaled to fit inside a sphere of this radius }
  ModelSize = 1;
  MinDistance = 1.2;
  MaxDistance = 20;
  DefaultDistance = 3;
  { The width of the animation list and the space around the panel }
  ListWidth = 220;
  PanelMargin = 10;
  { Material design icons for the buttons above the list }
  GlyphFullscreen = #$F3#$B0#$8A#$93;
  GlyphFullscreenExit = #$F3#$B0#$8A#$94;
  GlyphExit = #$F3#$B0#$85#$9A;
  GlyphShadows = #$F3#$B0#$98#$B7;

{ The assets folder is looked for next to the program and then in the
  current folder }

function AssetsFolder: string;
begin
  Result := ExtractFilePath(ParamStr(0)) + 'assets';
  if not DirectoryExists(Result) then
    Result := ExpandFileName('assets');
  Result := IncludeTrailingPathDelimiter(Result);
end;

function CreateProgram(const Name, VertSource, FragSource: string): TShaderProgram;
begin
  Result := TShaderProgram.CreateFromSource(VertSource, FragSource);
  if not Result.Valid then
    raise Exception.Create(Name + ' shader: ' + Result.ErrorString);
end;

function Uniform(Prog: TShaderProgram; const Name: string): Integer;
begin
  Ctx.GetUniform(Prog.Handle, Name, Result);
end;

{ The direction pointing toward the light in world space }

function LightDirection: TVec3;
begin
  Result := Vec3(0.5, 1, 0.6);
  Result.Normalize;
end;

{ TChaseScene }

procedure TChaseScene.Initialize;
const
  GroundSize = 8;
var
  Size, ModelHeight: Float;
begin
  inherited Initialize;
  FDistance := DefaultDistance;
  FProgram := CreateProgram('model', ModelVertexShader, ModelFragmentShader);
  FShadowProgram := CreateProgram('shadow', ShadowVertexShader, ShadowFragmentShader);
  FGroundProgram := CreateProgram('ground', GroundVertexShader, GroundFragmentShader);
  FBones := Uniform(FProgram, 'bones');
  FModelMatrix := Uniform(FProgram, 'model');
  FLightMatrix := Uniform(FProgram, 'light');
  FLightDir := Uniform(FProgram, 'lightDir');
  FShadowBones := Uniform(FShadowProgram, 'bones');
  FGroundLightMatrix := Uniform(FGroundProgram, 'light');
  FShadowsOn := Uniform(FProgram, 'shadows');
  FGroundShadowsOn := Uniform(FGroundProgram, 'shadows');
  { The diffuse texture is in slot 0 and the shadow map is in slot 1 }
  FProgram.Push;
  Ctx.SetUniform(Uniform(FProgram, 'tex'), 0);
  Ctx.SetUniform(Uniform(FProgram, 'shadowMap'), 1);
  FProgram.Pop;
  FGroundProgram.Push;
  Ctx.SetUniform(Uniform(FGroundProgram, 'shadowMap'), 1);
  FGroundProgram.Pop;
  { Loading the model and its embedded textures can take a few seconds }
  FModel := TSkinnedModel.Create(AssetsFolder + ModelName);
  { The world matrix scales the model to fit and stands it on the ground at
    the origin }
  Size := ModelSize / FModel.Radius;
  FWorld.Identity;
  FWorld.Scale(Size, Size, Size);
  FWorld.Translate(-FModel.Center.X, -FModel.Bottom, -FModel.Center.Z);
  ModelHeight := (FModel.Center.Y - FModel.Bottom) * Size * 2;
  { The ground is a square at a height of 0 }
  FGround := TVertexBuffer.Create;
  FGround.SetProgram(FGroundProgram.Handle);
  FGround.BeginBuffer(vertTriangles, 6);
  FGround.Add(-GroundSize, 0, -GroundSize).Add(-GroundSize, 0, GroundSize).Add(GroundSize, 0, GroundSize);
  FGround.Add(-GroundSize, 0, -GroundSize).Add(GroundSize, 0, GroundSize).Add(GroundSize, 0, -GroundSize);
  FGround.EndBuffer;
  FFocus := ModelHeight / 2;
  FLightProjection.Ortho(-2.5, 2.5, 2.5, -2.5, 0.5, 10);
  FShadow := TShadowBuffer.Create(2048);
  FAnimationFiles := TStringList.Create;
  BuildPanel;
  BuildStats;
  FStart := Time;
end;

procedure TChaseScene.Finalize;
begin
  FAnimationFiles.Free;
  FShadow.Free;
  FGround.Free;
  FModel.Free;
  FGroundProgram.Free;
  FShadowProgram.Free;
  FProgram.Free;
  inherited Finalize;
end;

{ The panel is a window on the left side of the scene, sector 4, holding a
  row with the shadows, fullscreen, and exit buttons on the right above a list of the rest pose and
  the animation files }

procedure TChaseScene.BuildPanel;
var
  Folder: string;
  Names: TStringList;
  Search: TSearchRec;
  Items: StringArray;
  I: Integer;
begin
  Folder := AssetsFolder + AnimationFolder + PathDelim;
  Names := TStringList.Create;
  try
    if FindFirst(Folder + '*.fbx', faAnyFile, Search) = 0 then
    try
      repeat
        Names.Add(Search.Name);
      until FindNext(Search) <> 0;
    finally
      FindClose(Search);
    end;
    Names.Sort;
    Items.Push(RestPoseName);
    FAnimationFiles.Add('');
    for I := 0 to Names.Count - 1 do
    begin
      Items.Push(ChangeFileExt(Names[I], ''));
      FAnimationFiles.Add(Folder + Names[I]);
    end;
  finally
    Names.Free;
  end;
  FPanel := Widget.Add<TWindow>;
  FPanel.Text := 'Animations';
  FPanel.CloseButton := False;
  FPanel.Sector := 4;
  FPanel.Margin := PanelMargin;
  with FPanel.Add<THBox> do
  begin
    Align := alignFar;
    Margin := 0;
    with This.Add<TGlyphButton>(FShadowsButton) do
    begin
      CanToggle := True;
      Down := True;
      Text := GlyphShadows;
      Hint := 'Turn the shadows off';
      OnClick := ShadowsClick;
    end;
    with This.Add<TGlyphButton>(FFullscreen) do
    begin
      CanToggle := True;
      Down := (Host.Window <> nil) and Host.Window.Fullscreen;
      OnClick := FullscreenClick;
    end;
    with This.Add<TGlyphButton> do
    begin
      Text := GlyphExit;
      Hint := 'Exit this program';
      OnClick := ExitClick;
    end;
  end;
  UpdateFullscreenButton;
  FList := FPanel.Add<TListBox>;
  FList.Width := ListWidth;
  FList.Items := Items;
  FList.ItemIndex := 0;
  FList.OnChange := AnimationChange;
  LayoutPanel;
end;

{ The list is made as tall as the scene allows, so the panel fills the left
  side. The panel height is the list height plus its title and borders. }

procedure TChaseScene.LayoutPanel;
var
  Extra: Float;
begin
  Extra := FPanel.Height - FList.Height;
  if Extra < 0 then
    Extra := 0;
  FList.Height := Max(80, Height - PanelMargin * 2 - Extra);
end;

{ The performance graph is pinned to the top of the scene, sector 2, in a
  faded box like the one in the mega demo, and is always visible }

procedure TChaseScene.BuildStats;
begin
  with Widget.Add<THBox> do
  begin
    Sector := 2;
    Margin := -5;
    Fade := 0.15;
    with This.Add<TPerformanceGraph>(FStats) do
    begin
      Width := 500;
      Height := 50;
      Margin := 5;
    end;
  end;
end;

{ The fullscreen button shows the glyph of the mode it switches to. F1 also
  toggles fullscreen in the SDL application, so the button follows the window
  each frame. }

procedure TChaseScene.UpdateFullscreenButton;
var
  Full: Boolean;
begin
  Full := (Host.Window <> nil) and Host.Window.Fullscreen;
  if FFullscreen.Down <> Full then
    FFullscreen.Down := Full;
  if Full then
  begin
    FFullscreen.Text := GlyphFullscreenExit;
    FFullscreen.Hint := 'Switch to windowed mode';
  end
  else
  begin
    FFullscreen.Text := GlyphFullscreen;
    FFullscreen.Hint := 'Switch to fullscreen mode';
  end;
end;

procedure TChaseScene.FullscreenClick(Sender: TObject);
begin
  if Host.Window <> nil then
    Host.Window.Fullscreen := FFullscreen.Down;
  UpdateFullscreenButton;
end;

{ When the shadows are off the shadow map is not drawn and the shaders treat
  everything as lit }

procedure TChaseScene.ShadowsClick(Sender: TObject);
begin
  if FShadowsButton.Down then
    FShadowsButton.Hint := 'Turn the shadows off'
  else
    FShadowsButton.Hint := 'Turn the shadows on';
end;

procedure TChaseScene.ExitClick(Sender: TObject);
begin
  if Host.Window <> nil then
    Host.Window.Close;
end;

{ Choosing an animation plays it from the start. A file which cannot be loaded
  returns the model to its rest pose and shows the error in the title of the
  window. }

procedure TChaseScene.AnimationChange(Sender: TObject);
var
  I: Integer;
begin
  I := FList.ItemIndex;
  if (I < 0) or (I >= FAnimationFiles.Count) then
    Exit;
  try
    if FAnimationFiles[I] = '' then
      FModel.ClearAnimation
    else
      FModel.LoadAnimation(FAnimationFiles[I]);
  except
    on E: Exception do
    begin
      FModel.ClearAnimation;
      if Host.Window <> nil then
        Host.Window.Title := 'Chase - ' + E.Message;
    end;
  end;
  FStart := Time;
end;

{ The light looks at the middle of the model from far enough away to see the
  model and the shadow it casts on the ground. It follows the model as it
  moves so that the shadow map always covers it. }

procedure TChaseScene.UpdateLight;
var
  L, P, Target: TVec3;
begin
  L := LightDirection;
  P := FWorld * FModel.RootPosition;
  Target := Vec3(P.X, FFocus, P.Z);
  FLightView.LookAt(Vec3(Target.X + L.X * 5, Target.Y + L.Y * 5, Target.Z + L.Z * 5),
    Target, Vec3(0, 1, 0));
  FLight := FLightProjection * FLightView;
end;

procedure TChaseScene.Render;
var
  Bones: TBoneMatrices;
  Projection, View: TMatrix4x4;
  H: Integer;
begin
  H := Max(Height, 1);
  { The canvas turns off depth testing and culling and changes the blend
    function when it draws the widgets, so the state the render context starts
    with is restored }
  glEnable(GL_DEPTH_TEST);
  glEnable(GL_CULL_FACE);
  glEnable(GL_BLEND);
  glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
  FModel.Animate(Time - FStart, Bones);
  UpdateLight;
  { Draw the depth of the model as seen by the light into the shadow buffer,
    unless the shadows are turned off }
  if FShadowsButton.Down then
  begin
    FShadow.StartRecording;
    Ctx.SetProjection(FLightProjection);
    Ctx.SetModelview(FLightView * FWorld);
    FShadowProgram.Push;
    glUniformMatrix4fv(FShadowBones, FModel.BoneCount, GL_FALSE, @Bones[0]);
    FModel.SetProgram(FShadowProgram.Handle);
    FModel.Draw;
    FShadowProgram.Pop;
    FShadow.StopRecording;
  end;
  { The camera orbits a point above the origin at the middle height of the
    model }
  Ctx.SetViewport(0, 0, Width, H);
  Ctx.SetClearColor(0.15, 0.15, 0.2, 1);
  Ctx.Clear;
  Projection.Perspective(45, Width / H, 0.1, 100);
  View.Identity;
  View.Translate(0, 0, -FDistance);
  View.Rotate(FPitch, FYaw, 0, roXYZ);
  View.Translate(0, -FFocus, 0);
  Ctx.SetProjection(Projection);
  Ctx.PushTexture(FShadow.Texture, 1);
  { Draw the model. Its buffer pushes the same program again and sets the
    projection and modelview uniforms when it draws. }
  Ctx.SetModelview(View * FWorld);
  FProgram.Push;
  glUniformMatrix4fv(FBones, FModel.BoneCount, GL_FALSE, @Bones[0]);
  Ctx.SetUniform(FModelMatrix, FWorld);
  Ctx.SetUniform(FLightMatrix, FLight);
  Ctx.SetUniform(FLightDir, LightDirection);
  Ctx.SetUniform(FShadowsOn, FShadowsButton.Down);
  FModel.SetProgram(FProgram.Handle);
  FModel.Draw;
  FProgram.Pop;
  { Draw the ground after the model because its edges fade out }
  Ctx.SetModelview(View);
  FGroundProgram.Push;
  Ctx.SetUniform(FGroundLightMatrix, FLight);
  Ctx.SetUniform(FGroundShadowsOn, FShadowsButton.Down);
  Ctx.PushCulling(False);
  FGround.Draw;
  Ctx.PopCulling;
  FGroundProgram.Pop;
  Ctx.PopTexture;
  { The panel is sized to the scene before the widgets are drawn }
  LayoutPanel;
  UpdateFullscreenButton;
  WidgetsRender;
end;

{ Mouse input reaches the widgets first, so dragging and the wheel only move
  the camera outside of the panel }

procedure TChaseScene.DoMouseDown(var Args: TSceneMouseArgs);
begin
  inherited DoMouseDown(Args);
  if Args.Handled then
    Exit;
  if Args.Button = buttonLeft then
  begin
    FDragging := True;
    Args.Handled := True;
  end;
end;

procedure TChaseScene.DoMouseMove(var Args: TSceneMouseArgs);
begin
  { A drag which started outside of the panel keeps turning the camera when
    the mouse moves over it }
  if not FDragging then
  begin
    inherited DoMouseMove(Args);
    Exit;
  end;
  FYaw := FYaw + Args.XRel * 0.5;
  FPitch := EnsureRange(FPitch + Args.YRel * 0.5, -89, 89);
  Args.Handled := True;
end;

procedure TChaseScene.DoMouseUp(var Args: TSceneMouseArgs);
begin
  if FDragging and (Args.Button = buttonLeft) then
  begin
    FDragging := False;
    Args.Handled := True;
    Exit;
  end;
  inherited DoMouseUp(Args);
end;

procedure TChaseScene.DoMouseWheel(var Args: TSceneWheelArgs);
begin
  inherited DoMouseWheel(Args);
  if Args.Handled then
    Exit;
  { Each notch of the wheel moves the camera ten percent closer or farther }
  FDistance := EnsureRange(FDistance * Power(0.9, Args.Delta), MinDistance, MaxDistance);
  Args.Handled := True;
end;

end.
