import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:framesketch_player/features/annotations/models/annotation_timeline_index.dart';
import 'package:framesketch_player/features/annotations/models/frame_marker.dart';
import 'package:framesketch_player/features/annotations/models/stroke.dart';

void main() {
  group('AnnotationTimelineIndex', () {
    test('finds active keyframe using snapped frame times', () {
      final index = AnnotationTimelineIndex.build(
        fps: 10,
        strokes: [
          _stroke('a', startTimeMs: 0),
          _stroke('b', startTimeMs: 205),
          _stroke('c', startTimeMs: 390),
        ],
        markers: const [],
      );

      expect(index.sortedKeyframeTimesMs, [0, 200, 400]);
      expect(index.activeKeyframeTimeMsAt(50), 0);
      expect(index.activeKeyframeTimeMsAt(240), 200);
      expect(index.activeKeyframeTimeMsAt(349), 200);
      expect(index.activeKeyframeTimeMsAt(351), 400);
    });

    test('returns visible strokes grouped by snapped keyframe', () {
      final first = _stroke('first', startTimeMs: 95);
      final second = _stroke('second', startTimeMs: 104);
      final later = _stroke('later', startTimeMs: 305);
      final index = AnnotationTimelineIndex.build(
        fps: 10,
        strokes: [first, later, second],
        markers: const [],
      );

      expect(index.sortedKeyframeTimesMs, [100, 300]);
      expect(index.strokesAtKeyframe(100), [first, second]);
      expect(index.visibleStrokesAt(240), [first, second]);
      expect(index.visibleStrokesAt(305), [later]);
    });

    test('combines active keyframe strokes with whiteboard range strokes', () {
      final keyframe = _stroke('keyframe', startTimeMs: 100);
      final whiteboard = _stroke(
        'whiteboard',
        startTimeMs: 150,
        endTimeMs: 350,
        timingMode: StrokeTimingMode.whiteboard,
      );
      final index = AnnotationTimelineIndex.build(
        fps: 10,
        strokes: [keyframe, whiteboard],
        markers: const [],
      );

      expect(index.sortedKeyframeTimesMs, [100]);
      expect(
        index.visibleStrokesAtPosition(
          200,
          allStrokes: [keyframe, whiteboard],
        ),
        [keyframe, whiteboard],
      );
      expect(
        index.visibleStrokesAtPosition(
          400,
          allStrokes: [keyframe, whiteboard],
        ),
        [keyframe],
      );
    });

    test(
      'looks up markers by snapped frame and preserves marker sort order',
      () {
        final alpha = _marker('a', timeMs: 101, label: 'Alpha');
        final beta = _marker('b', timeMs: 99, label: 'Beta');
        final later = _marker('c', timeMs: 250, label: 'Later');
        final index = AnnotationTimelineIndex.build(
          fps: 10,
          strokes: const [],
          markers: [later, beta, alpha],
        );

        expect(index.sortedMarkers, [beta, alpha, later]);
        expect(index.markersAtFrame(100), [beta, alpha]);
        expect(index.markerAtFrame(100), beta);
        expect(index.markersByFrameTimeMs[100], [beta, alpha]);
        expect(index.markersAtFrame(250), [later]);
        expect(index.markerAtFrame(250), later);
        expect(index.markersAtFrame(500), isEmpty);
        expect(index.markerAtFrame(500), isNull);
      },
    );

    test('navigates to adjacent markers and wraps around', () {
      final first = _marker('a', timeMs: 0, label: 'First');
      final middle = _marker('b', timeMs: 210, label: 'Middle');
      final last = _marker('c', timeMs: 405, label: 'Last');
      final index = AnnotationTimelineIndex.build(
        fps: 10,
        strokes: const [],
        markers: [middle, last, first],
      );

      expect(index.adjacentMarker(forward: true, positionMs: 0), middle);
      expect(index.adjacentMarker(forward: true, positionMs: 250), last);
      expect(index.adjacentMarker(forward: true, positionMs: 500), first);
      expect(index.adjacentMarker(forward: false, positionMs: 0), last);
      expect(index.adjacentMarker(forward: false, positionMs: 400), middle);
      expect(index.adjacentMarker(forward: false, positionMs: 50), first);
    });
  });
}

Stroke _stroke(
  String id, {
  required int startTimeMs,
  int? endTimeMs,
  StrokeTimingMode timingMode = StrokeTimingMode.keyframe,
}) {
  return Stroke(
    id: id,
    tool: DrawingTool.pen,
    color: Colors.cyan,
    strokeWidth: 2,
    points: const [StrokePoint(x: 0.1, y: 0.1), StrokePoint(x: 0.2, y: 0.2)],
    startTimeMs: startTimeMs,
    endTimeMs: endTimeMs ?? startTimeMs + 100,
    timingMode: timingMode,
  );
}

FrameMarker _marker(String id, {required int timeMs, required String label}) {
  return FrameMarker(id: id, timeMs: timeMs, label: label, color: Colors.amber);
}
