import 'package:path/path.dart' as path;

import '../../../core/models/annotation_data.dart';
import '../../annotations/models/annotation_timeline_index.dart';
import '../../annotations/models/stroke.dart';

enum FrameRangeExportRoute { annotated, unannotated }

class FrameRangeExportJob {
  final int frameNumber;
  final Duration timestamp;
  final String outputPath;
  final int? activeKeyframeMs;
  final List<Stroke> visibleStrokes;

  const FrameRangeExportJob({
    required this.frameNumber,
    required this.timestamp,
    required this.outputPath,
    required this.activeKeyframeMs,
    required this.visibleStrokes,
  });
}

class FrameRangeExportPlan {
  final List<FrameRangeExportJob> jobs;
  final FrameRangeExportRoute route;
  final String selectExpression;

  const FrameRangeExportPlan({
    required this.jobs,
    required this.route,
    required this.selectExpression,
  });

  bool get hasVisibleAnnotations =>
      jobs.any((job) => job.visibleStrokes.isNotEmpty);
}

class ExportOrchestrationPlanner {
  const ExportOrchestrationPlanner();

  FrameRangeExportPlan planFrameRange({
    required int startFrame,
    required int endFrame,
    required int step,
    required double fps,
    required String outputDirectoryPath,
    required String suggestedBaseName,
    required String frameExtension,
    AnnotationData? annotationData,
  }) {
    if (startFrame < 0) {
      throw ArgumentError.value(startFrame, 'startFrame', 'Must be >= 0.');
    }
    if (endFrame < startFrame) {
      throw ArgumentError.value(endFrame, 'endFrame', 'Must be >= startFrame.');
    }
    if (step <= 0) {
      throw ArgumentError.value(step, 'step', 'Must be > 0.');
    }
    if (fps <= 0) {
      throw ArgumentError.value(fps, 'fps', 'Must be > 0.');
    }

    final timelineIndex = annotationData == null
        ? null
        : AnnotationTimelineIndex.build(
            strokes: annotationData.strokes,
            markers: annotationData.markers,
            fps: annotationData.fps,
          );

    final jobs = <FrameRangeExportJob>[];
    for (var frame = startFrame; frame <= endFrame; frame += step) {
      final timestamp = durationForFrame(frame: frame, fps: fps);
      final activeKeyframeMs = timelineIndex?.activeKeyframeTimeMsAt(
        timestamp.inMilliseconds,
      );
      jobs.add(
        FrameRangeExportJob(
          frameNumber: frame,
          timestamp: timestamp,
          outputPath: path.join(
            outputDirectoryPath,
            '${suggestedBaseName}_frame_${frame.toString().padLeft(6, '0')}.$frameExtension',
          ),
          activeKeyframeMs: activeKeyframeMs,
          visibleStrokes: activeKeyframeMs == null
              ? const []
              : timelineIndex!.strokesAtKeyframe(activeKeyframeMs),
        ),
      );
    }

    final route =
        annotationData == null ||
            jobs.every((job) => job.visibleStrokes.isEmpty)
        ? FrameRangeExportRoute.unannotated
        : FrameRangeExportRoute.annotated;

    return FrameRangeExportPlan(
      jobs: List.unmodifiable(jobs),
      route: route,
      selectExpression: buildFrameSelectExpression(jobs),
    );
  }

  Duration durationForFrame({required int frame, required double fps}) {
    final micros = ((frame * 1000000.0) / fps).round();
    return Duration(microseconds: micros);
  }

  String buildFrameSelectExpression(List<FrameRangeExportJob> jobs) {
    if (jobs.isEmpty) {
      throw ArgumentError.value(jobs, 'jobs', 'Must not be empty.');
    }

    if (jobs.length == 1) {
      return 'eq(n\\,${jobs.first.frameNumber})';
    }

    final first = jobs.first.frameNumber;
    final last = jobs.last.frameNumber;
    final step = jobs[1].frameNumber - jobs[0].frameNumber;
    final isArithmetic =
        step > 0 &&
        jobs.indexed.every((entry) {
          final expected = first + entry.$1 * step;
          return entry.$2.frameNumber == expected;
        });

    if (!isArithmetic) {
      return jobs.map((job) => 'eq(n\\,${job.frameNumber})').join('+');
    }

    if (step == 1) {
      return 'between(n\\,$first\\,$last)';
    }

    return 'between(n\\,$first\\,$last)*not(mod(n-$first\\,$step))';
  }
}
