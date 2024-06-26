{
   Double Commander
   -------------------------------------------------------------------------
   Working with SpecialDir

   Copyright (C) 2009-2016  Alexander Koblov (alexx2000@mail.ru)

   This program is free software; you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation; either version 2 of the License, or
   (at your option) any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program; if not, write to the Free Software
   Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

   -This unit has been added in 2014.
   -Inspired a lot from "usearchtemplate"
   -Icon used for button to work with path is called "folder_wrench.png"
    and was taken from "http://www.famfamfam.com/lab/icons/silk/".
    It is already mentionned in the "about" section of the application
    that icons are coming from this site.

}

unit uSpecialDir;

{$mode objfpc}{$H+}

interface

uses
  Menus, Classes, SysUtils;

const
  TAGOFFSET_FORHOTDIRUSEINPATHHELPER = $10000;
  TAGOFFSET_FORHOTDIRRELATIVEINPATHHELPER = $20000;

type
  { TKindOfPathFile }
  TKindOfPathFile = (pfFILE, pfPATH);

  { TKindOfSpecialDir }
  TKindOfSpecialDir = (sd_NULL, sd_DOUBLECOMMANDER, sd_WINDOWSTC, sd_WINDOWSNONTC, sd_ENVIRONMENTVARIABLE);

  { TKindSpecialDirMenuPopulation }
  TKindSpecialDirMenuPopulation = (mp_PATHHELPER, mp_CHANGEDIR);

  { TProcedureWithJustASender }
  TProcedureWithJustASender = procedure(Sender: TObject) of Object;

  { TSpecialDir }
  TSpecialDir = class
  private
    fDispatcher: TKindOfSpecialDir;
    fVariableName: string;
    fPathValue: string;
  public
    constructor Create;
    property Dispatcher: TKindOfSpecialDir read fDispatcher write fDispatcher;
    property VariableName: string read fVariableName write fVariableName;
    property PathValue: string read fPathValue write fPathValue;
  end;

  { TSpecialDirList }
  TSpecialDirList = class(TList)
  private
    fIndexOfSpecialDirComptibleTC:longint; //Index of first windows SpecialDir compatible with TC
    fIndexOfNewVariableNotInTC:longint; //Index of first SpecialDir non-compatible TC
    fIndexOfEnvironmentVariable:longint; //Index of first EnvironmentVariable
    fRecipientComponent:TComponent;
    fRecipientType:TKindOfPathFile;
    function GetSpecialDir(Index: Integer): TSpecialDir;
  public
    constructor Create;
    procedure Clear; override;
    procedure PopulateMenuWithSpecialDir(mncmpMenuComponentToPopulate:TComponent; KindSpecialDirMenuPopulation:TKindSpecialDirMenuPopulation; ProcedureIfChangeDirClick:TProcedureWithJustASender);
    procedure SpecialDirMenuClick(Sender: TObject);
    procedure PopulateSpecialDir;
    procedure SetSpecialDirRecipientAndItsType(ParamComponent:TComponent; ParamKindOfPathFile:TKindOfPathFile);
    property SpecialDir[Index: Integer]: TSpecialDir read GeTSpecialDir;
    property IndexOfSpecialDirComptibleTC: longint read fIndexOfSpecialDirComptibleTC write fIndexOfSpecialDirComptibleTC; //Index of first windows Special Dir compatible with TC
    property IndexOfNewVariableNotInTC: longint read fIndexOfNewVariableNotInTC write fIndexOfNewVariableNotInTC; //Index of first non-compatible Total Commander path
    property IndexOfEnvironmentVariable: longint read fIndexOfEnvironmentVariable write fIndexOfEnvironmentVariable; //Index of first EnvironmentVariable
  end;

function GetMenuCaptionAccordingToOptions(const WantedCaption:string; const MatchingPath:string):string;
procedure LoadWindowsSpecialDir;

implementation

uses
  //Lazarus, Free-Pascal, etc.
  EditBtn, Dialogs, ExtCtrls, StrUtils, StdCtrls, lazutf8,
  {$IFDEF MSWINDOWS}
  ShlObj, uShellFolder,
  {$ENDIF}

  //DC
  DCOSUtils, uDCUtils, uGlobsPaths, fmain, uLng, uGlobs, uHotDir, uOSUtils,
  DCStrUtils;

{ The special path are sorted first by type of special path they represent (DC, Windows, Environment...)
  Then, by alphabetical order.
  But also, the most commun useful path could be placed first to be more user friendly.}
function CompareSpecialDir(Item1,Item2:Pointer):integer;
  function GetWeigth(sSpecialDir:string):longint;
  begin
    result:=10;
    if sSpecialDir='%$PERSONAL%' then result:=1;
    if sSpecialDir='%$DESKTOP%' then result:=2;
    if sSpecialDir='%$APPDATA%' then result:=3;
  end;

var
  Weight1,Weight2:longint;
begin
  if TSpecialDir(Item1).Dispatcher<>TSpecialDir(Item2).Dispatcher then
  begin
    if TSpecialDir(Item1).Dispatcher<TSpecialDir(Item2).Dispatcher then result:=-1 else result:=1;
  end
  else
  begin
    Weight1:=GetWeigth(TSpecialDir(Item1).VariableName);
    Weight2:=GetWeigth(TSpecialDir(Item2).VariableName);
    if Weight1<>Weight2 then
    begin
      if Weight1<Weight2 then result:=-1 else result:=1;
    end
    else
    begin
      result:=CompareText(TSpecialDir(Item1).VariableName,TSpecialDir(Item2).VariableName);
    end;
  end;
end;

{ TSpecialDir.Create }
constructor TSpecialDir.Create;
begin
  inherited Create;
  fDispatcher:=sd_NULL;
  fVariableName:='';
  fPathValue:='';
end;

{ TSpecialDirList.Create }
constructor TSpecialDirList.Create;
begin
  inherited Create;
  fIndexOfSpecialDirComptibleTC:=0;
  fIndexOfNewVariableNotInTC:=0;
  fIndexOfEnvironmentVariable:=0;
end;

{ TSpecialDirList.GetSpecialDir }
function TSpecialDirList.GetSpecialDir(Index: Integer): TSpecialDir;
begin
  Result:= TSpecialDir(Items[Index]);
end;

{ TSpecialDirList.Clear }
procedure TSpecialDirList.Clear;
var
  i: Integer;
begin
  for i := pred(Count) downto 0 do SpecialDir[i].Free;
  inherited Clear;
end;

{ TSpecialDirList.PopulatePopupMenuWithSpecialDir }
procedure TSpecialDirList.PopulateMenuWithSpecialDir(mncmpMenuComponentToPopulate:TComponent; KindSpecialDirMenuPopulation:TKindSpecialDirMenuPopulation; ProcedureIfChangeDirClick:TProcedureWithJustASender);
var
  miMainTree:TMenuItem;
  IndexVariable:longint;

  procedure AddStraightToMainTree(CaptionForMenuItem:string; TagForMenuItem:longint; ProcedureWhenClickOnMenuItem:TProcedureWhenClickOnMenuItem);
  begin
    miMainTree:=TMenuItem.Create(mncmpMenuComponentToPopulate);
    miMainTree.Caption:=CaptionForMenuItem;
    if (CaptionForMenuItem<>'-') AND (ProcedureWhenClickOnMenuItem<>nil) then
    begin
      miMainTree.Tag:=TagForMenuItem;
      miMainTree.OnClick:=ProcedureWhenClickOnMenuItem;
    end;

    if mncmpMenuComponentToPopulate.ClassType=TPopupMenu then TPopupMenu(mncmpMenuComponentToPopulate).Items.Add(miMainTree)
      else if mncmpMenuComponentToPopulate.ClassType=TMenuItem then TMenuItem(mncmpMenuComponentToPopulate).Add(miMainTree);
  end;

  procedure AddToSubMenu(ParamMenuItem:TMenuItem; TagRequested:longint; ProcedureWhenClickOnMenuItem:TProcedureWhenClickOnMenuItem);
  var
    localmi:TMenuItem;
  begin
    localmi:=TMenuItem.Create(ParamMenuItem);
    localmi.Caption:=GetMenuCaptionAccordingToOptions(SpecialDir[IndexVariable].VariableName,SpecialDir[IndexVariable].PathValue);
    localmi.tag:=TagRequested;
    localmi.OnClick:=ProcedureWhenClickOnMenuItem;
    ParamMenuItem.Add(localmi);
  end;

  procedure AddBatchOfMenuItems(SubMenuTitle:string; StartingIndex,StopIndex,TagOffset:longint; ProcedureWhenClickOnMenuItem:TProcedureWhenClickOnMenuItem);
  begin
    if StopIndex>StartingIndex then
    begin
      miMainTree:=TMenuItem.Create(mncmpMenuComponentToPopulate);
      miMainTree.Caption:=SubMenuTitle;
      if mncmpMenuComponentToPopulate.ClassType=TPopupMenu then TPopupMenu(mncmpMenuComponentToPopulate).Items.Add(miMainTree)
        else if mncmpMenuComponentToPopulate.ClassType=TMenuItem then TMenuItem(mncmpMenuComponentToPopulate).Add(miMainTree);

      IndexVariable:=StartingIndex;
      while IndexVariable<StopIndex do
        begin
          AddToSubMenu(miMainTree,TagOffset+IndexVariable,ProcedureWhenClickOnMenuItem);
          inc(IndexVariable);
        end;
    end;
  end;

begin
  case KindSpecialDirMenuPopulation of
    mp_PATHHELPER:
      begin
        //1o) "Use special path...", we add the special path used by TC
        AddBatchOfMenuItems(rsMsgSpecialDirUseDC,0,IndexOfSpecialDirComptibleTC,100,@SpecialDirMenuClick);

        //2o) "Use special path...", if in Windows, we add the Windows special folder beginning with TC compatible ones and then the newer ones we introduce in DC
        {$IFDEF MSWINDOWS}
        AddBatchOfMenuItems(rsMsgSpecialDirUseTC,IndexOfSpecialDirComptibleTC,IndexOfNewVariableNotInTC,100,@SpecialDirMenuClick);
        AddBatchOfMenuItems(rsMsgSpecialDirUseOther,IndexOfNewVariableNotInTC,IndexOfEnvironmentVariable,100,@SpecialDirMenuClick);
        {$ENDIF}

        //3o) "Use special path...", then, the ones from environment variable
        AddBatchOfMenuItems(rsMsgSpecialDirEnvVar,IndexOfEnvironmentVariable,Count,100,@SpecialDirMenuClick);

        //4o) "Use hotdir path...", then the ones user might have with his HotDir
        AddStraightToMainTree(rsMsgSpecialDirUseHotDir, 0, nil);
        gDirectoryHotlist.PopulateMenuWithHotDir(miMainTree,@SpecialDirMenuClick,nil,mpPATHHELPER,TAGOFFSET_FORHOTDIRUSEINPATHHELPER);
        AddStraightToMainTree('-',0,nil);

        //5o) "Make relative to special path...", we add the special path used by TC
        AddBatchOfMenuItems(rsMsgSpecialDirMkDCRel,0,IndexOfSpecialDirComptibleTC,1100,@SpecialDirMenuClick);

        //6o) "Make relative to special path...", if in Windows, we add the Windows special folder beginning with TC compatible ones and then the newer ones we introduce in DC
        {$IFDEF MSWINDOWS}
        AddBatchOfMenuItems(rsMsgSpecialDirMkTCTel,IndexOfSpecialDirComptibleTC,IndexOfNewVariableNotInTC,1100,@SpecialDirMenuClick);
        AddBatchOfMenuItems(rsMsgSpecialDirMkWnRel,IndexOfNewVariableNotInTC,IndexOfEnvironmentVariable,1100,@SpecialDirMenuClick);
        {$ENDIF}

        //7o)  "Make relative to special path...", then, the ones from environment variable
        AddBatchOfMenuItems(rsMsgSpecialDirMkEnvRel,IndexOfEnvironmentVariable,Count,1100,@SpecialDirMenuClick);

        //8o)  "Make relative to HotDir path...", then, the ones from hotdir
        AddStraightToMainTree(rsMsgSpecialDirMakeRelToHotDir, 0, nil);
        gDirectoryHotlist.PopulateMenuWithHotDir(miMainTree,@SpecialDirMenuClick,nil,mpPATHHELPER,TAGOFFSET_FORHOTDIRRELATIVEINPATHHELPER);
        AddStraightToMainTree('-',0,nil);

        //9o) Then add the item to make the path in absolute format
        AddStraightToMainTree(rsMsgSpecialDirMkAbso,1,@SpecialDirMenuClick);
        AddStraightToMainTree('-',0,nil);

        //10o) Then allow to indicate the one from the active and non-active panel
        AddStraightToMainTree(rsMsgSpecialDirAddActi,2,@SpecialDirMenuClick);
        AddStraightToMainTree(rsMsgSpecialDirAddNonActi,3,@SpecialDirMenuClick);

        //11o) Finally, offer the possibility to browse into folder
        AddStraightToMainTree(rsMsgSpecialDirBrowsSel,4,@SpecialDirMenuClick);
      end; //mp_PATHHELPER:

    mp_CHANGEDIR:
      begin
        AddStraightToMainTree(rsMsgSpecialDir,0,nil);
        mncmpMenuComponentToPopulate:=miMainTree;

        AddBatchOfMenuItems(rsMsgSpecialDirGotoDC,0,IndexOfSpecialDirComptibleTC,TAGOFFSET_FORCHANGETOSPECIALDIR,ProcedureIfChangeDirClick);
        {$IFDEF MSWINDOWS}
        AddBatchOfMenuItems(rsMsgSpecialDirGotoTC,IndexOfSpecialDirComptibleTC,IndexOfNewVariableNotInTC,TAGOFFSET_FORCHANGETOSPECIALDIR,ProcedureIfChangeDirClick);
        AddBatchOfMenuItems(rsMsgSpecialDirGotoOther,IndexOfNewVariableNotInTC,IndexOfEnvironmentVariable,TAGOFFSET_FORCHANGETOSPECIALDIR,ProcedureIfChangeDirClick);
        {$ENDIF}

        AddBatchOfMenuItems(rsMsgSpecialDirGotoEnvVar,IndexOfEnvironmentVariable,Count,TAGOFFSET_FORCHANGETOSPECIALDIR,ProcedureIfChangeDirClick);
      end; //mp_CHANGEDIR

  end; //case KindSpecialDirMenuPopulation of
end;

{ TSpecialDirList.SpecialDirMenuClick }
procedure TSpecialDirList.SpecialDirMenuClick(Sender: TObject);
  function GetCorrectPathForHotDirFromHints(AnyPath, WindowsVariableName, WindowsPathName:String):String;
  var
    SubWorkingPath,MaybeSubstitionPossible:String;
  begin
    result:=AnyPath;
    SubWorkingPath:=IncludeTrailingPathDelimiter(mbExpandFileName(AnyPath));
    MaybeSubstitionPossible:=ExtractRelativePath(IncludeTrailingPathDelimiter(WindowsPathName),SubWorkingPath);
    if MaybeSubstitionPossible<>SubWorkingPath then
      result:=IncludeTrailingPathDelimiter(WindowsVariableName)+MaybeSubstitionPossible;
  end;

var
  Dispatcher:longint; //Indicate wich menuitem user selected
  RememberFilename, OriginalPath, MaybeResultingOutputPath, sSelectedPath:string;
begin
  with Sender as TComponent do Dispatcher:=tag;
  OriginalPath:='';

  if fRecipientComponent.ClassType=TLabeledEdit then OriginalPath:=TLabeledEdit(fRecipientComponent).Text else
    if fRecipientComponent.ClassType=TFileNameEdit then OriginalPath:=TFileNameEdit(fRecipientComponent).FileName else
      if fRecipientComponent.ClassType=TEdit then OriginalPath:=TEdit(fRecipientComponent).Text else
        if fRecipientComponent.ClassType=TDirectoryEdit then OriginalPath:=TDirectoryEdit(fRecipientComponent).Text;

  if fRecipientType=pfFILE then
    begin
      RememberFilename:=ExtractFilename(OriginalPath);
      OriginalPath:=ExtractFilePath(OriginalPath);
    end;

  MaybeResultingOutputPath:=OriginalPath; //Let's play safe: returned path, by default, if nothing is trig, is the same as the original one, so, no change...

  case Dispatcher of
    1: //Make path absolute
      begin
        MaybeResultingOutputPath:=mbExpandFileName(OriginalPath);
      end;

    2: //Add path from active frame
      begin
        MaybeResultingOutputPath:=frmMain.ActiveFrame.CurrentLocation;
      end;

    3: //Add path from inactive frame
      begin
        MaybeResultingOutputPath:=frmMain.NotActiveFrame.CurrentLocation;
      end;

    4: //Browse and use selected path
      begin
        //by default, let's try to initialise dir browser to current dir value and if it's not present, let's take the current path of the active frame
        if MaybeResultingOutputPath='' then MaybeResultingOutputPath:=frmMain.ActiveFrame.CurrentPath;
        if SelectDirectory(rsSelectDir, mbExpandFileName(MaybeResultingOutputPath), sSelectedPath, False) then MaybeResultingOutputPath:=sSelectedPath;
      end;

    100..1099: //Use...
      begin
        MaybeResultingOutputPath:=gSpecialDirList.SpecialDir[Dispatcher-100].VariableName;
      end;

    1100..2099: //Make relative to...
      begin
        MaybeResultingOutputPath:=GetCorrectPathForHotDirFromHints(OriginalPath,gSpecialDirList.SpecialDir[Dispatcher-1100].VariableName,gSpecialDirList.SpecialDir[Dispatcher-1100].PathValue);
      end;

    TAGOFFSET_FORHOTDIRUSEINPATHHELPER..(TAGOFFSET_FORHOTDIRUSEINPATHHELPER+$FFFF):
      begin
        MaybeResultingOutputPath:=gDirectoryHotlist.HotDir[Dispatcher-TAGOFFSET_FORHOTDIRUSEINPATHHELPER].HotDirPath;
      end;

    TAGOFFSET_FORHOTDIRRELATIVEINPATHHELPER..(TAGOFFSET_FORHOTDIRRELATIVEINPATHHELPER+$FFFF):
      begin
        MaybeResultingOutputPath:=GetCorrectPathForHotDirFromHints(OriginalPath,gDirectoryHotlist.HotDir[Dispatcher-TAGOFFSET_FORHOTDIRRELATIVEINPATHHELPER].HotDirPath,gDirectoryHotlist.HotDir[Dispatcher-TAGOFFSET_FORHOTDIRRELATIVEINPATHHELPER].HotDirPath);
      end;
  end;

  if (MaybeResultingOutputPath<>'') then MaybeResultingOutputPath:=IncludeTrailingPathDelimiter(MaybeResultingOutputPath);

  if fRecipientType=pfFILE then MaybeResultingOutputPath:=MaybeResultingOutputPath+RememberFilename;

  if lowercase(OriginalPath)<>lowercase(MaybeResultingOutputPath) then
    begin
      if fRecipientComponent.ClassType=TLabeledEdit then TLabeledEdit(fRecipientComponent).Text:=MaybeResultingOutputPath else
        if fRecipientComponent.ClassType=TFileNameEdit then TFileNameEdit(fRecipientComponent).FileName:=MaybeResultingOutputPath else
          if fRecipientComponent.ClassType=TEdit then TEdit(fRecipientComponent).Text:=MaybeResultingOutputPath else
            if fRecipientComponent.ClassType=TDirectoryEdit then TDirectoryEdit(fRecipientComponent).Text:=MaybeResultingOutputPath;
    end;
end;

{ TSpecialDirList.PopulateSpecialDir }
procedure TSpecialDirList.PopulateSpecialDir;
var
  NbOfEnvVar, IndexVar, EqualPos:integer;
  EnvVar, EnvValue:string;
  LocalSpecialDir:TSpecialDir;
  MyYear,MyMonth,MyDay:word;

  {$IFDEF MSWINDOWS}
  procedure GetAndStoreSpecialDirInfos(SpecialConstant:integer; VariableName:string; ParamKindOfSpecialDir: TKindOfSpecialDir);
  var
    FilePath: array [0..Pred(MAX_PATH)] of WideChar;
  begin
    FillChar(FilePath, MAX_PATH, 0);
    SHGetSpecialFolderPathW(0, @FilePath[0], SpecialConstant, FALSE);
    if FilePath<>'' then
    begin
      LocalSpecialDir:=TSpecialDir.Create;
      LocalSpecialDir.fDispatcher:=ParamKindOfSpecialDir;
      LocalSpecialDir.VariableName:=VariableName;
      LocalSpecialDir.PathValue:= UTF16ToUTF8(UnicodeString(FilePath));
      Add(LocalSpecialDir);
    end;
  end;

  procedure GetAndStoreKnownDirInfos(const rfid: TGUID; VariableName: String; ParamKindOfSpecialDir: TKindOfSpecialDir);
  var
    FilePath: String;
  begin
    if GetKnownFolderPath(rfid, FilePath) then
    begin
      LocalSpecialDir:= TSpecialDir.Create;
      LocalSpecialDir.fDispatcher:= ParamKindOfSpecialDir;
      LocalSpecialDir.VariableName:= VariableName;
      LocalSpecialDir.PathValue:= FilePath;
      Add(LocalSpecialDir);
    end;
  end;
  {$ENDIF}

begin
  //Since in configuration we might need to recall this routine, let's clear the list
  if gSpecialDirList.Count>0 then gSpecialDirList.Clear;

  LocalSpecialDir:=TSpecialDir.Create;
  LocalSpecialDir.fDispatcher:=sd_DOUBLECOMMANDER;
  LocalSpecialDir.VariableName:=VARDELIMITER+'COMMANDER_PATH'+VARDELIMITER_END;
  LocalSpecialDir.PathValue:=ExcludeTrailingPathDelimiter(gpExePath);
  Add(LocalSpecialDir);

  LocalSpecialDir:=TSpecialDir.Create;
  LocalSpecialDir.fDispatcher:=sd_DOUBLECOMMANDER;
  LocalSpecialDir.VariableName:=VARDELIMITER+'DC_CONFIG_PATH'+VARDELIMITER_END;
  LocalSpecialDir.PathValue:=ExcludeTrailingPathDelimiter(gpCfgDir);
  Add(LocalSpecialDir);

  LocalSpecialDir:=TSpecialDir.Create;
  LocalSpecialDir.fDispatcher:=sd_DOUBLECOMMANDER;
  LocalSpecialDir.VariableName:=ENVVARTODAYSDATE;
  LocalSpecialDir.PathValue:=Format('%d-%2.2d-%2.2d',[1980,01,01]); //Don't worry for the exact date: the routine "ReplaceEnvVars" will substitue for the correct date value
  Add(LocalSpecialDir);

  DecodeDate(now,MyYear,MyMonth,MyDay);
  LocalSpecialDir:=TSpecialDir.Create;
  LocalSpecialDir.fDispatcher:=sd_DOUBLECOMMANDER;
  LocalSpecialDir.VariableName:=VARDELIMITER+'CURRENTUSER'+VARDELIMITER_END;
  LocalSpecialDir.PathValue:=GetCurrentUserName;
  Add(LocalSpecialDir);

  IndexOfSpecialDirComptibleTC:=count;

  {$IFDEF MSWINDOWS}
  //Done with the help of: http://stackoverflow.com/questions/471123/accessing-localapplicationdata-equivalent-in-delphi
  //Also with the help of: http://www.ghisler.ch/board/viewtopic.php?t=12709
  //The following ones are compatible with Total Commander
  //The first three ones are the most susceptible to be used so to speed up time when searching, we'll placed them first in the list
  //Please note that TC is using this convention for variable name: %$varname%
  GetAndStoreSpecialDirInfos(CSIDL_PERSONAL,'%$PERSONAL%',sd_WINDOWSTC);
  GetAndStoreSpecialDirInfos(CSIDL_DESKTOP,'%$DESKTOP%',sd_WINDOWSTC);
  GetAndStoreSpecialDirInfos(CSIDL_APPDATA,'%$APPDATA%',sd_WINDOWSTC);
  GetAndStoreSpecialDirInfos(CSIDL_COMMON_APPDATA,'%$COMMON_APPDATA%',sd_WINDOWSTC);
  GetAndStoreSpecialDirInfos(CSIDL_COMMON_DESKTOPDIRECTORY,'%$COMMON_DESKTOPDIRECTORY%',sd_WINDOWSTC);
  GetAndStoreSpecialDirInfos(CSIDL_COMMON_DOCUMENTS,'%$COMMON_DOCUMENTS%',sd_WINDOWSTC);
  GetAndStoreSpecialDirInfos(CSIDL_COMMON_PICTURES,'%$COMMON_PICTURES%',sd_WINDOWSTC);
  GetAndStoreSpecialDirInfos(CSIDL_COMMON_PROGRAMS,'%$COMMON_PROGRAMS%',sd_WINDOWSTC);
  GetAndStoreSpecialDirInfos(CSIDL_COMMON_STARTMENU,'%$COMMON_STARTMENU%',sd_WINDOWSTC);
  GetAndStoreSpecialDirInfos(CSIDL_COMMON_STARTUP,'%$COMMON_STARTUP%',sd_WINDOWSTC);
  GetAndStoreSpecialDirInfos(CSIDL_FONTS,'%$FONTS%',sd_WINDOWSTC);
  GetAndStoreSpecialDirInfos(CSIDL_LOCAL_APPDATA,'%$LOCAL_APPDATA%',sd_WINDOWSTC);
  GetAndStoreSpecialDirInfos(CSIDL_MYMUSIC,'%$MYMUSIC%',sd_WINDOWSTC);
  GetAndStoreSpecialDirInfos(CSIDL_MYPICTURES,'%$MYPICTURES%',sd_WINDOWSTC);
  GetAndStoreSpecialDirInfos(CSIDL_MYVIDEO,'%$MYVIDEO%',sd_WINDOWSTC);
  GetAndStoreSpecialDirInfos(CSIDL_PROGRAMS,'%$PROGRAMS%',sd_WINDOWSTC);
  GetAndStoreSpecialDirInfos(CSIDL_STARTMENU,'%$STARTMENU%',sd_WINDOWSTC);
  GetAndStoreSpecialDirInfos(CSIDL_STARTUP,'%$STARTUP%',sd_WINDOWSTC);

  if Win32MajorVersion > 5 then
  begin
    GetAndStoreKnownDirInfos(FOLDERID_AccountPictures, '%$AccountPictures%', sd_WINDOWSTC);
    GetAndStoreKnownDirInfos(FOLDERID_CameraRoll, '%$CameraRoll%', sd_WINDOWSTC);
    GetAndStoreKnownDirInfos(FOLDERID_Contacts, '%$Contacts%', sd_WINDOWSTC);
    GetAndStoreKnownDirInfos(FOLDERID_DeviceMetadataStore, '%$DeviceMetadataStore%', sd_WINDOWSTC);
    GetAndStoreKnownDirInfos(FOLDERID_Downloads, '%$Downloads%', sd_WINDOWSTC);
    GetAndStoreKnownDirInfos(FOLDERID_GameTasks, '%$GameTasks%', sd_WINDOWSTC);
    GetAndStoreKnownDirInfos(FOLDERID_ImplicitAppShortcuts, '%$ImplicitAppShortcuts%', sd_WINDOWSTC);
    GetAndStoreKnownDirInfos(FOLDERID_Libraries, '%$Libraries%', sd_WINDOWSTC);
    GetAndStoreKnownDirInfos(FOLDERID_Links, '%$Links%', sd_WINDOWSTC);
    GetAndStoreKnownDirInfos(FOLDERID_LocalAppDataLow, '%$LocalAppDataLow%', sd_WINDOWSTC);
    GetAndStoreKnownDirInfos(FOLDERID_OriginalImages, '%$OriginalImages%', sd_WINDOWSTC);
    GetAndStoreKnownDirInfos(FOLDERID_PhotoAlbums, '%$PhotoAlbums%', sd_WINDOWSTC);
    GetAndStoreKnownDirInfos(FOLDERID_Playlists, '%$Playlists%', sd_WINDOWSTC);
    GetAndStoreKnownDirInfos(FOLDERID_ProgramFilesCommonX64, '%$ProgramFilesCommonX64%', sd_WINDOWSTC);
    GetAndStoreKnownDirInfos(FOLDERID_ProgramFilesX64, '%$ProgramFilesX64%', sd_WINDOWSTC);
    GetAndStoreKnownDirInfos(FOLDERID_Public, '%$Public%', sd_WINDOWSTC);
    GetAndStoreKnownDirInfos(FOLDERID_PublicDownloads, '%$PublicDownloads%', sd_WINDOWSTC);
    GetAndStoreKnownDirInfos(FOLDERID_PublicGameTasks, '%$PublicGameTasks%', sd_WINDOWSTC);
    GetAndStoreKnownDirInfos(FOLDERID_PublicLibraries, '%$PublicLibraries%', sd_WINDOWSTC);
    GetAndStoreKnownDirInfos(FOLDERID_PublicRingtones, '%$PublicRingtones%', sd_WINDOWSTC);
    GetAndStoreKnownDirInfos(FOLDERID_PublicUserTiles, '%$PublicUserTiles%', sd_WINDOWSTC);
    GetAndStoreKnownDirInfos(FOLDERID_QuickLaunch, '%$QuickLaunch%', sd_WINDOWSTC);
    GetAndStoreKnownDirInfos(FOLDERID_Ringtones, '%$Ringtones%', sd_WINDOWSTC);
    GetAndStoreKnownDirInfos(FOLDERID_RoamedTileImages, '%$RoamedTileImages%', sd_WINDOWSTC);
    GetAndStoreKnownDirInfos(FOLDERID_RoamingTiles, '%$RoamingTiles%', sd_WINDOWSTC);
    GetAndStoreKnownDirInfos(FOLDERID_SampleMusic, '%$SampleMusic%', sd_WINDOWSTC);
    GetAndStoreKnownDirInfos(FOLDERID_SamplePictures, '%$SamplePictures%', sd_WINDOWSTC);
    GetAndStoreKnownDirInfos(FOLDERID_SamplePlaylists, '%$SamplePlaylists%', sd_WINDOWSTC);
    GetAndStoreKnownDirInfos(FOLDERID_SampleVideos, '%$SampleVideos%', sd_WINDOWSTC);
    GetAndStoreKnownDirInfos(FOLDERID_SavedGames, '%$SavedGames%', sd_WINDOWSTC);
    GetAndStoreKnownDirInfos(FOLDERID_SavedPictures, '%$SavedPictures%', sd_WINDOWSTC);
    GetAndStoreKnownDirInfos(FOLDERID_SavedSearches, '%$SavedSearches%', sd_WINDOWSTC);
    GetAndStoreKnownDirInfos(FOLDERID_Screenshots, '%$Screenshots%', sd_WINDOWSTC);
    GetAndStoreKnownDirInfos(FOLDERID_SearchHistory, '%$SearchHistory%', sd_WINDOWSTC);
    GetAndStoreKnownDirInfos(FOLDERID_SearchTemplates, '%$SearchTemplates%', sd_WINDOWSTC);
    GetAndStoreKnownDirInfos(FOLDERID_SidebarDefaultParts, '%$SidebarDefaultParts%', sd_WINDOWSTC);
    GetAndStoreKnownDirInfos(FOLDERID_SidebarParts, '%$SidebarParts%', sd_WINDOWSTC);
    GetAndStoreKnownDirInfos(FOLDERID_SkyDrive, '%$SkyDrive%', sd_WINDOWSTC);
    GetAndStoreKnownDirInfos(FOLDERID_SkyDriveCameraRoll, '%$SkyDriveCameraRoll%', sd_WINDOWSTC);
    GetAndStoreKnownDirInfos(FOLDERID_SkyDriveDocuments, '%$SkyDriveDocuments%', sd_WINDOWSTC);
    GetAndStoreKnownDirInfos(FOLDERID_SkyDrivePictures, '%$SkyDrivePictures%', sd_WINDOWSTC);
    GetAndStoreKnownDirInfos(FOLDERID_UserPinned, '%$UserPinned%', sd_WINDOWSTC);
    GetAndStoreKnownDirInfos(FOLDERID_UserProfiles, '%$UserProfiles%', sd_WINDOWSTC);
    GetAndStoreKnownDirInfos(FOLDERID_UserProgramFiles, '%$UserProgramFiles%', sd_WINDOWSTC);
    GetAndStoreKnownDirInfos(FOLDERID_UserProgramFilesCommon, '%$UserProgramFilesCommon%', sd_WINDOWSTC);
  end;

  //These ones are new ones non-compatible on 2014-05-21 with Total Commander
  IndexOfNewVariableNotInTC:=count;
  GetAndStoreSpecialDirInfos(CSIDL_ADMINTOOLS,'%$ADMINTOOLS%',sd_WINDOWSNONTC); // { <user name>\Start Menu\Programs\Administrative Tools }
  GetAndStoreSpecialDirInfos(CSIDL_ALTSTARTUP,'%$ALTSTARTUP%',sd_WINDOWSNONTC); //{ non localized startup }
  GetAndStoreSpecialDirInfos(CSIDL_BITBUCKET,'%$BITBUCKET%',sd_WINDOWSNONTC); //{ <desktop>\Recycle Bin }
  GetAndStoreSpecialDirInfos(CSIDL_CDBURN_AREA,'%$CDBURN_AREA%',sd_WINDOWSNONTC); // { USERPROFILE\Local Settings\Application Data\Microsoft\CD Burning }
  GetAndStoreSpecialDirInfos(CSIDL_COMMON_ADMINTOOLS,'%$COMMON_ADMINTOOLS%',sd_WINDOWSNONTC); // { All Users\Start Menu\Programs\Administrative Tools }
  GetAndStoreSpecialDirInfos(CSIDL_COMMON_ALTSTARTUP,'%$COMMON_ALTSTARTUP%',sd_WINDOWSNONTC); // { non localized common startup }
  GetAndStoreSpecialDirInfos(CSIDL_COMMON_FAVORITES,'%$COMMON_FAVORITES%',sd_WINDOWSNONTC); //
  GetAndStoreSpecialDirInfos(CSIDL_COMMON_MUSIC,'%$COMMON_MUSIC%',sd_WINDOWSNONTC); // { All Users\My Music }
  GetAndStoreSpecialDirInfos(CSIDL_COMMON_OEM_LINKS,'%$COMMON_OEM_LINKS%',sd_WINDOWSNONTC); // { Links to All Users OEM specific apps }
  GetAndStoreSpecialDirInfos(CSIDL_COMMON_TEMPLATES,'%$COMMON_TEMPLATES%',sd_WINDOWSNONTC); // { All Users\Templates }
  GetAndStoreSpecialDirInfos(CSIDL_COMMON_VIDEO,'%$COMMON_VIDEO%',sd_WINDOWSNONTC); // { All Users\My Video }
  GetAndStoreSpecialDirInfos(CSIDL_COMPUTERSNEARME,'%$COMPUTERSNEARME%',sd_WINDOWSNONTC); // { Computers Near Me (computered from Workgroup membership) }
  GetAndStoreSpecialDirInfos(CSIDL_CONNECTIONS,'%$CONNECTIONS%',sd_WINDOWSNONTC); // { Network and Dial-up Connections }
  GetAndStoreSpecialDirInfos(CSIDL_CONTROLS,'%$CONTROLS%',sd_WINDOWSNONTC); //{ My Computer\Control Panel }
  GetAndStoreSpecialDirInfos(CSIDL_COOKIES,'%$COOKIES%',sd_WINDOWSNONTC); //
  GetAndStoreSpecialDirInfos(CSIDL_DESKTOPDIRECTORY,'%$DESKTOPDIRECTORY%',sd_WINDOWSNONTC); //{ <user name>\Desktop }
  GetAndStoreSpecialDirInfos(CSIDL_DRIVES,'%$DRIVES%',sd_WINDOWSNONTC); //{ My Computer }
  GetAndStoreSpecialDirInfos(CSIDL_FAVORITES,'%$FAVORITES%',sd_WINDOWSNONTC); //{ <user name>\Favorites }
  GetAndStoreSpecialDirInfos(CSIDL_HISTORY,'%$HISTORY%',sd_WINDOWSNONTC); //
  GetAndStoreSpecialDirInfos(CSIDL_INTERNET,'%$INTERNET%',sd_WINDOWSNONTC); //{ Internet Explorer (icon on desktop) }
  GetAndStoreSpecialDirInfos(CSIDL_INTERNET_CACHE,'%$INTERNET_CACHE%',sd_WINDOWSNONTC); //
  GetAndStoreSpecialDirInfos(CSIDL_NETHOOD,'%$NETHOOD%',sd_WINDOWSNONTC); //{ <user name>\nethood }
  GetAndStoreSpecialDirInfos(CSIDL_NETWORK,'%$NETWORK%',sd_WINDOWSNONTC); //{ Network Neighborhood (My Network Places) }
  GetAndStoreSpecialDirInfos(CSIDL_PERSONAL,'%$PERSONALXP%',sd_WINDOWSNONTC); //{ My Documents.  This is equivalent to CSIDL_MYDOCUMENTS in XP and above }
  GetAndStoreSpecialDirInfos(CSIDL_PRINTERS,'%$PRINTERS%',sd_WINDOWSNONTC); //{ My Computer\Printers }
  GetAndStoreSpecialDirInfos(CSIDL_PRINTHOOD,'%$PRINTHOOD%',sd_WINDOWSNONTC); //{ <user name>\PrintHood }
  GetAndStoreSpecialDirInfos(CSIDL_PROFILE,'%$PROFILE%',sd_WINDOWSNONTC); // { USERPROFILE }
  //GetAndStoreSpecialDirInfos(CSIDL_PROFILES,'%PROFILES%'); //Does not work everywhere, let's remove it.
  GetAndStoreSpecialDirInfos(CSIDL_PROGRAM_FILES,'%$PROGRAM_FILES%',sd_WINDOWSNONTC); // { C:\Program Files }
  GetAndStoreSpecialDirInfos(CSIDL_PROGRAM_FILESX86,'%$PROGRAM_FILESX86%',sd_WINDOWSNONTC); // { x86 C:\Program Files on RISC }
  GetAndStoreSpecialDirInfos(CSIDL_PROGRAM_FILES_COMMON,'%$PROGRAM_FILES_COMMON%',sd_WINDOWSNONTC); // { C:\Program Files\Common }
  GetAndStoreSpecialDirInfos(CSIDL_PROGRAM_FILES_COMMONX86,'%$PROGRAM_FILES_COMMONX86%',sd_WINDOWSNONTC); // { x86 C:\Program Files\Common on RISC }
  GetAndStoreSpecialDirInfos(CSIDL_RECENT,'%$RECENT%',sd_WINDOWSNONTC); //{ <user name>\Recent }
  GetAndStoreSpecialDirInfos(CSIDL_RESOURCES,'%$RESOURCES%',sd_WINDOWSNONTC); // { Resource Directory }
  GetAndStoreSpecialDirInfos(CSIDL_RESOURCES_LOCALIZED,'%$RESOURCES_LOCALIZED%',sd_WINDOWSNONTC); // { Localized Resource Directory }
  GetAndStoreSpecialDirInfos(CSIDL_SENDTO,'%$SENDTO%',sd_WINDOWSNONTC); //{ <user name>\SendTo }
  GetAndStoreSpecialDirInfos(CSIDL_SYSTEM,'%$SYSTEM%',sd_WINDOWSNONTC); // { GetSystemDirectory() }
  GetAndStoreSpecialDirInfos(CSIDL_SYSTEMX86,'%$SYSTEMX86%',sd_WINDOWSNONTC); //{ x86 system directory on RISC }
  GetAndStoreSpecialDirInfos(CSIDL_TEMPLATES,'%$TEMPLATES%',sd_WINDOWSNONTC); //
  GetAndStoreSpecialDirInfos(CSIDL_WINDOWS,'%$WINDOWS%',sd_WINDOWSNONTC); // { GetWindowsDirectory() }

  if Win32MajorVersion > 5 then
  begin
    GetAndStoreKnownDirInfos(FOLDERID_ApplicationShortcuts, '%$ApplicationShortcuts%', sd_WINDOWSNONTC);
  end;
  {$ENDIF}

  IndexOfEnvironmentVariable:=count;
  //Let's store environment variable. It will be possible to search in faster eventually, if required
  NbOfEnvVar:= GetEnvironmentVariableCount;
  if NbOfEnvVar>0 then
    begin
      for IndexVar:= 1 to NbOfEnvVar do
      begin
        EnvVar:= mbGetEnvironmentString(IndexVar);

        EqualPos:= PosEx('=', EnvVar, 2);
        if EqualPos <> 0 then
          begin
            EnvValue:=copy(EnvVar, EqualPos + 1, MaxInt);
            {$IFDEF MSWINDOWS}
            if (not gShowOnlyValidEnv) OR (ExtractFileDrive(EnvValue)<>'') then
            {$ELSE}
            if (not gShowOnlyValidEnv) OR (UTF8LeftStr(EnvValue,1)=PathDelim) then
            {$ENDIF}
            begin
              LocalSpecialDir:=TSpecialDir.Create;
              LocalSpecialDir.fDispatcher:=sd_ENVIRONMENTVARIABLE;
              LocalSpecialDir.VariableName:=VARDELIMITER+copy(EnvVar, 1, EqualPos - 1)+VARDELIMITER_END;
              LocalSpecialDir.PathValue:=ExcludeTrailingPathDelimiter(EnvValue); // Other path variable values, like the few from DC or the ones from Windows, don't have the trailing path delimiter. So we do the same with path from environment variables.
              Add(LocalSpecialDir);
            end;
          end;
      end;
    end;

  Sort(@CompareSpecialDir);
end;

{ TSpecialDirList.SetSpecialDirRecipientAndItsType }
procedure TSpecialDirList.SetSpecialDirRecipientAndItsType(ParamComponent:TComponent; ParamKindOfPathFile:TKindOfPathFile);
begin
  fRecipientComponent:=ParamComponent;
  fRecipientType:=ParamKindOfPathFile;
end;

function GetMenuCaptionAccordingToOptions(const WantedCaption:string; const MatchingPath:string):string;
  begin
    result:=WantedCaption;
    if gShowPathInPopup then
    begin
      if UTF8length(MatchingPath)<100 then
        result:=result + ' - ['+IncludeTrailingPathDelimiter(MatchingPath)+']'
      else
        result:=result + ' - ['+IncludeTrailingPathDelimiter('...'+UTF8RightStr(MatchingPath,100))+']';
    end;
  end;

procedure LoadWindowsSpecialDir;
begin
  gSpecialDirList:=TSpecialDirList.Create;
  gSpecialDirList.PopulateSpecialDir;
end;

end.

