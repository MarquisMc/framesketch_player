# Quick Start Guide - Loop & Crop Features

## Full Video Loop

**Enable loop entire video:**
1. Press `L` or click repeat button (🔁)
2. Video will restart from beginning when end is reached
3. Press `L` again to disable

## Section Loop (A-B Loop)

**Loop between two points:**
1. Play to start point → Press `I` (green "A" marker appears)
2. Play to end point → Press `O` (orange "B" marker appears)
3. Press `[` to enable loop
4. Video loops between A and B
5. Drag markers on timeline to adjust
6. Click "Clear" to remove loop points

## Video Cropping

**Crop and export video:**
1. Press `C` to enter crop mode
2. Drag corners to resize crop area
3. Drag center to move crop area
4. (Optional) Select aspect ratio preset (16:9, 1:1, etc.)
5. Click "Export Cropped Video"
6. Choose save location
7. Wait for export to complete
8. Press `Esc` to exit crop mode

### Crop Controls
- **Corner handles**: Resize from corners (maintains aspect ratio if set)
- **Edge handles**: Resize individual edges
- **Center area**: Move entire crop
- **Aspect ratios**: Free, 16:9, 1:1, 9:16, 4:3, 3:4

## Keyboard Shortcuts

| Key | Action |
|-----|--------|
| `L` | Toggle full video loop |
| `I` | Set loop start (A point) |
| `O` | Set loop end (B point) |
| `[` | Toggle section loop |
| `C` | Toggle crop mode |
| `Esc` | Exit crop mode |

All shortcuts are customizable via Settings (⚙️).

## Setting as Default Video Player

**Make FrameSketch Player your default video player:**

### Method 1: Built-in Registration (Easiest)
1. Open FrameSketch Player
2. Click the menu icon (⋮) in the top-right corner
3. Select "Set as Default Video Player"
4. Right-click any video file → "Open with" → "FrameSketch Player"
5. Check "Always use this app" to set as default

### Method 2: Manual Setup
1. Right-click any video file (.mp4, .mov, .mkv, etc.)
2. Select "Open with" → "Choose another app"
3. Click "More apps" → "Look for another app on this PC"
4. Navigate to `framesketch_player.exe`
5. Check "Always use this app" to set as default

### Supported Formats
- MP4 (.mp4)
- QuickTime (.mov)
- Matroska (.mkv)
- AVI (.avi)
- WebM (.webm)
- Flash Video (.flv)
- MPEG-4 (.m4v)

### Opening Videos
Once registered, you can:
- Double-click video files to open in FrameSketch Player
- Right-click videos → "Open with" → "FrameSketch Player"
- Drag and drop video files onto the app
- Use `Ctrl+O` within the app to browse for videos

### Unregistering
Click the menu icon (⋮) → "Remove File Associations"

## Requirements

✅ **No external dependencies!** FFmpeg is bundled with the app - crop export works out of the box.
