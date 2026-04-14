# Project Status

This document captures the current implementation snapshot plus the roadmap-style planning that used to live in `README.md`.

## Current Implementation

### Playback

- Desktop playback via `media_kit` / `libmpv`
- Local file playback on Windows, macOS, and Linux
- YouTube URL loading for review sessions
- Frame stepping
- Timeline scrubbing
- Fullscreen playback
- Jump forward/backward controls
- Timecode display

### Review Workflow

- Project library with persisted entries
- Thumbnail generation for local projects
- YouTube thumbnail support for YouTube-backed projects
- Rename, revert-name, refresh, and delete project actions
- Auto-save support
- Manual save and `Save As`
- Portable `.framesketch` annotation files

### Annotation Tools

- Pen
- Eraser
- Rectangle
- Filled square
- Circle
- Filled circle
- Line
- Arrow
- Text
- Selection / box selection

### Annotation Behavior

- Keyframed annotations
- Automatic keyframe creation mode
- Manual keyframe creation mode
- Undo / redo
- Stroke selection
- Stroke move / scale / delete
- Inline text editing
- Normalized coordinate storage
- Load and save for local and YouTube sessions

### Markers

- Frame markers with label, note, and color
- Previous / next marker navigation
- Import marker list
- Export marker list
- Merge or replace imported markers

### Looping

- Full-video loop
- A/B loop
- Timeline loop markers

### Crop and Export

- Interactive crop overlay
- Aspect ratio presets including `Original`, `16:9`, `1:1`, `9:16`, `4:3`, and `3:4`
- Export selected range or full duration
- Burned-in annotation export for local videos
- Cancelable export
- Stream copy when no visual transform is required
- Re-encode path when crop or overlays are required

### Customization and Platform Support

- Custom keyboard shortcuts
- Light / dark mode
- Custom theme generation
- Windows file association registration for supported video files and `.framesketch`

## Technical Snapshot

### App Architecture

- Flutter desktop app
- Riverpod-based state management
- Freezed / JSON-serializable model layer
- FFmpeg-backed export pipeline
- `youtube_explode_dart` source resolution for YouTube playback
- `shared_preferences` persistence for settings and project library

### Export Pipeline

The export flow currently does the following:

1. Resolves a local source video
2. Applies optional time-range trimming
3. Applies optional crop filtering
4. Renders annotation overlays to temporary PNGs
5. Burns overlays into the output video when annotations are present
6. Writes MP4 output using H.264/AAC when re-encoding is required
7. Falls back to stream copy when no crop or overlay work is needed

### Annotation Model

The current annotation model includes:

- Keyframed strokes
- Stroke timestamps
- Text content and font size
- Marker metadata
- Source identity for local videos or YouTube sessions
- Portable annotation-file storage

## Current Limitations

These are the main known limits in the current implementation:

1. Export is local-file only; YouTube sources are not exportable.
2. YouTube playback depends on available streams and may fail for restricted, age-gated, private, or unsupported videos.
3. Large videos or very dense annotation sessions may feel slower on older hardware.
4. Desktop is the primary supported target; mobile is not the documented focus.
5. Variable frame rate content may still have edge cases depending on source metadata and stepping behavior.

## Completed Milestones

- [x] Frame-accurate desktop playback
- [x] Annotation overlay system
- [x] Smart eraser workflow
- [x] A/B loop support
- [x] Project library
- [x] YouTube review-source loading
- [x] Marker import/export
- [x] Crop and range export
- [x] Burned-in annotation video export
- [x] Custom keyboard shortcuts
- [x] Theme manager and generated themes
- [x] Windows file association tooling

## Roadmap

These are the remaining ideas and future-facing features that still make sense to track outside the main README.

### Near-Term Improvements

- Timeline thumbnail preview on scrub/hover
- Recent files access separate from the project browser
- Playback speed control
- Clearer export presets and export-history UX
- More polish around large-project handling and responsiveness

### Annotation Enhancements

- Multi-layer annotation support
- Better stroke grouping and organization
- Richer text formatting options
- Additional shape presets and review callout styles
- Annotation templates / presets
- Improved timestamp-based visibility controls

### Review and Media Tools

- Audio waveform visualization
- Video rotation and flip controls
- Additional comparison/review utilities
- Better source metadata display

### Long-Term Ideas

- Export annotations as separate image sequences or assets
- More advanced project/session management
- Additional collaboration or sharing workflows

## Related Files

- [README.md](README.md)
- [FEATURES_IMPLEMENTATION.md](FEATURES_IMPLEMENTATION.md)
- [IMPLEMENTATION_NOTES.md](IMPLEMENTATION_NOTES.md)
