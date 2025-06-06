{
   Double Commander
   -------------------------------------------------------------------------
   Base class for file views which have a main control with a list of files.

   Copyright (C) 2012  Przemyslaw Nagay (cobines@gmail.com)
   Copyright (C) 2015-2023  Alexander Koblov (alexx2000@mail.ru)

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
}

unit uFileViewWithMainCtrl;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Controls, ExtCtrls, StdCtrls, LCLType, LMessages, EditBtn,
  Graphics, LCLVersion,
  uFile, uDisplayFile,
  uFileViewWorker,
  uOrderedFileView,
  uFileView,
  uDragDropEx,
  uFileViewNotebook,
  uDebug;

type

  TFileViewOnDrawCell = procedure(Sender: TFileView; aCol, aRow: Integer;
    aRect: TRect; focused: Boolean; aFile: TDisplayFile) of object;

  TRenameFileActionType=(rfatName,rfatExt,rfatFull,rfatToSeparators,rfatNextSeparated);

  TRenameFileEditInfo=record
    LenNam:integer;    // length of renaming file name
    LenExt:integer;    // length of renaming file ext
    LenFul:integer;    // full length of renaming file name with ext and dot

    CycleFinished: Boolean;
    UserManualEdit:boolean; // true if user press a key or click/select part of filename, false - if pressed F2(or assigned key)

    LastAction:TRenameFileActionType;  // need for organize correct cycle Name-FullName-Ext (or FullName-Name-Ext)
  end;

  { TEditButtonEx }

  TEditButtonEx = class(TEditButton)
  private
    procedure handleSpecialKeys( var Key: Word );
    function GetFont: TFont;
    procedure SetFont(AValue: TFont);
  protected
    // Workaround: https://gitlab.com/freepascal.org/lazarus/lazarus/-/issues/36006
{$IF (DEFINED(LCLQT) or DEFINED(LCLQT5) or DEFINED(LCLQT6)) and (LCL_FULLVERSION < 3020000)}
    procedure Hack(Data: PtrInt);
    procedure EditExit; override;
{$ENDIF}
    function CalcButtonVisible: Boolean; override;
    function GetDefaultGlyphName: String; override;
    procedure EditKeyDown(var Key: word; Shift: TShiftState); override;
  public
    onKeySWITCH: TKeyEvent;
    onKeyESCAPE: TNotifyEvent;
    onKeyRETURN: TNotifyEvent;
    property Font: TFont read GetFont write SetFont;
  end;

  { TFileViewWithMainCtrl }

  TFileViewWithMainCtrl = class(TOrderedFileView)
  private
{$IFDEF LCLGTK2}
    FLastDoubleClickTime : TDateTime;
{$ENDIF}
    FMainControl: TWinControl;

    { Events for drag&drop from external applications }
    function OnExDragBegin: Boolean;
    function OnExDragEnd: Boolean;
    function OnExDragEnter(var DropEffect: TDropEffect; ScreenPoint: TPoint): Boolean;
    function OnExDragOver(var DropEffect: TDropEffect; ScreenPoint: TPoint): Boolean;
    function OnExDrop(const FileNamesList: TStringList; DropEffect: TDropEffect; ScreenPoint: TPoint): Boolean;
    function OnExDragLeave: Boolean;

    procedure SetMainControl(AValue: TWinControl);
    procedure tmContextMenuTimer(Sender: TObject);
    // Needed for rename on mouse
    procedure tmRenameFileTimer(Sender: TObject);
    // If internal dragging is currently in effect, this function
    // stops internal dragging and starts external.
    procedure TransformDraggingToExternal(ScreenPoint: TPoint);

    procedure edtRenameEnter(Sender: TObject);
    procedure edtRenameExit(Sender: TObject);
    procedure edtRenameButtonClick(Sender: TObject);
    procedure edtRenameMouseDown(Sender: TObject; Button: TMouseButton;Shift: TShiftState; X, Y: Integer);

{$IFDEF LCLWIN32}
    procedure edtRenameKeyDown(Sender: TObject; var Key: word; Shift: TShiftState);
{$ENDIF}
    procedure edtRenameOnKeyESCAPE(Sender: TObject);
    procedure edtRenameOnKeyRETURN(Sender: TObject);
    procedure edtRenameOnKeySwitch(Sender: TObject; var Key: Word; Shift: TShiftState);
  protected
    edtRename: TEditButtonEx;
    FRenameFile: TFile;
    FRenFile:TRenameFileEditInfo;
    FRenTags:string;  // rename separators

    FWindowProc: TWndMethod;
    // Used to register as a drag and drop source and target.
    FDragDropSource: uDragDropEx.TDragDropSource;
    FDragDropTarget: uDragDropEx.TDragDropTarget;
    FHintFileIndex: PtrInt;
    FMainControlLastMouseButton: TMouseButton; // Mouse button that initiated dragging
    {en
       Used to check if button-up was received after button-down
       or after dropping something after dragging with right mouse button.
    }
    FMainControlMouseDown: Boolean;
    FMainControlMouseDownPoint: TPoint;
    FMouseSelectionStartIndex: Integer;
    FMouseSelectionLastState: Boolean;
    FDragStartPoint: TPoint;
    FDragFileIndex: PtrInt;
    FDropFileIndex: PtrInt;
    FStartDrag: Boolean;
    tmContextMenu: TTimer;
    tmMouseScroll: TTimer;
    // Needed for rename on mouse
    FRenameFileIndex: PtrInt;
    tmRenameFile: TTimer;
    FMouseRename: Boolean;
    FMouseFocus: Boolean;
{$IFNDEF LCLWIN32}
    FMouseEnter: Boolean;
{$ENDIF}
    procedure AfterChangePath; override;
    // Simulates releasing mouse button that started a dragging operation,
    // but was released in another window or another application.
    procedure ClearAfterDragDrop; virtual;
    procedure CreateDefault(AOwner: TWinControl); override;
    procedure DisplayFileListChanged; override;
    {en
       Changes drawing colors depending on if this panel is active.
    }
    procedure DoActiveChanged; override;
    procedure DoLoadingFileListLongTime; override;
    procedure DoUpdateView; override;
    procedure FinalizeDragDropEx(AControl: TWinControl);
    {en
       Retrieves file index under mouse cursor.
       @param(X, Y
              Should be client coordinates of MainControl.)
       @param(AtFileList
              Whether X, Y point to the filelist, not at specific file but at empty space.
              If AtFileList is @false then X, Y point somewhere outside the file list.)
    }
    function GetFileIndexFromCursor(X, Y: Integer; out AtFileList: Boolean): PtrInt; virtual; abstract;
    procedure InitializeDragDropEx(AControl: TWinControl);
    procedure MouseScrollTimer(Sender: TObject); virtual; abstract;
    {en
       Returns @true if currently selecting with right mouse button.
    }
    function IsMouseSelecting: Boolean; inline;
    procedure MainControlDblClick(Sender: TObject);
    procedure DoMainControlFileWork;
    procedure MouseStateReset;
    procedure MainControlQuadClick(Sender: TObject);
    procedure MainControlDragDrop(Sender, Source: TObject; X, Y: Integer);
    procedure MainControlDragOver(Sender, Source: TObject; X, Y: Integer; State: TDragState; var Accept: Boolean);
    procedure MainControlEndDrag(Sender, Target: TObject; X, Y: Integer);
    procedure MainControlEnter(Sender: TObject);
    procedure MainControlExit(Sender: TObject);
    procedure MainControlKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure MainControlKeyUp(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure MainControlMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure MainControlMouseLeave(Sender: TObject);
    procedure MainControlMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
    procedure MainControlMouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure MainControlShowHint(Sender: TObject; HintInfo: PHintInfo);
    procedure MainControlUTF8KeyPress(Sender: TObject; var UTF8Key: TUTF8Char);
    procedure MainControlResize(Sender: TObject);
    procedure MainControlWindowProc(var TheMessage: TLMessage);
    {en
       Updates the drop row index, which is used to draw a rectangle
       on directories during drag&drop operations.
    }
    procedure SetDropFileIndex(NewFileIndex: PtrInt);
    function GetIconRect(FileIndex: PtrInt): TRect; virtual;
    procedure WorkerStarting(const Worker: TFileViewWorker); override;
    procedure WorkerFinished(const Worker: TFileViewWorker); override;

    procedure ShowRenameFileEditInitSelect(Data: PtrInt);
    procedure ShowRenameFileEdit(var AFile: TFile); virtual;
    procedure UpdateRenameFileEditPosition; virtual;
    procedure RenameSelectPart(AActionType:TRenameFileActionType); virtual;

    property MainControl: TWinControl read FMainControl write SetMainControl;

{$IFDEF LCLGTK2}
    function TooManyDoubleClicks: Boolean;
{$ENDIF}

  public
    destructor Destroy; override;
    procedure DoDragDropOperation(Operation: TDragDropOperation;
                                  var DropParams: TDropParams); override;
    function Focused: Boolean; override;
    procedure SetFocus; override;
    procedure SetDragCursor(Shift: TShiftState); override;

    procedure UpdateColor; override;

  published
    procedure cm_RenameOnly(const Params: array of string);
    procedure cm_ContextMenu(const Params: array of string);
  end;

implementation

uses
{$IF DEFINED(LCLGTK2)}
  Gtk2Proc,  // for ReleaseMouseCapture
  GTK2Globals,  // for DblClickTime
{$ENDIF}
  LCLIntf, LCLProc, LazUTF8, Forms, Dialogs, Buttons, DCOSUtils, DCStrUtils,
  fMain, uShowMsg, uLng, uFileProperty, uFileSource, uFileSourceOperationTypes,
  uGlobs, uInfoToolTip, uFileSystemFileSource, uFileSourceUtil,
  uArchiveFileSourceUtil, uFormCommands, uKeyboard, uFileSourceSetFilePropertyOperation,
  uFileSystemWatcher;

type
  TControlHandlersHack = class(TWinControl)
  end;

{ TEditButtonEx }

procedure TEditButtonEx.EditKeyDown(var Key: Word; Shift: TShiftState);
begin
  inherited EditKeyDown(Key, Shift);

  case Key of
    VK_UP,
    VK_DOWN,
    VK_ESCAPE,
    VK_RETURN,
    VK_SELECT:
      handleSpecialKeys( Key );
  end;

{$IFDEF LCLGTK2}
  // Workaround for GTK2 - up and down arrows moving through controls.
  if Key in [VK_UP, VK_DOWN] then Key := 0;
{$ENDIF}
end;

procedure TEditButtonEx.handleSpecialKeys(var Key: Word);
begin
  if Key = VK_ESCAPE then begin
    if Assigned(onKeyESCAPE) then onKeyESCAPE( self );
  end else if Key in [VK_RETURN, VK_SELECT] then begin
    if Assigned(onKeyRETURN) then onKeyRETURN( self );
  end else begin
    if Assigned(onKeySWITCH) then onKeySWITCH( Self, Key, [] );
  end;
end;

function TEditButtonEx.GetFont: TFont;
begin
  Result:= BaseEditor.Font;
end;

procedure TEditButtonEx.SetFont(AValue: TFont);
begin
  BaseEditor.Font:= AValue;
end;

{$IF (DEFINED(LCLQT) or DEFINED(LCLQT5) or DEFINED(LCLQT6)) and (LCL_FULLVERSION < 3020000)}
procedure TEditButtonEx.Hack(Data: PtrInt);
begin
  if (csClicked in Button.ControlState) then
  begin
    BuddyClick;
    Button.ControlState:= Button.ControlState - [csClicked];
  end;
  inherited EditExit;
end;

procedure TEditButtonEx.EditExit;
begin
  Application.QueueAsyncCall(@Hack, 0);
end;
{$ENDIF}

function TEditButtonEx.GetDefaultGlyphName: String;
begin
  Result:= BitBtnResNames[idButtonOk];
end;

function TEditButtonEx.CalcButtonVisible: Boolean;
begin
  Result:= (inherited CalcButtonVisible) and gInplaceRenameButton;
end;

{ TFileViewWithMainCtrl }


{$IFDEF LCLWIN32}
procedure TFileViewWithMainCtrl.edtRenameKeyDown(Sender: TObject; var Key: word; Shift: TShiftState);
begin
  case Key of
    // Workaround for Win32 - right arrow must clear selection at first move.
    VK_RIGHT:
      begin
        if (Win32MajorVersion < 10) and (Shift = []) and (edtRename.SelLength > 0) then
        begin
          Key := edtRename.CaretPos.X;
          edtRename.SelLength := 0;
          edtRename.CaretPos := Classes.Point(Key, 0);
          Key := 0;
        end;
        FRenFile.UserManualEdit:=True; // user begin manual edit - no need cycle Name,Ext,FullName selection
      end;
     VK_LEFT:
        FRenFile.UserManualEdit:=True; // user begin manual edit - no need cycle Name,Ext,FullName selection
  end;
end;
{$ENDIF}

procedure TFileViewWithMainCtrl.edtRenameOnKeyESCAPE(Sender: TObject);
begin
  edtRename.Visible:=False;
  SetFocus;
end;

procedure TFileViewWithMainCtrl.edtRenameOnKeyRETURN(Sender: TObject);
var
  NewFileName: String;
  OldFileName: String;
begin
  NewFileName := edtRename.Text;
  OldFileName := ExtractFileName(edtRename.Hint);

  try
    case uFileSourceUtil.RenameFile(FileSource, FRenameFile, NewFileName, True, True) of
      sfprSuccess:
        begin
          // FRenameFile is nil when a file list
          // already updated by the real 'rename' event
          if FlatView and Assigned(FRenameFile) and (TFileSystemWatcher.Features * [fsfFlatView] = []) then
          begin
            PushRenameEvent(FRenameFile, NewFileName);
          end;
          edtRename.Visible:= False;
          SetActiveFile(CurrentPath + NewFileName);
          SetFocus;
        end;
      sfprError:
        msgError(Format(rsMsgErrRename, [OldFileName, NewFileName]));
    end;
  except
    on e: EInvalidFileProperty do
      msgError(Format(rsMsgErrRename + ':' + LineEnding + '%s (%s)', [OldFileName, NewFileName, rsMsgInvalidFileName, e.Message]));
  end;
end;

procedure TFileViewWithMainCtrl.edtRenameOnKeySwitch(Sender: TObject;
  var Key: Word; Shift: TShiftState);
var
  AFile: TFile;
  Index: PtrInt;
  OldIndex: PtrInt;
  NewFileName: String;
  OldFileName: String;
  Result: TSetFilePropertyResult;
begin
  if (Key = VK_UP) then
    Index:= GetActiveFileIndex - 1
  else begin
    Index:= GetActiveFileIndex + 1
  end;
  if not IsFileIndexInRange(Index) then
  begin
    Key:= 0;
    Exit;
  end;
  AFile:= FFiles[Index].FSFile.Clone;
  try
    if not AFile.IsNameValid then
    begin
      Key:= 0;
      Exit;
    end;
    edtRename.Tag:= 1;
    EnableWatcher(False);
    NewFileName := edtRename.Text;
    OldFileName := ExtractFileName(edtRename.Hint);
    try
      if (OldFileName = NewFileName) then
        Result:= sfprSkipped
      else begin
        Result:= uFileSourceUtil.RenameFile(FileSource, FRenameFile, NewFileName, True, False);
      end;
      case Result of
        sfprSkipped,
        sfprSuccess:
          begin
            if (Result = sfprSuccess) then
            begin
              OldIndex:= GetActiveFileIndex;
              FFiles[OldIndex].FSFile.Name:= NewFileName;
              DoFileUpdated(FFiles[OldIndex], [fpName]);
            end;
            SetActiveFile(Index);
            edtRename.Tag:= 2;
            ShowRenameFileEdit(AFile);
            edtRename.Tag:= 1;
            UpdateRenameFileEditPosition;
          end;
        sfprError:
          begin
            Key:= 0;
            msgError(Format(rsMsgErrRename, [OldFileName, NewFileName]));
          end;
      end;
    except
      on e: EInvalidFileProperty do
      begin
        Key:= 0;
        msgError(Format(rsMsgErrRename + ':' + LineEnding + '%s (%s)', [OldFileName, NewFileName, rsMsgInvalidFileName, e.Message]));
      end;
    end;
  finally
    FreeAndNil(AFile);
  end;
end;

procedure TFileViewWithMainCtrl.ClearAfterDragDrop;
begin
  tmMouseScroll.Enabled := False;
  // Clear some control specific flags.
  MainControl.ControlState := MainControl.ControlState - [csClicked, csLButtonDown];
end;

procedure TFileViewWithMainCtrl.cm_ContextMenu(const Params: array of string);
var
  Rect: TRect;
  Point: TPoint;
  AFileIndex: PtrInt;
  UserWishForContextMenu: TUserWishForContextMenu = uwcmComplete;
  bUserWishJustActionMenu: boolean;
begin
  if IsLoadingFileList then Exit;

  if Length(Params)>0 then
  begin
    GetParamBoolValue(Params[0], 'justactionmenu', bUserWishJustActionMenu);
    if bUserWishJustActionMenu then
      UserWishForContextMenu:=uwcmJustDCAction
    else
      UserWishForContextMenu:=uwcmComplete;
  end;

  AFileIndex:= GetActiveFileIndex;
  if AFileIndex < 0 then
  begin
    Point.X:= 0;
    Point.Y:= 0;
  end
  else begin
    Rect := GetFileRect(AFileIndex);
    Point.X := Rect.Left + ((Rect.Right - Rect.Left) div 2);
    Point.Y := Rect.Top + ((Rect.Bottom - Rect.Top) div 2);
  end;
  Point := MainControl.ClientToScreen(Point);
  // SetCursorPos(Point.X+100, Point.Y+25);
  frmMain.Commands.DoContextMenu(Self, Point.X, Point.Y, False, UserWishForContextMenu);
end;

procedure TFileViewWithMainCtrl.CreateDefault(AOwner: TWinControl);
begin
  FDropFileIndex := -1;
  FHintFileIndex := -1;
{$IFDEF LCLGTK2}
  FLastDoubleClickTime := Now;
{$ENDIF}
  FStartDrag := False;

  inherited CreateDefault(AOwner);

  edtRename := TEditButtonEx.Create(Self);
  edtRename.Visible := False;
  edtRename.TabStop := False;
  edtRename.AutoSize := False;
{$IFDEF LCLWIN32}
  edtRename.onKeyDown:=@edtRenameKeyDown;
{$ENDIF}
  edtRename.onKeyESCAPE:=@edtRenameOnKeyESCAPE;
  edtRename.onKeyRETURN:=@edtRenameOnKeyRETURN;
  edtRename.onKeySWITCH:=@edtRenameOnKeySwitch;
  edtRename.OnMouseDown:=@edtRenameMouseDown;
  edtRename.OnEnter := @edtRenameEnter;
  edtRename.OnExit := @edtRenameExit;
  edtRename.OnButtonClick := @edtRenameButtonClick;

  tmMouseScroll := TTimer.Create(Self);
  tmMouseScroll.Enabled  := False;
  tmMouseScroll.Interval := 100;
  tmMouseScroll.OnTimer  := @MouseScrollTimer;

  tmContextMenu := TTimer.Create(Self);
  tmContextMenu.Enabled  := False;
  tmContextMenu.Interval := 500;
  tmContextMenu.OnTimer  := @tmContextMenuTimer;

  tmRenameFile := TTimer.Create(Self);
  tmRenameFile.Enabled  := False;
  tmRenameFile.Interval := 1000;
  tmRenameFile.OnTimer  := @tmRenameFileTimer;
  FRenameFileIndex := -1;
end;

destructor TFileViewWithMainCtrl.Destroy;
begin
  if Assigned(HotMan) then
    HotMan.UnRegister(MainControl);
  inherited Destroy;
end;

procedure TFileViewWithMainCtrl.DisplayFileListChanged;
begin
  inherited DisplayFileListChanged;
  if edtRename.Visible then
    UpdateRenameFileEditPosition;
end;

procedure TFileViewWithMainCtrl.DoActiveChanged;
begin
  inherited DoActiveChanged;
  UpdateColor;
  // Needed for rename on mouse
  FMouseRename := False;
end;

procedure TFileViewWithMainCtrl.DoDragDropOperation(Operation: TDragDropOperation; var DropParams: TDropParams);
var
  AFile: TDisplayFile;
  ClientDropPoint: TPoint;
  FileIndex: PtrInt;
  AtFileList: Boolean;
  FileSourceIndex, PathIndex: Integer;
begin
  try
    with DropParams do
    begin
      if Files.Count > 0 then
      begin
        ClientDropPoint := MainControl.ScreenToClient(ScreenDropPoint);
        FileIndex := GetFileIndexFromCursor(ClientDropPoint.X, ClientDropPoint.Y, AtFileList);

        // default to current active directory in the destination panel
        TargetPath := Self.CurrentPath;

        if (DropIntoDirectories = True) and IsFileIndexInRange(FileIndex) then
        begin
          AFile := FFiles[FileIndex];

          // If dropped into a directory modify destination path and file source accordingly.
          if Assigned(AFile) and
             (AFile.FSFile.IsDirectory or AFile.FSFile.IsLinkToDirectory) then
          begin
            if AFile.FSFile.Name = '..' then
            begin
              if TargetFileSource.IsPathAtRoot(CurrentPath) then
              begin
                // Change to previous file source and last path.
                FileSourceIndex := History.CurrentFileSourceIndex - 1;
                if FileSourceIndex < 0 then
                  TargetFileSource := nil // No parent file sources.
                else
                begin
                  PathIndex := History.PathsCount[FileSourceIndex] - 1;
                  if PathIndex < 0 then
                    TargetFileSource := nil // No paths.
                  else
                  begin
                    TargetFileSource := FileSources[FileSourceIndex];
                    TargetPath := History.Path[FileSourceIndex, PathIndex];
                  end;
                end;
              end
              else
              begin
                // Remove the last subdirectory in the path.
                TargetPath := TargetFileSource.GetParentDir(TargetPath);
              end;
            end
            else
              TargetPath := TargetPath + AFile.FSFile.Name + DirectorySeparator;
          end
          else if FileIsArchive(AFile.FSFile.FullPath) then
            try
              TargetFileSource:= GetArchiveFileSource(FileSource, AFile.FSFile, EmptyStr, False, False);
              if Assigned(TargetFileSource) then TargetPath:= TargetFileSource.GetRootDir;
            except
              on E: Exception do
                msgError(E.Message + LineEnding + AFile.FSFile.FullPath);
            end;
        end;
      end;
    end;

    // Execute the operation.
    frmMain.DoDragDropOperation(Operation, DropParams);

  finally
    FreeAndNil(DropParams);
  end;
end;

procedure TFileViewWithMainCtrl.DoLoadingFileListLongTime;
begin
  UpdateColor;
  inherited DoLoadingFileListLongTime;
end;

procedure TFileViewWithMainCtrl.DoUpdateView;
begin
  inherited DoUpdateView;
  UpdateColor;
end;

procedure TFileViewWithMainCtrl.UpdateColor;
begin
  inherited UpdateColor;
  MainControl.Color := DimColor(gColors.FilePanel^.BackColor);
end;

procedure TFileViewWithMainCtrl.FinalizeDragDropEx(AControl: TWinControl);
begin
  FreeAndNil(FDragDropSource);
  FreeAndNil(FDragDropTarget);
end;

function TFileViewWithMainCtrl.Focused: Boolean;
begin
  Result := Assigned(MainControl) and MainControl.Focused;
end;

procedure TFileViewWithMainCtrl.InitializeDragDropEx(AControl: TWinControl);
begin
  // Register as drag&drop source and target.
  FDragDropSource := uDragDropEx.CreateDragDropSource(AControl);
  if Assigned(FDragDropSource) then
    FDragDropSource.RegisterEvents(nil, nil, @OnExDragEnd);

  FDragDropTarget := uDragDropEx.CreateDragDropTarget(AControl);
  if Assigned(FDragDropTarget) then
    FDragDropTarget.RegisterEvents(@OnExDragEnter, @OnExDragOver,
                                   @OnExDrop, @OnExDragLeave);
end;

function TFileViewWithMainCtrl.IsMouseSelecting: Boolean;
begin
  Result := FMainControlMouseDown and (FMainControlLastMouseButton = mbRight) and
            gMouseSelectionEnabled and (gMouseSelectionButton = 1);
end;

procedure TFileViewWithMainCtrl.MainControlDblClick(Sender: TObject);
{$IFDEF LCLCOCOA}
// Trigger MouseUp Event if Tab Changed
var
  OldTabIndex: Integer;
  NewTabIndex: Integer;
begin
  if not Assigned(NotebookPage) then
  begin
    DoMainControlFileWork();
    exit;
  end;

  OldTabIndex := TFileViewPage(NotebookPage).Notebook.ActivePageIndex;

  DoMainControlFileWork();

  NewTabIndex := TFileViewPage(NotebookPage).Notebook.ActivePageIndex;
  if NewTabIndex<> OldTabIndex then TControl(Sender).Perform(LM_LBUTTONUP,0,0);
end;
{$ELSE}
begin
  DoMainControlFileWork();
end;
{$ENDIF}

procedure TFileViewWithMainCtrl.DoMainControlFileWork;
var
  Point : TPoint;
  FileIndex : PtrInt;
  AtFileList: Boolean;
begin
  // Needed for rename on mouse
  tmRenameFile.Enabled := False;
  FRenameFileIndex := -1;
  if IsLoadingFileList then Exit;
{$IFDEF LCLGTK2}
  // Workaround for two doubleclicks being sent on GTK.
  if TooManyDoubleClicks then Exit;
{$ENDIF}

  FStartDrag := False; // don't start drag on double click
  Point := FMainControlMouseDownPoint;

  // If on a file/directory then choose it.
  FileIndex := GetFileIndexFromCursor(Point.x, Point.y, AtFileList);
  if IsFileIndexInRange(FileIndex) then
  begin
{$IF DEFINED(LCLQT) or DEFINED(LCLQT5)}
    // Workaround: under Qt4 widgetset long operation (opening archive
    // for example) blocking mouse at whole system while operation executing
    Sleep(100);
    Application.ProcessMessages;
{$ENDIF}
    ChooseFile(FFiles[FileIndex]);
  end
  else if gDblClickToParent and AtFileList then
  begin
    ChangePathToParent(True);
  end;

{$IFDEF LCLGTK2}
  FLastDoubleClickTime := Now;
{$ENDIF}
end;

procedure TFileViewWithMainCtrl.MouseStateReset;
begin
  FStartDrag := False;
  FRangeSelecting := False;

  if IsMouseSelecting and (GetCaptureControl = MainControl) then
    SetCaptureControl(nil);

  FMainControlMouseDown := False;
end;

procedure TFileViewWithMainCtrl.MainControlDragDrop(Sender, Source: TObject; X, Y: Integer);
var
  SourcePanel: TFileViewWithMainCtrl;
  SourceFiles: TFiles;
  DropParams: TDropParams;
begin
  if not (Source is TWinControl) or
     not (TWinControl(Source).Parent is TFileViewWithMainCtrl) then
    Exit;

  SourcePanel := ((Source as TWinControl).Parent) as TFileViewWithMainCtrl;

  // Get file names from source panel.
  SourceFiles := SourcePanel.CloneSelectedOrActiveFiles;
  try
    // Drop onto target panel.
    DropParams := TDropParams.Create(
      SourceFiles, // Will be freed automatically.
      GetDropEffectByKeyAndMouse(GetKeyShiftStateEx,
                                 SourcePanel.FMainControlLastMouseButton,
                                 gDefaultDropEffect),
      MainControl.ClientToScreen(Classes.Point(X, Y)),
      True,
      SourcePanel, Self,
      Self.FileSource, Self.CurrentPath);

    frmMain.DropFiles(DropParams);
    SetDropFileIndex(-1);
  except
    FreeAndNil(SourceFiles);
    raise;
  end;
end;

procedure TFileViewWithMainCtrl.MainControlDragOver(Sender, Source: TObject; X, Y: Integer; State: TDragState; var Accept: Boolean);
var
  AFile: TDisplayFile;
  SourcePanel: TFileView;
  TargetPanel: TFileView;
  SourceDir, TargetDir: String;
  FileIndex: PtrInt;
  AtFileList: Boolean;
begin
  Accept := False;

  if not (Source is TWinControl) or
     not (TWinControl(Source).Parent is TFileView) then
    Exit;

  SourcePanel := ((Source as TWinControl).Parent) as TFileView;
  TargetPanel := Self;

  FileIndex := GetFileIndexFromCursor(X, Y, AtFileList);

  // Always allow dropping into an empty panel.
  // And it is also allowed to drop onto header in case all visible items
  // are directories and the user wants to drop into panel's current directory.
  if FileIndex = InvalidFileIndex then
  begin
    SetDropFileIndex(-1);
    Accept := Sender <> Source;
    Exit;
  end;

  SourceDir := SourcePanel.CurrentPath;
  TargetDir := TargetPanel.CurrentPath;

  AFile := FFiles[FileIndex];

  if AFile.FSFile.IsDirectory or AFile.FSFile.IsLinkToDirectory or
     FileIsArchive(AFile.FSFile.FullPath) then
    begin
      if State = dsDragLeave then
        // Mouse is leaving the control or drop will occur immediately.
        // Don't draw DropRow rectangle.
        SetDropFileIndex(-1)
      else
        SetDropFileIndex(FileIndex);

      if Sender = Source then
      begin
        if not ((FileIndex = FDragFileIndex) or (AFile.Selected = True)) then
          Accept := True;
      end
      else
      begin
        if Assigned(SourcePanel) and Assigned(TargetPanel) then
        begin
          if AFile.FSFile.Name = '..' then
            TargetDir := TargetPanel.FileSource.GetParentDir(TargetDir)
          else
            TargetDir := TargetDir + AFile.FSFile.Name + DirectorySeparator;

          if SourceDir <> TargetDir then Accept := True;
        end
        else
          Accept := True;
      end;
    end
  else if (Sender <> Source) then
    begin
      SetDropFileIndex(-1);

      if Assigned(SourcePanel) then
      begin
        if SourcePanel.CurrentPath <> TargetPanel.CurrentPath then
          Accept := True;
      end
      else
        Accept := True;
    end
  else
    begin
      SetDropFileIndex(-1);
    end;
end;

procedure TFileViewWithMainCtrl.MainControlEndDrag(Sender, Target: TObject; X, Y: Integer);
  procedure ClearDropNode(aFileView: TFileView);
  begin
    if aFileView is TFileViewWithMainCtrl then
      TFileViewWithMainCtrl(aFileView).SetDropFileIndex(-1);
  end;
begin
  // If cancelled by the user, DragManager does not send drag-leave event
  // to the target, so we must clear the DropRow in both panels.

  ClearDropNode(frmMain.FrameLeft);
  ClearDropNode(frmMain.FrameRight);

  if uDragDropEx.TransformDragging = False then
    ClearAfterDragDrop;
end;

procedure TFileViewWithMainCtrl.MainControlEnter(Sender: TObject);
begin
  Active := True;
{$IFNDEF LCLWIN32}
  FMouseEnter:= ssLeft in GetKeyShiftStateEx;
{$ENDIF}
end;

procedure TFileViewWithMainCtrl.MainControlExit(Sender: TObject);
begin
  FRangeSelecting := False;
end;

procedure TFileViewWithMainCtrl.MainControlKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
var
  ScreenPoint: TPoint;
begin
  if IsLoadingFileList then Exit;

  case Key of

    VK_APPS:
      begin
        cm_ContextMenu([]);
        Key := 0;
      end;

    {$IFDEF DARWIN}
    VK_LWIN,
    VK_RWIN,
    {$ENDIF}
    VK_MENU:  // Alt key
      if MainControl.Dragging then
      begin
        // Force transform to external dragging in anticipation of user
        // pressing Alt+Tab to change active application window.

        // Disable flag, so that dragging isn't immediately transformed
        // back to internal before the other application window is shown.
        uDragDropEx.AllowTransformToInternal := False;

        GetCursorPos(ScreenPoint);
        TransformDraggingToExternal(ScreenPoint);
      end;
  end;

  DoHandleKeyDown(Key, Shift);
end;

procedure TFileViewWithMainCtrl.MainControlKeyUp(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  FRangeSelecting := False;
end;

procedure TFileViewWithMainCtrl.MainControlMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  FileIndex: PtrInt;
  AtFileList: Boolean;
  AFile, APreviousFile: TDisplayFile;
begin
  SetDragCursor(Shift);
  FMainControlMouseDownPoint:= Classes.Point(X, Y);
  if gRenameConfirmMouse and edtRename.Visible then
    edtRenameOnKeyRETURN(edtRename);
  if (DragManager <> nil) and DragManager.IsDragging and (Button = mbRight) then
    Exit;
  FileIndex := GetFileIndexFromCursor(X, Y, AtFileList);
  if not AtFileList then
    Exit;

{$IF DEFINED(LCLWIN32) OR DEFINED(LCLCOCOA)}
  FMouseFocus:= MainControl.Focused;
  SetFocus;
{$ELSE}
  FMouseFocus := not FMouseEnter;
  FMouseEnter := False;
{$ENDIF}

  // history navigation for mice with extra buttons
  if Button in [mbExtra1, mbExtra2] then
  begin
    MouseStateReset;

    case Button of
      mbExtra1: GoToPrevHistory;
      mbExtra2: GoToNextHistory;
    end;
    Exit;
  end;

  if IsLoadingFileList then Exit;

  if IsFileIndexInRange(FileIndex) then
  begin
    AFile := FFiles[FileIndex];
    FMainControlLastMouseButton := Button;
    // Needed for rename on mouse
    FRenameFileIndex := -1;

    case Button of
      mbRight:
      begin
        SetActiveFile(FileIndex, False);

        if gMouseSelectionEnabled and (gMouseSelectionButton = 1) then
        begin
          FMouseSelectionStartIndex := FileIndex;
          FMouseSelectionLastState := not AFile.Selected;
          tmContextMenu.Enabled:= True; // start context menu timer
          MarkFile(AFile, FMouseSelectionLastState, False);
          DoSelectionChanged(FileIndex);
          SetCaptureControl(MainControl);
        end;
      end;

      mbLeft:
      begin
        if gMouseSelectionEnabled then
        begin
          if ssModifier in Shift then
            begin
              // if there is no selected files then select also previous file
              if not HasSelectedFiles then
              begin
                APreviousFile := GetActiveDisplayFile;
                if Assigned(APreviousFile) and (APreviousFile <> AFile) then
                  MarkFile(APreviousFile, True, False);
              end;
              InvertFileSelection(AFile, False);
              DoSelectionChanged(FileIndex);
            end
          else if ssShift in Shift then
            begin
              FRangeSelecting := True;
              SelectRange(FileIndex);
            end
          else begin
            if FMouseRename then
            begin
              APreviousFile := GetActiveDisplayFile;
              // Start the rename file timer if the actual file is clicked again
              if Assigned(APreviousFile) and (APreviousFile = AFile) then
              begin
                if AFile.FSFile.IsNameValid then
                begin
                  FRenameFileIndex := FileIndex;
                  tmRenameFile.Enabled := True;
                end;
              end;
            end;
            // Select files/folders with a left click on their icons
            if (gMouseSelectionIconClick > 0) and
               (PtInRect(GetIconRect(FileIndex), Classes.Point(X, Y))) then
            begin
              InvertFileSelection(AFile, False);
              DoSelectionChanged(FileIndex);
              FMainControlMouseDown:= False;
            end
            //  If mark with left button enable
            else if (gMouseSelectionButton = 0) then
            begin
              if not AFile.Selected then
                MarkFiles(False);
            end;
          end;
        end;//of mouse selection handler
      end;
      else begin
        SetActiveFile(FileIndex);
        Exit;
      end;
    end;

    { Dragging }

    // Check if not already dragging (started by a different button)
    // and if the mouse button is not used for selection.
    if not MainControl.Dragging and
       not (gMouseSelectionEnabled and (Button = mbRight) and (gMouseSelectionButton = Integer(Button))) then
    begin
      // indicate that drag start at next mouse move event
      FStartDrag := True;
      FDragStartPoint.X := X;
      FDragStartPoint.Y := Y;
      FDragFileIndex := FileIndex;
      uDragDropEx.TransformDragging := False;
      uDragDropEx.AllowTransformToInternal := True;
    end;
  end
  else // if mouse on empty space
    begin
      if (Button = mbRight) and (gMouseSelectionEnabled) and (gMouseSelectionButton = 1) then
        tmContextMenu.Enabled:= True; // start context menu timer
    end;
  // Needed for rename on mouse
  FMouseRename := gInplaceRename;
end;

procedure TFileViewWithMainCtrl.MainControlMouseLeave(Sender: TObject);
begin
end;

procedure TFileViewWithMainCtrl.MainControlMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
var
  Point: TPoint;
  AFile: TDisplayFile;
  ExpectedButton: TShiftStateEnum;
  FileIndex: PtrInt;
  AtFileList: Boolean;
  SelStartIndex, SelEndIndex: Integer;
begin
  SetDragCursor(Shift);
  if FMainControlMouseDown and MainControl.Dragging then
  begin
    // If dragging has started then clear MouseDown flag.
    if (Abs(FDragStartPoint.X - X) > DragManager.DragThreshold) or
       (Abs(FDragStartPoint.Y - Y) > DragManager.DragThreshold) then
    begin
      FMainControlMouseDown := False;
    end;
  end;

  // If dragging is currently in effect, the window has mouse capture and
  // we can retrieve the window over which the mouse cursor currently is.
  if MainControl.Dragging and uDragDropEx.IsExternalDraggingSupported then
  begin
    Point := MainControl.ClientToScreen(Classes.Point(X, Y));

    // use specifically LCLIntf.WindowFromPoint to avoid confusion with Windows.WindowFromPoint
    if LCLIntf.WindowFromPoint(Point) = 0 then
    begin
      // If result is 0 then the window belongs to another process
      // and we transform intra-process dragging into inter-process dragging.

      TransformDraggingToExternal(Point);
    end;
  end

  else

  // if we are about to start dragging
  if FStartDrag and ((Abs(FDragStartPoint.X - X) > DragManager.DragThreshold) or
                     (Abs(FDragStartPoint.Y - Y) > DragManager.DragThreshold)) then
    begin
      FStartDrag := False;

      case FMainControlLastMouseButton of
        mbLeft   : ExpectedButton := ssLeft;
        mbMiddle : ExpectedButton := ssMiddle;
        mbRight  : ExpectedButton := ssRight;
        else       Exit;
      end;

      // Make sure the same mouse button is still pressed.
      if not (ExpectedButton in Shift) then
      begin
        ClearAfterDragDrop;
      end
      else if IsFileIndexInRange(FDragFileIndex) then
      begin
        AFile := FFiles[FDragFileIndex];
        // Check if valid item is being dragged.
        if IsItemValid(AFile) then
        begin
          MainControl.BeginDrag(False);
          // Restore selection of active file
          if (FSelectedCount > 0) and (not AFile.Selected) then MarkFile(AFile, True);
        end;
      end;
    end;

  // Disable the rename file timer if we are dragging
  if FMouseRename and MainControl.Dragging then
  begin
     tmRenameFile.Enabled := False;
     FRenameFileIndex := -1;
  end;
  // Show file info tooltip.
  if ShowHint and
     not MainControl.Dragging and ([ssLeft, ssMiddle, ssRight] * Shift = []) then
    begin
      FileIndex := GetFileIndexFromCursor(X, Y, AtFileList);
      if FileIndex <> FHintFileIndex then
      begin
        FHintFileIndex := FileIndex;
        Application.CancelHint;
      end;
    end;

  if edtRename.Visible then Exit;

  // A single click starts programs and opens files
  if (gMouseSingleClickStart in [1..3]) and (FMainControlMouseDown = False) and
     (Shift * [ssShift, ssAlt, ssModifier] = []) and (not MainControl.Dragging) then
  begin
    FileIndex := GetFileIndexFromCursor(X, Y, AtFileList);
    if IsFileIndexInRange(FileIndex) and
       (GetActiveFileIndex <> FileIndex) then
    begin
      SetActiveFile(FileIndex);
    end;
  end;

  // Selection with right mouse button, if enabled.
  if FMainControlMouseDown and (FMainControlLastMouseButton = mbRight) and
     gMouseSelectionEnabled and (gMouseSelectionButton = 1) then
  begin
    FileIndex := GetFileIndexFromCursor(X, Y, AtFileList);
    if IsFileIndexInRange(FileIndex) and
       (GetActiveFileIndex <> FileIndex) then
    begin
      tmContextMenu.Enabled:= False; // stop context menu timer
      if FMouseSelectionStartIndex < FileIndex then
      begin
        SelStartIndex := FMouseSelectionStartIndex;
        SelEndIndex := FileIndex;
      end
      else
      begin
        SelStartIndex := FileIndex;
        SelEndIndex := FMouseSelectionStartIndex;
      end;

      SetActiveFile(FileIndex, False);
      MarkFiles(SelStartIndex, SelEndIndex, FMouseSelectionLastState);
    end;
  end;
end;

procedure TFileViewWithMainCtrl.MainControlMouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  FileIndex: PtrInt;
  AtFileList: Boolean;
begin
  if IsLoadingFileList then Exit;

  FStartDrag := False;
  FRangeSelecting := False;

  // Handle only if button-up was not lifted to finish drag&drop operation.
  if not FMainControlMouseDown then
    Exit;

  if IsMouseSelecting and (GetCaptureControl = MainControl) then
    SetCaptureControl(nil);

  // A single click is used to open items
  if (gMouseSingleClickStart > 0) and (Button = mbLeft) and
     (Shift * [ssShift, ssAlt, ssModifier, ssDouble] = []) and FMouseFocus then
  begin
    // A single click only opens folders. For files, a double click is needed.
    if (gMouseSingleClickStart and 2 <> 0) then
    begin
      FileIndex := GetFileIndexFromCursor(X, Y, AtFileList);
      if IsFileIndexInRange(FileIndex) then
      begin
        with FFiles[FileIndex].FSFile do
        begin
          if (IsDirectory or IsLinkToDirectory) then
            DoMainControlFileWork();
        end;
      end
    end
    // A single click starts programs and opens files
    else begin
      DoMainControlFileWork();
    end;
  end;

  FMainControlMouseDown := False;
end;

procedure TFileViewWithMainCtrl.MainControlQuadClick(Sender: TObject);
begin
  DoMainControlFileWork();
end;

procedure TFileViewWithMainCtrl.MainControlShowHint(Sender: TObject; HintInfo: PHintInfo);
var
  sHint: String;
  AFile: TDisplayFile;
begin
  HintInfo^.HintStr:= EmptyStr;

  if not gShowToolTip then Exit;
  if not IsFileIndexInRange(FHintFileIndex) then Exit;

  AFile := FFiles[FHintFileIndex];
  if AFile.FSFile.Name = '..' then Exit;

  HintInfo^.HintStr:= AFile.FSFile.Name;
  sHint:= GetFileInfoToolTip(FileSource, AFile.FSFile);
  if (sHint <> EmptyStr) then
    HintInfo^.HintStr:= HintInfo^.HintStr + LineEnding + sHint;

  if gFileInfoToolTipValue[ord(gToolTipHideTimeOut)] <> -1 then HintInfo^.HideTimeout := gFileInfoToolTipValue[ord(gToolTipHideTimeOut)];
end;

procedure TFileViewWithMainCtrl.MainControlUTF8KeyPress(Sender: TObject; var UTF8Key: TUTF8Char);
begin
  if IsLoadingFileList then Exit;

  // check if ShiftState is equal to quick search / filter modes
  if quickSearch.CheckSearchOrFilter(UTF8Key) then
    Exit;
end;

procedure TFileViewWithMainCtrl.MainControlResize(Sender: TObject);
begin
  if edtRename.Visible then
    UpdateRenameFileEditPosition;
end;

procedure TFileViewWithMainCtrl.MainControlWindowProc(var TheMessage: TLMessage);
begin
  // Cancel rename if user scroll file list by mouse
  if (TheMessage.Msg = LM_VSCROLL) or (TheMessage.Msg = LM_HSCROLL) or
     (TheMessage.Msg = LM_MOUSEWHEEL) then
  begin
    edtRename.Hide;
    SetFocus;
  end;
  FWindowProc(TheMessage);
end;

function TFileViewWithMainCtrl.OnExDragBegin: Boolean;
begin
  Result := True;
end;

function TFileViewWithMainCtrl.OnExDragEnd: Boolean;
{$IF DEFINED(MSWINDOWS)}
var
  startPoint: TPoint;
  currentPoint: TPoint;
{$ENDIF}
begin
{$IF DEFINED(MSWINDOWS)}
  // On windows dragging can be transformed back into internal.
  // Check if drag was aborted due to mouse moving back into
  // the application window or the user just cancelled it.
  if TransformDragging and (FDragDropSource.GetLastStatus = DragDropAborted) then
  begin
    // Transform to internal dragging again.

    // Save current mouse position.
    GetCursorPos(currentPoint);

    // Temporarily set cursor position to the point where the drag was started
    // so that DragManager can properly read the control being dragged.
    startPoint := MainControl.ClientToScreen(FDragStartPoint);
    SetCursorPos(startPoint.X, startPoint.Y);

    // Begin internal dragging.
    MainControl.BeginDrag(True);

    // Move cursor back.
    SetCursorPos(currentPoint.X, currentPoint.Y);

    // Clear flag.
    TransformDragging := False;

    Exit(True);
  end;
{$ENDIF}

  ClearAfterDragDrop;

  Result := True;
end;

function TFileViewWithMainCtrl.OnExDragEnter(var DropEffect: TDropEffect; ScreenPoint: TPoint): Boolean;
begin
  Result := True;
end;

function TFileViewWithMainCtrl.OnExDragLeave: Boolean;
begin
  SetDropFileIndex(-1);
  Result := True;
end;

function TFileViewWithMainCtrl.OnExDragOver(var DropEffect: TDropEffect; ScreenPoint: TPoint): Boolean;
var
  ClientPoint: TPoint;
  AFile: TDisplayFile;
  FileIndex: PtrInt;
  AtFileList: Boolean;
begin
  // Dropping into empty panel allowed.
  Result := True;

  ClientPoint := MainControl.ScreenToClient(ScreenPoint);
  FileIndex := GetFileIndexFromCursor(ClientPoint.x, ClientPoint.y, AtFileList);

  if IsFileIndexInRange(FileIndex) then
  begin
    // Get the file over which there is something dragged.
    AFile := FFiles[FileIndex];

    // If it is a directory or link mark possibility of drop.
    if AFile.FSFile.IsDirectory or AFile.FSFile.IsLinkToDirectory or
       FileIsArchive(AFile.FSFile.FullPath) then
      SetDropFileIndex(FileIndex)
    else
      SetDropFileIndex(-1);
  end
  else
    SetDropFileIndex(-1);
end;

function TFileViewWithMainCtrl.OnExDrop(const FileNamesList: TStringList; DropEffect: TDropEffect; ScreenPoint: TPoint): Boolean;
var
  AFiles: TFiles = nil;
  DropParams: TDropParams;
begin
  Result := False;
  if FileNamesList.Count > 0 then
  try
    AFiles := TFileSystemFileSource.CreateFilesFromFileList(
        ExtractFilePath(FileNamesList[0]), FileNamesList);
    try
      DropParams := TDropParams.Create(
        AFiles, DropEffect, ScreenPoint, True,
        nil, Self, Self.FileSource, Self.CurrentPath);

      frmMain.DropFiles(DropParams);

      Result := True;
    finally
      FreeAndNil(AFiles);
    end;
  except
    on e: EFileNotFound do
      MessageDlg(e.Message, mtError, [mbOK], 0);
  end;

  SetDropFileIndex(-1);
end;

procedure TFileViewWithMainCtrl.SetDropFileIndex(NewFileIndex: PtrInt);
var
  OldDropIndex: PtrInt;
begin
  if FDropFileIndex <> NewFileIndex then
  begin
    OldDropIndex := FDropFileIndex;

    // Set new index before redrawing.
    FDropFileIndex := NewFileIndex;

    if IsFileIndexInRange(OldDropIndex) then
      RedrawFile(OldDropIndex);
    if IsFileIndexInRange(NewFileIndex) then
      RedrawFile(NewFileIndex);
  end;
end;

function TFileViewWithMainCtrl.GetIconRect(FileIndex: PtrInt): TRect;
begin
  Result:= Classes.Rect(0, 0, 0, 0);
end;

procedure TFileViewWithMainCtrl.SetFocus;
begin
  // CanFocus checks parent controls, but not parent form.
  if GetParentForm(Self).CanFocus and MainControl.CanFocus then
  begin
    if FFocusQuickSearch then
    begin
      MainControl.SetFocus;
      inherited SetFocus;
      Exit;
    end;
    inherited SetFocus;
    MainControl.SetFocus;
    {$IFDEF LCLCOCOA}
    Active := true;
    {$ENDIF}
  end;
end;

procedure TFileViewWithMainCtrl.SetDragCursor(Shift: TShiftState);
var
  DropEffect: TDropEffect;
begin
  if (DragManager <> nil) and DragManager.IsDragging then
    begin
      DropEffect := GetDropEffectByKey(Shift, gDefaultDropEffect);

      if DropEffect = DropMoveEffect then
        TControlHandlersHack(MainControl).DragCursor:= crArrowMove
      else if DropEffect = DropLinkEffect then
        TControlHandlersHack(MainControl).DragCursor:= crArrowLink
      else if DropEffect = DropCopyEffect then
        TControlHandlersHack(MainControl).DragCursor:= crArrowCopy
      else
        TControlHandlersHack(MainControl).DragCursor:= crDrag;

      DragManager.DragMove(Mouse.CursorPos);
    end
  else
    TControlHandlersHack(MainControl).DragCursor:= crDrag;
end;

procedure TFileViewWithMainCtrl.cm_RenameOnly(const Params: array of string);
var
  aFile: TFile;
begin
  if not IsLoadingFileList and
     (fsoSetFileProperty in FileSource.GetOperationsTypes) then
    begin
      aFile:= CloneActiveFile;
      if Assigned(aFile) then
      try
        if aFile.IsNameValid then
          ShowRenameFileEdit(aFile)
        else if gCurDir then
          ShowPathEdit;
      finally
        FreeAndNil(aFile);
      end;
    end;
end;

procedure TFileViewWithMainCtrl.SetMainControl(AValue: TWinControl);
begin
  if FMainControl = AValue then Exit;
  FMainControl := AValue;

  FMainControl.ControlStyle   := FMainControl.ControlStyle + [csQuadClicks];

  FMainControl.OnEnter        := @MainControlEnter;
  FMainControl.OnExit         := @MainControlExit;
  FMainControl.OnKeyDown      := @MainControlKeyDown;
  FMainControl.OnKeyUp        := @MainControlKeyUp;
  FMainControl.OnShowHint     := @MainControlShowHint;
  FMainControl.OnUTF8KeyPress := @MainControlUTF8KeyPress;
  FMainControl.AddHandlerOnResize(@MainControlResize);

  TControlHandlersHack(FMainControl).OnDblClick   := @MainControlDblClick;
  TControlHandlersHack(FMainControl).OnQuadClick  := @MainControlQuadClick;
  TControlHandlersHack(FMainControl).OnDragDrop   := @MainControlDragDrop;
  TControlHandlersHack(FMainControl).OnDragOver   := @MainControlDragOver;
  TControlHandlersHack(FMainControl).OnEndDrag    := @MainControlEndDrag;
  TControlHandlersHack(FMainControl).OnMouseDown  := @MainControlMouseDown;
  TControlHandlersHack(FMainControl).OnMouseLeave := @MainControlMouseLeave;
  TControlHandlersHack(FMainControl).OnMouseMove  := @MainControlMouseMove;
  TControlHandlersHack(FMainControl).OnMouseUp    := @MainControlMouseUp;

  edtRename.Parent := FMainControl;

  HotMan.Register(MainControl, 'Files Panel');
end;

procedure TFileViewWithMainCtrl.tmContextMenuTimer(Sender: TObject);
var
  AFile: TDisplayFile;
  Index, Count: Integer;
  ClientPoint, MousePoint: TPoint;
  Background: Boolean;
  FileIndex: PtrInt;
  AtFileList: Boolean;
  Status: Boolean;
begin
  FMainControlMouseDown:= False;
  tmContextMenu.Enabled:= False; // stop context menu timer

  MousePoint  := Mouse.CursorPos;
  ClientPoint := MainControl.ScreenToClient(MousePoint);
  FileIndex   := GetFileIndexFromCursor(ClientPoint.x, ClientPoint.y, AtFileList);
  Background  := not IsFileIndexInRange(FileIndex);

  if not Background then
  begin
    // Skip if a rename is in progress on the same file
    if FRenameFileIndex = FileIndex then
      Exit;

    // Restore selection status by default
    Status := not FMouseSelectionLastState;
    if (Status = False) then
    begin
      Count := 0;
      for Index := 0 to FFiles.Count - 1 do
      begin
        if FFiles[Index].Selected then
        begin
          Inc(Count);
          // If multiple files selected then
          // select file under cursor too
          if Count > 1 then
          begin
            Status := True;
            Break;
          end;
        end;
      end;
    end;

    AFile := FFiles[FileIndex];
    MarkFile(AFile, Status, False);
    DoSelectionChanged(FileIndex);
  end;

  frmMain.Commands.DoContextMenu(Self, MousePoint.x, MousePoint.y, Background);
end;

procedure TFileViewWithMainCtrl.tmRenameFileTimer(Sender: TObject);
var
  ClientPoint, MousePoint: TPoint;
  Background: Boolean;
  FileIndex: PtrInt;
  AtFileList: Boolean;
begin
  if FMainControlMouseDown = True then
   begin
     FMainControlMouseDown := False;
     tmRenameFile.Enabled := False; // stop timer
     Exit;
   end;
  tmRenameFile.Enabled := False; // stop timer

  MousePoint  := Mouse.CursorPos;
  ClientPoint := MainControl.ScreenToClient(MousePoint);
  FileIndex   := GetFileIndexFromCursor(ClientPoint.x, ClientPoint.y, AtFileList);
  Background  := not IsFileIndexInRange(FileIndex);

  if not Background then
  begin
    if FRenameFileIndex = FileIndex then
    begin
      FMouseRename := False;
      cm_RenameOnly([]);
    end;
  end;
  FRenameFileIndex := -1;
end;

procedure TFileViewWithMainCtrl.TransformDraggingToExternal(ScreenPoint: TPoint);
begin
  // Set flag temporarily before stopping internal dragging,
  // so that triggered events will know that dragging is transforming.
  TransformDragging := True;

  // Stop internal dragging
  DragManager.DragStop(False);

{$IF DEFINED(LCLGTK) or DEFINED(LCLGTK2)}
  // Under GTK, DragManager does not release it's mouse capture on
  // DragStop(). We must release it here manually or LCL will get confused
  // with who "owns" the capture after the GTK drag&drop finishes.
  ReleaseMouseCapture;
{$ENDIF}

  // Clear flag before starting external dragging.
  TransformDragging := False;

  // Start external dragging.
  // On Windows it does not return until dragging is finished.

  if IsFileIndexInRange(FDragFileIndex) then
  begin
    BeginDragExternal(FFiles[FDragFileIndex],
                      FDragDropSource,
                      FMainControlLastMouseButton,
                      ScreenPoint);
  end;
end;

procedure TFileViewWithMainCtrl.edtRenameEnter(Sender: TObject);
begin
  FWindowProc:= MainControl.WindowProc;
  MainControl.WindowProc:= @MainControlWindowProc;
end;

procedure TFileViewWithMainCtrl.edtRenameExit(Sender: TObject);
begin
  FreeAndNil(FRenameFile);
  edtRename.Visible := False;
  MainControl.WindowProc:= FWindowProc;

  if edtRename.Tag > 0 then
  begin
    edtRename.Tag:= 0;
    EnableWatcher(IsFileSystemWatcher);
    Reload(True);
  end;

  // OnEnter don't called automatically (bug?)
  // TODO: Check on which widgetset/OS this is needed.
  FMainControl.OnEnter(Self);
end;

procedure TFileViewWithMainCtrl.edtRenameButtonClick(Sender: TObject);
begin
  edtRenameOnKeyRETURN(Sender);
end;

procedure TFileViewWithMainCtrl.edtRenameMouseDown(Sender: TObject;
  Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  FRenFile.UserManualEdit:=True; // user begin manual edit - no need cycle Name,Ext,FullName selection
end;

procedure TFileViewWithMainCtrl.AfterChangePath;
begin
  if edtRename.Visible then
  begin
    edtRename.Hide;
    SetFocus;
  end;
  inherited AfterChangePath;
  if IsMouseSelecting then
  begin
    MouseStateReset;
  end;
end;

{$IFDEF LCLGTK2}
function TFileViewWithMainCtrl.TooManyDoubleClicks: Boolean;
begin
  Result := ((Now - FLastDoubleClickTime) <= ((1/86400)*(DblClickTime/1000)));
end;
{$ENDIF}

procedure TFileViewWithMainCtrl.WorkerFinished(const Worker: TFileViewWorker);
begin
  inherited WorkerFinished(Worker);
  MainControl.Cursor := crDefault;
  // Update status line only
  if not (csDestroying in ComponentState) then UpdateInfoPanel;
end;

procedure TFileViewWithMainCtrl.ShowRenameFileEditInitSelect(Data: PtrInt);
begin
  if Assigned(FRenameFile) then
  begin
    if gRenameSelOnlyName and not (FRenameFile.IsDirectory or FRenameFile.IsLinkToDirectory) then
      RenameSelectPart(rfatName)
    else
      RenameSelectPart(rfatFull);
  end;
end;

procedure TFileViewWithMainCtrl.ShowRenameFileEdit(var AFile: TFile);
var
  S: String;
begin
  S:= AFile.Name;
  FRenFile.LenFul := UTF8Length(S);
  FRenFile.LenExt := UTF8Length(ExtractFileExt(S));
  FRenFile.LenNam := FRenFile.LenFul - FRenFile.LenExt;


  if edtRename.Visible and (edtRename.Tag < 2) then
  begin
    if AFile.IsDirectory or AFile.IsLinkToDirectory then Exit;
    if FRenFile.UserManualEdit then FRenFile.CycleFinished:= True;

    if not FRenFile.CycleFinished then
    begin
      if gRenameSelOnlyName then
      begin
        if FRenFile.LastAction = rfatName then
           RenameSelectPart(rfatFull)
        else begin
           RenameSelectPart(rfatExt);
           FRenFile.CycleFinished:= True;
           Exit;
        end;
      end else
      begin
        if FRenFile.LastAction = rfatFull then
           RenameSelectPart(rfatName)
        else begin
           RenameSelectPart(rfatExt);
           FRenFile.CycleFinished:= True;
           Exit;
        end;
      end;
      exit;
    end;

    // if Cycle not finished - below code wil never execute, so cycle finished:

    if FRenFile.UserManualEdit then            // if user do something(selecting by mouse or press key) and then press F2 - extend to nearest separators
    begin
       RenameSelectPart(rfatToSeparators);
       FRenFile.UserManualEdit:= False;
    end else                                         // else - select next sepoarated part of file
       RenameSelectPart(rfatNextSeparated);

  end else
  begin
    FRenameFile := aFile;
    edtRename.Hint := aFile.FullPath;
    edtRename.Text := aFile.Name;
    edtRename.Visible := True;
    edtRename.SetFocus;

    FRenTags:= ' -_.';  // separator set

    FRenFile.UserManualEdit:= False;
    // cycle of selection Name-FullName-Ext or FullName-Name-Ext,
    // after finish this cycle will be part selection mechanism, don't need cycle if no extension
    FRenFile.CycleFinished:= (FRenFile.LenExt = 0);

    Application.QueueAsyncCall(@ShowRenameFileEditInitSelect, 0);

    aFile:= nil;
  end;
end;

procedure TFileViewWithMainCtrl.UpdateRenameFileEditPosition;
var
  AFile: TDisplayFile;
begin
  if edtRename.Visible then
  begin
    AFile:= GetActiveDisplayFile;
    // Cannot find original file, cancel rename
    if (AFile = nil) or (not mbCompareFileNames(AFile.FSFile.FullPath, FRenameFile.FullPath)) then
    begin
      edtRename.Hide;
      SetFocus;
    end;
  end;
end;

procedure TFileViewWithMainCtrl.RenameSelectPart(AActionType: TRenameFileActionType);
var
  ib,ie:integer;
begin
  FRenFile.LastAction:=AActionType;

  case AActionType of   // get current selection action type
    rfatName:
      begin
        {$IFDEF LCLGTK2}
        edtRename.SelStart:=1;
        {$ENDIF}
        edtRename.SelStart:=0;
        edtRename.SelLength:=FRenFile.LenNam;
      end;
    rfatExt :
      begin
        edtRename.SelStart:=FRenFile.LenNam+1;
        edtRename.SelLength:=FRenFile.LenExt;
      end;
    rfatFull:
      begin
        {$IFDEF LCLGTK2}
        edtRename.SelStart:=1;
        {$ENDIF}
        edtRename.SelStart:=0;
        edtRename.SelLength:=FRenFile.LenFul;
      end;
    rfatToSeparators:
      begin
        // search backward the separator to set begin of selection
        ib:=TagPos(FRenTags,edtRename.Text,edtRename.SelStart,True);                       // begin

        // skip next separators if exist
        while (ib>0)and(ib<FRenFile.LenFul)and(Pos(edtRename.Text[ib+1],FRenTags)>0)do inc(ib);

        if ib>=FRenFile.LenFul then ib:=0;

        if ib>=edtRename.SelStart+edtRename.SelLength+1 then  // if new position index higher of the same - search end index from it
           ie:=TagPos(FRenTags,edtRename.Text,ib+1,False)
        else                                                 // else search of end begin from last start index+selectionLength+1
           ie:=TagPos(FRenTags,edtRename.Text,edtRename.SelStart+edtRename.SelLength+1,False);  // end

        edtRename.SelStart:=ib;
        edtRename.SelLength:=ie-ib-1;

      end;
    rfatNextSeparated:
      begin
        ib:=TagPos(FRenTags,edtRename.Text,edtRename.SelStart+edtRename.SelLength+1,False);

        // skip next separators if exist
        while (ib>0)and(ib<FRenFile.LenFul)and(Pos(edtRename.Text[ib+1],FRenTags)>0)do inc(ib);

        //UTF8FindNearestCharStart();
        if ib>=FRenFile.LenFul then
           edtRename.SelStart:=0
        else
           edtRename.SelStart:=ib;

        ie:=TagPos(FRenTags,edtRename.Text,edtRename.SelStart+1,False)-1;  // end
        if ie<0 then ie:=FRenFile.LenFul;

        edtRename.SelLength:=ie-edtRename.SelStart;
      end;
  end;
end;


procedure TFileViewWithMainCtrl.WorkerStarting(const Worker: TFileViewWorker);
begin
  inherited WorkerStarting(Worker);
  MainControl.Cursor := crHourGlass;
  UpdateInfoPanel; // Update status line only
end;

end.

