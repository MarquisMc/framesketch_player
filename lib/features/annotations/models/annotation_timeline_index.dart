import 'frame_marker.dart';
import 'stroke.dart';

class AnnotationTimelineIndex {
  final double fps;
  final List<int> sortedKeyframeTimesMs;
  final Map<int, List<Stroke>> strokesByKeyframeTimeMs;
  final List<FrameMarker> sortedMarkers;
  final List<int> sortedMarkerFrameTimesMs;
  final Map<int, List<FrameMarker>> markersByFrameTimeMs;

  const AnnotationTimelineIndex({
    required this.fps,
    required this.sortedKeyframeTimesMs,
    required this.strokesByKeyframeTimeMs,
    required this.sortedMarkers,
    required this.sortedMarkerFrameTimesMs,
    required this.markersByFrameTimeMs,
  });

  factory AnnotationTimelineIndex.empty([double fps = 30.0]) {
    return AnnotationTimelineIndex(
      fps: fps > 0 ? fps : 30.0,
      sortedKeyframeTimesMs: const [],
      strokesByKeyframeTimeMs: const {},
      sortedMarkers: const [],
      sortedMarkerFrameTimesMs: const [],
      markersByFrameTimeMs: const {},
    );
  }

  factory AnnotationTimelineIndex.build({
    required List<Stroke> strokes,
    required List<FrameMarker> markers,
    required double fps,
  }) {
    final effectiveFps = fps > 0 ? fps : 30.0;
    final strokesByKeyframe = <int, List<Stroke>>{};
    for (final stroke in strokes) {
      if (stroke.timingMode == StrokeTimingMode.whiteboard) {
        continue;
      }

      final keyframeMs = snapToFrameTimeMs(stroke.startTimeMs, effectiveFps);
      strokesByKeyframe.putIfAbsent(keyframeMs, () => <Stroke>[]).add(stroke);
    }

    final sortedKeyframes = strokesByKeyframe.keys.toList()..sort();
    final frozenStrokesByKeyframe = <int, List<Stroke>>{
      for (final keyframeMs in sortedKeyframes)
        keyframeMs: List<Stroke>.unmodifiable(strokesByKeyframe[keyframeMs]!),
    };

    final sortedMarkers = sortMarkers(markers);
    final sortedMarkerFrameTimesMs = <int>[];
    final markersByFrame = <int, List<FrameMarker>>{};
    for (final marker in sortedMarkers) {
      final frameMs = snapToFrameTimeMs(marker.timeMs, effectiveFps);
      sortedMarkerFrameTimesMs.add(frameMs);
      markersByFrame.putIfAbsent(frameMs, () => <FrameMarker>[]).add(marker);
    }

    return AnnotationTimelineIndex(
      fps: effectiveFps,
      sortedKeyframeTimesMs: List<int>.unmodifiable(sortedKeyframes),
      strokesByKeyframeTimeMs: Map<int, List<Stroke>>.unmodifiable(
        frozenStrokesByKeyframe,
      ),
      sortedMarkers: List<FrameMarker>.unmodifiable(sortedMarkers),
      sortedMarkerFrameTimesMs: List<int>.unmodifiable(
        sortedMarkerFrameTimesMs,
      ),
      markersByFrameTimeMs: Map<int, List<FrameMarker>>.unmodifiable({
        for (final entry in markersByFrame.entries)
          entry.key: List<FrameMarker>.unmodifiable(entry.value),
      }),
    );
  }

  static int snapToFrameTimeMs(int positionMs, double fps) {
    if (fps <= 0) return positionMs;
    final frameDurationMs = 1000.0 / fps;
    final frameIndex = (positionMs / frameDurationMs).round();
    return (frameIndex * frameDurationMs).round();
  }

  static int compareMarkers(FrameMarker a, FrameMarker b) {
    final byTime = a.timeMs.compareTo(b.timeMs);
    if (byTime != 0) return byTime;

    final byLabel = a.label.toLowerCase().compareTo(b.label.toLowerCase());
    if (byLabel != 0) return byLabel;

    return a.id.compareTo(b.id);
  }

  static List<FrameMarker> sortMarkers(List<FrameMarker> markers) {
    final sorted = [...markers];
    sorted.sort(compareMarkers);
    return sorted;
  }

  int? activeKeyframeTimeMsAt(int positionMs) {
    if (sortedKeyframeTimesMs.isEmpty) return null;

    final snappedPositionMs = snapToFrameTimeMs(positionMs, fps);
    final index = _upperBound(sortedKeyframeTimesMs, snappedPositionMs) - 1;
    if (index < 0) return null;
    return sortedKeyframeTimesMs[index];
  }

  List<Stroke> strokesAtKeyframe(int keyframeMs) {
    return strokesByKeyframeTimeMs[keyframeMs] ?? const [];
  }

  List<Stroke> visibleStrokesAt(int positionMs) {
    return visibleStrokesAtPosition(positionMs, allStrokes: [
      for (final keyframeMs in sortedKeyframeTimesMs)
        ...strokesAtKeyframe(keyframeMs),
    ]);
  }

  List<Stroke> visibleStrokesAtPosition(
    int positionMs, {
    required List<Stroke> allStrokes,
  }) {
    final keyframeMs = activeKeyframeTimeMsAt(positionMs);
    final visible = <Stroke>[];
    if (keyframeMs != null) {
      visible.addAll(strokesAtKeyframe(keyframeMs));
    }

    for (final stroke in allStrokes) {
      if (stroke.timingMode == StrokeTimingMode.whiteboard &&
          isWhiteboardStrokeVisibleAt(stroke, positionMs, fps)) {
        visible.add(stroke);
      }
    }

    return List<Stroke>.unmodifiable(visible);
  }

  static bool isWhiteboardStrokeVisibleAt(
    Stroke stroke,
    int positionMs,
    double fps,
  ) {
    if (stroke.timingMode != StrokeTimingMode.whiteboard) return false;

    final startMs = snapToFrameTimeMs(stroke.startTimeMs, fps);
    final endMs = snapToFrameTimeMs(stroke.endTimeMs, fps);
    if (endMs <= startMs) {
      return positionMs >= startMs;
    }

    return positionMs >= startMs && positionMs < endMs;
  }

  /// Returns all markers stored in [markersByFrameTimeMs] for the frame that
  /// [positionMs] snaps to via [snapToFrameTimeMs] using this index's [fps].
  List<FrameMarker> markersAtFrame(int positionMs) {
    final snappedPositionMs = snapToFrameTimeMs(positionMs, fps);
    return markersByFrameTimeMs[snappedPositionMs] ?? const [];
  }

  /// Returns only the first marker at the snapped frame, following the current
  /// sort order stored in [markersByFrameTimeMs]. Use [markersAtFrame] when all
  /// markers for a frame are needed.
  FrameMarker? markerAtFrame(int positionMs) {
    final markers = markersAtFrame(positionMs);
    if (markers.isEmpty) return null;
    return markers.first;
  }

  FrameMarker? adjacentMarker({
    required bool forward,
    required int positionMs,
  }) {
    if (sortedMarkers.isEmpty) return null;

    final currentFrameMs = snapToFrameTimeMs(positionMs, fps);
    if (forward) {
      final index = _upperBound(sortedMarkerFrameTimesMs, currentFrameMs);
      return index < sortedMarkers.length
          ? sortedMarkers[index]
          : sortedMarkers.first;
    }

    final index = _lowerBound(sortedMarkerFrameTimesMs, currentFrameMs) - 1;
    return index >= 0 ? sortedMarkers[index] : sortedMarkers.last;
  }

  int _lowerBound(List<int> values, int target) {
    var low = 0;
    var high = values.length;
    while (low < high) {
      final mid = low + ((high - low) >> 1);
      if (values[mid] < target) {
        low = mid + 1;
      } else {
        high = mid;
      }
    }
    return low;
  }

  int _upperBound(List<int> values, int target) {
    var low = 0;
    var high = values.length;
    while (low < high) {
      final mid = low + ((high - low) >> 1);
      if (values[mid] <= target) {
        low = mid + 1;
      } else {
        high = mid;
      }
    }
    return low;
  }
}
