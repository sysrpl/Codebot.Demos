unit Main;

{$mode delphi}

interface

uses
  Classes, SysUtils, Forms, Controls, Dialogs,
  Codebot.Render.Controls,
  Codebot.Render.Scenes.Controller,
  MachineScene;

{ TMachineForm }

type
  TMachineForm = class(TForm)
    GraphicsBox: TGraphicsBox;
    procedure FormCreate(Sender: TObject);
  private
    FController: TSceneController;
    procedure GraphicsFailed(Sender: TObject);           d;

var
  MachineForm: TMachineForm;

implementation

{$r *.lfm}

{ TMachineForm }

procedure TMachineForm.FormCreate(Sender: TObject);
begin
  { The controller is owned by the form, so the box stops rendering before
    the controller is freed }
  FController := TSceneController.Create(Self);
  GraphicsBox.OnFailed := GraphicsFailed;
  FController.OpenScene(GraphicsBox, TMachineScene);
end;

{ GraphicsFailed is called when the render thread or the physics step thread
  stops because of an exception }

procedure TMachineForm.GraphicsFailed(Sender: TObject);
begin
  ShowMessage('The demo stopped: ' + GraphicsBox.ErrorMessage);
end;

end.
