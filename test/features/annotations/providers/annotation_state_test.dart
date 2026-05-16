import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:framesketch_player/core/models/annotation_data.dart';
import 'package:framesketch_player/features/annotations/models/stroke.dart';
import 'package:framesketch_player/features/annotations/providers/annotation_provider.dart';

void main() {
  group('AnnotationState.copyWith', () {
    test('preserves current stroke unless explicitly cleared', () {
      final stroke = Stroke(
        id: 'stroke',
        tool: DrawingTool.pen,
        color: Colors.cyan,
        strokeWidth: 2,
        points: const [
          StrokePoint(x: 0.1, y: 0.1),
          StrokePoint(x: 0.2, y: 0.2),
        ],
      );
      final drawingState = const AnnotationState().copyWith(
        currentStroke: stroke,
        isDrawing: true,
      );

      final updatedState = drawingState.copyWith(hasUnsavedChanges: true);
      final clearedState = drawingState.copyWith(clearCurrentStroke: true);

      expect(updatedState.currentStroke, stroke);
      expect(clearedState.currentStroke, isNull);
    });
  });

  group('AnnotationNotifier history', () {
    test('redo restores a moved annotation after undo', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final originalStroke = Stroke(
        id: 'stroke',
        tool: DrawingTool.rectangle,
        color: Colors.cyan,
        strokeWidth: 2,
        points: const [
          StrokePoint(x: 0.1, y: 0.1),
          StrokePoint(x: 0.2, y: 0.2),
        ],
      );
      final annotationData = AnnotationData(
        videoId: 'video',
        videoPath: 'video.mp4',
        fps: 30,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        strokes: [originalStroke],
      );

      final notifier = container.read(annotationProvider.notifier);
      notifier.initializeFromAnnotationData(annotationData);
      notifier.setTool(DrawingTool.select);

      notifier.startStroke(const StrokePoint(x: 0.15, y: 0.15));
      notifier.addPointToStroke(const StrokePoint(x: 0.25, y: 0.25));
      notifier.finishStroke();

      final movedStroke = container.read(annotationProvider).allStrokes.single;
      expect(movedStroke.points.first.x, closeTo(0.2, 0.0001));
      expect(movedStroke.points.first.y, closeTo(0.2, 0.0001));

      await notifier.undo();
      final undoneStroke = container.read(annotationProvider).allStrokes.single;
      expect(undoneStroke.points, originalStroke.points);

      await notifier.redo();
      final redoneStroke = container.read(annotationProvider).allStrokes.single;
      expect(redoneStroke.points, movedStroke.points);
    });
  });
}
