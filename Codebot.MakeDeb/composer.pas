(********************************************************)
(*                                                      *)
(*  Debian Packager                                     *)
(*  http://www.getlazarus.org/apps/makedeb              *)
(*  Anthony Walter <admin@getlazarus.org>               *)
(*                                                      *)
(*  Released under ther GPL V3 license                  *)
(*                                                      *)
(*  Last Modified July 2022                             *)
(*                                                      *)
(********************************************************)

unit Composer;

{$mode delphi}

interface

uses
  Classes, SysUtils, Graphics, Controls, Forms, StdCtrls, Dialogs, Buttons,
  ExtDlgs, ExtCtrls, FileUtil, Process, DebianPack,
  Codebot.System,
  Codebot.Text,
  Codebot.Text.Json,
  Codebot.Graphics,
  Codebot.Graphics.Types,
  Codebot.Controls,
  Codebot.Controls.Tooltips,
  Codebot.Controls.Banner,
  Codebot.Controls.Extras,
  Codebot.Controls.Buttons;

{ TComposeForm }

type
  TComposeForm = class(TBannerForm)
    ApplicationProperties: TApplicationProperties;
    IconImage: TImageStrip;
    ButtonImages: TImageStrip;
    IconDialog: TOpenPictureDialog;
    OpenDialog: TOpenDialog;
    AppEdit: TEdit;
    SectionBox: TComboBox;
    PackageEdit: TEdit;
    AuthorEdit: TEdit;
    IconButton: TThinButton;
    CaptionEdit: TEdit;
    WebsiteEdit: TEdit;
    VerisonEdit: TEdit;
    ShortEdit: TEdit;
    LongEdit: TMemo;
    Progress: TIndeterminateProgress;
    BuildButton: TButton;
    CloseButton: TButton;
    Label1: TLabel;
    Label2: TLabel;
    Label3: TLabel;
    Label4: TLabel;
    Label5: TLabel;
    Label6: TLabel;
    Label7: TLabel;
    Label8: TLabel;
    Label9: TLabel;
    AppButton: TSpeedButton;
    ArrowImage: TImage;
    IconTimer: TTimer;
    ContentButton: TSpeedButton;
    HelpButton: TSpeedButton;
    procedure AppButtonClick(Sender: TObject);
    procedure ApplicationPropertiesShowHint(var HintStr: string;
      var CanShow: Boolean; var HintInfo: THintInfo);
    procedure BuildButtonClick(Sender: TObject);
    procedure CloseButtonClick(Sender: TObject);
    procedure FormCloseQuery(Sender: TObject; var CanClose: boolean);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure IconButtonClick(Sender: TObject);
    procedure IconButtonDrawButton(Sender: TObject; Surface: ISurface;
      Rect: TRectI; State: TDrawState);
    procedure IconTimerTimer(Sender: TObject);
    procedure ContentButtonClick(Sender: TObject);
  private
    FThread: TSimpleThread;
    FTitle: string;
    FSubTitle: string;
    FPackage: TDebianPackage;
    FOriginal: IBitmap;
    FCustom: IBitmap;
    FCancelled: Boolean;
    FPriorStatus: TProgressStatus;
    FPriorCaption: string;
    procedure DisableEdits;
    procedure DoThreadDone(Sender: TObject);
    procedure DoThreadStatus(Sender: TObject);
    procedure EnableEdits;
    procedure LoadDepends(FileName: string);
    procedure LoadPackage(FileName: string);
    procedure SavePackage(FileName: string);
  protected
    procedure Draw; override;
  end;

var
  ComposeForm: TComposeForm;

implementation

{$R *.lfm}

function XmlUnescape(const S: string): string;
begin
  Result := S.Replace('&lt;', '<').Replace('&gt;', '>').Replace('&quot;', '"')
    .Replace('&apos;', '''').Replace('&amp;', '&');
end;

{ Older versions saved .mkdeb files as flat xml, <data><Name>value</Name>...
  Convert those into the same json layout used by newer saves. }

function XmlToJson(const Xml: string; N: TJsonNode): Boolean;
var
  D: TJsonNode;
  I, J, K: Integer;
  Tag: string;
begin
  Result := False;
  I := Pos('<data>', Xml);
  if I < 1 then
    Exit;
  D := N.Force('data');
  I := I + Length('<data>');
  while True do
  begin
    I := Pos('<', Xml, I);
    if (I < 1) or (Copy(Xml, I, 2) = '</') then
      Break;
    J := Pos('>', Xml, I);
    if J < 1 then
      Break;
    Tag := Copy(Xml, I + 1, J - I - 1);
    if (Tag = '') or Tag.EndsWith('/') then
    begin
      I := J + 1;
      Continue;
    end;
    K := Pos('</' + Tag + '>', Xml, J);
    if K < 1 then
      Break;
    D.Add(Tag, XmlUnescape(Copy(Xml, J + 1, K - J - 1)));
    I := K + Length(Tag) + 3;
  end;
  Result := True;
end;

{ Read FileName.mkdeb in either the json or older xml format }

function ReadPackageFile(const FileName: string; N: TJsonNode): Boolean;
var
  S: string;
begin
  Result := False;
  S := FileName + '.mkdeb';
  if not FileExists(S) then
    Exit;
  S := FileReadStr(S).Trim;
  if S.BeginsWith('<') then
    Result := XmlToJson(S, N)
  else
    Result := N.TryParse(S);
end;

procedure TComposeForm.LoadDepends(FileName: string);
var
  N: TJsonNode;
  S: string;
begin
  N := TJsonNode.Create;
  try
    if ReadPackageFile(FileName, N) then
    begin
      S := N.Force('data/depends').AsString;
      FPackage.Depends := S.Split(', ');
      Exit;
    end;
  finally
    N.Free;
  end;
  FPackage.Depends.Clear;
end;

procedure TComposeForm.SavePackage(FileName: string);
var
  Control: TControl;
  Buffer: TBuffer;
  N, D: TJsonNode;
  S: string;
  I: Integer;
begin
  N := TJsonNode.Create;
  try
    D := N.Force('data');
    for I := 0 to ControlCount - 1 do
    begin
      Control := Controls[I];
      if Control is TEdit then
        D.Add(Control.Name, TEdit(Control).Text)
      else if Control is TMemo then
        D.Add(Control.Name, TMemo(Control).Text)
      else if Control is TComboBox then
        D.Add(Control.Name, IntToStr(TComboBox(Control).ItemIndex))
      else if Control is TCheckBox then
        D.Add(Control.Name, TCheckBox(Control).Checked);
    end;
    if FileArchitecture(FileName) = FileArchitecture(ParamStr(0)) then
      D.Add('depends', FPackage.Depends.Join(', '));
    S := FileExtractName(FileName);
    S := FileChangeExt(S, '.png');
    S := PathCombine(GetTempDir(True), S);
    FCustom.SaveToFile(S);
    Buffer.LoadFromFile(S);
    D.Add('icon', HexEncode(Buffer));
    FileDelete(S);
    FileName := FileName + '.mkdeb';
    N.SaveToFile(FileName);
  finally
    N.Free;
  end;
end;

procedure TComposeForm.LoadPackage(FileName: string);
var
  Control: TControl;
  Buffer: TBuffer;
  N, D: TJsonNode;
  S: string;
  I: Integer;
begin
  if FileExists(FileName + '.mkdeb') then
  begin
    S := '';
    N := TJsonNode.Create;
    try
      if ReadPackageFile(FileName, N) then
      begin
        D := N.Force('data');
        for I := 0 to ControlCount - 1 do
        begin
          Control := Controls[I];
          if Control is TEdit then
            TEdit(Control).Text := D.Force(Control.Name).AsString
          else if Control is TMemo then
            TMemo(Control).Text := D.Force(Control.Name).AsString
          else if Control is TComboBox then
            TComboBox(Control).ItemIndex := StrToIntDef(D.Force(Control.Name).AsString, -1)
          else if Control is TCheckBox then
            TCheckBox(Control).Checked := D.Force(Control.Name).AsBoolean;
        end;
        FPackage.Depends := D.Force('depends').AsString.Split(', ');
        S := D.Force('icon').AsString;
      end;
      FCustom.Clear;
      if S.Length > 1000 then
      begin
        Buffer := HexDecode(S);
        S := FileExtractName(FileName);
        S := FileChangeExt(S, '.png');
        S := PathCombine(GetTempDir(True), S);
        Buffer.SaveToFile(S);
        FCustom.LoadFromFile(S);
        FileDelete(S);
      end;
      if FCustom.Empty then
        FCustom := FOriginal.Clone;
      IconImage.Clear;
      IconImage.Add(FCustom);
      Exit;
    finally
      N.Free;
    end;
  end;
  for I := 0 to ControlCount - 1 do
  begin
    Control := Controls[I];
    if Control is TEdit then
      TEdit(Control).Text := ''
    else if Control is TMemo then
      TMemo(Control).Text := ''
    else if Control is TComboBox then
      TComboBox(Control).ItemIndex := -1
    else if Control is TCheckBox then
      TCheckBox(Control).Checked := False;
  end;
  AppEdit.Text := FileName;
  CaptionEdit.Text := FileExtractNameOnly(FileName);
  PackageEdit.Text := CaptionEdit.Text;
  VerisonEdit.Text := '1.0-1';
  FCustom := FOriginal.Clone;
  IconImage.Clear;
  IconImage.Add(FCustom);
end;

procedure TComposeForm.ApplicationPropertiesShowHint(var HintStr: string;
  var CanShow: Boolean; var HintInfo: THintInfo);
begin
  if FThread <> nil then
    Exit;
  CanShow := False;
  if HintStr <> '' then
  begin
    if UseTipify then
      Tipify(HintInfo.HintControl)
    else
    begin
      if Progress.Status <> psHelp then
      begin
        FPriorStatus := Progress.Status;
        FPriorCaption := Progress.Caption;
      end;
      Progress.Status := psHelp;
      Progress.Caption := HintStr;
    end;
  end
  else
  begin
    if UseTipify then
      Tipify(nil)
    else
    begin
      Progress.Status := FPriorStatus;
      Progress.Caption := FPriorCaption;
    end;
  end;
end;

procedure AlignVert(Controls: array of TControl);
var
  Y, I: Integer;
begin
  if Length(Controls) < 2 then
    Exit;
  Y := Controls[0].Top + Controls[0].Height div 2;
  for I := 1 to Length(Controls) - 1 do
    Controls[I].Top := Y - Controls[I].Height div 2;
end;

{ TComposeForm }

procedure TComposeForm.FormCreate(Sender: TObject);
begin
  FOriginal := NewBitmap;
  IconImage.CopyTo(FOriginal);
  FCustom := FOriginal.Clone;
  FPackage := TDebianPackage.Create;
  AlignVert([AppEdit, AppButton]);
  AlignVert([BuildButton, Progress]);
  AppButton.Glyph.Colorize(clWindowText);
  { The arrow sits in the always white header }
  ArrowImage.Picture.Bitmap.Colorize(clBlack);
  FTitle := Title.Text;
  FSubTitle := TitleSub.Text;
  Title.Text := '';
  TitleSub.Text := '';
end;

procedure TComposeForm.FormDestroy(Sender: TObject);
begin
  FPackage.Free;
end;

procedure TComposeForm.FormShow(Sender: TObject);
begin
  if Tag = 1 then Exit;
  Tag := 1;
  Progress.Top := BuildButton.Top - (Progress.Height - BuildButton.Height) div 2;
end;

procedure TComposeForm.Draw;
var
  S: ISurface;
  F: IFont;
  P: IPen;
  R: TRectI;
begin
  inherited Draw;
  if FTitle = '' then
    Exit;
  S := Surface;
  F := NewFont(Title.Font);
  R := ClientRect;
  R.Bottom := Banner.Height;
  R.Left := IconButton.Width + 46;
  S.TextOut(F, 'Click here pick your application icon', R, drLeft);
  R := IconButton.BoundsRect;
  R.Inflate(-4, -4);
  P := NewPen(clBlack, 3);
  P.LinePattern := pnDash;
  S.RoundRectangle(R, 12);
  S.Stroke(P);
end;

procedure TComposeForm.IconButtonClick(Sender: TObject);
var
  B: IBitmap;
begin
  if IconDialog.Execute and FileExists(IconDialog.FileName) then
  begin
    B := NewBitmap;
    B.LoadFromFile(IconDialog.FileName);
    if (B.Width > 15) and (B.Width < 513) and (B.Height = B.Width) then
    begin
      FCustom := B;
      if FCustom.Width > 64 then
        FCustom := FCustom.Resample(64, 64);
      FCustom.Format := fmPng;
      IconImage.Clear;
      IconImage.Add(FCustom);
    end
    else
      MessageDlg('Icons must be square and be between 16px and 512px', mtError, [mbOK], 0);
  end;
end;

{ The header is always white, so draw the icon button with black outlines
  instead of theme colors meant for the form background }

procedure TComposeForm.IconButtonDrawButton(Sender: TObject; Surface: ISurface;
  Rect: TRectI; State: TDrawState);
const
  Radius = 2;
var
  G: IGradientBrush;
  C: TColorB;
begin
  if dsPressed in State then
    C := TColorB(clWhite).Darken(0.2)
  else if dsHot in State then
    C := TColorB(clWhite).Darken(0.08)
  else
    Exit;
  G := NewBrush(Rect.Left, Rect.Top, Rect.Left, Rect.Bottom);
  G.AddStop(C.Lighten(0.4), 0);
  G.AddStop(C, 1);
  Surface.FillRoundRect(G, Rect, Radius);
  Surface.StrokeRoundRect(NewPen(TColorB(clBlack).Fade(0.6)), Rect, Radius);
end;

procedure TComposeForm.IconTimerTimer(Sender: TObject);
begin
  IconTimer.Enabled := False;
  Title.Text := FTitle;
  TitleSub.Text := FSubTitle;
  FTitle := '';
  FSubTitle := '';
  ArrowImage.Visible := False;
  Invalidate;
end;

procedure TComposeForm.ContentButtonClick(Sender: TObject);
begin

end;

procedure TComposeForm.FormCloseQuery(Sender: TObject; var CanClose: boolean);
begin
  CanClose := FThread = nil;
end;

procedure TComposeForm.DoThreadStatus(Sender: TObject);
begin
  Progress.Caption := FThread.Status;
end;

procedure TComposeForm.DoThreadDone(Sender: TObject);
begin
  FThread := nil;
  EnableEdits;
  CloseButton.Caption := 'Close';
  if FCancelled then
  begin
    Progress.Status := psError;
    Progress.Caption := 'Deb file creation cancelled';
  end
  else if FPackage.FailReason <> '' then
  begin
    Progress.Status := psError;
    Progress.Caption := FPackage.FailReason;
  end
  else
  begin
    Progress.Status := psReady;
    Progress.Caption := 'Deb file creation complete';
    SavePackage(FPackage.FileName);
  end;
  FPriorStatus := Progress.Status;
  FPriorCaption := Progress.Caption;
end;

procedure TComposeForm.DisableEdits;
var
  C: TControl;
  I: Integer;
begin
  for I := 0 to ControlCount - 1 do
  begin
    C := Controls[I];
    if C is TLabel then
      Continue;
    if C = CloseButton then
      Continue;
    if C is TIndeterminateProgress then
      Continue;
    C.Enabled := False;
  end;
end;

procedure TComposeForm.EnableEdits;
var
  I: Integer;
begin
  for I := 0 to ControlCount - 1 do
    Controls[I].Enabled := True;
end;

procedure TComposeForm.CloseButtonClick(Sender: TObject);
begin
  if FThread = nil then
    Close
  else
  begin
    Progress.Caption := 'Stopping';
    FCancelled := True;
    FThread.Terminate;
  end;
  CloseButton.Enabled := False;
end;

procedure TComposeForm.BuildButtonClick(Sender: TObject);

  procedure Validate(State: Boolean; const Msg: string; W: TWinControl);
  begin
    if State then
    begin
      W.Color := clDefault;
      Exit;
    end;
    Progress.Status := psError;
    Progress.Caption := Msg;
    FPriorStatus := Progress.Status;
    FPriorCaption := Progress.Caption;
    W.Color := W.CurrentColor.Blend(clRed, 0.2).Color;
    W.SetFocus;
    Abort;
  end;

var
  S: string;
begin
  if FThread = nil then
  begin
    FPackage.FileName := Trim(AppEdit.Text);
    Validate(FileExists(FPackage.FileName), 'Application file not found', AppEdit);
    S := FileArchitecture(FPackage.FileName);
    Validate(S <> '', 'Application file is invalid', AppEdit);
    if S <> FileArchitecture(ParamStr(0)) then
    begin
      LoadDepends(FPackage.FileName);
      S := FileArchitecture(ParamStr(0));
      Validate(FPackage.Depends.Length > 0, 'Build package for ' + S + ' first', AppEdit);
    end;
    IconImage.CopyTo(FPackage.Icon);
    S := FileExtractPath(FPackage.FileName);
    ChDir(S);
    FPackage.Caption := Trim(CaptionEdit.Text);
    Validate(FPackage.Caption.Length > 1, 'Invalid caption', CaptionEdit);
    FPackage.Name := Trim(PackageEdit.Text);
    Validate(FPackage.Name.IsIdentifier, 'Invalid package identifier', PackageEdit);
    FPackage.Version := Trim(VerisonEdit.Text);
    Validate(SectionBox.ItemIndex > -1, 'Invalid category', SectionBox);
    case SectionBox.ItemIndex of
      0: S := 'admin';
      1: S := 'comm';
      2: S := 'database';
      3: S := 'devel';
      4: S := 'editors';
      5: S := 'electronics';
      6: S := 'fonts';
      7: S := 'games';
      8: S := 'graphics';
      9: S := 'math';
      10: S := 'web';
      11: S := 'net';
      12: S := 'news';
      13: S := 'science';
      14: S := 'sound';
      15: S := 'utils';
      16: S := 'video';
    else
      S := 'misc';
    end;
    FPackage.Section := S;
    FPackage.Author := Trim(AuthorEdit.Text);
    FPackage.Website := Trim(WebsiteEdit.Text);
    FPackage.ShortInfo := Trim(ShortEdit.Text);
    FPackage.LongInfo := Trim(LongEdit.Text);
    Progress.Caption := 'Creating deb package';
    Progress.Status := psBusy;
    Progress.Visible := True;
    CloseButton.SetFocus;
    CloseButton.Caption := 'Stop';
    BuildButton.Enabled := False;
    FCancelled := False;
    DisableEdits;
    FThread := TSimpleThread.Create(FPackage.Build, DoThreadStatus, DoThreadDone);
  end;
end;

procedure TComposeForm.AppButtonClick(Sender: TObject);
begin
  if OpenDialog.Execute then
  begin
    AppEdit.Text := OpenDialog.FileName;
    LoadPackage(AppEdit.Text);
    AppEdit.Text := OpenDialog.FileName;
  end;
end;

end.

