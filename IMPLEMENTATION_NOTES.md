# FrameSketch Player - Implementation Notes

## Technical Decisions & Tradeoffs

### Video Backend Selection

**Chosen: media_kit (libmpv wrapper)**

**Rationale:**
1. **Desktop-first design**: Unlike `video_player` (mobile-focused), media_kit has excellent Windows/macOS/Linux support
2. **Hardware acceleration**: Native texture rendering via libmpv provides smooth playback
3. **Codec coverage**: FFmpeg integration means support for virtually all video formats
4. **Seeking precision**: libmpv's seek implementation is reliable and frame-accurate
5. **Active maintenance**: Well-maintained with regular updates

**Alternatives Considered:**
- `video_player`: Poor desktop support, limited codec coverage
- `dart_vlc`: VLC wrapper, but less stable than libmpv on Windows
- Custom FFmpeg bindings: Would require extensive platform-specific code

### Frame Stepping Strategy

**Implemented Approach: Time-based seeking with FPS calculation**

```dart
// Calculate next frame position
final frameDuration = Duration(microseconds: (1000000 / fps).round());
final nextPosition = currentPosition + frameDuration;
await player.seek(nextPosition);
```

**Why this works:**
- FPS extracted from video metadata via FFprobe
- Microsecond precision prevents drift over long sessions
- Works with all codecs without codec-specific logic
- Fast execution (no frame decoding required)

**Limitations:**
- **Variable Frame Rate (VFR) videos**: Uses average FPS, which may drift
  - Example: If a video has 29.97 FPS in section A and 30.0 FPS in section B, stepping will be slightly off in one section
  - **Mitigation**: For professional use, convert VFR to CFR (constant frame rate) before annotation

- **Exact frame matching**: We seek to a timestamp, trusting libmpv to decode the nearest keyframe
  - Modern codecs (H.264/H.265) have frequent keyframes, so this is usually accurate
  - For B-frame heavy content, there may be a 1-2 frame variance

**Why not true frame-by-frame decoding?**
- Would require:
  1. Decode every frame to memory
  2. Store in circular buffer
  3. Display from buffer instead of live decode
- **Problems**:
  - Memory intensive (4K video = ~8MB per frame uncompressed)
  - Slow initialization
  - Complex synchronization logic
  - Doesn't work well with scrubbing

**Verdict**: Time-based seeking is the right choice for a desktop annotation tool. It's fast, simple, and accurate enough for 99% of use cases.

### Smooth Scrubbing Implementation

**Problem**: Dragging a slider fires hundreds of events per second. If each triggers a video seek, the UI freezes.

**Solution**: Three-tier approach

1. **Optimistic UI updates**
   ```dart
   // Update slider position immediately (no wait)
   state = state.copyWith(scrubbingPosition: newPosition);
   ```

2. **Debounced seeking**
   ```dart
   // Only actually seek every 60ms during drag
   _seekDebounceTimer?.cancel();
   _seekDebounceTimer = Timer(Duration(milliseconds: 60), () {
     player.seek(position);
   });
   ```

3. **Final precise seek**
   ```dart
   // When user releases, do one final exact seek
   void endScrubbing() {
     _seekDebounceTimer?.cancel();
     player.seek(finalPosition);
   }
   ```

**Results**:
- Slider feels responsive (immediate visual feedback)
- Video updates ~16 times per second (smooth enough)
- No UI freezes even on 4K video
- Final position is always exact

**Tradeoff**: During aggressive scrubbing, video preview lags slightly behind slider. This is acceptable because:
- User gets immediate feedback from slider position
- Final seek on release is precise
- Alternative (lag slider to match video) feels sluggish

### Annotation Coordinate System

**Challenge**: Window can be resized, video has fixed resolution. How do we ensure annotations stay aligned?

**Solution**: Normalized coordinates (0.0 to 1.0)

```dart
// When user draws at pixel (640, 360) on a 1280x720 viewport:
final normalizedX = 640 / 1280; // = 0.5
final normalizedY = 360 / 720;  // = 0.5

// When window is resized to 1920x1080, annotation renders at:
final pixelX = 0.5 * 1920; // = 960
final pixelY = 0.5 * 1080; // = 540
```

**Benefits**:
- Annotations scale perfectly with window size
- JSON files are resolution-independent
- Can annotate on laptop, view on desktop

**Implementation detail**: We store the original viewport size in the annotation file for reference, but don't use it for rendering. This helps if we later want to export at original resolution.

### State Management Architecture

**Chosen: Riverpod 2.x with StateNotifier**

**Provider hierarchy**:
```
playerProvider (owns Player instance, emits playback state)
    ↓
timelineProvider (reads player state, manages scrubbing)
    ↓
annotationProvider (reads player position for timestamps)
```

**Why StateNotifier over simpler alternatives?**
- **ChangeNotifier**: No immutable state, harder to debug
- **StreamProvider**: More boilerplate for state updates
- **StateProvider**: Too simple, no lifecycle management
- **StateNotifier**: Sweet spot of power and simplicity

**Key pattern**: Providers are independent but can read each other via `ref.read()`. This prevents tight coupling while allowing communication.

### FFmpeg Integration Strategy

**Design principle**: Graceful degradation

**App behavior**:
1. On startup: Check if `ffprobe` is available
2. If missing: Still launch, but show error when user opens video
3. Provide clear instructions on how to install FFmpeg

**Why not bundle FFmpeg?**
- **Windows**: FFmpeg binaries are ~100MB (too large for repo)
- **License**: FFmpeg is LGPL, requires dynamic linking
- **Updates**: System-installed FFmpeg gets security updates

**Compromise**: `media_kit_libs_windows_video` package includes libmpv binaries (which contain FFmpeg libs) for playback. But we still need standalone `ffprobe` CLI for metadata extraction.

**Future improvement**: Could bundle ffprobe.exe (only ~50MB) in Windows release builds.

### Annotation Storage Format

**Chosen: JSON with explicit schema**

**Why JSON over alternatives?**
- **Binary (protobuf/msgpack)**: Harder to debug, not human-editable
- **XML**: Too verbose
- **SQLite**: Overkill for single-video annotations
- **JSON**: Human-readable, easy to version control, simple

**Schema design decisions**:

1. **Separate strokes array**: Easy to iterate, append, undo
2. **Timestamps per point**: Allows future time-based filtering ("show only strokes from 10-20s")
3. **Color as int**: `Color.value` is an int (ARGB). Simpler than hex strings.
4. **videoId hash**: Handles case where video is moved (path changes but ID stays same)

**Example**:
```json
{
  "videoId": "a1b2c3d4e5f6g7h8",
  "videoPath": "C:/Videos/test.mp4",
  "strokes": [
    {
      "id": "550e8400-e29b-41d4-a716-446655440000",
      "tool": "pen",
      "color": 4294901760,
      "strokeWidth": 3.0,
      "points": [
        {"x": 0.25, "y": 0.5, "timestampMs": 1000},
        {"x": 0.26, "y": 0.51, "timestampMs": 1033}
      ]
    }
  ]
}
```

### Performance Optimizations

**Applied techniques**:

1. **RepaintBoundary on video layer**
   - Prevents entire stack from repainting when annotations change
   - Video texture stays cached

2. **CustomPainter for annotations**
   - Only repaints when stroke list changes
   - Much faster than rebuilding widget tree

3. **Normalized coordinates**
   - Transform calculations happen in paint(), not on every pointer move
   - Reduces state updates

4. **Debounced seeking**
   - Reduces load on video decoder
   - Prevents seek queue buildup

**What we didn't optimize (yet)**:
- **Path simplification**: Could reduce points in long strokes (Douglas-Peucker algorithm)
- **Spatial indexing**: For 1000+ strokes, could use R-tree to cull off-screen strokes
- **Texture caching**: Could cache rendered annotation layer as texture

**When to optimize**: These are only needed if users report slowdowns with 500+ strokes. Current architecture handles typical use (10-50 strokes) easily.

### Keyboard Shortcut System

**Implementation**: Focus + KeyEvent handling

```dart
Focus(
  onKeyEvent: (node, event) {
    if (event.logicalKey == LogicalKeyboardKey.space) {
      playerNotifier.togglePlayPause();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  },
  child: Scaffold(...),
)
```

**Why not RawKeyboardListener?**
- `Focus` is the modern Flutter approach
- Better handling of focus scope
- More reliable on desktop platforms

**Critical detail**: Must call `focusNode.requestFocus()` after dialogs close, otherwise shortcuts stop working.

### Error Handling Philosophy

**Principle**: Fail gracefully, inform user clearly

Examples:
- **FFprobe missing**: Show error dialog with installation instructions
- **Video won't load**: Display error in viewport, don't crash
- **Annotation save fails**: Show snackbar, keep unsaved state
- **Invalid video format**: Explain codec issue, suggest re-encoding

**No silent failures**: Every error path shows UI feedback.

### Testing Strategy

**Current state**: Minimal automated tests (MVP focus)

**Recommended test coverage**:
1. **Unit tests**:
   - `TimecodeFormatter`: Parse/format edge cases
   - `CoordinateTransformer`: Normalization math
   - `AnnotationStorageService`: JSON serialization

2. **Widget tests**:
   - `PlaybackControls`: Button states
   - `DrawingToolsPanel`: Tool selection
   - `TimelineScrubber`: Slider behavior

3. **Integration tests**:
   - Load video → annotate → save → reload
   - Keyboard shortcuts work
   - Undo/redo stack

**Why not implemented yet?**: MVP prioritized working features. Tests should be added before 1.0 release.

## Known Issues & Workarounds

### Issue: media_kit first-frame flicker
**Symptom**: Brief black frame when opening video
**Cause**: libmpv initialization
**Workaround**: None. Acceptable for MVP.
**Fix**: Could show loading spinner longer to mask it.

### Issue: Annotations jitter when window resizes
**Symptom**: Strokes briefly misalign during resize
**Cause**: LayoutBuilder rebuilds before video aspect ratio updates
**Workaround**: Resize slowly
**Fix**: Lock aspect ratio in video container.

### Issue: FFprobe detection fails in some Windows setups
**Symptom**: "FFprobe not found" even when installed
**Cause**: Non-standard PATH configuration
**Workaround**: Hardcode path in settings (not implemented)
**Fix**: Add settings UI for custom ffprobe path.

## Future Architecture Considerations

### Export Annotated Video

**Planned approach**:
1. Render each annotation frame to PNG sequence
2. Use FFmpeg overlay filter:
   ```bash
   ffmpeg -i input.mp4 -i annotations_%04d.png
          -filter_complex overlay output.mp4
   ```
3. Run in isolate with progress callbacks

**Challenges**:
- Must render annotations at video resolution (not viewport size)
- Memory intensive (4K frames)
- Slow (real-time encoding for 10min video = 10min wait)

**Optimization**: Could render only frames with annotations, copy rest.

### Timeline Thumbnails

**Approach**:
1. On video load, extract keyframe at 10s intervals using FFmpeg
2. Cache thumbnails in temp directory
3. Display in timeline on hover

**Challenge**: Storage (100 thumbnails × 50KB = 5MB per video)

### Recent Files

**Already partially implemented**: `AnnotationStorageService.addToRecentFiles()`

**Needs**: UI menu to display list.

## Conclusion

This implementation prioritizes:
1. **Correctness**: Frame stepping is accurate, annotations are precise
2. **Performance**: Smooth playback and scrubbing on typical hardware
3. **Simplicity**: Clean architecture, easy to extend
4. **User experience**: Clear errors, keyboard shortcuts, auto-save

**Production-ready?** MVP is functional for basic use. For production:
- Add comprehensive tests
- Implement export feature
- Polish UI (better icons, themes)
- Add settings panel (custom FFmpeg path, etc.)
- Performance profiling with large annotation sets

**Estimated effort**: ~2-3 weeks additional work for production polish.
