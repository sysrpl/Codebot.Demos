unit Main;

{$mode delphi}

interface

uses
  Codebot.System,
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, ExtCtrls,
  Codebot.Controls.Containers,
  Codebot.WebKit.Controls,
  Codebot.WebKit.Controls.Extras;

{ TMainForm }

type
  TMainForm = class(TForm)
    AddressBar: TWebAddressBar;
    Browser: TWebBrowser;
    Splitter: ExtCtrls.TSplitter;
    InspectorBox: TCaptionBox;
    Inspector: TWebInspector;
    StatusIndicator: TWebStatusIndicator;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure InspectorBoxClose(Sender: TObject);
  private
    procedure ApplicationIdle(Sender: TObject; var Done: Boolean);
  end;

var
  MainForm: TMainForm;

implementation

{$R *.lfm}

{ TMainForm }

{ The address bar loads its home page, www.getlazarus.org, when the program
  starts }

procedure TMainForm.FormCreate(Sender: TObject);
begin
  Application.AddOnIdleHandler(ApplicationIdle);
  AddressBar.ButtonClick(abHome);
end;

procedure TMainForm.FormDestroy(Sender: TObject);
begin
  Application.RemoveOnIdleHandler(ApplicationIdle);
end;

{ The inspector box is shown and hidden by the address bar and by the browser,
  so the splitter is kept showing only while the box is }

procedure TMainForm.ApplicationIdle(Sender: TObject; var Done: Boolean);
begin
  if Splitter.Visible = InspectorBox.Visible then
    Exit;
  if InspectorBox.Visible then
    { The splitter is placed above the box so it is aligned between the box
      and the browser }
    Splitter.Top := InspectorBox.Top - Splitter.Height;
  Splitter.Visible := InspectorBox.Visible;
end;

{ The inspect button on the address bar shows and hides the caption box with
  the inspector. Closing the box with its own close button also turns the
  inspector off. }

procedure TMainForm.InspectorBoxClose(Sender: TObject);
begin
  Inspector.Active := False;
end;

end.
