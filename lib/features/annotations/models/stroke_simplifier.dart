import 'dart:math' as math;

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

    if (_shouldKeepOriginalPenStroke(
      originalPoints: stroke.points,
      simplifiedPoints: simplifiedPoints,
      tolerance: tolerance,
    )) {
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

  static bool _shouldKeepOriginalPenStroke({
    required List<StrokePoint> originalPoints,
    required List<StrokePoint> simplifiedPoints,
    required double tolerance,
  }) {
    if (originalPoints.length <= 2) {
      return false;
    }

    if (_hasSelfIntersection(originalPoints)) {
      return true;
    }

    if (_isCompactStroke(originalPoints, tolerance)) {
      return true;
    }

    if (simplifiedPoints.length > 2) {
      return false;
    }

    var pathLength = 0.0;
    for (var i = 1; i < originalPoints.length; i += 1) {
      pathLength += _distance(originalPoints[i - 1], originalPoints[i]);
    }

    final endpointDistance = _distance(
      simplifiedPoints.first,
      simplifiedPoints.last,
    );
    final detourDistance = pathLength - endpointDistance;

    return detourDistance > math.max(tolerance * 2, endpointDistance * 0.5);
  }

  static bool _isCompactStroke(List<StrokePoint> points, double tolerance) {
    var minX = double.infinity;
    var minY = double.infinity;
    var maxX = double.negativeInfinity;
    var maxY = double.negativeInfinity;

    for (final point in points) {
      if (point.x < minX) minX = point.x;
      if (point.y < minY) minY = point.y;
      if (point.x > maxX) maxX = point.x;
      if (point.y > maxY) maxY = point.y;
    }

    final width = maxX - minX;
    final height = maxY - minY;
    final compactThreshold = tolerance * 4;
    return math.sqrt(width * width + height * height) <= compactThreshold;
  }

  static bool _hasSelfIntersection(List<StrokePoint> points) {
    if (points.length < 4) {
      return false;
    }

    for (var firstStart = 0; firstStart < points.length - 1; firstStart += 1) {
      final firstEnd = firstStart + 1;
      for (
        var secondStart = firstEnd + 1;
        secondStart < points.length - 1;
        secondStart += 1
      ) {
        final secondEnd = secondStart + 1;
        if (firstStart == 0 &&
            secondEnd == points.length - 1 &&
            _distanceSquared(points.first, points.last) <= 1e-12) {
          continue;
        }

        if (_segmentsIntersect(
          points[firstStart],
          points[firstEnd],
          points[secondStart],
          points[secondEnd],
        )) {
          return true;
        }
      }
    }

    return false;
  }

  static bool _segmentsIntersect(
    StrokePoint a,
    StrokePoint b,
    StrokePoint c,
    StrokePoint d,
  ) {
    final orientation1 = _orientation(a, b, c);
    final orientation2 = _orientation(a, b, d);
    final orientation3 = _orientation(c, d, a);
    final orientation4 = _orientation(c, d, b);

    if (orientation1 != orientation2 && orientation3 != orientation4) {
      return true;
    }

    return orientation1 == 0 && _pointOnSegment(a, c, b) ||
        orientation2 == 0 && _pointOnSegment(a, d, b) ||
        orientation3 == 0 && _pointOnSegment(c, a, d) ||
        orientation4 == 0 && _pointOnSegment(c, b, d);
  }

  static int _orientation(StrokePoint a, StrokePoint b, StrokePoint c) {
    const epsilon = 1e-12;
    final value = (b.y - a.y) * (c.x - b.x) - (b.x - a.x) * (c.y - b.y);
    if (value.abs() <= epsilon) {
      return 0;
    }

    return value > 0 ? 1 : 2;
  }

  static bool _pointOnSegment(StrokePoint a, StrokePoint point, StrokePoint b) {
    return point.x >= math.min(a.x, b.x) &&
        point.x <= math.max(a.x, b.x) &&
        point.y >= math.min(a.y, b.y) &&
        point.y <= math.max(a.y, b.y);
  }

  static double _distance(StrokePoint a, StrokePoint b) {
    final dx = a.x - b.x;
    final dy = a.y - b.y;
    return math.sqrt(dx * dx + dy * dy);
  }
}
