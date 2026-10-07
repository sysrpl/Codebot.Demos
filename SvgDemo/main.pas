unit Main;

{$mode delphi}

interface

uses
  Classes, SysUtils, Forms, Controls,
  Codebot.Render.Controls,
  Codebot.Render.Scenes.Controller,
  SvgScene;

{ TSvgForm }

type
  TSvgForm = class(TForm)
    GraphicsBox: TGraphicsBox;
    procedure FormCreate(Sender: TObject);
  private
    FController: TSceneController;
  end;

var
  SvgForm: TSvgForm;

implementation

{$r *.lfm}

{ TSvgForm }

procedure TSvgForm.FormCreate(Sender: TObject);
begin
  { The controller is owned by the form, so the box stops rendering before
    the controller is freed }
  FController := TSceneController.Create(Self);
  FController.OpenScene(GraphicsBox, TSvgDemoScene);
end;

end.
