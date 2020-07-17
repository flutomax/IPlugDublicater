unit uHelper;

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
  Winapi.Windows, System.SysUtils, System.Classes;

type
  TFileWorkEvent = reference to procedure(const Path: string);


  function CopyDirectory(const SourceDirName, DestDirName: string; OnWork: TFileWorkEvent): Boolean;
  function RenameProjectContents(const InputProjectPath, OutputProjectPath,
    OutputProjectName, Manufacturer: string; OnWork: TFileWorkEvent): boolean;

implementation

uses
  System.Types, System.IOUtils, System.StrUtils, System.Masks;

// files that we don't want to duplicate
const
  DONT_COPY_FILES: array[0..9] of string = ('*.exe', '*.dmg', '*.pkg',
    '*.mpkg', '*.svn', '*.ncb', '*.suo', '*.layout', '*.depend', '*.aps');

  DONT_COPY_DIRECTORIES: array[0..5] of string = ('.vs', '*sdf', 'ipch',
    'build-*', '.DS_Store', 'xcuserdata');

  FOLDERS_TO_SEARCH: array[0..3] of string = ('-macOS.xcodeproj', '-iOS.xcodeproj',
    '.xcworkspace', 'iOSAppIcon.appiconset');

  SUBFOLDERS_TO_SEARCH: array[0..11] of string = ('projects', 'config', 'resources',
    'installer', 'scripts', 'manual', 'xcschemes', 'xcshareddata', 'xcuserdata',
    'en-osx.lproj', 'project.xcworkspace', 'Images.xcassets');

  FILTERED_FILE_EXTENSIONS: array[0..7] of string = ('.ico', '.icns', '.pdf',
    '.png', '.zip', '.exe', '.wav', '.aif');

function DirectoryFilter(const Path: string; const SearchRec: TSearchRec): Boolean;
var
  s: string;
begin
  for s in DONT_COPY_DIRECTORIES do
    if MatchesMask(SearchRec.Name, s) then
      exit(false);
  result := true;
end;

function FilesFilter(const Path: string; const SearchRec: TSearchRec): Boolean;
var
  s: string;
begin
  for s in DONT_COPY_FILES do
    if MatchesMask(SearchRec.Name, s) then
      exit(false);
  result := true;
end;

function GetDirectoryList(const Path: string; List: TStrings): boolean;

  function RecurseFolder(const Path: string): boolean;
  var
    f: TSearchRec;
    r: integer;
    s: string;
  begin
    Result := false;
    r := FindFirst(Path + '*.*', faAnyFile, f);
    if r = 0 then
    try
      while r = 0 do
      begin
        if (f.Name <> '.') and (f.Name <> '..') then
        begin
          if (F.Attr and faDirectory) = faDirectory then
            if DirectoryFilter(Path, f) then
            begin
              s := Path + IncludeTrailingBackslash(f.Name);
              RecurseFolder(s);
              List.Add(s);
            end
        end;
        r := FindNext(F);
      end;
      if r <> ERROR_NO_MORE_FILES then
        exit;
    finally
      FindClose(f);
    end;
    result := true;
  end;

begin
  if not TDirectory.Exists(Path) then
    Result := false
  else
  List.BeginUpdate;
  try
    List.Clear;
    List.Add(IncludeTrailingBackslash(Path));
    try
      Result := RecurseFolder(IncludeTrailingBackslash(Path));
    except
      Result := false;
    end;
  finally
    List.EndUpdate;
  end;
end;


function CopyDirectory(const SourceDirName, DestDirName: string;
  OnWork: TFileWorkEvent): Boolean;
var
  fl: TStringDynArray;
  i, j: integer;
  s, dir: string;
  dirs, files: TStringList;
begin
  result := false;
  dirs := TStringList.Create;
  files := TStringList.Create;
  try
    GetDirectoryList(SourceDirName, dirs);
    for i := 0 to dirs.Count - 1 do
    begin
      fl := TDirectory.GetFiles(dirs[i], TSearchOption.soTopDirectoryOnly, FilesFilter);
      for j := 0 to High(fl) do
        files.Add(fl[j]);
      dir := TPath.Combine(DestDirName, ExtractRelativePath(SourceDirName, dirs[i]));
      if not TDirectory.Exists(dir) then
      begin
        OnWork(Format('Create directory "%s"', [dir]));
        TDirectory.CreateDirectory(dir);
      end;
    end;

    for i := 0 to files.Count - 1 do
    begin
      s := TPath.Combine(DestDirName, ExtractRelativePath(SourceDirName, files[i]));
      OnWork(Format('Copy "%s"', [files[i]]));
      TFile.Copy(files[i], s);
    end;
  finally
    dirs.Free;
    files.Free;
  end;
  result := true;
end;

function ExtractDirName(const Path: string): string;
begin
  result := TPath.GetFileName(ExcludeTrailingBackslash(Path));
end;

function GetProjectRoot(const configfile: string): string;
var
  s: string;
  f: TStringList;
  i, p: integer;
begin
  if not FileExists(configfile) then
    exit;
  f := TStringList.Create;
  try
    f.LoadFromFile(configfile);
    for i := 0 to f.Count - 1 do
    begin
      s := f[i];
      p := AnsiPos(f.NameValueSeparator, s);
      if (p <> 0) and (AnsiCompareText(Trim(Copy(S, 1, p - 1)), 'IPLUG2_ROOT') = 0) then
      begin
        result := Trim(Copy(s, p + 1, MaxInt));
        if PathDelim = '\' then
          result := result.Replace('/', '\');
        break;
      end;
    end;
  finally
    f.Free;
  end;
end;

procedure ReplaceStrs(const filename, s, r: string);
var
  t: string;
begin
  t := TFile.ReadAllText(filename);
  t := AnsiReplaceStr(t, s, r);
  TFile.WriteAllText(filename, t);
end;

procedure ReplaceTexts(const filename, s, r: string);
var
  t: string;
begin
  t := TFile.ReadAllText(filename);
  t := AnsiReplaceText(t, s, r);
  TFile.WriteAllText(filename, t);
end;

function DirWalk(const dir, searchproject, replaceproject, searchman, replaceman,
  oldroot, newroot: string; OnWork: TFileWorkEvent): boolean;
var
  s, t, fullpath, filename, newfilename, base, extension: string;
begin
  result := true;
  // Processing directories
  for fullpath in TDirectory.GetDirectories(dir) do
  begin
    s := ExtractDirName(fullpath);
    for t in FOLDERS_TO_SEARCH do
      if SameFileName(s, searchproject + t) then
      begin
        OnWork(Format('Rename "%s"', [fullpath]));
        TDirectory.Move(fullpath, TPath.Combine(dir, replaceproject + t));
        s := TPath.Combine(dir, replaceproject + t);
        OnWork(Format('Recursing in directory "%s"', [s]));
        DirWalk(s, searchproject, replaceproject, searchman, replaceman,
          oldroot, newroot, OnWork);
      end;
    for t in SUBFOLDERS_TO_SEARCH do
    begin
      if SameFileName(s, t) then
      begin
        OnWork(Format('Recursing in directory "%s"', [fullpath]));
        DirWalk(fullpath, searchproject, replaceproject, searchman, replaceman,
          oldroot, newroot, OnWork);
      end;
    end;
  end;

  // Processing files
  for fullpath in TDirectory.GetFiles(dir) do
  begin
    filename := TPath.GetFileName(fullpath);
    base := TPath.GetFileNameWithoutExtension(fullpath);
    extension := TPath.GetExtension(fullpath);
    newfilename := filename.Replace(searchproject, replaceproject);
    if AnsiIndexText(extension, FILTERED_FILE_EXTENSIONS) = -1 then
    begin

      OnWork(Format('Replacing project name strings in file "%s"', [filename]));
      ReplaceTexts(fullpath, searchproject, replaceproject);

      OnWork(Format('Replacing manufacturer name strings in file "%s"', [filename]));
      ReplaceTexts(fullpath, searchman, replaceman);

      if not SameFileName(oldroot, newroot) then
      begin
        OnWork(Format('Replacing iPlug2 root folder in file "%s"', [filename]));
        ReplaceTexts(fullpath, oldroot, newroot);
      end;
    end else begin
      OnWork(Format('NOT replacing name strings in file "%s"', [filename]));
    end;

    if not SameFileName(filename, newfilename) then
    begin
      OnWork(Format('Renaming file "%s" to "%s"', [filename, newfilename]));
      TFile.Move(fullpath, TPath.Combine(dir, newfilename));
    end;

  end;

end;

function RenameProjectContents(const InputProjectPath, OutputProjectPath,
  OutputProjectName, Manufacturer: string; OnWork: TFileWorkEvent): boolean;
var
  projectname, configpath, configfile, oldroot, newroot, iplug2folder: string;
begin
  projectname := ExtractDirName(InputProjectPath);
  configpath := TPath.Combine(InputProjectPath, 'config');
  configfile := TPath.Combine(configpath, projectname + '-mac.xcconfig');
  oldroot := GetProjectRoot(configfile);
  iplug2folder := IncludeTrailingBackslash(TPath.GetFullPath(TPath.Combine(configpath, oldroot)));
  newroot := ExtractRelativePath(IncludeTrailingBackslash(TPath.Combine(OutputProjectPath, 'config')), iplug2folder);
  newroot := ExcludeTrailingBackslash(newroot);
  result := DirWalk(OutputProjectPath, projectname, OutputProjectName,
    'AcmeInc', Manufacturer, oldroot, newroot, OnWork);

end;


end.
