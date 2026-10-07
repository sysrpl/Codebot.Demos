unit Main;

{$mode delphi}

interface

uses
  Classes, SysUtils, Forms, Controls, Dialogs, LCLType,
  Codebot.Render.Controls,
  Codebot.Render.Scenes.Controller,
  JointScene;

{ TJointForm }

type
  TJointForm = class(TForm)
    GraphicsBox: TGraphicsBox;
    procedure FormCreate(Sender: TObject);
  private
    FController: TSceneController;
    procedure GraphicsFailed(Sender: TObject);
    procedure GraphicsKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
  end;

var
  JointForm: TJointForm;

implementation

{$R *.lfm}

{ TJointForm }

procedure TJointForm.FormCreate(Sender: TObject);
begin
  { The controller is owned by the form, so the box stops rendering before
    the controller is freed }
  FController := TSceneController.Create(Self);
  GraphicsBox.OnFailed := GraphicsFailed;
  { The controller passes key presses on to this handler before the scene }
  GraphicsBox.OnKeyDown := GraphicsKeyDown;
  FController.OpenScene(GraphicsBox, TJointScene);
end;

{ GraphicsFailed is called when the render thread or the physics step thread
  stops because of an exception }

procedure TJointForm.GraphicsFailed(Sender: TObject);
begin
  ShowMessage('The demo stopped: ' + GraphicsBox.ErrorMessage);
end;

{ F1 toggles full screen }

procedure TJointForm.GraphicsKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if Key <> VK_F1 then
    Exit;
  if WindowState = wsFullScreen then
    WindowState := wsNormal
  else
    WindowState := wsFullScreen;
  Key := 0;
end;

end.
