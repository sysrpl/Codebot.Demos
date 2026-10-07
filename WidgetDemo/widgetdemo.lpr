program widgetdemo;

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
  DemoScene
  { you can add units after this };

{$r *.res}

begin
  {$ifdef usesdl}
  Application.Title := 'Widget Demo';
  Application.Width := 1280;
  Application.Height := 720;
  Application.Run(TDemoScene);
  {$else}
  RequireDerivedFormResource := True;
  Application.Scaled := True;
  {$push}{$warn 5044 off}
  Application.MainFormOnTaskbar := True;
  {$pop}
  Application.Initialize;
  Application.CreateForm(TDemoForm, DemoForm);
  Application.Run;
  {$endif}
end.
