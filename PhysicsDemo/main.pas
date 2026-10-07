unit Main;

{$mode delphi}

interface

uses
  Classes, SysUtils, Forms, Controls, Dialogs,
  Codebot.Render.Controls,
  Codebot.Render.Scenes.Controller,
  PhysicsScene;

{ TPhysicsForm }

type
  TPhysicsForm = class(TForm)
    GraphicsBox: TGraphicsBox;
    procedure FormCreate(Sender: TObject);
  private
    FController: TSceneController;
    procedure GraphicsFailed(Sender: TObject);
  end;

var
  PhysicsForm: TPhysicsForm;

implementation

{$r *.lfm}

{ TPhysicsForm }

procedure TPhysicsForm.FormCreate(Sender: TObject);
begin
  { The controller is owned by the form, so the box stops rendering before
    the controller is freed }
  FController := TSceneController.Create(Self);
  GraphicsBox.OnFailed := GraphicsFailed;
  FController.OpenScene(GraphicsBox, TPhysicsDemoScene);
end;

{ GraphicsFailed is called when the render thread or the physics step thread
  stops because of an exception }

procedure TPhysicsForm.GraphicsFailed(Sender: TObject);
begin
  ShowMessage('The demo stopped: ' + GraphicsBox.ErrorMessage);
end;

end.
