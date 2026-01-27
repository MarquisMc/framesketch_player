# File Association Setup Guide

FrameSketch Player can be set as your default video player on Windows with built-in one-click registration.

## Quick Setup (Recommended)

1. **Build the application** (first time only):
   ```bash
   flutter pub get
   flutter build windows --release
   ```

2. **Run the application**:
   - Navigate to `build\windows\x64\runner\Release\`
   - Run `framesketch_player.exe`

3. **Register as default player**:
   - Click the **menu icon (⋮)** in the top-right corner
   - Select **"Set as Default Video Player"**
   - A confirmation dialog will appear

4. **Set as default for video files**:
   - Right-click any video file (.mp4, .mov, .mkv, etc.)
   - Select **"Open with"** → **"Choose another app"**
   - Select **"FrameSketch Player"** from the list
   - Check **"Always use this app"**
   - Click **OK**

## Features

### Supported Video Formats
- MP4 (.mp4)
- QuickTime (.mov)
- Matroska (.mkv)
- AVI (.avi)
- WebM (.webm)
- Flash Video (.flv)
- MPEG-4 (.m4v)

### Menu Options

**⋮ Menu Icon** provides three options:

1. **Set as Default Video Player**
   - Registers the application with Windows
   - Adds FrameSketch Player to "Open with" menus
   - One-time setup, no administrator required

2. **Remove File Associations**
   - Unregisters all file associations
   - Removes FrameSketch Player from Windows registry
   - Can be re-registered anytime

3. **Check Registration Status**
   - Shows whether the app is currently registered
   - Helpful for troubleshooting

## Opening Videos After Registration

Once registered, you can open videos in multiple ways:

1. **Double-click** any video file (if set as default)
2. **Right-click** → **"Open with"** → **"FrameSketch Player"**
3. **Drag and drop** video files onto the application window
4. **Command line**: `framesketch_player.exe "path/to/video.mp4"`
5. **File dialog**: Press `Ctrl+O` or click the folder icon

## Technical Details

### How It Works
- Writes to `HKEY_CURRENT_USER\Software\Classes` registry
- Creates ProgID: `FrameSketchPlayer.VideoFile`
- Registers supported file extensions
- Adds to Windows "Applications" list
- No administrator privileges required (uses HKEY_CURRENT_USER)

### Registry Locations
- **ProgID**: `HKEY_CURRENT_USER\Software\Classes\FrameSketchPlayer.VideoFile`
- **Extensions**: `HKEY_CURRENT_USER\Software\Classes\.<ext>\OpenWithProgids`
- **Application**: `HKEY_CURRENT_USER\Software\Classes\Applications\framesketch_player.exe`

### Safety
- Only modifies HKEY_CURRENT_USER (user-specific settings)
- Does not require administrator privileges
- Does not modify system-wide settings
- Can be completely removed with "Remove File Associations"
- Original file associations remain intact

## Troubleshooting

### App Doesn't Show in "Open With" Menu
1. Click ⋮ → "Check Registration Status"
2. If not registered, click ⋮ → "Set as Default Video Player"
3. Try right-clicking the video file again

### "Failed to Register" Error
- Ensure the app is built and running from the correct location
- Check that you have write permissions to your user registry
- Try closing and reopening the application

### Want to Unregister
- Click ⋮ → "Remove File Associations"
- Confirm the operation completed successfully

## Alternative: PowerShell Scripts (Optional)

For advanced users or automated deployment, PowerShell scripts are included:

- `register_file_associations.ps1` - Registers file associations
- `unregister_file_associations.ps1` - Removes file associations

**Note**: The built-in menu is easier and recommended for most users.

## Distribution

When distributing FrameSketch Player:

1. Share the entire `build\windows\x64\runner\Release\` folder
2. Users can run `framesketch_player.exe` directly
3. Users can register via the built-in menu (⋮)
4. No installation or setup wizard required

---

**FrameSketch Player** - Professional video player with built-in file association management.
