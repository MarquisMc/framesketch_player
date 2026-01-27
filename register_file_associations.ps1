# PowerShell script to register FrameSketch Player as default video player
# Run this script as Administrator
#
# NOTE: This script is optional! FrameSketch Player now has built-in file association
# registration. Just open the app and click the menu icon (⋮) → "Set as Default Video Player"

# Get the path to the executable
$exePath = Join-Path $PSScriptRoot "build\windows\x64\runner\Release\framesketch_player.exe"

# Check if the executable exists
if (-not (Test-Path $exePath)) {
    Write-Host "ERROR: Executable not found at: $exePath" -ForegroundColor Red
    Write-Host "Please build the release version first using: flutter build windows --release" -ForegroundColor Yellow
    exit 1
}

Write-Host "Registering FrameSketch Player for video file associations..." -ForegroundColor Green

# Define the ProgID
$progId = "FrameSketchPlayer.VideoFile"
$appName = "FrameSketch Player"

# Video file extensions to register
$videoExtensions = @('.mp4', '.mov', '.mkv', '.avi', '.webm', '.flv', '.m4v')

# Create the ProgID key
$progIdPath = "Registry::HKEY_CURRENT_USER\Software\Classes\$progId"
New-Item -Path $progIdPath -Force | Out-Null
Set-ItemProperty -Path $progIdPath -Name "(Default)" -Value "$appName Video File"

# Set the icon
$iconPath = "$progIdPath\DefaultIcon"
New-Item -Path $iconPath -Force | Out-Null
Set-ItemProperty -Path $iconPath -Name "(Default)" -Value "`"$exePath`",0"

# Set the open command
$shellPath = "$progIdPath\shell\open\command"
New-Item -Path $shellPath -Force | Out-Null
Set-ItemProperty -Path $shellPath -Name "(Default)" -Value "`"$exePath`" `"%1`""

# Register each file extension
foreach ($ext in $videoExtensions) {
    Write-Host "Registering $ext..." -ForegroundColor Cyan

    # Create extension key
    $extPath = "Registry::HKEY_CURRENT_USER\Software\Classes\$ext"
    New-Item -Path $extPath -Force | Out-Null

    # Create OpenWithProgids key
    $openWithPath = "$extPath\OpenWithProgids"
    New-Item -Path $openWithPath -Force | Out-Null
    Set-ItemProperty -Path $openWithPath -Name $progId -Value ([byte[]]@()) -Type Binary

    # Add to the list of applications that can open this file type
    $openWithListPath = "$extPath\OpenWithList\framesketch_player.exe"
    New-Item -Path $openWithListPath -Force | Out-Null
}

# Add to the Applications registry
$appsPath = "Registry::HKEY_CURRENT_USER\Software\Classes\Applications\framesketch_player.exe"
New-Item -Path $appsPath -Force | Out-Null
Set-ItemProperty -Path $appsPath -Name "FriendlyAppName" -Value $appName

# Create supported types
$supportedTypesPath = "$appsPath\SupportedTypes"
New-Item -Path $supportedTypesPath -Force | Out-Null
foreach ($ext in $videoExtensions) {
    Set-ItemProperty -Path $supportedTypesPath -Name $ext -Value ""
}

# Set shell command
$appShellPath = "$appsPath\shell\open\command"
New-Item -Path $appShellPath -Force | Out-Null
Set-ItemProperty -Path $appShellPath -Name "(Default)" -Value "`"$exePath`" `"%1`""

Write-Host "`nRegistration complete!" -ForegroundColor Green
Write-Host "`nYou can now:" -ForegroundColor Yellow
Write-Host "1. Right-click any video file" -ForegroundColor White
Write-Host "2. Select 'Open with' -> 'Choose another app'" -ForegroundColor White
Write-Host "3. Select 'FrameSketch Player' from the list" -ForegroundColor White
Write-Host "4. Check 'Always use this app' to set as default" -ForegroundColor White
Write-Host "`nAlternatively, go to Settings -> Apps -> Default apps to set FrameSketch Player as your default video player." -ForegroundColor White
