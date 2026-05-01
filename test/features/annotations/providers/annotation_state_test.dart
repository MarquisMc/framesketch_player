import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
}
