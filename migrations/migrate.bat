@echo off
REM Database Migration Script: v17 to v18
REM Windows Batch version

echo ========================================
echo Database Migration: v17 -^> v18
echo ========================================
echo.

set DB_PATH=%LOCALAPPDATA%\Hadraniel_Admin\admin_app.db
set MIGRATION_FILE=migrations\migrate_v17_to_v18.sql

REM Check if database exists
if not exist "%DB_PATH%" (
    echo ERROR: Database not found!
    echo Expected location: %DB_PATH%
    echo Please run the app at least once.
    pause
    exit /b 1
)

REM Check if migration file exists
if not exist "%MIGRATION_FILE%" (
    echo ERROR: Migration file not found!
    echo Expected: %MIGRATION_FILE%
    echo Please run this from the app root directory.
    pause
    exit /b 1
)

REM Check for sqlite3
set SQLITE3=
where sqlite3 >nul 2>&1
if %ERRORLEVEL% equ 0 (
    set SQLITE3=sqlite3
) else if exist "tools\sqlite3.exe" (
    set SQLITE3=tools\sqlite3.exe
) else (
    echo ERROR: sqlite3.exe not found!
    echo.
    echo Please download from: https://www.sqlite.org/download.html
    echo Place it in the tools\ folder
    pause
    exit /b 1
)

echo Found database: %DB_PATH%
echo Found migration: %MIGRATION_FILE%
echo Using SQLite: %SQLITE3%
echo.

REM Create backup  
echo Creating backup...
set BACKUP_PATH=%DB_PATH%.backup_%DATE:~-4%%DATE:~-7,2%%DATE:~-10,2%_%TIME:~0,2%%TIME:~3,2%%TIME:~6,2%
set BACKUP_PATH=%BACKUP_PATH: =0%
copy "%DB_PATH%" "%BACKUP_PATH%" >nul
if %ERRORLEVEL% neq 0 (
    echo ERROR: Failed to create backup!
    pause
    exit /b 1
)
echo Backup created: %BACKUP_PATH%
echo.

REM Run migration
echo Running migration...
%SQLITE3% "%DB_PATH%" ".read %MIGRATION_FILE%"
if %ERRORLEVEL% neq 0 (
    echo.
    echo ERROR: Migration failed!
    echo Restoring backup...
    copy "%BACKUP_PATH%" "%DB_PATH%" >nul
    echo Database restored.
    pause
    exit /b 1
)

echo.
echo ========================================
echo Migration completed successfully!
echo ========================================
echo.
echo Backup kept at: %BACKUP_PATH%
echo You can delete it after testing the app.
echo.
pause
