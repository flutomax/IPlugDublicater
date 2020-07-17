unit uMain;

{
  IPlug Dublicater
  Based on Python shell script for Duplicating WDL-OL IPlug Projects
  Oli Larkin 2012-2019 http://www.olilarkin.co.uk
  Vasily Makarov 2020 http://stone-voices.ru
  License: WTFPL http://sam.zoy.org/wtfpl/COPYING

  fixed Manufacturer can contain spaces
}

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Vcl.ExtCtrls,
  System.ImageList, Vcl.ImgList;

type
  TFrmMain = class(TForm)
    GpProperties: TGridPanel;
    EdOutputProjectPath: TButtonedEdit;
    ImlMain: TImageList;
    LbOutputProjectName: TLabel;
    LbManufacturer: TLabel;
    LbOutputProjectPath: TLabel;
    EdOutputProjectName: TEdit;
    EdManufacturer: TEdit;
    DlgPath: TFileOpenDialog;
    BtnMake: TButton;
    EdInputProjectPath: TButtonedEdit;
    LbInputProjectPath: TLabel;
    LbxLog: TListBox;
    BtnClose: TButton;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure EdOutputProjectPathRightButtonClick(Sender: TObject);
    procedure LbInputProjectPathClick(Sender: TObject);
    procedure BtnMakeClick(Sender: TObject);
    procedure BtnCloseClick(Sender: TObject);
  private
    fIniFileName: string;
    fInputProjectPath: string;
    fOutputProjectName: string;
    fOutputProjectPath: string;
    fManufacturer: string;
    fOutputPath: string;
  public
    procedure AddLog(const s: string);
  end;

var
  FrmMain: TFrmMain;

implementation

{$R *.dfm}

uses
  System.IniFiles, System.IOUtils, uHelper;

const
  sMain = 'Main';
  sInputProjectPath = 'InputProjectPath';
  sOutputProjectName = 'OutputProjectName';
  sOutputProjectPath = 'OutputProjectPath';
  sManufacturer = 'Manufacturer';

procedure TFrmMain.FormCreate(Sender: TObject);
var
  ini: TMemIniFile;
begin
  fIniFileName := ChangeFileExt(Application.ExeName, '.ini');
  ini := TMemIniFile.Create(fIniFileName);
  try
    fInputProjectPath := ini.ReadString(sMain, sInputProjectPath, '');
    fOutputProjectName := ini.ReadString(sMain, sOutputProjectName, '');
    fOutputProjectPath := ini.ReadString(sMain, sOutputProjectPath, '');
    fManufacturer := ini.ReadString(sMain, sManufacturer, '');
  finally
    ini.Free;
  end;

  EdInputProjectPath.Text := fInputProjectPath;
  EdOutputProjectName.Text := fOutputProjectName;
  EdOutputProjectPath.Text := fOutputProjectPath;
  EdManufacturer.Text := fManufacturer;
end;

procedure TFrmMain.FormDestroy(Sender: TObject);
var
  ini: TMemIniFile;
begin
  ini := TMemIniFile.Create(fIniFileName);
  try
    ini.WriteString(sMain, sInputProjectPath, fInputProjectPath);
    ini.WriteString(sMain, sOutputProjectName, fOutputProjectName);
    ini.WriteString(sMain, sOutputProjectPath, fOutputProjectPath);
    ini.WriteString(sMain, sManufacturer, fManufacturer);
    ini.UpdateFile;
  finally
    ini.Free;
  end;
end;

procedure TFrmMain.LbInputProjectPathClick(Sender: TObject);
var
  c: TWinControl;
begin
  c := TLabel(Sender).FocusControl;
  if Assigned(c) and c.CanFocus then
    c.SetFocus;
end;

procedure TFrmMain.EdOutputProjectPathRightButtonClick(Sender: TObject);
begin
  DlgPath.FileName := TButtonedEdit(Sender).Text;
  if DlgPath.Execute(Handle) then
    TButtonedEdit(Sender).Text := DlgPath.FileName;
end;

procedure TFrmMain.AddLog(const s: string);
begin
  with LbxLog do
    ItemIndex := Items.Add(s);
end;

procedure TFrmMain.BtnCloseClick(Sender: TObject);
begin
  Close;
end;

procedure TFrmMain.BtnMakeClick(Sender: TObject);
var
  s: string;
begin
  fInputProjectPath := Trim(EdInputProjectPath.Text);
  fOutputProjectName := Trim(EdOutputProjectName.Text);
  fManufacturer := Trim(EdManufacturer.Text);
  fOutputProjectPath := Trim(EdOutputProjectPath.Text);

  // checks
  if fOutputProjectName.IsEmpty then
    raise EArgumentException.Create('Output project name is empty!');

  if fManufacturer.IsEmpty then
    raise EArgumentException.Create('Manufacturer is empty!');

  if fOutputProjectName.Contains(' ') then
    raise EArgumentException.Create('Output project name has spaces!');

  if not DirectoryExists(fInputProjectPath) then
    raise EPathNotFoundException.Create('Input path does not exist!');

  if not DirectoryExists(fOutputProjectPath) then
    raise EPathNotFoundException.Create('Output path does not exist!');

  // format paths
  fInputProjectPath := IncludeTrailingBackslash(fInputProjectPath);
  fOutputProjectPath := IncludeTrailingBackslash(fOutputProjectPath);

  fOutputPath := TPath.Combine(fOutputProjectPath, fOutputProjectName);
  if DirectoryExists(fOutputPath) then
    raise EPathNotFoundException.Create('Output project allready exists!');

  AddLog(Format('Copying "%s" folder to "%s"', [fInputProjectPath, fOutputPath]));
  if not CopyDirectory(fInputProjectPath, fOutputPath, AddLog) then
    raise EInOutError.Create(SysErrorMessage(GetLastError));

  RenameProjectContents(fInputProjectPath, fOutputPath, fOutputProjectName,
    fManufacturer, AddLog);

  s := TPath.Combine(TDirectory.GetParent(fInputProjectPath), 'gitignore_template');
  if FileExists(s) then
  begin
    AddLog('Copying gitignore template into project folder');
    TFile.Copy(s, TPath.Combine(fOutputPath, '.gitignore'));
  end;

  AddLog('Done');

end;


end.
