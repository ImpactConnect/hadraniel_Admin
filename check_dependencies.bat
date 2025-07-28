@echo off
echo Checking Hadraniel Admin Dependencies...
echo.

echo Checking if application executable exists...
if exist "build\windows\x64\runner\Release\hadraniel_admin.exe" (
    echo ✓ Application executable found
) else (
    echo ✗ Application executable NOT found
    echo Please run: flutter build windows --release
    pause
    exit /b 1
)

echo.
echo Checking required DLLs...
set "BUILD_DIR=build\windows\x64\runner\Release"

if exist "%BUILD_DIR%\flutter_windows.dll" (
    echo ✓ flutter_windows.dll found
) else (
    echo ✗ flutter_windows.dll NOT found
)

if exist "%BUILD_DIR%\app_links_plugin.dll" (
    echo ✓ app_links_plugin.dll found
) else (
    echo ✗ app_links_plugin.dll NOT found
)

if exist "%BUILD_DIR%\flutter_secure_storage_windows_plugin.dll" (
    echo ✓ flutter_secure_storage_windows_plugin.dll found
) else (
    echo ✗ flutter_secure_storage_windows_plugin.dll NOT found
)

if exist "%BUILD_DIR%\url_launcher_windows_plugin.dll" (
    echo ✓ url_launcher_windows_plugin.dll found
) else (
    echo ✗ url_launcher_windows_plugin.dll NOT found
)

if exist "%BUILD_DIR%\data" (
    echo ✓ data directory found
) else (
    echo ✗ data directory NOT found
)

echo.
echo Checking Visual C++ Redistributable...
reg query "HKLM\SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x64" >nul 2>&1
if errorlevel 1 (
    echo ✗ Visual C++ 2015-2022 Redistributable (x64) may be missing
    echo Download from: https://aka.ms/vs/17/release/vc_redist.x64.exe
) else (
    echo ✓ Visual C++ 2015-2022 Redistributable (x64) is installed
)

echo.
echo Testing application launch...
echo Starting application in test mode...
start "" "%BUILD_DIR%\hadraniel_admin.exe"
echo.
echo If the application window doesn't appear within 10 seconds,
echo there may be a runtime dependency issue.
echo Check Windows Event Viewer for error details.
echo.
pause