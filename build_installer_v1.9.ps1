# Hadraniel Admin v1.9 Installer Build Script
# PowerShell version with enhanced error handling and logging

param(
    [switch]$SkipFlutterBuild,
    [switch]$OpenOutput,
    [switch]$TestInstaller,
    [switch]$Verbose
)

# Set error action preference
$ErrorActionPreference = "Stop"

# Function to write colored output
function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$Color = "White"
    )
    Write-Host $Message -ForegroundColor $Color
}

# Function to check if a command exists
function Test-Command {
    param([string]$Command)
    try {
        Get-Command $Command -ErrorAction Stop | Out-Null
        return $true
    }
    catch {
        return $false
    }
}

try {
    Write-ColorOutput "========================================" "Cyan"
    Write-ColorOutput "Building Hadraniel Admin v1.9 Installer" "Cyan"
    Write-ColorOutput "========================================" "Cyan"
    Write-Host ""

    # Check if Inno Setup is installed
    $InnoSetupPath = "C:\Program Files (x86)\Inno Setup 6\ISCC.exe"
    if (-not (Test-Path $InnoSetupPath)) {
        Write-ColorOutput "ERROR: Inno Setup 6 not found!" "Red"
        Write-ColorOutput "Please install Inno Setup 6 from: https://jrsoftware.org/isinfo.php" "Yellow"
        Write-ColorOutput "Expected location: $InnoSetupPath" "Yellow"
        exit 1
    }
    Write-ColorOutput "✓ Inno Setup 6 found" "Green"

    # Check if Flutter is available
    if (-not (Test-Command "flutter")) {
        Write-ColorOutput "ERROR: Flutter not found in PATH!" "Red"
        Write-ColorOutput "Please ensure Flutter is installed and added to PATH" "Yellow"
        exit 1
    }
    Write-ColorOutput "✓ Flutter found" "Green"

    # Check if Flutter build exists or build if needed
    $FlutterExePath = "build\windows\x64\runner\Release\hadraniel_admin.exe"
    if (-not (Test-Path $FlutterExePath) -and -not $SkipFlutterBuild) {
        Write-ColorOutput "WARNING: Flutter Windows build not found!" "Yellow"
        Write-ColorOutput "Building Flutter app for Windows..." "Yellow"
        Write-Host ""
        
        $buildArgs = @("build", "windows", "--release")
        if ($Verbose) {
            $buildArgs += "--verbose"
        }
        
        & flutter $buildArgs
        if ($LASTEXITCODE -ne 0) {
            Write-ColorOutput "ERROR: Flutter build failed!" "Red"
            exit 1
        }
        Write-ColorOutput "✓ Flutter build completed" "Green"
    }
    elseif (Test-Path $FlutterExePath) {
        Write-ColorOutput "✓ Flutter build found" "Green"
    }
    else {
        Write-ColorOutput "WARNING: Skipping Flutter build as requested" "Yellow"
    }

    # Create output directory if it doesn't exist
    $OutputDir = "Installer\Output"
    if (-not (Test-Path $OutputDir)) {
        New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
        Write-ColorOutput "✓ Created output directory" "Green"
    }

    # Check if the Inno Setup script exists
    $ScriptPath = "Installer\v1.9_script.iss"
    if (-not (Test-Path $ScriptPath)) {
        Write-ColorOutput "ERROR: Inno Setup script not found: $ScriptPath" "Red"
        exit 1
    }
    Write-ColorOutput "✓ Inno Setup script found" "Green"

    # Compile the Inno Setup script
    Write-Host ""
    Write-ColorOutput "Compiling Inno Setup script..." "Cyan"
    Write-Host ""
    
    $compileArgs = @($ScriptPath)
    if ($Verbose) {
        $compileArgs += "/V9"  # Maximum verbosity
    }
    
    & $InnoSetupPath $compileArgs
    
    if ($LASTEXITCODE -ne 0) {
        Write-ColorOutput "ERROR: Inno Setup compilation failed!" "Red"
        Write-ColorOutput "Check the script for errors and try again." "Yellow"
        exit 1
    }

    Write-Host ""
    Write-ColorOutput "========================================" "Green"
    Write-ColorOutput "SUCCESS: Installer created successfully!" "Green"
    Write-ColorOutput "========================================" "Green"
    Write-Host ""
    
    $InstallerPath = "Installer\Output\HadranielAdminSetup_v1.9.exe"
    Write-ColorOutput "Output file: $InstallerPath" "White"
    
    if (Test-Path $InstallerPath) {
        $FileInfo = Get-Item $InstallerPath
        Write-ColorOutput "File size: $([math]::Round($FileInfo.Length / 1MB, 2)) MB" "White"
        Write-ColorOutput "Created: $($FileInfo.CreationTime)" "White"
    }
    
    Write-Host ""
    Write-ColorOutput "You can now distribute this installer to users." "White"
    Write-Host ""

    # Open output folder if requested or ask user
    if ($OpenOutput -or (-not $OpenOutput -and -not $TestInstaller)) {
        $openChoice = Read-Host "Open output folder? (y/n)"
        if ($openChoice -eq "y" -or $openChoice -eq "Y" -or $OpenOutput) {
            Start-Process "explorer.exe" -ArgumentList (Resolve-Path $OutputDir)
        }
    }

    # Test installer if requested or ask user
    if ($TestInstaller -or (-not $TestInstaller -and -not $OpenOutput)) {
        $testChoice = Read-Host "Test the installer now? (y/n)"
        if ($testChoice -eq "y" -or $testChoice -eq "Y" -or $TestInstaller) {
            Start-Process $InstallerPath
        }
    }

    Write-Host ""
    Write-ColorOutput "Build process completed successfully!" "Green"
}
catch {
    Write-ColorOutput "ERROR: $($_.Exception.Message)" "Red"
    if ($Verbose) {
        Write-ColorOutput "Stack trace: $($_.ScriptStackTrace)" "Red"
    }
    exit 1
}
finally {
    if (-not $OpenOutput -and -not $TestInstaller) {
        Read-Host "Press Enter to continue..."
    }
}