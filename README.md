# FrameSketch Player

A professional desktop video playback tool with frame-accurate stepping and non-destructive annotation overlay capabilities.

## Features

### Video Playback
- **Multi-format support**: MP4, MOV, MKV, AVI, WebM, FLV, M4V via FFmpeg/libmpv
- **Smooth scrubbing**: Responsive timeline seeking with debounced updates
- **Frame-accurate stepping**: Step forward/backward by exactly one frame
- **Precise timecode display**: HH:MM:SS.mmm format with frame counter
- **Jump controls**: Skip forward/backward by 1 second intervals

### Annotation Tools
- **Freehand drawing**: Pen tool for marking up video frames
- **Color selection**: 8 preset colors (red, green, blue, yellow, orange, purple, white, black)
- **Adjustable stroke width**: 1-10 pixel brush sizes
- **Undo/Redo**: Full annotation history support
- **Persistent storage**: Annotations saved as JSON files alongside videos
- **Normalized coordinates**: Annotations scale with window resizing
- **Non-destructive**: Original video files remain untouched

### Keyboard Shortcuts
- **Space**: Play/Pause
- **Left Arrow**: Previous frame
- **Right Arrow**: Next frame
- **Shift + Left Arrow**: Jump back 1 second
- **Shift + Right Arrow**: Jump forward 1 second
- **Ctrl + O**: Open video file
- **Ctrl + S**: Save annotations
- **Ctrl + Z**: Undo last stroke
- **Ctrl + Y / Ctrl + Shift + Z**: Redo stroke

## Technical Architecture

### Video Engine
**Backend**: `media_kit` + `media_kit_video` (libmpv wrapper)
- Hardware-accelerated rendering via native texture
- Excellent desktop support (Windows/macOS/Linux)
- Frame-accurate seeking capabilities
- Extensive codec support through FFmpeg

### Frame Stepping Implementation
**Hybrid approach**:
1. Extract FPS from video metadata using FFprobe
2. Calculate frame duration: `1/fps` seconds
3. Seek to position ± frame duration
4. Clamp to video bounds [0, duration]

**Accuracy**: Frame stepping is accurate to the microsecond level. For videos with variable frame rates, the average FPS is used.

### Smooth Scrubbing Strategy
1. **Debounced seeking**: Throttle seek operations to ~60ms intervals during drag
2. **Final precise seek**: Execute exact seek when user releases slider
3. **Non-blocking UI**: All operations are async; timeline remains responsive
4. **Optimistic updates**: UI shows scrubbing position immediately

### State Management
**Riverpod 2.x** providers:
- `playerProvider`: Video playback state and controls
- `timelineProvider`: Scrubbing state with debouncing
- `annotationProvider`: Drawing tools and stroke management

### Data Model
Annotations are stored as JSON files with `.annotations.json` extension:

```json
{
  "videoId": "unique_hash",
  "videoPath": "/path/to/video.mp4",
  "fps": 30.0,
  "createdAt": "2024-01-15T10:30:00.000Z",
  "updatedAt": "2024-01-15T11:45:00.000Z",
  "strokes": [
    {
      "id": "uuid",
      "tool": "pen",
      "color": 4294901760,
      "strokeWidth": 3.0,
      "points": [
        {"x": 0.5, "y": 0.3, "timestampMs": 1500}
      ],
      "startTimeMs": 1000,
      "endTimeMs": 5000
    }
  ],
  "viewportWidth": 1920,
  "viewportHeight": 1080
}
```

**Coordinate normalization**: All stroke points are stored in normalized coordinates (0.0 to 1.0) to ensure annotations scale correctly across different window sizes.

## Setup Instructions

### Prerequisites

1. **Flutter SDK**: Version 3.10.7 or higher
   ```bash
   flutter --version
   ```

2. **FFmpeg & FFprobe** (REQUIRED):
   - **Windows**:
     - Download from [ffmpeg.org](https://ffmpeg.org/download.html) or [gyan.dev](https://www.gyan.dev/ffmpeg/builds/)
     - Extract to `C:\ffmpeg\` (recommended)
     - Or add to system PATH

   - **macOS**:
     ```bash
     brew install ffmpeg
     ```

   - **Linux**:
     ```bash
     sudo apt-get install ffmpeg  # Debian/Ubuntu
     sudo dnf install ffmpeg       # Fedora
     ```

3. **Desktop Support Enabled**:
   ```bash
   flutter config --enable-windows-desktop
   flutter config --enable-macos-desktop
   flutter config --enable-linux-desktop
   ```

### Installation

1. **Clone or extract** the project:
   ```bash
   cd d:/Projects/framesketch_player
   ```

2. **Install dependencies**:
   ```bash
   flutter pub get
   ```

3. **Run code generation** (for Freezed models):
   ```bash
   flutter pub run build_runner build --delete-conflicting-outputs
   ```

### Running the Application

#### Windows
```bash
flutter run -d windows
```

#### macOS
```bash
flutter run -d macos
```

#### Linux
```bash
flutter run -d linux
```

#### Build Release Version (Windows)
```bash
flutter build windows --release
```
Executable will be in: `build\windows\x64\runner\Release\framesketch_player.exe`

## Usage Guide

### Opening a Video

**Method 1: Using File Dialog**
1. Click the folder icon in the toolbar or press `Ctrl+O`
2. Select a video file (supports mp4, mov, mkv, avi, webm, flv, m4v)
3. Video will load and metadata will be extracted via FFprobe

**Method 2: Command-Line / Default Video Player**
1. Pass video path as argument: `framesketch_player.exe "path/to/video.mp4"`
2. Or set as default player (see below) and double-click video files

### Setting as Default Video Player

**Windows - Built-in Registration (Recommended):**
1. Open FrameSketch Player
2. Click the menu icon (⋮) in the top-right corner
3. Select "Set as Default Video Player"
4. Right-click any video file → "Open with" → "FrameSketch Player"
5. Check "Always use this app" to set as default

**Manual Registration:**
1. Right-click a video file → "Open with" → "Choose another app"
2. Click "More apps" → "Look for another app on this PC"
3. Navigate to `framesketch_player.exe`
4. Select and check "Always use this app"

**Check Status or Unregister:**
Click the menu icon (⋮) for options to check registration status or remove file associations.

### Playback Controls
- Use the play/pause button or press `Space`
- Step through frames using arrow keys or the step buttons
- Scrub by dragging the timeline slider

### Drawing Annotations
1. Select the **Pen** tool from the left panel
2. Choose a **color** by clicking a color swatch
3. Adjust **stroke width** using the slider
4. Click and drag on the video to draw
5. Use **Undo** (Ctrl+Z) to remove strokes
6. Press **Ctrl+S** to save annotations

### Saving & Loading Annotations
- **Auto-load**: Annotations are automatically loaded when opening a video with existing `.annotations.json` file
- **Manual save**: Press `Ctrl+S` or click the save icon
- **Storage location**: Annotations are saved in the same directory as the video file

## Project Structure

```
lib/
├── main.dart                          # App entry point
├── app.dart                           # Main app layout with keyboard shortcuts
├── core/
│   ├── models/
│   │   ├── video_metadata.dart        # Video file metadata
│   │   └── annotation_data.dart       # Annotation data model
│   ├── services/
│   │   ├── ffprobe_service.dart       # FFprobe integration
│   │   ├── ffmpeg_service.dart        # FFmpeg operations
│   │   └── annotation_storage_service.dart  # JSON persistence
│   └── utils/
│       ├── timecode_formatter.dart    # Time formatting utilities
│       └── coordinate_transformer.dart # Normalized coordinate handling
├── features/
│   ├── player/
│   │   ├── providers/
│   │   │   └── player_provider.dart   # Video playback state
│   │   └── widgets/
│   │       ├── video_viewport.dart    # Video display + overlay stack
│   │       └── playback_controls.dart # Play/pause/step buttons
│   ├── timeline/
│   │   ├── providers/
│   │   │   └── timeline_provider.dart # Scrubbing state
│   │   └── widgets/
│   │       └── timeline_scrubber.dart # Seek slider
│   └── annotations/
│       ├── models/
│       │   └── stroke.dart            # Stroke and point data
│       ├── providers/
│       │   └── annotation_provider.dart # Drawing state
│       └── widgets/
│           ├── annotation_overlay.dart # CustomPaint overlay
│           └── drawing_tools_panel.dart # Tool selection UI
```

## Known Limitations & Future Improvements

### Current Limitations

1. **Variable Frame Rate (VFR) videos**: Frame stepping uses average FPS, which may drift slightly in VFR content
2. **Export functionality**: Burning annotations into video (FFmpeg filter overlay) is not yet implemented
3. **Eraser tool**: Currently disabled (pen-only mode)
4. **Timeline thumbnails**: Preview thumbnails on scrubber not implemented
5. **Multi-stroke selection**: Cannot select/move/delete individual strokes after drawing

### Planned Features

- [ ] Export annotated video with burned-in strokes (FFmpeg overlay filter)
- [ ] Eraser tool for removing parts of strokes
- [ ] Shape tools (rectangle, arrow, circle)
- [ ] Text annotation support
- [ ] Timeline thumbnail preview on hover
- [ ] Recent files menu
- [ ] Playback speed control (0.25x - 2x)
- [ ] Stroke selection and manipulation (move, resize, delete)
- [ ] Multi-layer annotation support
- [ ] Timestamp-based annotation visibility (show/hide strokes by time range)
- [ ] Export annotations as separate image sequence
- [ ] Annotation templates/presets

### Performance Considerations

- **Heavy videos**: 4K+ videos may see slower seeking on older hardware
- **Many strokes**: 1000+ strokes may impact rendering performance (use Clear All to reset)
- **FFprobe parsing**: First video load extracts metadata; subsequent loads are faster

## Troubleshooting

### "FFprobe not found" Error
**Solution**: Install FFmpeg and ensure it's in your system PATH or placed in `C:\ffmpeg\bin\` (Windows).

**Verify installation**:
```bash
ffprobe -version
ffmpeg -version
```

### Video Loads but Shows Black Screen
**Possible causes**:
- Unsupported codec (rare with FFmpeg)
- Hardware acceleration issue

**Solution**: Try a different video format (MP4 H.264 is most compatible)

### Annotations Not Saving
**Check**:
- Write permissions in video directory
- Disk space availability
- Console for error messages

### Sluggish Scrubbing
**Solutions**:
- Close other applications
- Try lower resolution video
- Ensure GPU drivers are updated

## Implementation Notes

### Frame Stepping Tradeoffs

**Chosen Approach**: Calculated time-based seeking
- **Pros**: Works with all video formats; no codec-specific logic required
- **Cons**: May drift slightly on VFR content; relies on accurate FPS metadata

**Alternative Considered**: True frame-by-frame decode
- **Pros**: Perfect accuracy
- **Cons**: Extremely slow; would require background thread processing; memory intensive

**Conclusion**: Time-based seeking provides the best balance of accuracy and performance for a desktop tool.

### Scrubbing Performance

**Debouncing strategy** prevents UI lockup:
- Slider updates optimistically (immediate visual feedback)
- Actual seeks throttled to 60ms intervals
- Final precise seek on mouse release

This approach keeps the UI responsive even during aggressive scrubbing of high-bitrate video.

### Annotation Overlay Architecture

**Stack-based rendering**:
1. Bottom layer: media_kit Video widget (RepaintBoundary for performance)
2. Top layer: CustomPaint overlay with GestureDetector

**Benefits**:
- No video re-encoding required
- Annotations render at native resolution
- Easy to edit/delete strokes in real-time
- Minimal performance overhead

## Development

### Running in Debug Mode
```bash
flutter run -d windows --verbose
```

### Regenerating Freezed Models
```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

### Running Tests
```bash
flutter test
```

## License

This project is provided as-is for educational and professional use.

## Credits

Built with:
- [Flutter](https://flutter.dev/) - UI framework
- [media_kit](https://pub.dev/packages/media_kit) - Video playback (libmpv wrapper)
- [Riverpod](https://pub.dev/packages/flutter_riverpod) - State management
- [Freezed](https://pub.dev/packages/freezed) - Data classes
- [FFmpeg](https://ffmpeg.org/) - Media processing

---

**FrameSketch Player** - Frame-accurate video annotation for professionals.
