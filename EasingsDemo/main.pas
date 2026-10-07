unit Main;

{$mode delphi}

interface

uses
  Classes, SysUtils, Forms, Controls,
  Codebot.Render.Controls,
  Codebot.Render.Scenes.Controller,
  EasingsScene;

{ TEasingsForm }

type
  TEasingsForm = class(TForm)
    GraphicsBox: TGraphicsBox;
    procedure FormCreate(Sender: TObject);
  private
    FController: TSceneController;
  end;

var
  EasingsForm: TEasingsForm;

implementation

{$r *.lfm}

{ TEasingsForm }

procedure TEasingsForm.FormCreate(Sender: TObject);
begin
  { The controller is owned by the form, so the box stops rendering before
    the controller is freed }
  FController := TSceneController.Create(Self);
  FController.OpenScene(GraphicsBox, TEasingsDemoScene);
end;

end.
