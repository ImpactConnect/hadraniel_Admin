@echo off
echo ========================================
echo Building Hadraniel Admin v1.9 Installer
echo ========================================
echo.

set "INNO_PATH=C:\Program Files (x86)\Inno Setup 6\ISCC.exe"
set "FLUTTER_EXE=build\windows\x64\runner\Release\hadraniel_admin.exe"
set "SCRIPT_PATH=Installer\v1.9_script.iss"
set "OUTPUT_DIR=Installer\Output"

:: Check if Inno Setup is installed
if not exist "%INNO_PATH%" (
    echo ERROR: Inno Setup 6 not found!
    echo Please install Inno Setup 6 from: https://jrsoftware.org/isinfo.php
    echo Expected location: %INNO_PATH%
    pause
    exit /b 1
)

:: Check if Flutter build exists
if not exist "%FLUTTER_EXE%" (
    echo WARNING: Flutter Windows build not found!
    echo Building Flutter app for Windows...
    echo.
    flutter build windows --release
    if errorlevel 1 (
        echo ERROR: Flutter build failed!
        pause
        exit /b 1
    )
)

:: Create output directory if it doesn't exist
if not exist "%OUTPUT_DIR%" (
    mkdir "%OUTPUT_DIR%"
)

:: Compile the Inno Setup script
echo Compiling Inno Setup script...
echo.
"%INNO_PATH%" "%SCRIPT_PATH%"

if errorlevel 1 (
    echo.
    echo ERROR: Inno Setup compilation failed!
    echo Check the script for errors and try again.
    pause
    exit /b 1
)

echo.
echo ========================================
echo SUCCESS: Installer created successfully!
echo ========================================
echo.
echo Output file: %OUTPUT_DIR%\HadranielAdminSetup_v1.9.exe
echo.
echo You can now distribute this installer to users.
echo.

:: Ask if user wants to open the output folder
set /p open_folder="Open output folder? (y/n): "
if /i "%open_folder%"=="y" (
    explorer "%OUTPUT_DIR%"
)

:: Ask if user wants to test the installer
set /p test_installer="Test the installer now? (y/n): "
if /i "%test_installer%"=="y" (
    start "" "%OUTPUT_DIR%\HadranielAdminSetup_v1.9.exe"
)

echo.
echo Build process completed!
pause