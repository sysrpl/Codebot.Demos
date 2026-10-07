unit Main;

{$mode delphi}

interface

uses
  Classes, SysUtils, Forms, Controls,
  Codebot.Render.Controls,
  Codebot.Render.Scenes.Controller,
  DemoScene;

{ TDemoForm }

type
  TDemoForm = class(TForm)
    GraphicsBox: TGraphicsBox;
    procedure FormCreate(Sender: TObject);
  private
    FController: TSceneController;
  end;

var
  DemoForm: TDemoForm;

implementation

{$r *.lfm}

{ TDemoForm }

procedure TDemoForm.FormCreate(Sender: TObject);
begin
  { The controller is owned by the form, so the box stops rendering before
    the controller is freed }
  FController := TSceneController.Create(Self);
  FController.OpenScene(GraphicsBox, TDemoScene);
end;

end.
