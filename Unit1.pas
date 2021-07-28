<<<<<<< HEAD
unit Unit1;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Vcl.ComCtrls, TlHelp32, inifiles, Vcl.ExtCtrls, ShellApi,
  IdIntercept, IdBaseComponent, IdLogBase, IdLogFile, IdLogStream, Vcl.AppEvnts, System.Win.Registry;

type
  TForm1 = class(TForm)
    startw: TButton;
    startb: TButton;
    PageControl1: TPageControl;
    TabSheet1: TTabSheet;
    TabSheet2: TTabSheet;
    Panel1: TPanel;
    Panel2: TPanel;
    Label1: TLabel;
    Checker: TTimer;
    autorestart_checkbox: TCheckBox;
    startwithwin_checkbox: TCheckBox;
    Button1: TButton;
    procedure startwClick(Sender: TObject);
    procedure startbClick(Sender: TObject);
    procedure CheckerTimer(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure startwithwin_checkboxClick(Sender: TObject);
    procedure Button1Click(Sender: TObject);
    procedure startwithwin_checkboxMouseEnter(Sender: TObject);
    procedure startwithwin_checkboxMouseLeave(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  Form1: TForm1;
  IniFile : TIniFile;
  worldserver_loc : string;
  bnetserver_loc : string;
  autorestartservers : string;
  startserverswithapp : string;
  startappwithwinfos : string;
  iclickedreallytostartwithwinfos : bool;
  embeded : bool;
  stopservers : bool;

implementation

{$R *.dfm}

function add_startup(name, filename: string): BOOL;
begin
  try
    begin
      if (FileExists(filename)) and not(name = '') then
      begin
        filename := StringReplace(filename, '/', '\',
          [rfReplaceAll, rfIgnoreCase]);
        with TRegistry.Create do
          try
            RootKey := HKEY_LOCAL_MACHINE;
            OpenKey('\SOFTWARE\Microsoft\Windows\CurrentVersion\Run', True);
            WriteString(name, filename);
          finally
            CloseKey;
            Free;
          end;
        Result := True;
      end
      else
      begin
        Result := False;
      end;
    end;
  except
    Result := False;
  end;
end;

function delete_startup(filename: string): BOOL;
begin
  if not(filename = '') then
  begin
    try
      begin
        with TRegistry.Create do
          try
            RootKey := HKEY_LOCAL_MACHINE;
            OpenKey('\SOFTWARE\Microsoft\Windows\CurrentVersion\Run', True);
            DeleteValue(filename);
          finally
            CloseKey;
            Free;
          end;
        Result := True;
      end;
    except
      Result := False;
    end;
  end
  else
  begin
    Result := False;
  end;
end;

function processExists(exeFileName: string): Boolean;
var
  ContinueLoop: BOOL;
  FSnapshotHandle: THandle;
  FProcessEntry32: TProcessEntry32;
begin
  FSnapshotHandle := CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
  FProcessEntry32.dwSize := SizeOf(FProcessEntry32);
  ContinueLoop := Process32First(FSnapshotHandle, FProcessEntry32);
  Result := False;
  while Integer(ContinueLoop) <> 0 do
  begin
    if ((UpperCase(ExtractFileName(FProcessEntry32.szExeFile)) =
      UpperCase(ExeFileName)) or (UpperCase(FProcessEntry32.szExeFile) =
      UpperCase(ExeFileName))) then
    begin
      Result := True;
    end;
    ContinueLoop := Process32Next(FSnapshotHandle, FProcessEntry32);
  end;
  CloseHandle(FSnapshotHandle);
end;

   function KillTask(ExeFileName: string): Integer;
    const
      PROCESS_TERMINATE = $0001;
    var
      ContinueLoop: BOOL;
      FSnapshotHandle: THandle;
      FProcessEntry32: TProcessEntry32;
    begin
      Result := 0;
      FSnapshotHandle := CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
      FProcessEntry32.dwSize := SizeOf(FProcessEntry32);
      ContinueLoop := Process32First(FSnapshotHandle, FProcessEntry32);
      while Integer(ContinueLoop) <> 0 do
      begin
        if ((UpperCase(ExtractFileName(FProcessEntry32.szExeFile)) =
          UpperCase(ExeFileName)) or (UpperCase(FProcessEntry32.szExeFile) =
          UpperCase(ExeFileName))) then
          Result := Integer(TerminateProcess(
                            OpenProcess(PROCESS_TERMINATE,
                                        BOOL(0),
                                        FProcessEntry32.th32ProcessID),
                                        0));
         ContinueLoop := Process32Next(FSnapshotHandle, FProcessEntry32);
      end;
      CloseHandle(FSnapshotHandle);
    end;

procedure ShowAppEmbedded(WindowHandle: THandle; Container: TWinControl);
var
  WindowStyle : Integer;
  FAppThreadID: Cardinal;
begin
  /// Set running app window styles.
  WindowStyle := GetWindowLong(WindowHandle, GWL_STYLE);
  WindowStyle := WindowStyle
                 - WS_CAPTION
                 - WS_BORDER
                 - WS_OVERLAPPED
                 - WS_THICKFRAME;
  SetWindowLong(WindowHandle,GWL_STYLE,WindowStyle);

  /// Attach container app input thread to the running app input thread, so that
  ///  the running app receives user input.
  FAppThreadID := GetWindowThreadProcessId(WindowHandle, nil);
  AttachThreadInput(GetCurrentThreadId, FAppThreadID, True);

  /// Changing parent of the running app to our provided container control
  SetParent(WindowHandle,Container.Handle);
  SendMessage(Container.Handle, WM_UPDATEUISTATE, UIS_INITIALIZE, 0);
  UpdateWindow(WindowHandle);

  /// This prevents the parent control to redraw on the area of its child windows (the running app)
  SetWindowLong(Container.Handle, GWL_STYLE, GetWindowLong(Container.Handle,GWL_STYLE) or WS_CLIPCHILDREN);
  /// Make the running app to fill all the client area of the container
  SetWindowPos(WindowHandle,0,0,0,Container.ClientWidth,Container.ClientHeight,SWP_NOZORDER);

  SetForegroundWindow(WindowHandle);

  embeded := true;
end;

procedure StopWorld;
begin
  // if world server running before close
  if (processExists('worldserver.exe')) then
  begin
    KillTask('worldserver.exe');
    form1.Panel1.Caption:='World Server is stopped.';
  end;
end;

procedure StopBnet;
begin
  // if bnet server running before close
  if (processExists('bnetserver.exe')) then
  begin
    KillTask('bnetserver.exe');
    form1.Panel2.Caption:='Bnet Server is stopped.';
  end;
end;

procedure TForm1.FormClose(Sender: TObject; var Action: TCloseAction);
begin
IniFile := TIniFile.Create(ChangeFileExt(Application.ExeName,'.ini')) ;
   try
     if autorestart_checkbox.Checked then
        IniFile.WriteString('Starthings', 'autorestartservers', 'yes')
     else
        IniFile.WriteString('Starthings', 'autorestartservers', 'no');
     if startwithwin_checkbox.Checked then
        IniFile.WriteString('Starthings', 'startappwithwinfos', 'yes')
     else
        IniFile.WriteString('Starthings', 'startappwithwinfos', 'no');
   finally
     IniFile.Free;
   end;

// + we stop the servers
StopBnet;
StopWorld;

end;

procedure TForm1.FormCreate(Sender: TObject);
begin
   checker.Enabled := true;
   iclickedreallytostartwithwinfos := false;
   embeded := false;
end;

procedure TForm1.FormShow(Sender: TObject);
begin
  IniFile := TIniFile.Create(ChangeFileExt(Application.ExeName,'.ini')) ;
   try
     worldserver_loc := ExpandFileName(ExtractFileDir(Application.ExeName) + '\') + 'worldserver.exe';
     bnetserver_loc := ExpandFileName(ExtractFileDir(Application.ExeName) + '\') + 'bnetserver.exe';
     //debug check location string
     //showmessage(worldserver_loc);
     autorestartservers := IniFile.ReadString('Starthings','autorestartservers','') ;
     startserverswithapp := IniFile.ReadString('Starthings','startserverswithapp','') ;
     startappwithwinfos := IniFile.ReadString('Starthings','startappwithwinfos','') ;
   finally
     IniFile.Free;
   end;
  // check settings
  if autorestartservers = 'yes' then
    autorestart_checkbox.Checked := true
  else
    autorestart_checkbox.Checked := false;
  if startappwithwinfos = 'yes' then
    startwithwin_checkbox.Checked := true
  else
    startwithwin_checkbox.Checked := false;
  // we want to see the worldserver window first
  pagecontrol1.ActivePage := TabSheet1;
end;

procedure TForm1.startwClick(Sender: TObject);
begin
  if processExists('worldserver.exe') then
    StopWorld
  else
  begin
    // begin starting
    if fileexists(worldserver_loc) then
      begin
        panel1.Caption:='Starting worldserver.';
        pagecontrol1.ActivePage := TabSheet1;
        ShellExecute(0, nil, (PChar(worldserver_loc)), nil, nil, SW_MINIMIZE);
     end
    else
    begin
      panel1.Caption:='Cannot find worldserver.exe.';
      autorestart_checkbox.Checked:=false;
      ShowMessage('Cannot find worldserver.exe. '#13#10'Place this app to the directory of worldserver.exe.');
    end;
  end;
end;

procedure TForm1.startwithwin_checkboxClick(Sender: TObject);
var
  dir: string;
  path: string;
begin
  if iclickedreallytostartwithwinfos = true then // show messages wont come out on starting
  begin
    if (startwithwin_checkbox.Checked) then
    begin
      dir := GetCurrentDir;
      path := Application.ExeName;

      if (add_startup('fuckyou', path)) then
      begin
        ShowMessage('Setting up starting with Windows successfully.');
      end
      else
      begin
        ShowMessage('Setting up starting with Windows failed.');
      end;
    end;
    if (startwithwin_checkbox.Checked= false) then
    begin
      if (delete_startup('fuckyou')) then
      begin
        ShowMessage('Starting this application with Windows is turned off successfully.');
      end
      else
      begin
        ShowMessage('Cannot remove the option to start this application with Windows. '#13#10'Sorry! :(  '#13#10' You have to do it manually: '#13#10' HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Run');
      end;
    end;
  end;
end;

procedure TForm1.startwithwin_checkboxMouseEnter(Sender: TObject);
begin
     iclickedreallytostartwithwinfos := true;
end;

procedure TForm1.startwithwin_checkboxMouseLeave(Sender: TObject);
begin
    iclickedreallytostartwithwinfos := false;
end;

procedure TForm1.Button1Click(Sender: TObject);
begin
  ShowMessage('TrinityCore Auto-Restarter for Windows.'#13#10'Works only with bnetserver.exe and worldserver.exe'#13#10'Place this exe to the worldserver.exe and bnetserver.exe directory.'#13#10'Tested on Windows Server 2012R and on Windows 11. '#13#10'Made by Fluxurion.');
end;

procedure TForm1.CheckerTimer(Sender: TObject);
begin
  // IF WORLD SERVER RUNNING
  if processExists('worldserver.exe') then
  begin
    panel1.Caption:='World Server is running.';
    panel1.Color:= clLime;
    startw.Caption:='Stop World Server';
    // embeding the worldserver
    ShowAppEmbedded(FindWindow(nil, PChar(ExpandFileName(ExtractFileDir(Application.ExeName) + '\') + 'worldserver.exe')), TabSheet1);
    //ShowAppEmbedded(FindWindow(nil, 'TrinityCore World Server Daemon'), TabSheet1);
  end
  else
  begin
    panel1.Caption:='World Server is stopped.';
    panel1.Color:= clSilver;
    startw.Caption:='Start World Server';
    // if autorestart enabled we call the start button click event
    if (autorestart_checkbox.Checked = true) then startw.Click;
  end;
  // IF BNET SERVER RUNNING
  if processExists('bnetserver.exe') then
  begin
    panel2.Caption:='Bnet Server is running.';
    panel2.Color:= clLime;
    startb.Caption:='Stop Bnet Server';
    // embeding the bnetserver
    ShowAppEmbedded(FindWindow(nil, PChar(ExpandFileName(ExtractFileDir(Application.ExeName) + '\') + 'bnetserver.exe')), TabSheet2);
    //ShowAppEmbedded(FindWindow(nil, 'TrinityCore Battle.net Server Daemon'), TabSheet2);
  end
  else
  begin
    panel2.Caption:='Bnetserver is stopped.';
    panel2.Color:= clSilver;
    startb.Caption:='Start Bnet Server';
    // if autorestart enabled we call the start button click event
    if (autorestart_checkbox.Checked = true) then startb.Click;
  end;
end;



procedure TForm1.startbClick(Sender: TObject);
begin
  if processExists('bnetserver.exe') then
    StopBnet
  else
  begin
    // begin starting
    if fileexists(bnetserver_loc) then
      begin
        panel2.Caption:='Starting bnetserver.';
        //pagecontrol1.ActivePage := TabSheet2;
        //ShellExecute(0, nil, (PChar(bnetserver_loc)), nil, nil, SW_MINIMIZE);
        ShellExecute(Self.Handle,'open',Pchar('bnetserver.exe'),'',nil,SW_MINIMIZE);
      end
    else
      begin
        panel2.Caption:='Cannot find bnetserver.exe.';
        autorestart_checkbox.Checked:=false;
        ShowMessage('Cannot find bnetserver.exe. '#13#10'Place this app to the directory of bnetserver.exe.');
      end;
  end;
end;


end.
=======
unit Unit1;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Vcl.ComCtrls, TlHelp32, inifiles, Vcl.ExtCtrls, ShellApi,
  IdIntercept, IdBaseComponent, IdLogBase, IdLogFile, IdLogStream, Vcl.AppEvnts, System.Win.Registry;

type
  TForm1 = class(TForm)
    startw: TButton;
    startb: TButton;
    StopButton: TButton;
    PageControl1: TPageControl;
    TabSheet1: TTabSheet;
    TabSheet2: TTabSheet;
    Panel1: TPanel;
    Panel2: TPanel;
    Label1: TLabel;
    Checker: TTimer;
    autorestart_checkbox: TCheckBox;
    startwithwin_checkbox: TCheckBox;
    Button1: TButton;
    procedure startwClick(Sender: TObject);
    procedure startbClick(Sender: TObject);
    procedure CheckerTimer(Sender: TObject);
    procedure StopButtonClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure startwithwin_checkboxClick(Sender: TObject);
    procedure Button1Click(Sender: TObject);
    procedure startwithwin_checkboxMouseEnter(Sender: TObject);
    procedure startwithwin_checkboxMouseLeave(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  Form1: TForm1;
  IniFile : TIniFile;
  worldserver_loc : string;
  bnetserver_loc : string;
  autorestartservers : string;
  startserverswithapp : string;
  startappwithwinfos : string;
  iclickedreallytostartwithwinfos : bool;
  embeded : bool;

implementation

{$R *.dfm}

function add_startup(name, filename: string): BOOL;
begin
  try
    begin
      if (FileExists(filename)) and not(name = '') then
      begin
        filename := StringReplace(filename, '/', '\',
          [rfReplaceAll, rfIgnoreCase]);
        with TRegistry.Create do
          try
            RootKey := HKEY_LOCAL_MACHINE;
            OpenKey('\SOFTWARE\Microsoft\Windows\CurrentVersion\Run', True);
            WriteString(name, filename);
          finally
            CloseKey;
            Free;
          end;
        Result := True;
      end
      else
      begin
        Result := False;
      end;
    end;
  except
    Result := False;
  end;
end;

function delete_startup(filename: string): BOOL;
begin
  if not(filename = '') then
  begin
    try
      begin
        with TRegistry.Create do
          try
            RootKey := HKEY_LOCAL_MACHINE;
            OpenKey('\SOFTWARE\Microsoft\Windows\CurrentVersion\Run', True);
            DeleteValue(filename);
          finally
            CloseKey;
            Free;
          end;
        Result := True;
      end;
    except
      Result := False;
    end;
  end
  else
  begin
    Result := False;
  end;
end;

function processExists(exeFileName: string): Boolean;
var
  ContinueLoop: BOOL;
  FSnapshotHandle: THandle;
  FProcessEntry32: TProcessEntry32;
begin
  FSnapshotHandle := CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
  FProcessEntry32.dwSize := SizeOf(FProcessEntry32);
  ContinueLoop := Process32First(FSnapshotHandle, FProcessEntry32);
  Result := False;
  while Integer(ContinueLoop) <> 0 do
  begin
    if ((UpperCase(ExtractFileName(FProcessEntry32.szExeFile)) =
      UpperCase(ExeFileName)) or (UpperCase(FProcessEntry32.szExeFile) =
      UpperCase(ExeFileName))) then
    begin
      Result := True;
    end;
    ContinueLoop := Process32Next(FSnapshotHandle, FProcessEntry32);
  end;
  CloseHandle(FSnapshotHandle);
end;

   function KillTask(ExeFileName: string): Integer;
    const
      PROCESS_TERMINATE = $0001;
    var
      ContinueLoop: BOOL;
      FSnapshotHandle: THandle;
      FProcessEntry32: TProcessEntry32;
    begin
      Result := 0;
      FSnapshotHandle := CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
      FProcessEntry32.dwSize := SizeOf(FProcessEntry32);
      ContinueLoop := Process32First(FSnapshotHandle, FProcessEntry32);
      while Integer(ContinueLoop) <> 0 do
      begin
        if ((UpperCase(ExtractFileName(FProcessEntry32.szExeFile)) =
          UpperCase(ExeFileName)) or (UpperCase(FProcessEntry32.szExeFile) =
          UpperCase(ExeFileName))) then
          Result := Integer(TerminateProcess(
                            OpenProcess(PROCESS_TERMINATE,
                                        BOOL(0),
                                        FProcessEntry32.th32ProcessID),
                                        0));
         ContinueLoop := Process32Next(FSnapshotHandle, FProcessEntry32);
      end;
      CloseHandle(FSnapshotHandle);
    end;

procedure ShowAppEmbedded(WindowHandle: THandle; Container: TWinControl);
var
  WindowStyle : Integer;
  FAppThreadID: Cardinal;
begin
  /// Set running app window styles.
  WindowStyle := GetWindowLong(WindowHandle, GWL_STYLE);
  WindowStyle := WindowStyle
                 - WS_CAPTION
                 - WS_BORDER
                 - WS_OVERLAPPED
                 - WS_THICKFRAME;
  SetWindowLong(WindowHandle,GWL_STYLE,WindowStyle);

  /// Attach container app input thread to the running app input thread, so that
  ///  the running app receives user input.
  FAppThreadID := GetWindowThreadProcessId(WindowHandle, nil);
  AttachThreadInput(GetCurrentThreadId, FAppThreadID, True);

  /// Changing parent of the running app to our provided container control
  SetParent(WindowHandle,Container.Handle);
  SendMessage(Container.Handle, WM_UPDATEUISTATE, UIS_INITIALIZE, 0);
  UpdateWindow(WindowHandle);

  /// This prevents the parent control to redraw on the area of its child windows (the running app)
  SetWindowLong(Container.Handle, GWL_STYLE, GetWindowLong(Container.Handle,GWL_STYLE) or WS_CLIPCHILDREN);
  /// Make the running app to fill all the client area of the container
  SetWindowPos(WindowHandle,0,0,0,Container.ClientWidth,Container.ClientHeight,SWP_NOZORDER);

  SetForegroundWindow(WindowHandle);

  embeded := true;
end;

procedure TForm1.StopButtonClick(Sender: TObject);
begin
  // if both servers stopped before close
  if not (processExists('bnetserver.exe') or processExists('worldserver.exe')) then
  begin
    ShowMessage('Both of the servers were stopped already.');
  end;
  // if both servers running before close
  if (processExists('bnetserver.exe') and processExists('worldserver.exe')) then
  begin
    if processExists('bnetserver.exe') then KillTask('bnetserver.exe');
    if processExists('worldserver.exe') then KillTask('worldserver.exe');
    ShowMessage('I stopped both of the servers.');
  end;
  // if bnet server running before close
  if ((processExists('bnetserver.exe')) and not (processExists('worldserver.exe'))) then
  begin
    if processExists('bnetserver.exe') then KillTask('bnetserver.exe');
    ShowMessage('I stopped the bnet server. '#13#10'World server was closed already.');
  end;
  // if world server running before close
  if (not (processExists('bnetserver.exe')) and (processExists('worldserver.exe'))) then
  begin
    if processExists('worldserver.exe') then KillTask('worldserver.exe');
    ShowMessage('I stopped the world server. '#13#10'Bnet server was closed already.');
  end;
end;


procedure TForm1.FormClose(Sender: TObject; var Action: TCloseAction);
begin
IniFile := TIniFile.Create(ChangeFileExt(Application.ExeName,'.ini')) ;
   try
     if autorestart_checkbox.Checked then
        IniFile.WriteString('Starthings', 'autorestartservers', 'yes')
     else
        IniFile.WriteString('Starthings', 'autorestartservers', 'no');
     if startwithwin_checkbox.Checked then
        IniFile.WriteString('Starthings', 'startappwithwinfos', 'yes')
     else
        IniFile.WriteString('Starthings', 'startappwithwinfos', 'no');
   finally
     IniFile.Free;
   end;

// + we stop the servers
StopButton.Click;

end;

procedure TForm1.FormCreate(Sender: TObject);
begin
   checker.Enabled := true;
   iclickedreallytostartwithwinfos := false;
   embeded := false;
end;

procedure TForm1.FormShow(Sender: TObject);
begin
  IniFile := TIniFile.Create(ChangeFileExt(Application.ExeName,'.ini')) ;
   try
     worldserver_loc := 'worldserver.exe';
     bnetserver_loc := 'bnetserver.exe';
     autorestartservers := IniFile.ReadString('Starthings','autorestartservers','') ;
     startserverswithapp := IniFile.ReadString('Starthings','startserverswithapp','') ;
     startappwithwinfos := IniFile.ReadString('Starthings','startappwithwinfos','') ;
   finally
     IniFile.Free;
   end;
  // check settings
  if autorestartservers = 'yes' then
    autorestart_checkbox.Checked := true
  else
    autorestart_checkbox.Checked := false;
  if startappwithwinfos = 'yes' then
    startwithwin_checkbox.Checked := true
  else
    startwithwin_checkbox.Checked := false;
  // we want to see the worldserver window first
  pagecontrol1.ActivePage := TabSheet1;
end;

procedure TForm1.startwClick(Sender: TObject);
begin
  if processExists('worldserver.exe') then
    ShowMessage('Worldserver already running.')
  else
  begin
    // begin starting
    if fileexists(worldserver_loc) then
      begin
        panel1.Caption:='Starting worldserver.';
        pagecontrol1.ActivePage := TabSheet1;
        ShellExecute(0, nil, (PChar(worldserver_loc)), nil, nil, SW_MINIMIZE);
     end
    else
    begin
      panel1.Caption:='Cannot find worldserver.exe.';
      autorestart_checkbox.Checked:=false;
      ShowMessage('Cannot find worldserver.exe. '#13#10'Place this app to the directory of worldserver.exe.');
    end;
  end;
end;

procedure TForm1.startwithwin_checkboxClick(Sender: TObject);
var
  dir: string;
  path: string;
begin
  if iclickedreallytostartwithwinfos = true then // show messages wont come out on starting
  begin
    if (startwithwin_checkbox.Checked) then
    begin
      dir := GetCurrentDir;
      path := Application.ExeName;

      if (add_startup('fuckyou', path)) then
      begin
        ShowMessage('Setting up starting with Windows successfully.');
      end
      else
      begin
        ShowMessage('Setting up starting with Windows failed.');
      end;
    end;
    if (startwithwin_checkbox.Checked= false) then
    begin
      if (delete_startup('fuckyou')) then
      begin
        ShowMessage('Starting this application with Windows is turned off successfully.');
      end
      else
      begin
        ShowMessage('Cannot remove the option to start this application with Windows. '#13#10'Sorry! :(  '#13#10' You have to do it manually: '#13#10' HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Run');
      end;
    end;
  end;
end;

procedure TForm1.startwithwin_checkboxMouseEnter(Sender: TObject);
begin
     iclickedreallytostartwithwinfos := true;
end;

procedure TForm1.startwithwin_checkboxMouseLeave(Sender: TObject);
begin
    iclickedreallytostartwithwinfos := false;
end;

procedure TForm1.Button1Click(Sender: TObject);
begin
  ShowMessage('TrinityCore Auto-Restarter for Windows.'#13#10'Works only with bnetserver.exe and worldserver.exe'#13#10'Place this exe to the worldserver.exe and bnetserver.exe directory.'#13#10'Tested on Windows Server 2012R and on Windows 11. '#13#10'Made by Fluxurion.');
end;

procedure TForm1.CheckerTimer(Sender: TObject);
begin
  // IF WORLD SERVER RUNNING
  if processExists('worldserver.exe') then
  begin
    panel1.Caption:='Worldserver is running.';
    panel1.Color:= clLime;
    // embeding the worldserver
    ShowAppEmbedded(FindWindow(nil, PChar(ExpandFileName(ExtractFileDir(Application.ExeName) + '\') + 'worldserver.exe')), TabSheet1);
    //ShowAppEmbedded(FindWindow(nil, 'TrinityCore World Server Daemon'), TabSheet1);
  end
  else
  begin
    panel1.Caption:='Worldserver is stopped.';
    panel1.Color:= clSilver;
    // if autorestart enabled we call the start button click event
    if (autorestart_checkbox.Checked = true) then startw.Click;
  end;
  // IF BNET SERVER RUNNING
  if processExists('bnetserver.exe') then
  begin
    panel2.Caption:='Bnetserver is running.';
    panel2.Color:= clLime;
    // embeding the bnetserver
    ShowAppEmbedded(FindWindow(nil, PChar(ExpandFileName(ExtractFileDir(Application.ExeName) + '\') + 'bnetserver.exe')), TabSheet2);
    //ShowAppEmbedded(FindWindow(nil, 'TrinityCore Battle.net Server Daemon'), TabSheet2);
  end
  else
  begin
    panel2.Caption:='Bnetserver is stopped.';
    panel2.Color:= clSilver;
    // if autorestart enabled we call the start button click event
    if (autorestart_checkbox.Checked = true) then startb.Click;
  end;
end;



procedure TForm1.startbClick(Sender: TObject);
begin
  if processExists('bnetserver.exe') then
    ShowMessage('Bnetserver already running.')
  else
  begin
    // begin starting
    if fileexists(bnetserver_loc) then
      begin
        panel2.Caption:='Starting bnetserver.';
        pagecontrol1.ActivePage := TabSheet2;
        //ShellExecute(0, nil, (PChar(bnetserver_loc)), nil, nil, SW_MINIMIZE);
        ShellExecute(Self.Handle,'open',Pchar('bnetserver.exe'),'',nil,SW_MINIMIZE);
      end
    else
      begin
        panel2.Caption:='Cannot find bnetserver.exe.';
        autorestart_checkbox.Checked:=false;
        ShowMessage('Cannot find bnetserver.exe. '#13#10'Place this app to the directory of bnetserver.exe.');
      end;
  end;
end;


end.
>>>>>>> c03a664f59e3e3fbe18ad9e386c44aff23fb7a71
