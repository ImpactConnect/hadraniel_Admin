#define MyAppName "Hadraniel Admin"
#define MyAppVersion "1.9"
#define MyAppPublisher "Hadraniel Solutions"
#define MyAppURL "https://hadraniel.com"
#define MyAppExeName "hadraniel_admin.exe"

[Setup]
AppId={{B8E8F8A0-1234-5678-9ABC-DEF012345678}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
AllowNoIcons=yes
LicenseFile=
OutputDir=C:\Users\HP\Desktop\hadraniel_Admin\Installer\Output
OutputBaseFilename=HadranielAdminSetup_v{#MyAppVersion}
SetupIconFile=C:\Users\HP\Desktop\hadraniel_Admin\windows\runner\resources\app_icon.ico
Compression=lzma
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=admin
ArchitecturesAllowed=x64
ArchitecturesInstallIn64BitMode=x64

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked
Name: "quicklaunchicon"; Description: "{cm:CreateQuickLaunchIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked; OnlyBelowVersion: 6.1

[Files]
; Main application files
Source: "C:\Users\HP\Desktop\hadraniel_Admin\build\windows\x64\runner\Release\{#MyAppExeName}"; DestDir: "{app}"; Flags: ignoreversion
Source: "C:\Users\HP\Desktop\hadraniel_Admin\build\windows\x64\runner\Release\flutter_windows.dll"; DestDir: "{app}"; Flags: ignoreversion

; Plugin DLLs
Source: "C:\Users\HP\Desktop\hadraniel_Admin\build\windows\x64\runner\Release\app_links_plugin.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "C:\Users\HP\Desktop\hadraniel_Admin\build\windows\x64\runner\Release\flutter_secure_storage_windows_plugin.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "C:\Users\HP\Desktop\hadraniel_Admin\build\windows\x64\runner\Release\url_launcher_windows_plugin.dll"; DestDir: "{app}"; Flags: ignoreversion

; Data directory
Source: "C:\Users\HP\Desktop\hadraniel_Admin\build\windows\x64\runner\Release\data\*"; DestDir: "{app}\data"; Flags: ignoreversion recursesubdirs createallsubdirs

; Visual C++ Redistributable (download and include this file)
; Source: "vc_redist.x64.exe"; DestDir: "{tmp}"; Flags: deleteafterinstall

; Troubleshooting files
Source: "C:\Users\HP\Desktop\hadraniel_Admin\TROUBLESHOOTING_INVISIBLE_WINDOW.md"; DestDir: "{app}"; Flags: ignoreversion
Source: "C:\Users\HP\Desktop\hadraniel_Admin\check_dependencies.bat"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon
Name: "{userappdata}\Microsoft\Internet Explorer\Quick Launch\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: quicklaunchicon

; Troubleshooting shortcuts
Name: "{autoprograms}\{#MyAppName}\Check Dependencies"; Filename: "{app}\check_dependencies.bat"
Name: "{autoprograms}\{#MyAppName}\Troubleshooting Guide"; Filename: "{app}\TROUBLESHOOTING_INVISIBLE_WINDOW.md"

[Run]
; Install Visual C++ Redistributable (uncomment when you have the file)
; Filename: "{tmp}\vc_redist.x64.exe"; Parameters: "/quiet /norestart"; StatusMsg: "Installing Visual C++ Redistributable..."; Flags: waituntilterminated

; Launch application
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent

[Code]
// Check for Visual C++ Redistributable
function VCRedistNeedsInstall: Boolean;
var
  Version: String;
begin
  Result := not RegQueryStringValue(HKLM, 'SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x64', 'Version', Version);
end;

// Custom page to show troubleshooting info if needed
function InitializeSetup(): Boolean;
begin
  Result := True;
  if VCRedistNeedsInstall then
  begin
    if MsgBox('Visual C++ 2015-2022 Redistributable (x64) is required but not detected.' + #13#10 + 
              'The application may not work properly without it.' + #13#10 + #13#10 + 
              'Would you like to continue with the installation?' + #13#10 + 
              '(You can download it later from: https://aka.ms/vs/17/release/vc_redist.x64.exe)', 
              mbConfirmation, MB_YESNO) = IDNO then
      Result := False;
  end;
end;

// Show troubleshooting message after installation if VC++ is missing
procedure CurStepChanged(CurStep: TSetupStep);
begin
  if CurStep = ssPostInstall then
  begin
    if VCRedistNeedsInstall then
    begin
      MsgBox('IMPORTANT: Visual C++ 2015-2022 Redistributable (x64) was not detected.' + #13#10 + #13#10 +
             'If the application does not start or shows only in Task Manager:' + #13#10 +
             '1. Download and install: https://aka.ms/vs/17/release/vc_redist.x64.exe' + #13#10 +
             '2. Run the "Check Dependencies" shortcut from the Start Menu' + #13#10 +
             '3. See the Troubleshooting Guide for more solutions' + #13#10 + #13#10 +
             'These files are available in the installation directory.', 
             mbInformation, MB_OK);
    end;
  end;
end;