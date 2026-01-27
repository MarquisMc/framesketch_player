# PowerShell script to unregister FrameSketch Player file associations
# Run this script as Administrator

Write-Host "Unregistering FrameSketch Player file associations..." -ForegroundColor Yellow

# Define the ProgID
$progId = "FrameSketchPlayer.VideoFile"

# Video file extensions
$videoExtensions = @('.mp4', '.mov', '.mkv', '.avi', '.webm', '.flv', '.m4v')

# Remove the ProgID
$progIdPath = "Registry::HKEY_CURRENT_USER\Software\Classes\$progId"
if (Test-Path $progIdPath) {
    Remove-Item -Path $progIdPath -Recurse -Force
    Write-Host "Removed ProgID: $progId" -ForegroundColor Green
}

# Remove from each file extension
foreach ($ext in $videoExtensions) {
    Write-Host "Cleaning up $ext..." -ForegroundColor Cyan

    # Remove from OpenWithProgids
    $openWithPath = "Registry::HKEY_CURRENT_USER\Software\Classes\$ext\OpenWithProgids"
    if (Test-Path $openWithPath) {
        Remove-ItemProperty -Path $openWithPath -Name $progId -ErrorAction SilentlyContinue
    }

    # Remove from OpenWithList
    $openWithListPath = "Registry::HKEY_CURRENT_USER\Software\Classes\$ext\OpenWithList\framesketch_player.exe"
    if (Test-Path $openWithListPath) {
        Remove-Item -Path $openWithListPath -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# Remove from Applications registry
$appsPath = "Registry::HKEY_CURRENT_USER\Software\Classes\Applications\framesketch_player.exe"
if (Test-Path $appsPath) {
    Remove-Item -Path $appsPath -Recurse -Force
    Write-Host "Removed application registration" -ForegroundColor Green
}

Write-Host "`nUnregistration complete!" -ForegroundColor Green
