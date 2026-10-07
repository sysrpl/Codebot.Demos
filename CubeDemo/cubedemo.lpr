program cubedemo;

{$mode delphi}
{$define usesdl}

{ When usesdl is defined above the demo runs in an SDL window
  using Codebot.Render.Application, without the LCL or the Main form.
  Otherwise it runs in the LCL form in Main. }

uses
  { Codebot.System is first so threads are supported before other units start }
  Codebot.System,
  {$ifdef usesdl}
  Codebot.Render.Application,
  {$else}
  Interfaces, // this includes the LCL widgetset
  Forms, Main,
  {$endif}
  CubeScene
  { you can add units after this };

{$r *.res}

begin
  {$ifdef usesdl}
  Application.Title := 'Cube';
  Application.Run(TCubeScene);
  {$else}
  RequireDerivedFormResource := True;
  Application.Scaled := True;
  {$push}{$warn 5044 off}
  Application.MainFormOnTaskbar := True;
  {$pop}
  Application.Initialize;
  Application.CreateForm(TForm1, Form1);
  Application.Run;
  {$endif}
end.
