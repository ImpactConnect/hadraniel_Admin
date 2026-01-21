# Database Migration Script: v17 to v18
# Adds product status tracking columns
# Safe to run on any system with the app installed

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Database Migration: v17 -> v18" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Configuration
$dbPath = "$env:LOCALAPPDATA\Hadraniel_Admin\admin_app.db"
$migrationFile = ".\migrations\migrate_v17_to_v18.sql"
$backupPath = "$env:LOCALAPPDATA\Hadraniel_Admin\admin_app.db.backup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"

# Check if database exists
if (-not (Test-Path $dbPath)) {
    Write-Host "ERROR: Database not found at: $dbPath" -ForegroundColor Red
    Write-Host "Please ensure the app has been run at least once." -ForegroundColor Yellow
    exit 1
}

# Check if migration file exists
if (-not (Test-Path $migrationFile)) {
    Write-Host "ERROR: Migration file not found: $migrationFile" -ForegroundColor Red
    Write-Host "Please run this script from the app root directory." -ForegroundColor Yellow
    exit 1
}

# Check if sqlite3 is available
$sqlite3 = $null
if (Get-Command sqlite3 -ErrorAction SilentlyContinue) {
    $sqlite3 = "sqlite3"
} elseif (Test-Path ".\tools\sqlite3.exe") {
    $sqlite3 = ".\tools\sqlite3.exe"
} else {
    Write-Host "ERROR: sqlite3 not found!" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please download sqlite3.exe from https://www.sqlite.org/download.html" -ForegroundColor Yellow
    Write-Host "and place it in .\tools\ folder" -ForegroundColor Yellow
    exit 1
}

Write-Host "✓ Database found" -ForegroundColor Green
Write-Host "✓ Migration file found" -ForegroundColor Green
Write-Host "✓ SQLite3 available" -ForegroundColor Green
Write-Host ""

# Create backup
Write-Host "Creating backup..." -ForegroundColor Yellow
try {
    Copy-Item $dbPath $backupPath -Force
    Write-Host "✓ Backup created: $backupPath" -ForegroundColor Green
} catch {
    Write-Host "ERROR: Failed to create backup: $_" -ForegroundColor Red
    exit 1
}

Write-Host ""

# Check current version
Write-Host "Checking current database version..." -ForegroundColor Yellow
$currentVersion = & $sqlite3 $dbPath "PRAGMA user_version;"
Write-Host "Current version: $currentVersion" -ForegroundColor Cyan

if ($currentVersion -ge 18) {
    Write-Host ""
    Write-Host "Database is already at v18 or higher. No migration needed." -ForegroundColor Green
    Write-Host "Removing backup..." -ForegroundColor Yellow
    Remove-Item $backupPath -Force
    exit 0
}

Write-Host ""
Write-Host "Running migration..." -ForegroundColor Yellow
Write-Host ""

# Run migration
try {
    $output = & $sqlite3 $dbPath ".read $migrationFile" 2>&1
    
    if ($LASTEXITCODE -ne 0) {
        throw "Migration failed with exit code $LASTEXITCODE"
    }
    
    Write-Host $output
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "✓ Migration completed successfully!" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host ""
    
    # Verify new version
    $newVersion = & $sqlite3 $dbPath "PRAGMA user_version;"
    Write-Host "New database version: $newVersion" -ForegroundColor Cyan
    
    Write-Host ""
    Write-Host "Backup kept at: $backupPath" -ForegroundColor Yellow
    Write-Host "You can delete it after confirming the app works correctly." -ForegroundColor Yellow
    
} catch {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Red
    Write-Host "✗ Migration failed!" -ForegroundColor Red
    Write-Host "========================================" -ForegroundColor Red
    Write-Host ""
    Write-Host "Error: $_" -ForegroundColor Red
    Write-Host ""
    Write-Host "Restoring from backup..." -ForegroundColor Yellow
    Copy-Item $backupPath $dbPath -Force
    Write-Host "✓ Database restored" -ForegroundColor Green
    exit 1
}

Write-Host ""
Write-Host "You can now restart the app." -ForegroundColor Cyan
