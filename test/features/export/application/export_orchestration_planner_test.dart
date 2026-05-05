import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:framesketch_player/core/models/annotation_data.dart';
import 'package:framesketch_player/features/annotations/models/stroke.dart';
import 'package:framesketch_player/features/export/application/export_orchestration_planner.dart';
import 'package:path/path.dart' as path;

void main() {
  group('ExportOrchestrationPlanner', () {
    const planner = ExportOrchestrationPlanner();

    test(
      'builds frame jobs and routes annotated ranges to annotated export',
      () {
        final beforeRange = _stroke('before', startTimeMs: 500);
        final inRange = _stroke('in-range', startTimeMs: 2000);
        final afterRange = _stroke('after', startTimeMs: 5000);

        final plan = planner.planFrameRange(
          startFrame: 10,
          endFrame: 30,
          step: 10,
          fps: 10,
          outputDirectoryPath: path.join('tmp', 'frames'),
          suggestedBaseName: 'clip',
          frameExtension: 'png',
          annotationData: _annotationData([beforeRange, inRange, afterRange]),
        );

        expect(plan.route, FrameRangeExportRoute.annotated);
        expect(plan.hasVisibleAnnotations, isTrue);
        expect(plan.selectExpression, r'between(n\,10\,30)*not(mod(n-10\,10))');
        expect(plan.jobs.map((job) => job.frameNumber), [10, 20, 30]);
        expect(plan.jobs.map((job) => job.timestamp), const [
          Duration(milliseconds: 1000),
          Duration(milliseconds: 2000),
          Duration(milliseconds: 3000),
        ]);
        expect(plan.jobs[0].activeKeyframeMs, 500);
        expect(plan.jobs[0].visibleStrokes, [beforeRange]);
        expect(plan.jobs[1].activeKeyframeMs, 2000);
        expect(plan.jobs[1].visibleStrokes, [inRange]);
        expect(plan.jobs[2].activeKeyframeMs, 2000);
        expect(plan.jobs[2].visibleStrokes, [inRange]);
        expect(
          plan.jobs[1].outputPath,
          path.join('tmp', 'frames', 'clip_frame_000020.png'),
        );
      },
    );

    test('routes ranges without visible annotations to unannotated export', () {
      final futureStroke = _stroke('future', startTimeMs: 5000);

      final plan = planner.planFrameRange(
        startFrame: 10,
        endFrame: 30,
        step: 10,
        fps: 10,
        outputDirectoryPath: path.join('tmp', 'frames'),
        suggestedBaseName: 'clip',
        frameExtension: 'jpg',
        annotationData: _annotationData([futureStroke]),
      );

      expect(plan.route, FrameRangeExportRoute.unannotated);
      expect(plan.hasVisibleAnnotations, isFalse);
      expect(plan.jobs, hasLength(3));
      expect(plan.jobs.every((job) => job.visibleStrokes.isEmpty), isTrue);
    });

    test('routes missing annotation data to unannotated export', () {
      final plan = planner.planFrameRange(
        startFrame: 42,
        endFrame: 42,
        step: 1,
        fps: 24,
        outputDirectoryPath: path.join('tmp', 'frames'),
        suggestedBaseName: 'clip',
        frameExtension: 'png',
      );

      expect(plan.route, FrameRangeExportRoute.unannotated);
      expect(plan.selectExpression, r'eq(n\,42)');
      expect(plan.jobs.single.visibleStrokes, isEmpty);
    });
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
