# FrameSketch Player

FrameSketch Player is a Flutter desktop video review tool for frame-accurate playback, keyed annotations, frame markers, and annotated exports.

It is built for review workflows where you need to step through footage precisely, mark issues on specific frames, save the session, and come back later without rebuilding context.

## Current Status

The app currently supports:

- Local video playback on Windows, macOS, and Linux via `media_kit` / `libmpv`
- Opening YouTube videos by URL for review and annotation
- A project library with thumbnails, rename, revert-name, and delete actions
- Frame-accurate stepping, scrubbing, loop controls, and fullscreen playback
- Keyframed annotations that appear on specific frames
- Drawing tools including pen, rectangle, filled square, circle, filled circle, line, arrow, text, eraser, and selection
- Frame markers with notes plus marker import/export
- Auto-save, manual save, and `Save As` for portable `.framesketch` files
- Crop and segment export for local videos
- Exporting local videos with burned-in annotations
- Custom keyboard shortcuts
- Light/dark mode plus custom generated themes
- Windows file association registration for supported video files and `.framesketch` files

## Feature Overview

### Playback and Navigation

- Frame stepping forward and backward
- Timeline scrubbing with responsive seek behavior
- Play/pause, jump controls, and fullscreen mode
- Full-video loop and A/B loop controls
- Exact timecode display with frame-aware review workflows

### Sources

#### Local Files

- Open video files directly from disk
- Re-open work from the project browser
- Open saved annotation files and restore the linked source automatically

#### YouTube

- Paste a YouTube URL and load it directly in the player
- Save annotations against a stable YouTube-backed project entry
- Reopen YouTube review sessions from the project browser

Notes:

- YouTube support is intended for playback and annotation review
- Export is limited to local video files
- Some videos may be unavailable due to YouTube restrictions, account requirements, regional limits, or missing playable streams

### Annotation System

Annotations are stored separately from the source media and keyed to frames. The current annotation toolset includes:

- Pen
- Rectangle
- Filled square
- Circle
- Filled circle
- Line
- Arrow
- Text
- Eraser
- Selection and box selection

Annotation workflows currently include:

- Undo and redo
- Stroke selection, movement, scaling, and deletion
- Keyframe-based visibility
- Automatic or manual keyframe creation modes
- Inline text editing
- Normalized coordinate storage so overlays scale with the viewport
- Save/load for both local videos and YouTube review sessions

### Frame Markers

Frame markers are lightweight review notes that sit alongside annotations.

- Add markers at the current frame
- Give each marker a label, note, and color
- Jump to previous/next marker
- Import or export marker lists as JSON
- Merge imported markers into the current session or replace the existing list

### Project Library

The built-in project browser keeps recent review sessions accessible without going back through the file picker.

- Local projects get generated thumbnails
- YouTube projects use YouTube thumbnail URLs when available
- Projects are sorted by last-opened time
- Local projects can be renamed on disk, including annotation-file updates
- Renamed local projects can be reverted back to their original name
- Deleting a local project removes the local video, annotations, and cached thumbnail

### Export

Export is available for local video files.

- Export the full video or a selected time range
- Crop using a draggable crop rectangle
- Use aspect presets such as `Original`, `16:9`, `1:1`, `9:16`, `4:3`, and `3:4`
- Burn visible annotations into the exported video
- Stream-copy when no crop or overlay work is needed
- Re-encode to H.264/AAC MP4 when visual processing is required
- Cancel an export in progress

## Keyboard Shortcuts

Shortcuts are customizable in the Settings dialog. Default bindings include:

### General

- `Space`: Play/pause
- `,`: Previous frame
- `.`: Next frame
- `Shift + Left Arrow`: Jump backward
- `Shift + Right Arrow`: Jump forward
- `Ctrl + O`: Open local file
- `Ctrl + S`: Save annotations
- `Ctrl + Z`: Undo
- `Ctrl + Y`: Redo

### Annotation Tools

- Selection, pen, eraser, rectangle, circle, line, arrow, and text all have configurable shortcuts
- Keyframe mode toggle is configurable
- Manual keyframe creation is configurable

### Loop and Crop

- Full loop, loop start, loop end, and A/B loop are configurable
- Crop mode toggle is configurable

### Marker Navigation

- Previous marker and next marker are configurable

## Annotation Files

The app works with portable annotation files using `.framesketch` and JSON-based storage.

Typical saved data includes:

- Source identity for a local video or YouTube session
- FPS metadata
- Keyframed strokes
- Frame markers
- Timestamps and update metadata

For local videos, annotations can also be saved and reloaded alongside the source workflow.

## Tech Stack

- [Flutter desktop](https://docs.flutter.dev/platform-integration/desktop)
- [`media_kit`](https://pub.dev/packages/media_kit) and [`media_kit_video`](https://pub.dev/packages/media_kit_video) for playback
- [Riverpod](https://riverpod.dev) for state management
- [Freezed](https://pub.dev/packages/freezed) + [JSON serialization](https://pub.dev/packages/freezed#fromjson-tojson) for models
- [FFmpeg](https://ffmpeg.org) for export and media processing
- [`youtube_explode_dart`](https://pub.dev/packages/youtube_explode_dart) for YouTube source resolution
- [`shared_preferences`](https://pub.dev/packages/shared_preferences) for local settings and project library persistence

## Project Structure

```text
lib/
|-- main.dart
|-- app.dart
|-- ui/
|   |-- editor_scaffold.dart
|   |-- editor_toolbar.dart
|   `-- inspector_panel.dart
|-- core/
|   |-- models/
|   |-- services/
|   |-- theme/
|   `-- utils/
`-- features/
    |-- annotations/
    |-- crop/
    |-- loop/
    |-- player/
    |-- projects/
    |-- settings/
    `-- timeline/
```

## Setup

### Prerequisites

1. Install Flutter `3.10.7` or newer.
2. Enable desktop support for the platforms you want to run.

```bash
flutter config --enable-windows-desktop
flutter config --enable-macos-desktop
flutter config --enable-linux-desktop
```

### Install Dependencies

```bash
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs
```

### Run

```bash
flutter run -d windows
```

Or use `macos` / `linux` as the target device.

### Build

```bash
flutter build windows --release
```

## Basic Usage

### Start a Review Session

1. Open a local file, YouTube URL, saved annotation file, or project-library entry.
2. Scrub or step to the frame you want to review.
3. Add annotations, text, or frame markers.
4. Save the session or let auto-save keep it up to date.

### Export a Reviewed Clip

1. Open a local video.
2. Set the crop region and export range if needed.
3. Save annotations.
4. Export to MP4 with burned-in overlays.

## Platform Notes

### Windows

- Includes file association registration helpers for supported video files and `.framesketch`
- Windows release packaging is already present in the repository

### macOS and Linux

- Playback is supported through the platform-specific `media_kit` desktop libraries

## Testing

Run the test suite with:

```bash
flutter test
```

## Known Limitations

- Export is local-file only; YouTube sources are not exportable
- YouTube playback depends on stream availability and may fail for restricted or unsupported videos
- Very large videos or very dense annotation sessions may reduce responsiveness on older hardware
- Desktop support is the primary target; the app is not documented as a mobile product

## License

This project is licensed under the Apache License 2.0.

See the [LICENSE](LICENSE) file for the full license text.
See the [NOTICE](NOTICE) file for attribution notices.
