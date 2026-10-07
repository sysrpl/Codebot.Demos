unit Main;

{$mode delphi}

interface

uses
  Classes, SysUtils, Forms, Controls,
  Codebot.Render.Controls,
  Codebot.Render.Scenes.Controller,
  Demo.Viewer;

{ TMegaForm }

type
  TMegaForm = class(TForm)
    GraphicsBox: TGraphicsBox;
    procedure FormCreate(Sender: TObject);
  private
    FController: TSceneController;
  end;

var
  MegaForm: TMegaForm;

implementation

{$r *.lfm}

{ TMegaForm }

procedure TMegaForm.FormCreate(Sender: TObject);
begin
  { The controller is owned by the form, so the box stops rendering before
    the controller is freed }
  FController := TSceneController.Create(Self);
  FController.OpenScene(GraphicsBox, TDemoViewer);
end;

end.
