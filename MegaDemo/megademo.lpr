program megademo;

{$mode delphi}
{$define usesdl}

{ MegaDemo runs the Tiny Sim drawing demos with codebot_render. When usesdl
  is defined above it runs in an SDL window using Codebot.Render.Application,
  without the LCL or the Main form. Otherwise it runs in the LCL form in
  Main. }

uses
  { Codebot.System is first so threads are supported before other units start }
  Codebot.System,
  {$ifdef usesdl}
  Codebot.Render.Application,
  {$else}
  Interfaces, // this includes the LCL widgetset
  Forms, Main,
  {$endif}
  Demo.Viewer
  { you can add units after this };

{$r *.res}

begin
  {$ifdef usesdl}
  Application.Title := 'Mega Demo';
  Application.Width := 1280;
  Application.Height := 720;
  Application.Run(TDemoViewer);
  {$else}
  RequireDerivedFormResource := True;
  Application.Scaled := True;
  {$push}{$warn 5044 off}
  Application.MainFormOnTaskbar := True;
  {$pop}
  Application.Initialize;
  Application.CreateForm(TMegaForm, MegaForm);
  Application.Run;
  {$endif}
end.
