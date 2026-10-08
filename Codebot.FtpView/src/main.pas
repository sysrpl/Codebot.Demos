unit Main;

{$mode delphi}

interface

uses
  Codebot.System,
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, ExtCtrls,
  LCLType,
  Codebot.Text,
  Codebot.Graphics,
  Codebot.Graphics.Types,
  Codebot.Controls.Grids,
  Codebot.Controls.Scrolling,
  Codebot.Controls.Extras,
  Codebot.Networking.Ftp;

{ TWorkThread runs a slow method in the background, then runs a second method
  on the main thread when it is done }

type
  TWorkThread = class(TThread)
  private
    FWork: TThreadMethod;
    FDone: TThreadMethod;
  protected
    procedure Execute; override;
  public
    constructor Create(Work, Done: TThreadMethod);
  end;

{ TEntryKind is the kind of an entry in the file grid }

  TEntryKind = (ekParent, ekFolder, ekFile);

{ TEntry is one row of the file grid }

  TEntry = record
    Kind: TEntryKind;
    Name: string;
    Size: LargeWord;
    Date: TDateTime;
  end;

{ TMainForm }

  TMainForm = class(TForm)
    HeaderBar1: THeaderBar;
    SiteEdit: TEdit;
    SelectTimer: TTimer;
    GridPanel: TPanel;
    Header: THeaderBar;
    FileGrid: TContentGrid;
    Splitter: TSplitter;
    ImagePanel: TPanel;
    ImageView: TDrawImage;
    Progress: TIndeterminateProgress;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
    procedure SiteEditKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure FileGridDrawCell(Sender: TObject; Surface: ISurface; Col, Row: Integer;
      Rect: TRectI; State: TDrawState);
    procedure FileGridDblClick(Sender: TObject);
    procedure HeaderColumnResize(Sender: TObject; Column: THeaderColumn);
    procedure FileGridSelection(Sender: TObject; Col, Row: Integer; var Allow: Boolean);
    procedure FileGridHotTrack(Sender: TObject; Col, Row: Integer; var Allow: Boolean);
    procedure FileGridDrawRow(Sender: TObject; Surface: ISurface; Row: Integer;
      Rect: TRectI; var DefaultDraw: Boolean);
    procedure SelectTimerTimer(Sender: TObject);
    procedure FileGridResize(Sender: TObject);
  private
    FClient: TFtpClient;
    FBusy: Boolean;
    FClosing: Boolean;
    FReconnect: Boolean;
    FHotRow: Integer;
    FHost: string;
    FPath: string;
    FItems: TArray<TRemoteFindData>;
    FEntries: TArray<TEntry>;
    FIconFont: IFont;
    FImageRemote: string;
    FImageLocal: string;
    FImageShown: string;
    FError: string;
    procedure Run(Work, Done: TThreadMethod; const Status: string);
    procedure OpenFolder(const Path: string);
    procedure SyncColumns;
    function JoinPath(const Folder, Name: string): string;
    function SelectedImage: string;
    procedure ShowSelected;
    procedure ImageWork;
    procedure ImageDone;
    procedure ListWork;
    procedure ListDone;
  end;

var
  MainForm: TMainForm;

implementation

{$R *.lfm}

const
  { Material design icons, drawn with the Material Design Icons font }
  IconParent = $F005D;
  IconFolder = $F024B;
  IconFile = $F0224;
  { Files with these extensions are shown in the image panel }
  ImageExtensions: array[0..4] of string = ('.png', '.jpg', '.jpeg', '.gif', '.bmp');

{ TWorkThread }

constructor TWorkThread.Create(Work, Done: TThreadMethod);
begin
  FWork := Work;
  FDone := Done;
  FreeOnTerminate := True;
  inherited Create(False);
end;

procedure TWorkThread.Execute;
begin
  FWork;
  Synchronize(FDone);
end;

{ TMainForm }

procedure TMainForm.FormCreate(Sender: TObject);
begin
  FClient := TFtpClient.Create;
  FReconnect := True;
  FHotRow := -1;
  FileGrid.ColCount := Header.Columns.Count;
  FileGrid.RowCount := 0;
  SyncColumns;
end;

procedure TMainForm.FormDestroy(Sender: TObject);
begin
  FClient.Free;
end;

procedure TMainForm.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
begin
  { The client is in use by a background thread, close when it is done }
  if FBusy then
  begin
    FClosing := True;
    CanClose := False;
  end;
end;

procedure TMainForm.SiteEditKeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
var
  S: string;
  I: Integer;
begin
  if Key <> VK_RETURN then
    Exit;
  Key := 0;
  if FBusy then
    Exit;
  { Accept a site with an optional ftp:// prefix and folder path }
  S := SiteEdit.Text;
  S := S.Trim;
  if S.StartsWith('ftp://', True) then
    S := S.Substring(6);
  I := S.IndexOf('/');
  if I > -1 then
  begin
    FHost := S.Substring(0, I);
    FPath := S.Substring(I);
  end
  else
  begin
    FHost := S;
    FPath := '';
  end;
  if FHost = '' then
    Exit;
  FReconnect := True;
  Run(ListWork, ListDone, 'Connecting to ' + FHost);
end;

procedure TMainForm.OpenFolder(const Path: string);
begin
  if FBusy then
    Exit;
  FPath := Path;
  Run(ListWork, ListDone, 'Opening ' + Path);
end;

procedure TMainForm.FileGridDblClick(Sender: TObject);
var
  Index: Integer;
  Entry: TEntry;
begin
  Index := FileGrid.Selection.Y;
  if (Index < 0) or (Index >= Length(FEntries)) then
    Exit;
  Entry := FEntries[Index];
  case Entry.Kind of
    ekParent:
      if FPath.LastIndexOf('/') > 0 then
        OpenFolder(FPath.Substring(0, FPath.LastIndexOf('/')))
      else
        OpenFolder('/');
    ekFolder:
      OpenFolder(JoinPath(FPath, Entry.Name));
  end;
end;

function TMainForm.JoinPath(const Folder, Name: string): string;
begin
  if Folder.EndsWith('/') then
    Result := Folder + Name
  else
    Result := Folder + '/' + Name;
end;

{ The grid columns follow the widths of the header columns }

procedure TMainForm.SyncColumns;
var
  Last, Used, I: Integer;
begin
  { The last column is stretched to the edge of the grid so the highlight of a
    row reaches across the whole grid }
  Last := Header.Columns.Count - 1;
  Used := 0;
  for I := 0 to Last - 1 do
  begin
    FileGrid.ColWidths[I] := Header.Columns[I].Width;
    Inc(Used, Header.Columns[I].Width);
  end;
  I := FileGrid.ClientWidth - Used;
  if I < Header.Columns[Last].Width then
    I := Header.Columns[Last].Width;
  FileGrid.ColWidths[Last] := I;
end;

procedure TMainForm.FileGridResize(Sender: TObject);
begin
  SyncColumns;
  FileGrid.Invalidate;
end;

procedure TMainForm.HeaderColumnResize(Sender: TObject; Column: THeaderColumn);
begin
  SyncColumns;
  FileGrid.Invalidate;
end;

procedure TMainForm.FileGridSelection(Sender: TObject; Col, Row: Integer;
  var Allow: Boolean);
begin
  { A whole row is drawn as selected, so every cell is repainted }
  FileGrid.Invalidate;
  { The image is fetched once the selection has stopped changing }
  SelectTimer.Enabled := False;
  SelectTimer.Enabled := True;
end;

{ The hot outline is drawn across a whole row, so the grid is repainted when
  the mouse moves to another row or leaves the rows, where Row is -1 }

procedure TMainForm.FileGridHotTrack(Sender: TObject; Col, Row: Integer;
  var Allow: Boolean);
begin
  if Row <> FHotRow then
  begin
    FHotRow := Row;
    FileGrid.Invalidate;
  end;
end;

procedure TMainForm.FileGridDrawRow(Sender: TObject; Surface: ISurface;
  Row: Integer; Rect: TRectI; var DefaultDraw: Boolean);
var
  State: TDrawState;
begin
  { The background of a row is drawn once across all of its cells }
  if Row >= Length(FEntries) then
    Exit;
  State := [];
  if Row = FileGrid.Selection.Y then
  begin
    Include(State, dsSelected);
    if FileGrid.Focused then
      Include(State, dsFocused);
  end;
  if Row = FHotRow then
    Include(State, dsHot);
  FileGrid.DrawRectState(Surface, Rect, State);
end;

procedure TMainForm.SelectTimerTimer(Sender: TObject);
begin
  SelectTimer.Enabled := False;
  { Wait for any listing or download to finish }
  if FBusy then
    SelectTimer.Enabled := True
  else
    ShowSelected;
end;

{ SelectedImage is the remote path of the selected file if it is an image,
  otherwise an empty string }

function TMainForm.SelectedImage: string;
var
  Index: Integer;
  Entry: TEntry;
  Ext: string;
begin
  Result := '';
  Index := FileGrid.Selection.Y;
  if (Index < 0) or (Index >= Length(FEntries)) then
    Exit;
  Entry := FEntries[Index];
  if Entry.Kind <> ekFile then
    Exit;
  Ext := FileExtractExt(Entry.Name).ToLower;
  for Index := Low(ImageExtensions) to High(ImageExtensions) do
    if Ext = ImageExtensions[Index] then
      Exit(JoinPath(FPath, Entry.Name));
end;

procedure TMainForm.ShowSelected;
var
  Remote: string;
begin
  Remote := SelectedImage;
  if Remote = '' then
  begin
    ImageView.Image.Clear;
    FImageShown := '';
    Exit;
  end;
  if Remote = FImageShown then
    Exit;
  FImageRemote := Remote;
  FImageLocal := GetTempDir + 'ftpview' + FileExtractExt(Remote).ToLower;
  Run(ImageWork, ImageDone, 'Downloading ' + FileExtractExt(Remote).ToLower);
end;

procedure TMainForm.ImageWork;
begin
  if not FClient.FileGet(FImageRemote, FImageLocal) then
    FError := 'Could not download ' + FileExtractName(FImageRemote);
end;

procedure TMainForm.ImageDone;
begin
  FBusy := False;
  if FClosing then
  begin
    Close;
    Exit;
  end;
  if FError = '' then
  try
    ImageView.Image.LoadFromFile(FImageLocal);
    FImageShown := FImageRemote;
    Progress.Caption := ExtractFileName(FImageRemote);
    Progress.Status := psReady;
  except
    ImageView.Image.Clear;
    FImageShown := '';
    Progress.Caption := 'Could not open ' + ExtractFileName(FImageRemote);
    Progress.Status := psError;
  end
  else
  begin
    ImageView.Image.Clear;
    FImageShown := '';
    Progress.Caption := FError;
    Progress.Status := psError;
  end;
  DeleteFile(FImageLocal);
  { The selection may have moved on while the image was downloading }
  if SelectedImage <> FImageShown then
    ShowSelected;
end;

procedure TMainForm.FileGridDrawCell(Sender: TObject; Surface: ISurface;
  Col, Row: Integer; Rect: TRectI; State: TDrawState);
const
  Margin = 6;
var
  Entry: TEntry;
  R: TRectI;
  S: string;
begin
  if Row >= Length(FEntries) then
    Exit;
  R := Rect;
  R.Left := R.Left + Margin;
  R.Right := R.Right - Margin;
  Entry := FEntries[Row];
  case Col of
    0:
      begin
        if FIconFont = nil then
        begin
          FIconFont := NewFont('Material Design Icons', 14);
          FIconFont.Quality := fqAntialiased;
          FIconFont.Color := clWindowText;
        end;
        case Entry.Kind of
          ekParent: S := UnicodeToStr(IconParent);
          ekFolder: S := UnicodeToStr(IconFolder);
        else
          S := UnicodeToStr(IconFile);
        end;
        Surface.TextOut(FIconFont, S, R, drLeft);
        R.Left := R.Left + Rect.Height;
        if Entry.Kind = ekParent then
          FileGrid.DrawText(Surface, 'Parent folder', R, drLeft)
        else
          FileGrid.DrawText(Surface, Entry.Name, R, drLeft);
      end;
    1:
      if Entry.Kind = ekFile then
        FileGrid.DrawText(Surface, FormatFloat('#,##0', Entry.Size), R, drRight);
    2:
      if Entry.Kind <> ekParent then
        FileGrid.DrawText(Surface, FormatDateTime('yyyy-mm-dd hh:nn', Entry.Date), R, drLeft);
  end;
end;

procedure TMainForm.Run(Work, Done: TThreadMethod; const Status: string);
begin
  FBusy := True;
  FError := '';
  Progress.Caption := Status;
  Progress.Status := psBusy;
  TWorkThread.Create(Work, Done);
end;

procedure TMainForm.ListWork;
var
  Data: TRemoteFindData;
  Count: Integer;
begin
  FItems := nil;
  if FReconnect then
  begin
    FClient.Disconnect;
    FClient.Host := FHost;
    if not FClient.Connect then
    begin
      FError := 'Could not connect to ' + FHost;
      Exit;
    end;
    FReconnect := False;
  end;
  if (FPath <> '') and not FClient.ChangeDir(FPath) then
  begin
    FError := 'Could not open ' + FPath;
    FReconnect := True;
    Exit;
  end;
  FPath := FClient.GetCurrentDir;
  Count := 0;
  if FClient.FindFirst('', Data) then
  repeat
    if (Data.Name = '.') or (Data.Name = '..') then
      Continue;
    SetLength(FItems, Count + 1);
    FItems[Count] := Data;
    Inc(Count);
  until not FClient.FindNext(Data);
end;

procedure TMainForm.ListDone;
var
  Count: Integer;

  procedure Add(Kind: TEntryKind; const Data: TRemoteFindData);
  begin
    SetLength(FEntries, Count + 1);
    FEntries[Count].Kind := Kind;
    FEntries[Count].Name := Data.Name;
    FEntries[Count].Size := Data.Size;
    FEntries[Count].Date := Data.Date;
    Inc(Count);
  end;

var
  Data: TRemoteFindData;
begin
  FBusy := False;
  if FClosing then
  begin
    Close;
    Exit;
  end;
  { An up entry leads to the parent folder, then come the folders and files }
  FEntries := nil;
  Count := 0;
  if (FError = '') and (FPath <> '/') then
  begin
    Data := Default(TRemoteFindData);
    Add(ekParent, Data);
  end;
  for Data in FItems do
    if fsaDirectory in Data.Attributes then
      Add(ekFolder, Data);
  for Data in FItems do
    if not (fsaDirectory in Data.Attributes) then
      Add(ekFile, Data);
  FileGrid.RowCount := Count;
  if Count > 0 then
    FileGrid.Selection := Point(0, 0);
  FileGrid.Invalidate;
  ImageView.Image.Clear;
  FImageShown := '';
  if FError <> '' then
  begin
    Progress.Caption := FError;
    Progress.Status := psError;
  end
  else
  begin
    Progress.Caption := Format('%d items in %s%s', [Length(FItems), FHost, FPath]);
    Progress.Status := psReady;
  end;
end;

end.
