{
    Double Commander
    -------------------------------------------------------------------------
    This unit contains platform depended functions.

    Copyright (C) 2006-2024 Alexander Koblov (alexx2000@mail.ru)

    This program is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 2 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program. If not, see <http://www.gnu.org/licenses/>.
}

unit uOSForms;

{$mode delphi}{$H+}

interface

uses
  LCLType, LMessages, Forms, Classes, SysUtils, Controls,
  uGlobs, uShellContextMenu, uDrive, uFile, uFileSource;

type

  { TAloneForm }

  TAloneForm = class(TForm)
  {$IF DEFINED(DARWIN) AND DEFINED(LCLQT)}
  protected
    procedure DoClose(var CloseAction: TCloseAction); override;
  {$ENDIF}
  public
    constructor CreateNew(AOwner: TComponent; Num: Integer = 0); override;
  end;

  { TModalDialog }

  TModalDialog = class(TAloneForm)
  protected
    FParentWindow: HWND;
    procedure CloseModal;
  protected
    procedure CreateParams(var Params: TCreateParams); override;
  public
    procedure ExecuteModal; virtual;
    function ShowModal: Integer; override;
  end;

  { TModalForm }

  {$IF DEFINED(LCLWIN32)}
  TModalForm = class(TModalDialog);
  {$ELSE}
  TModalForm = class(TForm);
  {$ENDIF}

{en
   Must be called on main form create
   @param(MainForm Main form)
}
procedure MainFormCreate(MainForm : TCustomForm);
{en
   Show file/folder properties dialog
   @param(Files List of files to show properties for)
}
procedure ShowFilePropertiesDialog(aFileSource: IFileSource; const Files: TFiles);
{en
   Show file/folder context menu
   @param(Parent Parent window)
   @param(Files List of files to show context menu for. It is freed by this function.)
   @param(X Screen X coordinate)
   @param(Y Screen Y coordinate)
   @param(CloseEvent Method called when popup menu is closed (optional))
}
procedure ShowContextMenu(Parent: TWinControl; var Files : TFiles; X, Y : Integer;
                          Background: Boolean; CloseEvent: TNotifyEvent; UserWishForContextMenu:TUserWishForContextMenu = uwcmComplete);
{en
   Show drive context menu
   @param(Parent Parent window)
   @param(sPath Path to drive)
   @param(X Screen X coordinate)
   @param(Y Screen Y coordinate)
   @param(CloseEvent Method called when popup menu is closed (optional))
}
procedure ShowDriveContextMenu(Parent: TWinControl; ADrive: PDrive; X, Y : Integer;
                               CloseEvent: TNotifyEvent);
{en
   Show trash context menu
   @param(Parent Parent window)
   @param(X Screen X coordinate)
   @param(Y Screen Y coordinate)
   @param(CloseEvent Method called when popup menu is closed (optional))
}
procedure ShowTrashContextMenu(Parent: TWinControl; X, Y : Integer;
                               CloseEvent: TNotifyEvent);
{en
   Show open icon dialog
   @param(Owner Owner)
   @param(sFileName Icon file name)
   @returns(The function returns @true if successful, @false otherwise)
}
function ShowOpenIconDialog(Owner: TCustomControl; var sFileName : String) : Boolean;

{$IF DEFINED(UNIX) AND NOT (DEFINED(DARWIN) OR DEFINED(HAIKU))}
{en
   Show open with dialog
   @param(FileList List of files to open with)
}
procedure ShowOpenWithDialog(TheOwner: TComponent; const FileList: TStringList);
{$ENDIF}

function GetControlHandle(AWindow: TWinControl): HWND;
function GetWindowHandle(AWindow: TWinControl): HWND; overload;
function GetWindowHandle(AHandle: HWND): HWND; overload;
procedure CopyNetNamesToClip;
procedure MapNetworkDrive;
function DarkStyle: Boolean;

implementation

uses
  ExtDlgs, LCLProc, Menus, Graphics, InterfaceBase, WSForms, LCLIntf,
  fMain, uConnectionManager, uShowMsg, uLng, uDCUtils, uDebug
  {$IF DEFINED(MSWINDOWS)}
  , LCLStrConsts, ComObj, ActiveX, DCOSUtils, uOSUtils, uFileSystemFileSource
  , uTotalCommander, FileUtil, Windows, ShlObj, uShlObjAdditional
  , uWinNetFileSource, uVfsModule, uMyWindows, DCStrUtils, uOleDragDrop
  , uDCReadRSVG, uFileSourceUtil, uGdiPlusJPEG, uListGetPreviewBitmap
  , Dialogs, Clipbrd, JwaDbt, uThumbnailProvider, uShellFolder
  , uRecycleBinFileSource, uWslFileSource, uDCReadHEIF, uDCReadJXL
  , uDCReadWIC, uShellFileSource, uPixMapManager
    {$IF DEFINED(DARKWIN)}
    , uDarkStyle
    {$ELSEIF DEFINED(LCLQT5)}
    , qt5, qtwidgets, uDarkStyle
    {$ENDIF}
  {$ENDIF}
  {$IF DEFINED(DARWIN)}
  , LCLStrConsts
  , BaseUnix, Errors, fFileProperties
  , uQuickLook, uOpenDocThumb, uMyDarwin, uDefaultTerminal
  {$ELSEIF DEFINED(UNIX)}
  , BaseUnix, Errors, fFileProperties, uJpegThumb, uOpenDocThumb
    {$IF NOT DEFINED(HAIKU)}
    , uDCReadRSVG, uMagickWand, uGio, uGioFileSource, uVfsModule, uVideoThumb
    , uDCReadWebP, uFolderThumb, uAudioThumb, uDefaultTerminal, uDCReadHEIF
    , uTrashFileSource, uFileManager, uFileSystemFileSource, fOpenWith
    , uDCReadJXL, uFileSourceUtil, uNetworkFileSource
    {$ENDIF}
    {$IF DEFINED(LINUX)}
    , uFlatpak
    {$ENDIF}
    {$IF DEFINED(LCLQT)}
    , qt4, qtwidgets
    {$ENDIF}
    {$IF DEFINED(LCLQT5)}
    , qt5, qtwidgets
    {$ENDIF}
    {$IF DEFINED(LCLQT6)}
    , qt6, qtwidgets
    {$ENDIF}
    {$IF DEFINED(LCLGTK2)}
    , Gtk2,  Glib2, Themes
    {$ENDIF}
  {$ENDIF}
  {$IF FPC_FULLVERSION < 30300}
  , uDCReadPNM
  {$ENDIF}
  , uDCReadSVG, uTurboJPEG;

{ TAloneForm }

{$IF DEFINED(DARWIN) AND DEFINED(LCLQT)}

var
  FMain, FBefore, FCurrent: TCustomForm;

procedure TAloneForm.DoClose(var CloseAction: TCloseAction);

  procedure TrySetFocus(Form: TCustomForm); inline;
  begin
    if Form.CanFocus then Form.SetFocus;
  end;

var
  psnFront, psnCurrent: ProcessSerialNumber;
begin
  inherited DoClose(CloseAction);
  if (GetCurrentProcess(psnCurrent) = noErr) and (GetFrontProcess(psnFront) = noErr) then
  begin
    // Check that our process is active
    if (psnCurrent.lowLongOfPSN = psnFront.lowLongOfPSN) and
       (psnCurrent.highLongOfPSN = psnFront.highLongOfPSN) then
    begin
      // Restore active form
      if (Screen.CustomFormIndex(FBefore) < 0) then
        TrySetFocus(FMain)
      else if (FBefore <> Self) then
        TrySetFocus(FBefore)
      else
        FBefore:= FMain;
    end;
  end;
end;

procedure ActiveFormChangedHandler(Self, Sender: TObject; Form: TCustomForm);
begin
  if (Form is TAloneForm) or (FMain = Form) then
  begin
    if FCurrent <> Form then
    begin
      FBefore:= FCurrent;
      FCurrent:= Form;
    end;
  end;
end;

{$ENDIF}

constructor TAloneForm.CreateNew(AOwner: TComponent; Num: Integer);
begin
  inherited CreateNew(AOwner, Num);
  // https://github.com/doublecmd/doublecmd/issues/769
  // https://github.com/doublecmd/doublecmd/issues/1358
  Constraints.MaxWidth:= High(Int16);
  Constraints.MaxHeight:= High(Int16);
end;

{ TModalDialog }

procedure TModalDialog.CloseModal;
var
  CloseAction: TCloseAction;
begin
  try
    CloseAction := caNone;
    if CloseQuery then
    begin
      CloseAction := caHide;
      DoClose(CloseAction);
    end;
    case CloseAction of
      caNone: ModalResult := 0;
      caFree: Release;
    end;
    { do not call widgetset CloseModal here, but in ShowModal to
      guarantee execution of it }
  except
    ModalResult := 0;
    Application.HandleException(Self);
  end;
end;

procedure TModalDialog.CreateParams(var Params: TCreateParams);
begin
  inherited CreateParams(Params);
  if FParentWindow <> 0 then
  begin
    // It doesn't affect anything under GTK2 and raise
    // a range check error (LCLGTK2 bug in the function CreateWidgetInfo)
{$IFNDEF LCLGTK2}
    Params.Style := Params.Style or WS_POPUP;
{$ENDIF}
    Params.WndParent := FParentWindow;
  end;
end;

procedure TModalDialog.ExecuteModal;
begin
  repeat
    { Delphi calls Application.HandleMessage
      But HandleMessage processes all pending events and then calls idle,
      which will wait for new messages. Under Win32 there is always a next
      message, so it works there. The LCL is OS independent, and so it uses
      a better way: }
    try
      WidgetSet.AppProcessMessages; // process all events
    except
      if Application.CaptureExceptions then
        Application.HandleException(Self)
      else
        raise;
    end;
    if Application.Terminated then
      ModalResult := mrCancel;
    if ModalResult <> 0 then
    begin
      CloseModal;
      if ModalResult <> 0 then Break;
    end;

    Application.Idle(true);
  until False;
end;

function TModalDialog.ShowModal: Integer;

  procedure RaiseShowModalImpossible;
  var
    s: String;
  begin
    DebugLn('TModalForm.ShowModal Visible=',dbgs(Visible),' Enabled=',dbgs(Enabled),
      ' fsModal=',dbgs(fsModal in FFormState),' MDIChild=',dbgs(FormStyle = fsMDIChild));
    s:='TCustomForm.ShowModal for '+DbgSName(Self)+' impossible, because';
    if Visible then
      s:=s+' already visible (hint for designer forms: set Visible property to false)';
    if not Enabled then
      s:=s+' not enabled';
    if fsModal in FFormState then
      s:=s+' already modal';
    if FormStyle = fsMDIChild then
      s:=s+' FormStyle=fsMDIChild';
    raise EInvalidOperation.Create(s);
  end;

var
{$IF DEFINED(LCLCOCOA)}
  DisabledList: TList;
{$ENDIF}
  SavedFocusState: TFocusState;
  ActiveWindow: HWnd;
begin
  if Self = nil then
    raise EInvalidOperation.Create('TModalForm.ShowModal Self = nil');
  if Application.Terminated then
    ModalResult := 0;
  // Cancel drags
  DragManager.DragStop(false);
  // Close popupmenus
  if ActivePopupMenu <> nil then
    ActivePopupMenu.Close;
  if Visible or (not Enabled) or (FormStyle = fsMDIChild) then
    RaiseShowModalImpossible;
  // Kill capture when opening another dialog
  if GetCapture <> 0 then
    SendMessage(GetCapture, LM_CANCELMODE, 0, 0);
  ReleaseCapture;

  if Owner is TCustomForm then
    ActiveWindow := TCustomForm(Owner).Handle
  else begin
    ActiveWindow := GetActiveWindow;
  end;

  // If parent window is normal window then call inherited method
//  if GetWindowLong(ActiveWindow, GWL_HWNDPARENT) <> 0 then
//    Result:= inherited ShowModal
//  else
    begin
      Include(FFormState, fsModal);
      FParentWindow := ActiveWindow;
      SavedFocusState := SaveFocusState;
      Screen.MoveFormToFocusFront(Self);
      ModalResult := 0;

      try
{$IF NOT DEFINED(LCLCOCOA)}
        EnableWindow(FParentWindow, False);
{$ENDIF}
        // If window already created then recreate it to force
        // call CreateParams with appropriate parent window
        if HandleAllocated then
        begin
{$IF NOT DEFINED(LCLWIN32)}
          RecreateWnd(Self);
{$ELSE}
          SetWindowLongPtr(Handle, GWL_STYLE, GetWindowLongPtr(Handle, GWL_STYLE) or LONG_PTR(WS_POPUP));
          SetWindowLongPtr(Handle, GWL_HWNDPARENT, FParentWindow);
{$ENDIF}
        end;
{$IF DEFINED(LCLCOCOA)}
        if WidgetSet.GetLCLCapability(lcModalWindow) = LCL_CAPABILITY_NO then
          DisabledList := Screen.DisableForms(Self)
        else
          DisabledList := nil;
{$ENDIF}
        Show;
        try
          EnableWindow(Handle, True);
          // Activate must happen after show
          Perform(CM_ACTIVATE, 0, 0);
          TWSCustomFormClass(WidgetSetClass).ShowModal(Self);

          ExecuteModal;

          Result := ModalResult;
          if HandleAllocated and (GetActiveWindow <> Handle) then
            ActiveWindow := 0;
        finally
          { Guarantee execution of widgetset CloseModal }
          TWSCustomFormClass(WidgetSetClass).CloseModal(Self);
          // Set our modalresult to mrCancel before hiding.
          if ModalResult = 0 then
            ModalResult := mrCancel;

{$IF DEFINED(LCLCOCOA)}
          Screen.EnableForms(DisabledList);
{$ELSE}
          EnableWindow(FParentWindow, True);
{$ENDIF}
          // Needs to be called only in ShowModal
          Perform(CM_DEACTIVATE, 0, 0);
          Exclude(FFormState, fsModal);
        end;
      finally
        RestoreFocusState(SavedFocusState);
        if LCLIntf.IsWindow(ActiveWindow) then
         SetActiveWindow(ActiveWindow);
        // Hide window when focus already changed back
        // to parent window to avoid blinking
        LCLIntf.ShowWindow(Handle, SW_HIDE);
        Visible := False;
      end;
    end;
end;

var
  ShellContextMenu : TShellContextMenu = nil;

{$IFDEF MSWINDOWS}

const
  WM_USER_ASSOCCHANGED = WM_USER + 201;

var
  OldWProc: WNDPROC;

function MyWndProc(hWnd: HWND; uiMsg: UINT; wParam: WPARAM; lParam: LPARAM): LRESULT; stdcall;
begin
  if (uiMsg = WM_SETTINGCHANGE) and (lParam <> 0) and (StrComp('Environment', {%H-}PAnsiChar(lParam)) = 0) then
  begin
    UpdateEnvironment;
    DCDebug('WM_SETTINGCHANGE:Environment');
  end;

  if (uiMsg = WM_DEVICECHANGE) and (wParam = DBT_DEVNODES_CHANGED) and (lParam = 0) then
  begin
    Screen.UpdateMonitors; // Refresh monitor list
    DCDebug('WM_DEVICECHANGE:DBT_DEVNODES_CHANGED');
  end;

  if (uiMsg = WM_USER_ASSOCCHANGED) then
  begin
    PixMapManager.ClearSystemCache;
    DCDebug('WM_USER_ASSOCCHANGED');
  end;

  Result := CallWindowProc(OldWProc, hWnd, uiMsg, wParam, lParam);
end;

{$IF DEFINED(LCLWIN32)}
procedure ActivateHandler(Self, Sender: TObject);
var
  I: Integer = 0;
begin
  with Screen do
  begin
    while (I < CustomFormCount) and (((CustomFormsZOrdered[I] is TModalForm) and
          ((CustomFormsZOrdered[I] as TModalForm).FParentWindow <> 0)) or not
          (fsModal in CustomFormsZOrdered[I].FormState)) do
      Inc(I);
    // If modal form exists then activate it
    if (I >= 0) and (I < CustomFormCount) then
      CustomFormsZOrdered[I].BringToFront;
  end;
end;
{$ELSEIF DEFINED(LCLQT5)}
procedure ScreenFormEvent(Self, Sender: TObject; Form: TCustomForm);
var
  Handle: HWND;
  AWindow: QWidgetH;
begin
  if g_darkModeSupported then
  begin
    Handle:= GetWindowHandle(Form);
    AllowDarkModeForWindow(Handle, True);
    RefreshTitleBarThemeColor(Handle);
  end;

  if (Form is THintWindow) then
  begin
    AWindow:= QWidget_window(TQtWidget(Form.Handle).GetContainerWidget);
    QWidget_setWindowFlags(AWindow, QtTool or QtFramelessWindowHint);
    QWidget_setAttribute(AWindow, QtWA_ShowWithoutActivating);
  end;
end;
{$ENDIF}

procedure MenuHandler(Self, Sender: TObject);
var
  Ret: DWORD;
begin
  Ret:= WNetDisconnectDialog(fmain.frmMain.Handle, RESOURCETYPE_DISK);
  case Ret of
    NO_ERROR, DWORD(-1): ;
    else MessageDlg(mbSysErrorMessage(Ret), mtError, [mbOK], 0);
  end;
end;

procedure CreateShortcut(Self, Sender: TObject);
var
  ShortcutName: String;
  SelectedFiles: TFiles;
begin
  if (not frmMain.ActiveFrame.FileSource.IsClass(TFileSystemFileSource)) or
     (not frmMain.NotActiveFrame.FileSource.IsClass(TFileSystemFileSource))then
  begin
    msgWarning(rsMsgErrNotSupported);
    Exit;
  end;

  SelectedFiles := frmMain.ActiveFrame.CloneSelectedOrActiveFiles;
  try
    if SelectedFiles.Count > 0 then
    begin
      ShortcutName:= frmMain.NotActiveFrame.CurrentPath + SelectedFiles[0].NameNoExt + '.lnk';
      if ShowInputQuery(rsMnuCreateShortcut, EmptyStr, ShortcutName) then
      begin
        if mbFileExists(ShortcutName) then
        begin
          if not msgYesNo(Format(rsMsgFileExistsRwrt, [WrapTextSimple(ShortcutName, 100)])) then
            Exit;
        end;
        try
          uMyWindows.CreateShortcut(SelectedFiles[0].FullPath, ShortcutName);
        except
          on E: Exception do msgError(E.Message);
        end;
      end;
    end;
  finally
    FreeAndNil(SelectedFiles);
  end;
end;
{$ENDIF}

{$IF DEFINED(LCLGTK2) or ((DEFINED(LCLQT) or DEFINED(LCLQT5) or DEFINED(LCLQT6)) and not (DEFINED(DARWIN) or DEFINED(MSWINDOWS)))}

procedure ScreenFormEvent(Self, Sender: TObject; Form: TCustomForm);
{$IF DEFINED(LCLGTK2)}
var
  ClassName: String;
begin
  ClassName:= Form.ClassName;
  gtk_window_set_role(PGtkWindow(Form.Handle), PAnsiChar(ClassName));
end;
{$ELSEIF DEFINED(LCLQT) or DEFINED(LCLQT5) or DEFINED(LCLQT6)}
var
  ClassName: WideString;
begin
  if not (Form is THintWindow) then
  begin
    ClassName:= Form.ClassName;
    QWidget_setWindowRole(QWidget_window(TQtWidget(Form.Handle).GetContainerWidget), @ClassName);
  end;
end;
{$ENDIF}

{$ENDIF}

{$IF DEFINED(LCLGTK2)}

procedure OnThemeChange; cdecl;
begin
  ThemeServices.IntfDoOnThemeChange;
end;

{$ENDIF}

procedure MainFormCreate(MainForm : TCustomForm);
{$IFDEF MSWINDOWS}
const
  SHCNRF_ShellLevel = $0002;
var
  Handle: HWND;
  Handler: TMethod;
  MenuItem: TMenuItem;
  AEntries: TSHChangeNotifyEntry;
begin
{$IF DEFINED(LCLWIN32)}
  Handler.Code:= @ActivateHandler;
  Handler.Data:= MainForm;
  // Setup application OnActivate handler
  Application.AddOnActivateHandler(TNotifyEvent(Handler), True);
  // Disable application button on taskbar
  with Widgetset do
  SetWindowLong(AppHandle, GWL_EXSTYLE, GetWindowLong(AppHandle, GWL_EXSTYLE) or WS_EX_TOOLWINDOW);
{$ELSEIF DEFINED(LCLQT5)}
  if g_darkModeEnabled then
  begin
    Handler.Data:= MainForm;
    Handler.Code:= @ScreenFormEvent;
    Screen.AddHandlerFormVisibleChanged(TScreenFormEvent(Handler), True);
  end;
{$ENDIF}
  // Register shell folder file source
  if (Win32MajorVersion > 5) then
  begin
    RegisterVirtualFileSource(TShellFileSource.RootName, TShellFileSource);
  end;
  // Register recycle bin file source
  if CheckWin32Version(5, 1) then
  begin
    RegisterVirtualFileSource(rsVfsRecycleBin, TRecycleBinFileSource);
  end;
  // Register Windows Subsystem for Linux (WSL) file source
  if CheckWin32Version(10) then
  begin
    RegisterVirtualFileSource('Linux', TWslFileSource, TWslFileSource.Available);
  end;
  // Register network file source
  RegisterVirtualFileSource(rsVfsNetwork, TWinNetFileSource);

  // If run under administrator
  if (IsUserAdmin = dupAccept) then
  begin
    with TfrmMain(MainForm) do
      StaticTitle:= StaticTitle + ' - Administrator';
  end;

  Handle:= GetWindowHandle(Application.MainForm);
  // Add main window message handler
  {$PUSH}{$HINTS OFF}
  OldWProc := WNDPROC(SetWindowLongPtr(Handle, GWL_WNDPROC, LONG_PTR(@MyWndProc)));
  {$POP}

  if Succeeded(SHGetFolderLocation(Handle, CSIDL_DRIVES, 0, 0, AEntries.pidl)) then
  begin
    AEntries.fRecursive:= False;
    SHChangeNotifyRegister(Handle, SHCNRF_ShellLevel, SHCNE_ASSOCCHANGED, WM_USER_ASSOCCHANGED, 1, @AEntries);
  end;

  with frmMain do
  begin
    Handler.Code:= @MenuHandler;
    Handler.Data:= MainForm;

    MenuItem:= TMenuItem.Create(mnuMain);
    MenuItem.Caption:= '-';
    mnuNetwork.Add(MenuItem);

    MenuItem:= TMenuItem.Create(mnuMain);
    MenuItem.Action:= actMapNetworkDrive;
    mnuNetwork.Add(MenuItem);

    MenuItem:= TMenuItem.Create(mnuMain);
    MenuItem.Caption:= rsMnuDisconnectNetworkDrive;
    MenuItem.OnClick:= TNotifyEvent(Handler);
    mnuNetwork.Add(MenuItem);

    MenuItem:= TMenuItem.Create(mnuMain);
    MenuItem.Caption:= '-';
    mnuNetwork.Add(MenuItem);

    MenuItem:= TMenuItem.Create(mnuMain);
    MenuItem.Action:= frmMain.actCopyNetNamesToClip;
    mnuNetwork.Add(MenuItem);

    MenuItem:= TMenuItem.Create(mnuMain);
    MenuItem.Caption:= rsMnuCreateShortcut;
    Handler.Code:= @CreateShortcut;
    MenuItem.OnClick:= TNotifyEvent(Handler);
    mnuFiles.Insert(mnuFiles.IndexOf(miMakeDir) + 1, MenuItem);
  end;
end;
{$ELSE}
{$IF DEFINED(LCLQT) or DEFINED(LCLQT5) or DEFINED(LCLQT6) or DEFINED(LCLGTK2)}
var
  Handler: TMethod;
{$ENDIF}
{$IF DEFINED(DARWIN)}
var
  MenuItem: TMenuItem;
{$ENDIF}
begin
  if fpGetUID = 0 then // if run under root
  begin
    with TfrmMain(MainForm) do
      StaticTitle:= StaticTitle + ' - ROOT PRIVILEGES';
  end;
  {$IF NOT (DEFINED(DARWIN) OR DEFINED(HAIKU))}
  if HasGio then
  begin
    if TGioFileSource.IsSupportedPath('trash://') then
      RegisterVirtualFileSource(rsVfsRecycleBin, TTrashFileSource, True);
    if TGioFileSource.IsSupportedPath('network://') then
      RegisterVirtualFileSource(rsVfsNetwork, TNetworkFileSource, True);
    RegisterVirtualFileSource('GVfs', TGioFileSource, False);
  end;
  {$ENDIF}

  {$IF DEFINED(DARWIN) AND DEFINED(LCLQT)}
  FMain:= MainForm;
  Handler.Data:= MainForm;
  Handler.Code:= @ActiveFormChangedHandler;
  Screen.AddHandlerActiveFormChanged(TScreenFormEvent(Handler), True);
  {$ELSEIF DEFINED(LCLGTK2) or DEFINED(LCLQT) or DEFINED(LCLQT5) or DEFINED(LCLQT6)}
  Handler.Data:= MainForm;
  Handler.Code:= @ScreenFormEvent;
  ScreenFormEvent(MainForm, MainForm, MainForm);
  Screen.AddHandlerFormAdded(TScreenFormEvent(Handler), True);
  {$ENDIF}

  {$IF DEFINED(LCLGTK2)}
  Handler.Data:= gtk_settings_get_default();
  if Assigned(Handler.Data) then
  begin
    g_signal_connect_data(Handler.Data, 'notify::gtk-theme-name',
                          @OnThemeChange, nil, nil, 0);
  end;
  {$ENDIF}

  {$IF DEFINED(DARWIN)}
  if HasMountURL then
  begin
    with frmMain do
    begin
      MenuItem:= TMenuItem.Create(mnuMain);
      MenuItem.Caption:= '-';
      mnuNetwork.Add(MenuItem);

      MenuItem:= TMenuItem.Create(mnuMain);
      MenuItem.Action:= actMapNetworkDrive;
      mnuNetwork.Add(MenuItem);
    end;
  end;
  {$ENDIF}
end;
{$ENDIF}

procedure ShowContextMenu(Parent: TWinControl; var Files : TFiles; X, Y : Integer;
                          Background: Boolean; CloseEvent: TNotifyEvent; UserWishForContextMenu:TUserWishForContextMenu = uwcmComplete);
{$IF DEFINED(MSWINDOWS)}
begin
  if Assigned(Files) and (Files.Count = 0) then
  begin
    FreeAndNil(Files);
    Exit;
  end;

  try
    // Create new context menu
    ShellContextMenu:= TShellContextMenu.Create(Parent, Files, Background, UserWishForContextMenu);
    ShellContextMenu.OnClose := CloseEvent;
    // Show context menu
    ShellContextMenu.PopUp(X, Y);
  finally
    // Free created menu
    FreeAndNil(ShellContextMenu);
  end;
end;
{$ELSEIF DEFINED(DARWIN)}
  function getFilePaths( contextFiles: TFiles ): TStringArray;
  var
    i: Integer;
    count: Integer;
  begin
    count:= contextFiles.Count;
    SetLength( Result, count );
    for i:=0 to count-1 do begin
      Result[i]:= contextFiles[i].FullPath;
    end;
  end;

var
  contextFiles: TFiles;
begin
  if Files.Count = 0 then
  begin
    FreeAndNil(Files);
    Exit;
  end;

  try
    // Create new context menu
    contextFiles:= Files;
    ShellContextMenu:= TShellContextMenu.Create(nil, Files, Background, UserWishForContextMenu);
    ShellContextMenu.OnClose := CloseEvent;
    frmMain.ActiveFrame.FileSource.QueryContextMenu(contextFiles, TPopupMenu(ShellContextMenu));
    // Show context menu
    MacosServiceMenuHelper.PopUp( ShellContextMenu, rsMacOSMenuServices, getFilepaths(contextFiles) );
  finally
    // Free created menu
    FreeAndNil(ShellContextMenu);
  end;
end;
{$ELSE}
begin
  if Files.Count = 0 then
  begin
    FreeAndNil(Files);
    Exit;
  end;

  // Free previous created menu
  FreeAndNil(ShellContextMenu);
  // Create new context menu
  ShellContextMenu:= TShellContextMenu.Create(nil, Files, Background, UserWishForContextMenu);
  ShellContextMenu.OnClose := CloseEvent;
  ShellContextMenu.PopUp(X, Y);
end;
{$ENDIF}

procedure ShowDriveContextMenu(Parent: TWinControl; ADrive: PDrive; X, Y : Integer;
                               CloseEvent: TNotifyEvent);
{$IFDEF MSWINDOWS}
var
  aFile: TFile;
  Files: TFiles;
begin
  if ADrive.DriveType = dtVirtual then
    ShowVirtualDriveMenu(ADrive, X, Y, CloseEvent)
  else begin
    aFile := TFileSystemFileSource.CreateFile(EmptyStr);
    if ADrive^.DriveType = dtSpecial then
    begin
      aFile.LinkProperty.LinkTo := ADrive^.DeviceId;
      aFile.Attributes := FILE_ATTRIBUTE_DEVICE;
    end
    else begin
      aFile.FullPath := ADrive^.Path;
      aFile.Attributes := faFolder or FILE_ATTRIBUTE_DEVICE;
    end;
    Files:= TFiles.Create(EmptyStr); // free in ShowContextMenu
    Files.Add(aFile);
    ShowContextMenu(Parent, Files, X, Y, False, CloseEvent);
  end;
end;
{$ELSE}
begin
  if ADrive.DriveType = dtVirtual then
    ShowVirtualDriveMenu(ADrive, X, Y, CloseEvent)
  else
  begin
    // Free previous created menu
    FreeAndNil(ShellContextMenu);
    // Create new context menu
    ShellContextMenu:= TShellContextMenu.Create(nil, ADrive);
    ShellContextMenu.OnClose := CloseEvent;
    // show context menu
    ShellContextMenu.PopUp(X, Y);
  end;
end;
{$ENDIF}

procedure ShowTrashContextMenu(Parent: TWinControl; X, Y: Integer;
  CloseEvent: TNotifyEvent);
{$IFDEF MSWINDOWS}
var
  Files: TFiles = nil;
begin
  ShowContextMenu(Parent, Files, X, Y, False, CloseEvent);
end;
{$ELSE}
begin

end;
{$ENDIF}

(* Show file properties dialog *)
procedure ShowFilePropertiesDialog(aFileSource: IFileSource; const Files: TFiles);
{$IFDEF UNIX}
begin
{$IF NOT (DEFINED(DARWIN) OR DEFINED(HAIKU))}
  if gSystemItemProperties and aFileSource.IsClass(TFileSystemFileSource) then
  begin
   if ShowItemProperties(Files) then Exit;
  end;
{$ENDIF}
  ShowFileProperties(aFileSource, Files);
end;
{$ELSE}
var
  Index: Integer;
  contMenu: IContextMenu;
  cmici: TCMInvokeCommandInfo;
  DataObject: THDropDataObject;
begin
  if Files.Count = 0 then Exit;

  try
    if CheckWin32Version(5, 1) then
    begin
      DataObject:= THDropDataObject.Create(DROPEFFECT_NONE);
      for Index:= 0 to Files.Count - 1 do
      begin
        DataObject.Add(Files[Index].FullPath);
      end;
      OleCheckUTF8(MultiFileProperties(DataObject, 0));
    end
    else begin
      contMenu := GetShellContextMenu(frmMain.Handle, Files, False);
      if Assigned(contMenu) then
      begin
        cmici:= Default(TCMInvokeCommandInfo);
        with cmici do
        begin
          cbSize := SizeOf(TCMInvokeCommandInfo);
          hwnd := frmMain.Handle;
          lpVerb := sCmdVerbProperties;
          nShow := SW_SHOWNORMAL;
        end;
        OleCheckUTF8(contMenu.InvokeCommand(cmici));
      end;
    end;
  except
    on E: EOleError do
      raise EContextMenuException.Create(E.Message);
  end;
end;
{$ENDIF}

function ShowOpenIconDialog(Owner: TCustomControl; var sFileName : String) : Boolean;
var
  opdDialog : TOpenPictureDialog;
{$IFDEF MSWINDOWS}
  sFilter : String;
  iPos, iIconIndex: Integer;
  bAlreadyOpen : Boolean;
  bFlagKeepGoing : Boolean = True;
{$ENDIF}
begin
  opdDialog := nil;
{$IFDEF MSWINDOWS}
  sFilter := GraphicFilter(TGraphic) + '|' + rsFilterProgramsLibraries + ' (*.exe;*.dll)|*.exe;*.dll' + '|' +
             Format(rsAllFiles, [GetAllFilesMask, GetAllFilesMask, '']);
  bAlreadyOpen := False;

  iPos :=Pos(',', sFileName);
  if iPos <> 0 then
    begin
      iIconIndex := StrToIntDef(Copy(sFileName, iPos + 1, Length(sFileName) - iPos), 0);
      sFileName := Copy(sFileName, 1, iPos - 1);
    end
  else
    begin
      opdDialog := TOpenPictureDialog.Create(Owner);
      opdDialog.Filter := sFilter;
      opdDialog.InitialDir := ExtractFileDir(sFileName);
      opdDialog.FileName := sFileName;
      Result := opdDialog.Execute;
      if Result then sFileName := opdDialog.FileName else bFlagKeepGoing := False;
      bAlreadyOpen := True;
    end;

  if FileIsExeLib(sFileName) then
    begin
      if bFlagKeepGoing then
      begin
        Result := SHChangeIconDialog(GetWindowHandle(Owner), sFileName, iIconIndex);
        if Result then sFileName := sFileName + ',' + IntToStr(iIconIndex);
      end;
    end
  else if not bAlreadyOpen then
{$ENDIF}
    begin
      opdDialog := TOpenPictureDialog.Create(Owner);
      opdDialog.InitialDir:=ExtractFileDir(sFileName);
{$IFDEF MSWINDOWS}
      opdDialog.Filter:= sFilter;
{$ENDIF}
      opdDialog.FileName := sFileName;
      Result:= opdDialog.Execute;
      sFileName := opdDialog.FileName;
    end;

  if Assigned(opdDialog) then
    FreeAndNil(opdDialog);
end;

function GetControlHandle(AWindow: TWinControl): HWND;
{$IF DEFINED(MSWINDOWS) and DEFINED(LCLQT5)}
begin
  Result:= HWND(QWidget_winId(TQtWidget(AWindow.Handle).GetContainerWidget));
end;
{$ELSE}
begin
  Result:= AWindow.Handle;
end;
{$ENDIF}

function GetWindowHandle(AWindow: TWinControl): HWND;
{$IF DEFINED(MSWINDOWS) and DEFINED(LCLQT5)}
begin
  Result:= Windows.GetAncestor(HWND(QWidget_winId(TQtWidget(AWindow.Handle).GetContainerWidget)), GA_ROOT);
end;
{$ELSE}
begin
  Result:= AWindow.Handle;
end;
{$ENDIF}

function GetWindowHandle(AHandle: HWND): HWND;
{$IF DEFINED(MSWINDOWS) and DEFINED(LCLQT5)}
begin
  Result:= Windows.GetAncestor(HWND(QWidget_winId(TQtWidget(AHandle).GetContainerWidget)), GA_ROOT);
end;
{$ELSE}
begin
  Result:= AHandle;
end;
{$ENDIF}

procedure CopyNetNamesToClip;
{$IF DEFINED(MSWINDOWS)}
var
  I: Integer;
  sl: TStringList = nil;
  SelectedFiles: TFiles = nil;
begin
  SelectedFiles := frmMain.ActiveFrame.CloneSelectedOrActiveFiles;
  try
    if SelectedFiles.Count > 0 then
    begin
      sl := TStringList.Create;
      for I := 0 to SelectedFiles.Count - 1 do
      begin
        sl.Add(mbGetRemoteFileName(SelectedFiles[I].FullPath));
      end;

      Clipboard.Clear; // Prevent multiple formats in Clipboard (specially synedit)
      Clipboard.AsText := TrimRightLineEnding(sl.Text, sl.TextLineBreakStyle);
    end;

  finally
    FreeAndNil(sl);
    FreeAndNil(SelectedFiles);
  end;
end;
{$ELSE}
begin
  msgWarning(rsMsgErrNotSupported);
end;
{$ENDIF}

procedure MapNetworkDrive;
{$IF DEFINED(MSWINDOWS)}
var
  Ret: DWORD;
  Res: TNetResourceA;
  CDS: TConnectDlgStruct;
begin
  ZeroMemory(@Res, SizeOf(TNetResourceA));
  Res.dwType := RESOURCETYPE_DISK;
  CDS.cbStructure := SizeOf(TConnectDlgStruct);
  CDS.hwndOwner := frmMain.Handle;
  CDS.lpConnRes := @Res;
  CDS.dwFlags := 0;
  Ret:= WNetConnectionDialog1(CDS);
  if Ret = NO_ERROR then
  begin
    SetFileSystemPath(frmMain.ActiveFrame, AnsiChar(Int64(CDS.dwDevNum) + Ord('a') - 1) + ':\');
  end
  else if Ret <> DWORD(-1) then begin
    MessageDlg(mbSysErrorMessage(Ret), mtError, [mbOK], 0);
  end;
end;
{$ELSEIF DEFINED(UNIX) AND NOT DEFINED(HAIKU)}
var
  Address: String = '';
begin
  if ShowInputQuery(Application.Title, rsMsgURL, False, Address) then
  begin
  {$IF DEFINED(DARWIN)}
    MountNetworkDrive(Address);
  {$ELSE}
    ChooseFileSource(frmMain.ActiveFrame, Address);
  {$ENDIF}
  end;
end;
{$ELSE}
begin
  msgWarning(rsMsgErrNotSupported);
end;
{$ENDIF}

function DarkStyle: Boolean;
{$IF DEFINED(DARKWIN)}
begin
  Result:= g_darkModeEnabled;
end;
{$ELSE}
begin
  Result:= not ColorIsLight(ColorToRGB(clWindow));
end;
{$ENDIF}

{$IF DEFINED(UNIX) AND NOT (DEFINED(DARWIN) OR DEFINED(HAIKU))}
procedure ShowOpenWithDialog(TheOwner: TComponent; const FileList: TStringList);
begin
  fOpenWith.ShowOpenWithDlg(TheOwner, FileList);
end;
{$ENDIF}

{$IF DEFINED(UNIX)}
procedure handle_sigterm(signal: longint); cdecl;
begin
  DCDebug('SIGTERM');
  frmMain.Close;
end;

procedure RegisterHandler;
var
  sa: sigactionrec;
begin
  FillChar(sa, SizeOf(sa), #0);
  sa.sa_handler := @handle_sigterm;
  if (fpSigAction(SIGTERM, @sa, nil) = -1) then
  begin
    Errors.PError('fpSigAction', GetLastOSError);
  end;
end;

initialization
  RegisterHandler;
{$ENDIF}

finalization
  FreeAndNil(ShellContextMenu);

end.

