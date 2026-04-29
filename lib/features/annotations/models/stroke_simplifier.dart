import 'stroke.dart';

class StrokeSimplifier {
  static const int minPointCount = 16;
  static const double defaultTolerance = 0.0015;

  const StrokeSimplifier._();

  static Stroke simplifyPenStroke(
    Stroke stroke, {
    double tolerance = defaultTolerance,
  }) {
    if (stroke.tool != DrawingTool.pen ||
        stroke.points.length < minPointCount ||
        tolerance <= 0) {
      return stroke;
    }

    final simplifiedPoints = simplifyPoints(stroke.points, tolerance);
    if (simplifiedPoints.length == stroke.points.length) {
      return stroke;
    }

    return stroke.copyWith(points: simplifiedPoints);
  }

  static List<StrokePoint> simplifyPoints(
    List<StrokePoint> points,
    double tolerance,
  ) {
    if (points.length < minPointCount || tolerance <= 0) {
      return points;
    }

    final keep = List<bool>.filled(points.length, false);
    keep[0] = true;
    keep[points.length - 1] = true;

    final toleranceSquared = tolerance * tolerance;
    _simplifySection(
      points: points,
      firstIndex: 0,
      lastIndex: points.length - 1,
      toleranceSquared: toleranceSquared,
      keep: keep,
    );

    final simplified = <StrokePoint>[];
    for (var i = 0; i < points.length; i += 1) {
      if (keep[i]) {
        simplified.add(points[i]);
      }
    }

    return simplified.length >= 2 ? simplified : points;
  }

  static void _simplifySection({
    required List<StrokePoint> points,
    required int firstIndex,
    required int lastIndex,
    required double toleranceSquared,
    required List<bool> keep,
  }) {
    final ranges = <(int, int)>[(firstIndex, lastIndex)];

    while (ranges.isNotEmpty) {
      final (currentFirstIndex, currentLastIndex) = ranges.removeLast();
      if (currentLastIndex <= currentFirstIndex + 1) {
        continue;
      }

      var maxDistanceSquared = -1.0;
      var maxIndex = currentFirstIndex;

      for (var i = currentFirstIndex + 1; i < currentLastIndex; i += 1) {
        final distanceSquared = _perpendicularDistanceSquared(
          points[i],
          points[currentFirstIndex],
          points[currentLastIndex],
        );
        if (distanceSquared > maxDistanceSquared) {
          maxDistanceSquared = distanceSquared;
          maxIndex = i;
        }
      }

      if (maxDistanceSquared <= toleranceSquared) {
        continue;
      }

      keep[maxIndex] = true;
      ranges.add((currentFirstIndex, maxIndex));
      ranges.add((maxIndex, currentLastIndex));
    }
  }

  static double _perpendicularDistanceSquared(
    StrokePoint point,
    StrokePoint lineStart,
    StrokePoint lineEnd,
  ) {
    final dx = lineEnd.x - lineStart.x;
    final dy = lineEnd.y - lineStart.y;

    if (dx == 0 && dy == 0) {
      return _distanceSquared(point, lineStart);
    }

    final t =
        ((point.x - lineStart.x) * dx + (point.y - lineStart.y) * dy) /
        (dx * dx + dy * dy);
    final clampedT = t.clamp(0.0, 1.0);
    final projX = lineStart.x + clampedT * dx;
    final projY = lineStart.y + clampedT * dy;
    final diffX = point.x - projX;
    final diffY = point.y - projY;
    return diffX * diffX + diffY * diffY;
  }

  static double _distanceSquared(StrokePoint a, StrokePoint b) {
    final dx = a.x - b.x;
    final dy = a.y - b.y;
    return dx * dx + dy * dy;
  }
}
