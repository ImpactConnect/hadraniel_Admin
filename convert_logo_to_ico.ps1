# PowerShell script to convert PNG to ICO format
Add-Type -AssemblyName System.Drawing

 = 'assets\images\logo.png'
 = 'windows\runner\resources\app_icon.ico'

if (-not (Test-Path )) {
    Write-Error 'Source file not found: '
    exit 1
}

try {
     = [System.Drawing.Image]::FromFile((Resolve-Path ).Path)
     = 256
     = New-Object System.Drawing.Bitmap(, )
     = [System.Drawing.Graphics]::FromImage()
    
    .InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    .SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    .PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    
    .DrawImage(, 0, 0, , )
    
     = Split-Path  -Parent
    if (-not (Test-Path )) {
        New-Item -ItemType Directory -Path  -Force
    }
    
    .Save((Resolve-Path ).Path + '\app_icon.ico', [System.Drawing.Imaging.ImageFormat]::Icon)
    
    Write-Host 'Successfully converted logo to app icon'
    
    .Dispose()
    .Dispose()
    .Dispose()
    
} catch {
    Write-Error 'Error converting image: '
    exit 1
}

Write-Host 'Icon conversion completed successfully!'
