# Troubleshooting: App Runs But Window Not Visible

If your Hadraniel Admin application appears in Task Manager but the window is not visible, follow these troubleshooting steps:

## Common Causes and Solutions

### 1. **Missing Visual C++ Redistributable**
**Symptoms:** App process starts but no window appears
**Solution:**
- Download and install [Microsoft Visual C++ 2015-2022 Redistributable (x64)](https://aka.ms/vs/17/release/vc_redist.x64.exe)
- Restart the application after installation

### 2. **Window Positioning Issues**
**Symptoms:** Window opens off-screen or minimized
**Solutions:**
- Press `Alt + Tab` to cycle through open windows
- Right-click the taskbar icon and select "Restore" or "Maximize"
- Check if the window is positioned outside visible screen area

### 3. **Missing Flutter Dependencies**
**Symptoms:** App crashes silently or fails to initialize
**Solution:**
- Run the dependency checker: `check_dependencies.bat`
- Ensure all required DLLs are present in the installation directory
- Rebuild the application: `flutter clean && flutter build windows --release`

### 4. **Data Directory Missing**
**Symptoms:** App starts but Flutter engine fails to initialize
**Solution:**
- Verify the `data` folder exists in the installation directory
- Ensure the installer script includes: `Source: "...\Release\data\*"; DestDir: "{app}\data"`

### 5. **Antivirus/Security Software**
**Symptoms:** App blocked from displaying windows
**Solution:**
- Add the application to antivirus whitelist
- Temporarily disable real-time protection to test
- Check Windows Defender exclusions

## Diagnostic Steps

### Step 1: Check Dependencies
```batch
# Run the dependency checker
check_dependencies.bat
```

### Step 2: Check Windows Event Viewer
1. Open Event Viewer (`eventvwr.msc`)
2. Navigate to Windows Logs > Application
3. Look for errors related to your application
4. Check for .NET Framework or Visual C++ runtime errors

### Step 3: Test with Debug Build
```batch
# Build and test debug version
flutter build windows --debug
cd build\windows\x64\runner\Debug
hadraniel_admin.exe
```

### Step 4: Check Process Details
1. Open Task Manager
2. Go to Details tab
3. Find `hadraniel_admin.exe`
4. Check CPU and Memory usage
   - High CPU: App might be stuck in a loop
   - Low CPU: App might be waiting for something

## Code Fixes Applied

The following fix has been applied to ensure the window shows immediately:

```cpp
// In flutter_window.cpp - Show window immediately
this->Show();

flutter_controller_->engine()->SetNextFrameCallback([&]() {
    // Ensure window is visible after first frame
    this->Show();
});
```

## Installer Improvements

To prevent this issue in future builds:

1. **Include VC++ Redistributable in installer:**
```iss
[Files]
; Include VC++ Redistributable
Source: "vc_redist.x64.exe"; DestDir: "{tmp}"; Flags: deleteafterinstall

[Run]
; Install VC++ Redistributable silently
Filename: "{tmp}\vc_redist.x64.exe"; Parameters: "/quiet"; StatusMsg: "Installing Visual C++ Redistributable..."
```

2. **Add dependency checks in installer:**
```iss
[Code]
function InitializeSetup(): Boolean;
begin
  // Check for required dependencies
  Result := True;
end;
```

## Contact Support

If the issue persists after trying all solutions:
1. Run `check_dependencies.bat` and note any missing components
2. Check Windows Event Viewer for specific error messages
3. Provide system information (Windows version, architecture)
4. Include any error logs or crash dumps

## Prevention for Future Builds

1. Always test the installer on a clean Windows machine
2. Include all required redistributables in the installer
3. Test on different Windows versions (10, 11)
4. Verify the application works without Flutter SDK installed
5. Use dependency walker tools to identify missing DLLs