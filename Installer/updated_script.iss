#define MyAppName "Hadraniel Admin"
#define MyAppVersion "2.6"
#define MyAppPublisher "Hadraniel Solutions"
#define MyAppURL "https://hadraniel.com"
#define MyAppExeName "hadraniel_admin.exe"
#define MyAppDescription "Administrative Dashboard for Hadraniel Business Management"
#define BuildPath "C:\Users\HP\Desktop\hadraniel_Admin\build\windows\x64\runner\Release"
#define ProjectPath "C:\Users\HP\Desktop\hadraniel_Admin"

[Setup]
AppId={{B8E8F8A0-1234-5678-9ABC-DEF012345678}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} {#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
AppComments={#MyAppDescription}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
AllowNoIcons=yes
LicenseFile=
InfoBeforeFile={#ProjectPath}\README.md
OutputDir={#ProjectPath}\Installer\Output
OutputBaseFilename=HadranielAdminSetup_v{#MyAppVersion}
SetupIconFile={#ProjectPath}\windows\runner\resources\app_icon.ico
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=admin
ArchitecturesAllowed=x64
ArchitecturesInstallIn64BitMode=x64
UninstallDisplayIcon={app}\{#MyAppExeName}
UninstallDisplayName={#MyAppName}
VersionInfoVersion={#MyAppVersion}
VersionInfoCompany={#MyAppPublisher}
VersionInfoDescription={#MyAppDescription}
VersionInfoCopyright=Copyright (C) 2024 {#MyAppPublisher}
MinVersion=6.1sp1
DisableProgramGroupPage=yes
DisableReadyPage=no
ShowLanguageDialog=auto
CloseApplications=yes
RestartApplications=yes
CreateUninstallRegKey=yes
ChangesAssociations=no

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked
Name: "quicklaunchicon"; Description: "{cm:CreateQuickLaunchIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked; OnlyBelowVersion: 6.1
Name: "startmenuicon"; Description: "Create Start Menu shortcut"; GroupDescription: "{cm:AdditionalIcons}"
Name: "autostart"; Description: "Start {#MyAppName} automatically when Windows starts"; GroupDescription: "Startup Options"; Flags: unchecked

[Files]
; Main application executable
Source: "{#BuildPath}\{#MyAppExeName}"; DestDir: "{app}"; Flags: ignoreversion

; Core Flutter runtime
Source: "{#BuildPath}\flutter_windows.dll"; DestDir: "{app}"; Flags: ignoreversion

; Plugin DLLs - Check if they exist before including
Source: "{#BuildPath}\app_links_plugin.dll"; DestDir: "{app}"; Flags: ignoreversion skipifsourcedoesntexist
Source: "{#BuildPath}\flutter_secure_storage_windows_plugin.dll"; DestDir: "{app}"; Flags: ignoreversion skipifsourcedoesntexist
Source: "{#BuildPath}\url_launcher_windows_plugin.dll"; DestDir: "{app}"; Flags: ignoreversion skipifsourcedoesntexist
Source: "{#BuildPath}\file_picker_plugin.dll"; DestDir: "{app}"; Flags: ignoreversion skipifsourcedoesntexist
Source: "{#BuildPath}\path_provider_windows_plugin.dll"; DestDir: "{app}"; Flags: ignoreversion skipifsourcedoesntexist
Source: "{#BuildPath}\shared_preferences_windows_plugin.dll"; DestDir: "{app}"; Flags: ignoreversion skipifsourcedoesntexist

; Application data and assets
Source: "{#BuildPath}\data\*"; DestDir: "{app}\data"; Flags: ignoreversion recursesubdirs createallsubdirs

; Configuration and environment files
Source: "{#ProjectPath}\.env"; DestDir: "{app}"; Flags: ignoreversion skipifsourcedoesntexist

; Documentation and troubleshooting files
Source: "{#ProjectPath}\README.md"; DestDir: "{app}\docs"; Flags: ignoreversion skipifsourcedoesntexist
Source: "{#ProjectPath}\TROUBLESHOOTING_INVISIBLE_WINDOW.md"; DestDir: "{app}\docs"; Flags: ignoreversion skipifsourcedoesntexist
Source: "{#ProjectPath}\check_dependencies.bat"; DestDir: "{app}\tools"; Flags: ignoreversion skipifsourcedoesntexist
Source: "{#ProjectPath}\run_debug.bat"; DestDir: "{app}\tools"; Flags: ignoreversion skipifsourcedoesntexist

; Additional project documentation
Source: "{#ProjectPath}\admin_app_project_description.md"; DestDir: "{app}\docs"; Flags: ignoreversion skipifsourcedoesntexist
Source: "{#ProjectPath}\customer_management_guide.md"; DestDir: "{app}\docs"; Flags: ignoreversion skipifsourcedoesntexist
Source: "{#ProjectPath}\outlet_management_guide.md"; DestDir: "{app}\docs"; Flags: ignoreversion skipifsourcedoesntexist
Source: "{#ProjectPath}\product_management.md"; DestDir: "{app}\docs"; Flags: ignoreversion skipifsourcedoesntexist
Source: "{#ProjectPath}\sales_management_phase.md"; DestDir: "{app}\docs"; Flags: ignoreversion skipifsourcedoesntexist
Source: "{#ProjectPath}\sales_rep_management_guide.md"; DestDir: "{app}\docs"; Flags: ignoreversion skipifsourcedoesntexist
Source: "{#ProjectPath}\stock_management_guide.md"; DestDir: "{app}\docs"; Flags: ignoreversion skipifsourcedoesntexist

; Visual C++ Redistributable (uncomment and provide file when available)
; Source: "vc_redist.x64.exe"; DestDir: "{tmp}"; Flags: deleteafterinstall

[Icons]
; Main application shortcuts
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: startmenuicon
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon
Name: "{userappdata}\Microsoft\Internet Explorer\Quick Launch\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: quicklaunchicon

; Utility shortcuts
Name: "{autoprograms}\{#MyAppName}\Tools\Check Dependencies"; Filename: "{app}\tools\check_dependencies.bat"; WorkingDir: "{app}\tools"
Name: "{autoprograms}\{#MyAppName}\Tools\Debug Mode"; Filename: "{app}\tools\run_debug.bat"; WorkingDir: "{app}\tools"
Name: "{autoprograms}\{#MyAppName}\Documentation\Troubleshooting Guide"; Filename: "{app}\docs\TROUBLESHOOTING_INVISIBLE_WINDOW.md"
Name: "{autoprograms}\{#MyAppName}\Documentation\User Guide"; Filename: "{app}\docs\README.md"
Name: "{autoprograms}\{#MyAppName}\Documentation\Project Description"; Filename: "{app}\docs\admin_app_project_description.md"

; Uninstall shortcut
Name: "{autoprograms}\{#MyAppName}\Uninstall {#MyAppName}"; Filename: "{uninstallexe}"

[Registry]
; Auto-start registry entry (only if task is selected)
Root: HKCU; Subkey: "Software\Microsoft\Windows\CurrentVersion\Run"; ValueType: string; ValueName: "{#MyAppName}"; ValueData: """{app}\{#MyAppExeName}"""; Tasks: autostart

; Application registration
Root: HKLM; Subkey: "Software\{#MyAppPublisher}\{#MyAppName}"; ValueType: string; ValueName: "InstallPath"; ValueData: "{app}"
Root: HKLM; Subkey: "Software\{#MyAppPublisher}\{#MyAppName}"; ValueType: string; ValueName: "Version"; ValueData: "{#MyAppVersion}"
Root: HKLM; Subkey: "Software\{#MyAppPublisher}\{#MyAppName}"; ValueType: string; ValueName: "Publisher"; ValueData: "{#MyAppPublisher}"

[Run]
; Install Visual C++ Redistributable (uncomment when you have the file)
; Filename: "{tmp}\vc_redist.x64.exe"; Parameters: "/quiet /norestart"; StatusMsg: "Installing Visual C++ Redistributable..."; Flags: waituntilterminated

; Launch application after installation
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent

[UninstallDelete]
; Clean up any generated files
Type: filesandordirs; Name: "{app}\logs"
Type: filesandordirs; Name: "{app}\cache"
Type: filesandordirs; Name: "{app}\temp"

[Code]
// Global variables
var
  ProgressPage: TOutputProgressWizardPage;
  ErrorLogPage: TOutputMsgMemoWizardPage;
  HasErrors: Boolean;

// Check for Visual C++ Redistributable
function VCRedistNeedsInstall: Boolean;
var
  Version: String;
begin
  // Check for Visual C++ 2015-2022 Redistributable (x64)
  Result := not RegQueryStringValue(HKLM, 'SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x64', 'Version', Version) and
            not RegQueryStringValue(HKLM, 'SOFTWARE\WOW6432Node\Microsoft\VisualStudio\14.0\VC\Runtimes\x64', 'Version', Version);
end;

// Check for .NET Framework
function DotNetFrameworkInstalled: Boolean;
var
  Version: String;
begin
  Result := RegQueryStringValue(HKLM, 'SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full', 'Version', Version);
end;

// Check system requirements
function CheckSystemRequirements: Boolean;
var
  Version: TWindowsVersion;
  ErrorMsg: String;
begin
  Result := True;
  ErrorMsg := '';
  
  GetWindowsVersionEx(Version);
  
  // Check Windows version (minimum Windows 7 SP1)
  if (Version.Major < 6) or ((Version.Major = 6) and (Version.Minor < 1)) then
  begin
    ErrorMsg := ErrorMsg + '- Windows 7 SP1 or later is required' + #13#10;
    Result := False;
  end;
  
  // Check for 64-bit architecture
  if not Is64BitInstallMode then
  begin
    ErrorMsg := ErrorMsg + '- 64-bit Windows is required' + #13#10;
    Result := False;
  end;
  
  // Check available disk space (minimum 500 MB)
  // Note: Disk space check removed due to complexity in pre-installation phase
  // Space will be checked during actual installation
  
  if not Result then
  begin
    MsgBox('System Requirements Check Failed:' + #13#10 + #13#10 + ErrorMsg + #13#10 + 
           'Please ensure your system meets the minimum requirements before installing.', 
           mbError, MB_OK);
  end;
end;

// Initialize setup with system checks
function InitializeSetup(): Boolean;
var
  WarningMsg: String;
  Response: Integer;
begin
  Result := True;
  HasErrors := False;
  
  // Check system requirements first
  if not CheckSystemRequirements then
  begin
    Result := False;
    Exit;
  end;
  
  // Check for dependencies and build warning message
  WarningMsg := '';
  
  if VCRedistNeedsInstall then
    WarningMsg := WarningMsg + '- Visual C++ 2015-2022 Redistributable (x64)' + #13#10;
    
  if not DotNetFrameworkInstalled then
    WarningMsg := WarningMsg + '- .NET Framework 4.7.2 or later' + #13#10;
  
  // Show warning if dependencies are missing
  if WarningMsg <> '' then
  begin
    Response := MsgBox('Missing Dependencies Detected:' + #13#10 + #13#10 + WarningMsg + #13#10 + 
                      'The application may not work properly without these components.' + #13#10 + #13#10 + 
                      'Would you like to continue with the installation?' + #13#10 + 
                      '(You can install missing components later using the tools provided)', 
                      mbConfirmation, MB_YESNO or MB_DEFBUTTON2);
    
    if Response = IDNO then
      Result := False;
  end;
end;

// Create custom pages
procedure InitializeWizard();
begin
  // Create progress page for post-install tasks
  ProgressPage := CreateOutputProgressPage('Finalizing Installation', 'Please wait while setup completes the installation...');
  
  // Create error log page
  ErrorLogPage := CreateOutputMsgMemoPage(wpFinished, 'Installation Notes', 'Important information about your installation', 
    'Please review the following information:', '');
end;

// Handle installation steps
procedure CurStepChanged(CurStep: TSetupStep);
var
  LogText: String;
  ResultCode: Integer;
begin
  case CurStep of
    ssPostInstall:
    begin
      ProgressPage.Show;
      try
        ProgressPage.SetText('Checking installation...', '');
        ProgressPage.SetProgress(0, 100);
        
        // Verify main executable
        if not FileExists(ExpandConstant('{app}\{#MyAppExeName}')) then
        begin
          LogText := LogText + 'ERROR: Main application file not found!' + #13#10;
          HasErrors := True;
        end
        else
          LogText := LogText + 'Main application installed successfully.' + #13#10;
        
        ProgressPage.SetProgress(25, 100);
        
        // Check Flutter runtime
        if not FileExists(ExpandConstant('{app}\flutter_windows.dll')) then
        begin
          LogText := LogText + 'ERROR: Flutter runtime not found!' + #13#10;
          HasErrors := True;
        end
        else
          LogText := LogText + 'Flutter runtime installed successfully.' + #13#10;
        
        ProgressPage.SetProgress(50, 100);
        
        // Check data directory
        if not DirExists(ExpandConstant('{app}\data')) then
        begin
          LogText := LogText + 'WARNING: Application data directory not found.' + #13#10;
        end
        else
          LogText := LogText + 'Application data installed successfully.' + #13#10;
        
        ProgressPage.SetProgress(75, 100);
        
        // Final dependency check
        if VCRedistNeedsInstall then
        begin
          LogText := LogText + #13#10 + 'IMPORTANT: Visual C++ Redistributable is missing.' + #13#10 + 
                    'Download from: https://aka.ms/vs/17/release/vc_redist.x64.exe' + #13#10 + 
                    'Or use the "Check Dependencies" tool from the Start Menu.' + #13#10;
        end;
        
        if not DotNetFrameworkInstalled then
        begin
          LogText := LogText + #13#10 + 'IMPORTANT: .NET Framework 4.7.2+ is missing.' + #13#10 + 
                    'Download from Microsofts official website.' + #13#10;
        end;
        
        ProgressPage.SetProgress(100, 100);
        Sleep(1000);
        
      finally
        ProgressPage.Hide;
      end;
      
      // Set up error log page content
      if (LogText <> '') then
      begin
        ErrorLogPage.RichEditViewer.Text := LogText;
        if HasErrors then
          ErrorLogPage.Caption := 'Installation Issues Detected'
        else
          ErrorLogPage.Caption := 'Installation Complete';
      end;
    end;
  end;
end;

// Show error log page if there are issues
function ShouldSkipPage(PageID: Integer): Boolean;
begin
  Result := False;
  
  // Show error log page only if there are messages to display
  if (PageID = ErrorLogPage.ID) then
    Result := (ErrorLogPage.RichEditViewer.Text = '');
end;

// Custom uninstall confirmation
function InitializeUninstall(): Boolean;
var
  Response: Integer;
begin
  Response := MsgBox('Are you sure you want to completely remove {#MyAppName} and all of its components?' + #13#10 + #13#10 + 
                    'This will remove:' + #13#10 + 
                    '- Application files' + #13#10 + 
                    '- Documentation' + #13#10 + 
                    '- Start menu shortcuts' + #13#10 + 
                    '- Registry entries' + #13#10 + #13#10 + 
                    'User data and configuration files will be preserved.', 
                    mbConfirmation, MB_YESNO or MB_DEFBUTTON2);
  
  Result := (Response = IDYES);
end;

// Post-uninstall cleanup
procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
begin
  case CurUninstallStep of
    usPostUninstall:
    begin
      // Clean up registry entries
      RegDeleteKeyIncludingSubkeys(HKLM, 'Software\{#MyAppPublisher}\{#MyAppName}');
      
      // Remove auto-start entry if it exists
      RegDeleteValue(HKCU, 'Software\Microsoft\Windows\CurrentVersion\Run', '{#MyAppName}');
      
      MsgBox('{#MyAppName} has been successfully removed from your computer.' + #13#10 + #13#10 + 
             'Thank you for using {#MyAppName}!', mbInformation, MB_OK);
    end;
  end;
end;