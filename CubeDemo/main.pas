unit Main;

{$mode delphi}

interface

uses
  Classes, SysUtils, Forms, Controls,
  Codebot.Render.Controls,
  Codebot.Render.Scenes.Controller,
  CubeScene;

{ TForm1 }

type
  TForm1 = class(TForm)
    GraphicsBox: TGraphicsBox;
    procedure FormCreate(Sender: TObject);
  private
    FController: TSceneController;
  end;

var
  Form1: TForm1;

implementation

{$r *.lfm}

{ TForm1 }

procedure TForm1.FormCreate(Sender: TObject);
begin
  { The controller is owned by the form, so the box stops rendering before
    the controller is freed }
  FController := TSceneController.Create(Self);
  FController.OpenScene(GraphicsBox, TCubeScene);
end;

end.
