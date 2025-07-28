@echo off
echo Starting Hadraniel Admin with debug output...
cd /d "C:\Users\HP\Desktop\hadraniel_Admin\build\windows\x64\runner\Release"
echo Current directory: %CD%
echo.
echo Checking if executable exists:
if exist "hadraniel_admin.exe" (
    echo hadraniel_admin.exe found
) else (
    echo hadraniel_admin.exe NOT found
    pause
    exit /b 1
)
echo.
echo Checking data directory:
if exist "data" (
    echo data directory found
) else (
    echo data directory NOT found
)
echo.
echo Starting application...
"hadraniel_admin.exe"
echo.
echo Application exited with code: %ERRORLEVEL%
echo.
pause