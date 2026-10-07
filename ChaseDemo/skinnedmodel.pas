unit SkinnedModel;

{$mode delphi}

interface

uses
  Classes, SysUtils, Math,
  Codebot.Geometry,
  Codebot.Interop.Assimp,
  Codebot.Render.Buffers,
  Codebot.Render.Textures;

const
  { The size of the bones uniform array in the vertex shader }
  MaxBones = 64;

type
  TBoneMatrices = array[0..MaxBones - 1] of TMatrix4x4;

{ TSkinnedModel loads a model with assimp into a skin vertex buffer and its
  diffuse texture. Its skeleton is in its rest pose until an animation is
  loaded from a separate file using the same skeleton. It must be used on the
  render thread. }

  TSkinnedModel = class
  private type
    TNode = record
      Parent: Integer;
      Transform: TMatrix4x4;
      Name: string;
      Channel: PAiNodeAnim;
      Bone: Integer;
    end;
  private
    FScene: PAiScene;
    FAnimationScene: PAiScene;
    FNodes: array of TNode;
    FBoneNames: array of string;
    FOffsets: array of TMatrix4x4;
    FGlobalInverse: TMatrix4x4;
    FRootMotionNode: Integer;
    FSkeletonNode: Integer;
    FDuration: Double;
    FTicksPerSecond: Double;
    FInPlace: Boolean;
    FBuffer: TSkinVertexBuffer;
    FTexture: TTexture;
    FCenter: TVec3;
    FRadius: Float;
    FBottom: Float;
    FRootPosition: TVec3;
    function BoneIndex(const Name: string): Integer;
    procedure AddNode(Node: PAiNode; Parent: Integer);
    procedure LinkChannels(Animation: PAiAnimation);
    function ChannelTransform(Channel: PAiNodeAnim; Ticks: Double; RootMotion: Boolean): TMatrix4x4;
    procedure LoadMeshes;
    procedure LoadTexture(const FileName: string);
    function GetBoneCount: Integer;
    function GetDuration: Double;
  public
    { Load a model file. Raises an exception if it cannot be read. }
    constructor Create(const FileName: string);
    destructor Destroy; override;
    { Load the first animation from a file and play it from the start. Nodes
      are matched to channels by name, or by name without a prefix ending in a
      colon. Raises an exception if the file cannot be read. }
    procedure LoadAnimation(const FileName: string);
    { Remove the animation, returning the skeleton to its rest pose }
    procedure ClearAnimation;
    { Pose the skeleton at a time in seconds, looping the animation, and
      output the bone matrices for the vertex shader }
    procedure Animate(Seconds: Double; out Bones: TBoneMatrices);
    { Set the shader program used to draw }
    procedure SetProgram(Prog: Integer);
    { Draw the model with its texture }
    procedure Draw;
    { The number of bones used by the model }
    property BoneCount: Integer read GetBoneCount;
    { The center of the model in its rest pose }
    property Center: TVec3 read FCenter;
    { Half of the largest dimension of the model in its rest pose }
    property Radius: Float read FRadius;
    { The lowest point of the model in its rest pose }
    property Bottom: Float read FBottom;
    { The length of the animation in seconds, or 0 if there is none }
    property Duration: Double read GetDuration;
    { When InPlace is True the horizontal movement of the root bone is removed
      so the model animates in place. It is False by default. }
    property InPlace: Boolean read FInPlace write FInPlace;
    { The position of the root bone in model space after the last Animate }
    property RootPosition: TVec3 read FRootPosition;
  end;

implementation

{ Assimp matrices are row major and TMatrix4x4 is column major }

function ToMatrix(const M: TAiMatrix4x4): TMatrix4x4;
begin
  Result.M[0, 0] := M.a1; Result.M[1, 0] := M.a2; Result.M[2, 0] := M.a3; Result.M[3, 0] := M.a4;
  Result.M[0, 1] := M.b1; Result.M[1, 1] := M.b2; Result.M[2, 1] := M.b3; Result.M[3, 1] := M.b4;
  Result.M[0, 2] := M.c1; Result.M[1, 2] := M.c2; Result.M[2, 2] := M.c3; Result.M[3, 2] := M.c4;
  Result.M[0, 3] := M.d1; Result.M[1, 3] := M.d2; Result.M[2, 3] := M.d3; Result.M[3, 3] := M.d4;
end;

{ Build a matrix which scales, then rotates, then translates }

function Compose(const P: TAiVector3D; const Q: TAiQuaternion; const S: TAiVector3D): TMatrix4x4;
var
  X, Y, Z, W: Float;
begin
  X := Q.x; Y := Q.y; Z := Q.z; W := Q.w;
  Result.M[0, 0] := (1 - 2 * (Y * Y + Z * Z)) * S.x;
  Result.M[0, 1] := 2 * (X * Y + Z * W) * S.x;
  Result.M[0, 2] := 2 * (X * Z - Y * W) * S.x;
  Result.M[0, 3] := 0;
  Result.M[1, 0] := 2 * (X * Y - Z * W) * S.y;
  Result.M[1, 1] := (1 - 2 * (X * X + Z * Z)) * S.y;
  Result.M[1, 2] := 2 * (Y * Z + X * W) * S.y;
  Result.M[1, 3] := 0;
  Result.M[2, 0] := 2 * (X * Z + Y * W) * S.z;
  Result.M[2, 1] := 2 * (Y * Z - X * W) * S.z;
  Result.M[2, 2] := (1 - 2 * (X * X + Y * Y)) * S.z;
  Result.M[2, 3] := 0;
  Result.M[3, 0] := P.x;
  Result.M[3, 1] := P.y;
  Result.M[3, 2] := P.z;
  Result.M[3, 3] := 1;
end;

function Lerp(const A, B: TAiVector3D; T: Float): TAiVector3D;
begin
  Result.x := A.x + (B.x - A.x) * T;
  Result.y := A.y + (B.y - A.y) * T;
  Result.z := A.z + (B.z - A.z) * T;
end;

{ Spherical interpolation along the shortest path }

function Slerp(const A, B: TAiQuaternion; T: Float): TAiQuaternion;
var
  C: TAiQuaternion;
  CosOmega, Omega, SinOmega, S0, S1, Len: Float;
begin
  C := B;
  CosOmega := A.x * B.x + A.y * B.y + A.z * B.z + A.w * B.w;
  if CosOmega < 0 then
  begin
    CosOmega := -CosOmega;
    C.x := -C.x; C.y := -C.y; C.z := -C.z; C.w := -C.w;
  end;
  if 1 - CosOmega > 0.0001 then
  begin
    Omega := ArcCos(CosOmega);
    SinOmega := Sin(Omega);
    S0 := Sin((1 - T) * Omega) / SinOmega;
    S1 := Sin(T * Omega) / SinOmega;
  end
  else
  begin
    S0 := 1 - T;
    S1 := T;
  end;
  Result.x := S0 * A.x + S1 * C.x;
  Result.y := S0 * A.y + S1 * C.y;
  Result.z := S0 * A.z + S1 * C.z;
  Result.w := S0 * A.w + S1 * C.w;
  Len := Sqrt(Result.x * Result.x + Result.y * Result.y + Result.z * Result.z + Result.w * Result.w);
  if Len > 0 then
  begin
    Result.x := Result.x / Len;
    Result.y := Result.y / Len;
    Result.z := Result.z / Len;
    Result.w := Result.w / Len;
  end;
end;

{ Find the key before a time and the fraction of the way to the next key,
  returning False when the time is outside of the keys }

function FindVectorKey(Keys: PAiVectorKeyArray; Count: Integer; Ticks: Double;
  out Index: Integer; out T: Float): Boolean;
begin
  Index := 0;
  T := 0;
  if (Count < 2) or (Ticks <= Keys^[0].mTime) then
    Exit(False);
  while (Index < Count - 1) and (Keys^[Index + 1].mTime <= Ticks) do
    Inc(Index);
  if Index >= Count - 1 then
    Exit(False);
  T := (Ticks - Keys^[Index].mTime) / (Keys^[Index + 1].mTime - Keys^[Index].mTime);
  Result := True;
end;

function InterpolateVector(Keys: PAiVectorKeyArray; Count: Integer; Ticks: Double;
  const Default: TAiVector3D): TAiVector3D;
var
  I: Integer;
  T: Float;
begin
  if Count < 1 then
    Exit(Default);
  if FindVectorKey(Keys, Count, Ticks, I, T) then
    Result := Lerp(Keys^[I].mValue, Keys^[I + 1].mValue, T)
  else if Ticks <= Keys^[0].mTime then
    Result := Keys^[0].mValue
  else
    Result := Keys^[Count - 1].mValue;
end;

{ Rotation keys are read using aiRotationKey because their size depends on
  the version of the loaded library }

function InterpolateRotation(Channel: PAiNodeAnim; Ticks: Double): TAiQuaternion;
var
  Count, I: Integer;
  A, B: PAiQuatKey;
begin
  Count := Channel.mNumRotationKeys;
  if Count < 1 then
  begin
    Result.w := 1; Result.x := 0; Result.y := 0; Result.z := 0;
    Exit;
  end;
  A := aiRotationKey(Channel, 0);
  if (Count = 1) or (Ticks <= A.mTime) then
    Exit(A.mValue);
  I := 0;
  while (I < Count - 1) and (aiRotationKey(Channel, I + 1)^.mTime <= Ticks) do
    Inc(I);
  if I >= Count - 1 then
    Exit(aiRotationKey(Channel, Count - 1)^.mValue);
  A := aiRotationKey(Channel, I);
  B := aiRotationKey(Channel, I + 1);
  Result := Slerp(A.mValue, B.mValue, (Ticks - A.mTime) / (B.mTime - A.mTime));
end;

{ TSkinnedModel }

constructor TSkinnedModel.Create(const FileName: string);
const
  Flags = aiProcess_Triangulate or aiProcess_JoinIdenticalVertices or
    aiProcess_GenSmoothNormals or aiProcess_LimitBoneWeights or aiProcess_FlipUVs;
var
  Props: PAiPropertyStore;
begin
  inherited Create;
  FInPlace := False;
  FRootMotionNode := -1;
  if not InitAssimp then
    raise Exception.Create('The assimp library could not be loaded');
  { FBX pivots are imported as extra $AssimpFbx$ nodes holding translations
    and rotations which the animation keys also contain, so they would be
    applied twice. Folding them into the bones avoids that. }
  Props := aiCreatePropertyStore;
  try
    aiSetImportPropertyInteger(Props, 'IMPORT_FBX_PRESERVE_PIVOTS', 0);
    FScene := aiImportFileExWithProperties(PAnsiChar(FileName), Flags, nil, Props);
  finally
    aiReleasePropertyStore(Props);
  end;
  if FScene = nil then
    raise Exception.Create('Could not load ' + FileName + ': ' + string(aiGetErrorString));
  if FScene.mNumMeshes = 0 then
    raise Exception.Create('There are no meshes in ' + FileName);
  FGlobalInverse := ToMatrix(FScene.mRootNode.mTransformation);
  FGlobalInverse.Invert;
  FTicksPerSecond := 25;
  LoadMeshes;
  LoadTexture(FileName);
end;

destructor TSkinnedModel.Destroy;
begin
  FBuffer.Free;
  FTexture.Free;
  ClearAnimation;
  if FScene <> nil then
    aiReleaseImport(FScene);
  inherited Destroy;
end;

function BaseName(const Name: string): string;
var
  I: Integer;
begin
  I := LastDelimiter(':', Name);
  Result := Copy(Name, I + 1, Length(Name));
end;

{ Link nodes to the channels of an animation, or unlink them all if the
  animation is nil }

procedure TSkinnedModel.LinkChannels(Animation: PAiAnimation);
var
  Channels: array of string;
  I, J: Integer;
begin
  FRootMotionNode := -1;
  FDuration := 0;
  FTicksPerSecond := 25;
  for I := 0 to High(FNodes) do
    FNodes[I].Channel := nil;
  if Animation = nil then
    Exit;
  FDuration := Animation.mDuration;
  if Animation.mTicksPerSecond > 0 then
    FTicksPerSecond := Animation.mTicksPerSecond;
  Channels := nil;
  SetLength(Channels, Animation.mNumChannels);
  for J := 0 to High(Channels) do
    Channels[J] := AiStr(Animation.mChannels^[J].mNodeName);
  for I := 0 to High(FNodes) do
  begin
    for J := 0 to High(Channels) do
      if Channels[J] = FNodes[I].Name then
      begin
        FNodes[I].Channel := Animation.mChannels^[J];
        Break;
      end;
    if FNodes[I].Channel = nil then
      for J := 0 to High(Channels) do
        if BaseName(Channels[J]) = BaseName(FNodes[I].Name) then
        begin
          FNodes[I].Channel := Animation.mChannels^[J];
          Break;
        end;
    { The first animated node is the root of the skeleton }
    if (FNodes[I].Channel <> nil) and (FRootMotionNode < 0) then
      FRootMotionNode := I;
  end;
end;

procedure TSkinnedModel.LoadAnimation(const FileName: string);
var
  Props: PAiPropertyStore;
  Scene: PAiScene;
begin
  Props := aiCreatePropertyStore;
  try
    aiSetImportPropertyInteger(Props, 'IMPORT_FBX_PRESERVE_PIVOTS', 0);
    Scene := aiImportFileExWithProperties(PAnsiChar(FileName), 0, nil, Props);
  finally
    aiReleasePropertyStore(Props);
  end;
  if Scene = nil then
    raise Exception.Create('Could not load ' + FileName + ': ' + string(aiGetErrorString));
  if Scene.mNumAnimations = 0 then
  begin
    aiReleaseImport(Scene);
    raise Exception.Create('There are no animations in ' + FileName);
  end;
  ClearAnimation;
  FAnimationScene := Scene;
  LinkChannels(Scene.mAnimations^[0]);
end;

procedure TSkinnedModel.ClearAnimation;
begin
  LinkChannels(nil);
  if FAnimationScene <> nil then
    aiReleaseImport(FAnimationScene);
  FAnimationScene := nil;
end;

function TSkinnedModel.BoneIndex(const Name: string): Integer;
var
  I: Integer;
begin
  for I := 0 to High(FBoneNames) do
    if FBoneNames[I] = Name then
      Exit(I);
  Result := -1;
end;

{ Flatten the node tree so that parents always come before their children }

procedure TSkinnedModel.AddNode(Node: PAiNode; Parent: Integer);
var
  I, Index: Integer;
begin
  Index := Length(FNodes);
  SetLength(FNodes, Index + 1);
  FNodes[Index].Name := AiStr(Node.mName);
  FNodes[Index].Parent := Parent;
  FNodes[Index].Transform := ToMatrix(Node.mTransformation);
  FNodes[Index].Bone := BoneIndex(FNodes[Index].Name);
  FNodes[Index].Channel := nil;
  for I := 0 to Node.mNumChildren - 1 do
    AddNode(Node.mChildren^[I], Index);
end;

function TSkinnedModel.ChannelTransform(Channel: PAiNodeAnim; Ticks: Double;
  RootMotion: Boolean): TMatrix4x4;
const
  Zero: TAiVector3D = (x: 0; y: 0; z: 0);
  One: TAiVector3D = (x: 1; y: 1; z: 1);
var
  P, S: TAiVector3D;
begin
  P := InterpolateVector(Channel.mPositionKeys, Channel.mNumPositionKeys, Ticks, Zero);
  if RootMotion and FInPlace and (Channel.mNumPositionKeys > 0) then
  begin
    P.x := Channel.mPositionKeys^[0].mValue.x;
    P.z := Channel.mPositionKeys^[0].mValue.z;
  end;
  S := InterpolateVector(Channel.mScalingKeys, Channel.mNumScalingKeys, Ticks, One);
  Result := Compose(P, InterpolateRotation(Channel, Ticks), S);
end;

procedure TSkinnedModel.Animate(Seconds: Double; out Bones: TBoneMatrices);
var
  Globals: array of TMatrix4x4;
  Ticks: Double;
  Local: TMatrix4x4;
  I: Integer;
begin
  for I := Low(Bones) to High(Bones) do
    Bones[I].Identity;
  Ticks := 0;
  if FDuration > 0 then
  begin
    Ticks := Seconds * FTicksPerSecond;
    Ticks := Ticks - Floor(Ticks / FDuration) * FDuration;
  end;
  Globals := nil;
  SetLength(Globals, Length(FNodes));
  for I := 0 to High(FNodes) do
  begin
    if FNodes[I].Channel <> nil then
      Local := ChannelTransform(FNodes[I].Channel, Ticks, I = FRootMotionNode)
    else
      Local := FNodes[I].Transform;
    if FNodes[I].Parent < 0 then
      Globals[I] := Local
    else
      Globals[I] := Globals[FNodes[I].Parent] * Local;
    if FNodes[I].Bone >= 0 then
      Bones[FNodes[I].Bone] := FGlobalInverse * Globals[I] * FOffsets[FNodes[I].Bone];
    if (I = FRootMotionNode) or ((FRootMotionNode < 0) and (I = FSkeletonNode)) then
      FRootPosition := FGlobalInverse * Vec3(Globals[I].M[3, 0], Globals[I].M[3, 1], Globals[I].M[3, 2]);
  end;
end;

{ Load every mesh into one buffer of triangles and build the node tree. The
  rest pose is computed on the CPU to find the bounds of the model. }

procedure TSkinnedModel.LoadMeshes;
type
  TInfluence = record
    Count: Integer;
    Bones: array[0..3] of Integer;
    Weights: array[0..3] of Float;
  end;
var
  Influences: array of array of TInfluence;
  Mesh: PAiMesh;
  Bone: PAiBone;
  Weight: TAiVertexWeight;
  Pose: TBoneMatrices;
  Skin: TMatrix4x4;
  Lo, Hi, P: TVec3;
  Normal: TVec3;
  Coord: TVec2;
  M, B, W, F, C, I, J, K, Smallest, Total: Integer;
  V: LongWord;
  Name: string;
  Inf: TInfluence;
  BoneIds, Weights: TVec4;
begin
  { Gather bones by name across meshes }
  Influences := nil;
  SetLength(Influences, FScene.mNumMeshes);
  for M := 0 to FScene.mNumMeshes - 1 do
  begin
    Mesh := FScene.mMeshes^[M];
    SetLength(Influences[M], Mesh.mNumVertices);
    for I := 0 to Mesh.mNumVertices - 1 do
      Influences[M][I].Count := 0;
    for B := 0 to Mesh.mNumBones - 1 do
    begin
      Bone := Mesh.mBones^[B];
      Name := AiStr(Bone.mName);
      K := BoneIndex(Name);
      if K < 0 then
      begin
        K := Length(FBoneNames);
        if K >= MaxBones then
          raise Exception.CreateFmt('The model has more than %d bones', [MaxBones]);
        SetLength(FBoneNames, K + 1);
        SetLength(FOffsets, K + 1);
        FBoneNames[K] := Name;
        FOffsets[K] := ToMatrix(Bone.mOffsetMatrix);
      end;
      { Keep the four strongest influences of each vertex }
      for W := 0 to Bone.mNumWeights - 1 do
      begin
        Weight := Bone.mWeights^[W];
        if Weight.mVertexId >= Mesh.mNumVertices then
          Continue;
        Inf := Influences[M][Weight.mVertexId];
        if Inf.Count < 4 then
        begin
          Inf.Bones[Inf.Count] := K;
          Inf.Weights[Inf.Count] := Weight.mWeight;
          Inc(Inf.Count);
        end
        else
        begin
          Smallest := 0;
          for J := 1 to 3 do
            if Inf.Weights[J] < Inf.Weights[Smallest] then
              Smallest := J;
          if Weight.mWeight > Inf.Weights[Smallest] then
          begin
            Inf.Bones[Smallest] := K;
            Inf.Weights[Smallest] := Weight.mWeight;
          end;
        end;
        Influences[M][Weight.mVertexId] := Inf;
      end;
    end;
  end;
  { Nodes are linked to bones by name, so they are added after the bones. The
    first frame is posed to measure the model. }
  AddNode(FScene.mRootNode, -1);
  { Without an animation the first bone in the tree is the root of the
    skeleton }
  FSkeletonNode := -1;
  for I := 0 to High(FNodes) do
    if FNodes[I].Bone >= 0 then
    begin
      FSkeletonNode := I;
      Break;
    end;
  Animate(0, Pose);
  Lo := Vec3(MaxSingle, MaxSingle, MaxSingle);
  Hi := Vec3(-MaxSingle, -MaxSingle, -MaxSingle);
  { Build the vertex buffer }
  Total := 0;
  for M := 0 to FScene.mNumMeshes - 1 do
    Inc(Total, FScene.mMeshes^[M].mNumFaces * 3);
  FBuffer := TSkinVertexBuffer.Create;
  FBuffer.BeginBuffer(vertTriangles, Total);
  for M := 0 to FScene.mNumMeshes - 1 do
  begin
    Mesh := FScene.mMeshes^[M];
    for F := 0 to Mesh.mNumFaces - 1 do
    begin
      if Mesh.mFaces^[F].mNumIndices <> 3 then
        Continue;
      for C := 0 to 2 do
      begin
        V := Mesh.mFaces^[F].mIndices^[C];
        P := Vec3(Mesh.mVertices^[V].x, Mesh.mVertices^[V].y, Mesh.mVertices^[V].z);
        if Mesh.mNormals <> nil then
          Normal := Vec3(Mesh.mNormals^[V].x, Mesh.mNormals^[V].y, Mesh.mNormals^[V].z)
        else
          Normal := Vec3(0, 1, 0);
        if Mesh.mTextureCoords[0] <> nil then
          Coord := Vec2(Mesh.mTextureCoords[0]^[V].x, Mesh.mTextureCoords[0]^[V].y)
        else
          Coord := Vec2(0, 0);
        Inf := Influences[M][V];
        BoneIds := Vec4(0, 0, 0, 0);
        Weights := Vec4(0, 0, 0, 0);
        if Inf.Count > 0 then
        begin
          BoneIds.X := Inf.Bones[0];
          Weights.X := Inf.Weights[0];
        end;
        if Inf.Count > 1 then
        begin
          BoneIds.Y := Inf.Bones[1];
          Weights.Y := Inf.Weights[1];
        end;
        if Inf.Count > 2 then
        begin
          BoneIds.Z := Inf.Bones[2];
          Weights.Z := Inf.Weights[2];
        end;
        if Inf.Count > 3 then
        begin
          BoneIds.W := Inf.Bones[3];
          Weights.W := Inf.Weights[3];
        end;
        FBuffer.Add(P, Normal, Coord, BoneIds, Weights);
        { Measure the posed vertex }
        if Inf.Count > 0 then
        begin
          for K := 0 to 15 do
            Skin.V[K] := 0;
          for J := 0 to Inf.Count - 1 do
            for K := 0 to 15 do
              Skin.V[K] := Skin.V[K] + Pose[Inf.Bones[J]].V[K] * Inf.Weights[J];
          P := Skin * P;
        end;
        Lo := Vec3(Min(Lo.X, P.X), Min(Lo.Y, P.Y), Min(Lo.Z, P.Z));
        Hi := Vec3(Max(Hi.X, P.X), Max(Hi.Y, P.Y), Max(Hi.Z, P.Z));
      end;
    end;
  end;
  FBuffer.EndBuffer;
  FCenter := Vec3((Lo.X + Hi.X) / 2, (Lo.Y + Hi.Y) / 2, (Lo.Z + Hi.Z) / 2);
  FRadius := Max(Max(Hi.X - Lo.X, Hi.Y - Lo.Y), Hi.Z - Lo.Z) / 2;
  FBottom := Lo.Y;
  if FRadius <= 0 then
    FRadius := 1;
end;

{ Load the diffuse texture of the first mesh from the textures embedded in
  the model or from a file next to the model }

procedure TSkinnedModel.LoadTexture(const FileName: string);
const
  White: array[0..3] of Byte = ($FF, $FF, $FF, $FF);
var
  Material: PAiMaterial;
  Path: TAiString;
  Texture: PAiTexture;
  Stream: TMemoryStream;
  Pixels: array of Byte;
  Name, S: string;
  I: Integer;
begin
  FTexture := TTexture.Create;
  FTexture.MagFilter := tfLinear;
  FTexture.MinFilter := tfLinear;
  FTexture.Wrap := True;
  Texture := nil;
  Name := '';
  Material := FScene.mMaterials^[FScene.mMeshes^[0].mMaterialIndex];
  if aiGetMaterialTexture(Material, aiTextureType_DIFFUSE, 0, @Path, nil, nil,
    nil, nil, nil, nil) = aiReturn_SUCCESS then
  begin
    Name := StringReplace(AiStr(Path), '\', '/', [rfReplaceAll]);
    { Embedded textures are named by index as in '*0' or by file name }
    if (Name <> '') and (Name[1] = AI_EMBEDDED_TEXNAME_PREFIX) then
    begin
      I := StrToIntDef(Copy(Name, 2, Length(Name)), -1);
      if (I > -1) and (I < Integer(FScene.mNumTextures)) then
        Texture := FScene.mTextures^[I];
    end
    else
      for I := 0 to FScene.mNumTextures - 1 do
      begin
        S := StringReplace(AiStr(FScene.mTextures^[I].mFilename), '\', '/', [rfReplaceAll]);
        if (S = Name) or (ExtractFileName(S) = ExtractFileName(Name)) then
        begin
          Texture := FScene.mTextures^[I];
          Break;
        end;
      end;
  end;
  if Texture <> nil then
  begin
    if Texture.mHeight = 0 then
    begin
      { A compressed image file such as a png }
      Stream := TMemoryStream.Create;
      try
        Stream.WriteBuffer(Texture.pcData^, Texture.mWidth);
        Stream.Position := 0;
        FTexture.LoadFromStream(Stream);
      finally
        Stream.Free;
      end;
    end
    else
    begin
      { Uncompressed BGRA texels }
      SetLength(Pixels, Texture.mWidth * Texture.mHeight * 4);
      for I := 0 to Texture.mWidth * Texture.mHeight - 1 do
      begin
        Pixels[I * 4] := Texture.pcData^[I].r;
        Pixels[I * 4 + 1] := Texture.pcData^[I].g;
        Pixels[I * 4 + 2] := Texture.pcData^[I].b;
        Pixels[I * 4 + 3] := Texture.pcData^[I].a;
      end;
      FTexture.LoadFromData(Texture.mWidth, Texture.mHeight, @Pixels[0]);
    end;
  end
  else
  begin
    S := ExtractFilePath(FileName) + ExtractFileName(Name);
    if (Name <> '') and FileExists(S) then
      FTexture.LoadFromFile(S)
    else
      FTexture.LoadFromData(1, 1, @White[0]);
  end;
  if FTexture.Width > 1 then
    FTexture.GenerateMipmaps;
end;

function TSkinnedModel.GetBoneCount: Integer;
begin
  Result := Length(FBoneNames);
end;

function TSkinnedModel.GetDuration: Double;
begin
  Result := FDuration / FTicksPerSecond;
end;

procedure TSkinnedModel.SetProgram(Prog: Integer);
begin
  FBuffer.SetProgram(Prog);
end;

procedure TSkinnedModel.Draw;
begin
  FTexture.Push;
  FBuffer.Draw;
  FTexture.Pop;
end;

end.
