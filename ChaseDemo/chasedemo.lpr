program chasedemo;

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
  ChaseScene
  { you can add units after this };

{$r *.res}

begin
  {$ifdef usesdl}
  Application.Title := 'Chase';
  Application.Width := 800;
  Application.Height := 600;
  { The demo is drawn without multisampling, which costs too much at 1080p on
    small GPUs such as the Raspberry Pi }
  Application.MultiSamples := 0;
  Application.Run(TChaseScene);
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
