import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:framesketch_player/core/models/annotation_data.dart';
import 'package:framesketch_player/core/services/video_export_service.dart';
import 'package:framesketch_player/features/annotations/models/stroke.dart';

void main() {
  group('VideoExportService overlay planning', () {
    final service = VideoExportService();

    test('preserves active keyframe timing across an export subrange', () {
      final beforeRange = _stroke('before', startTimeMs: 500);
      final insideRange = _stroke('inside', startTimeMs: 2000);
      final outsideRange = _stroke('outside', startTimeMs: 5000);

      final frames = service.planOverlayFrames(
        annotationData: _annotationData([
          beforeRange,
          insideRange,
          outsideRange,
        ]),
        startMs: 1000,
        endMs: 3500,
      );

      expect(frames, hasLength(2));
      expect(frames[0].startMs, 1000);
      expect(frames[0].endMs, 2000);
      expect(frames[0].strokes, [beforeRange]);
      expect(frames[1].startMs, 2000);
      expect(frames[1].endMs, 3500);
      expect(frames[1].strokes, [insideRange]);
    });

    test('adds transparent leading frames before first in-range keyframe', () {
      final keyframe = _stroke('inside', startTimeMs: 2000);

      final frames = service.planOverlayFrames(
        annotationData: _annotationData([keyframe]),
        startMs: 1000,
        endMs: 3000,
      );

      expect(frames, hasLength(2));
      expect(frames[0].startMs, 1000);
      expect(frames[0].endMs, 2000);
      expect(frames[0].strokes, isEmpty);
      expect(frames[1].startMs, 2000);
      expect(frames[1].endMs, 3000);
      expect(frames[1].strokes, [keyframe]);
    });

    test(
      'preserves prior keyframe state and skips keyframes after export range',
      () {
        final before = _stroke('before', startTimeMs: 500);
        final after = _stroke('after', startTimeMs: 5000);

        final frames = service.planOverlayFrames(
          annotationData: _annotationData([before, after]),
          startMs: 1000,
          endMs: 3000,
        );

        expect(frames, hasLength(1));
        expect(frames.first.startMs, 1000);
        expect(frames.first.endMs, 3000);
        expect(frames.first.strokes, [before]);
      },
    );
  });
}

AnnotationData _annotationData(List<Stroke> strokes) {
  final now = DateTime(2026);
  return AnnotationData(
    videoId: 'video',
    videoPath: 'video.mp4',
    fps: 10,
    createdAt: now,
    updatedAt: now,
    strokes: strokes,
  );
}

Stroke _stroke(String id, {required int startTimeMs}) {
  return Stroke(
    id: id,
    tool: DrawingTool.pen,
    color: Colors.cyan,
    strokeWidth: 2,
    points: const [StrokePoint(x: 0.1, y: 0.1), StrokePoint(x: 0.2, y: 0.2)],
    startTimeMs: startTimeMs,
    endTimeMs: startTimeMs + 100,
  );
}
