# FrameSketch Player - Quick Start Guide

Get up and running in 5 minutes!

## Step 1: Install FFmpeg (Required)

### Windows
1. Download FFmpeg from: https://www.gyan.dev/ffmpeg/builds/
2. Choose "ffmpeg-release-essentials.zip"
3. Extract to `C:\ffmpeg\`
4. Add `C:\ffmpeg\bin` to system PATH (or just extract to that location)

**Quick verification:**
```bash
ffprobe -version
```

### macOS
```bash
brew install ffmpeg
```

### Linux (Ubuntu/Debian)
```bash
sudo apt-get install ffmpeg
```

## Step 2: Setup Flutter Desktop

Ensure Flutter desktop is enabled:
```bash
flutter config --enable-windows-desktop  # Windows
flutter config --enable-macos-desktop    # macOS
flutter config --enable-linux-desktop    # Linux
```

## Step 3: Install Dependencies

```bash
cd d:/Projects/framesketch_player
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs
```

## Step 4: Run the App

```bash
flutter run -d windows  # or macos, linux
```

## Step 5: Test with a Video

1. Press `Ctrl+O` or click the folder icon
2. Select any MP4/MOV/MKV video
3. Wait for it to load (FFprobe extracts metadata)
4. Use playback controls to navigate
5. Draw annotations with the pen tool
6. Press `Ctrl+S` to save

## Keyboard Shortcuts Cheatsheet

| Key | Action |
|-----|--------|
| `Space` | Play/Pause |
| `←` | Previous frame |
| `→` | Next frame |
| `Shift + ←` | Jump back 1 second |
| `Shift + →` | Jump forward 1 second |
| `Ctrl + O` | Open video |
| `Ctrl + S` | Save annotations |
| `Ctrl + Z` | Undo |
| `Ctrl + Y` | Redo |

## Troubleshooting

**"FFprobe not found" error:**
- Make sure FFmpeg is installed and in PATH
- On Windows, check `C:\ffmpeg\bin\ffprobe.exe` exists

**Black screen after loading video:**
- Try a different video (MP4 H.264 works best)
- Check console for errors

**App won't build:**
- Run `flutter clean && flutter pub get`
- Ensure Flutter version is 3.10.7+

## Next Steps

- Read [README.md](README.md) for full feature documentation
- Check [IMPLEMENTATION_NOTES.md](IMPLEMENTATION_NOTES.md) for technical details
- Explore the annotation tools panel on the left
- Try frame stepping with arrow keys

Enjoy frame-accurate video annotation! 🎬
