import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:framesketch_player/features/annotations/models/stroke.dart';
import 'package:framesketch_player/features/annotations/models/stroke_simplifier.dart';

void main() {
  group('StrokeSimplifier', () {
    test('reduces redundant points on a nearly straight pen stroke', () {
      final stroke = _penStroke([
        for (var i = 0; i < 40; i += 1)
          StrokePoint(
            x: i / 100.0,
            y: (i / 100.0) + (i.isEven ? 0.0002 : -0.0002),
            timestampMs: i,
          ),
      ]);

      final simplified = StrokeSimplifier.simplifyPenStroke(stroke);

      expect(simplified.points.length, lessThan(stroke.points.length));
      expect(simplified.points.first, stroke.points.first);
      expect(simplified.points.last, stroke.points.last);
    });

    test('preserves points needed to represent visible shape changes', () {
      final stroke = _penStroke([
        const StrokePoint(x: 0.0, y: 0.0, timestampMs: 0),
        const StrokePoint(x: 0.05, y: 0.0, timestampMs: 1),
        const StrokePoint(x: 0.10, y: 0.0, timestampMs: 2),
        const StrokePoint(x: 0.15, y: 0.0, timestampMs: 3),
        const StrokePoint(x: 0.20, y: 0.0, timestampMs: 4),
        const StrokePoint(x: 0.25, y: 0.0, timestampMs: 5),
        const StrokePoint(x: 0.30, y: 0.0, timestampMs: 6),
        const StrokePoint(x: 0.35, y: 0.0, timestampMs: 7),
        const StrokePoint(x: 0.40, y: 0.0, timestampMs: 8),
        const StrokePoint(x: 0.45, y: 0.0, timestampMs: 9),
        const StrokePoint(x: 0.50, y: 0.20, timestampMs: 10),
        const StrokePoint(x: 0.55, y: 0.0, timestampMs: 11),
        const StrokePoint(x: 0.60, y: 0.0, timestampMs: 12),
        const StrokePoint(x: 0.65, y: 0.0, timestampMs: 13),
        const StrokePoint(x: 0.70, y: 0.0, timestampMs: 14),
        const StrokePoint(x: 0.75, y: 0.0, timestampMs: 15),
        const StrokePoint(x: 0.80, y: 0.0, timestampMs: 16),
      ]);

      final simplified = StrokeSimplifier.simplifyPenStroke(stroke);

      expect(
        simplified.points.any(
          (point) => (point.x - 0.50).abs() < 0.001 && point.y > 0.19,
        ),
        isTrue,
      );
    });

    test('does not simplify non-pen strokes or short strokes', () {
      final shortPen = _penStroke(const [
        StrokePoint(x: 0.0, y: 0.0),
        StrokePoint(x: 0.1, y: 0.1),
      ]);
      final line = shortPen.copyWith(tool: DrawingTool.line);

      expect(StrokeSimplifier.simplifyPenStroke(shortPen), same(shortPen));
      expect(StrokeSimplifier.simplifyPenStroke(line), same(line));
    });
  });
}

Stroke _penStroke(List<StrokePoint> points) {
  return Stroke(
    id: 'stroke',
    tool: DrawingTool.pen,
    color: Colors.cyan,
    strokeWidth: 2,
    points: points,
    startTimeMs: 0,
    endTimeMs: 100,
  );
}
