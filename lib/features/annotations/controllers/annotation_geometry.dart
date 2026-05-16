import 'package:flutter/material.dart';

import '../models/stroke.dart';
import '../widgets/annotation_hit_testing.dart';

typedef TextBoundsResolver = Rect Function(Stroke stroke);
typedef TextBoundsUpdater = Stroke Function(Stroke stroke, Rect rect);

StrokePoint squareConstrainedPoint(StrokePoint start, StrokePoint point) {
  final dx = point.x - start.x;
  final dy = point.y - start.y;
  final side = dx.abs() < dy.abs() ? dx.abs() : dy.abs();
  final signedDx = dx < 0 ? -side : side;
  final signedDy = dy < 0 ? -side : side;
  return StrokePoint(
    x: start.x + signedDx,
    y: start.y + signedDy,
    timestampMs: point.timestampMs,
  );
}

Rect? resizeRectFromHandle(
  Rect rect,
  ResizeHandle handle,
  StrokePoint currentPoint, {
  double minWidth = 0.005,
  double minHeight = 0.005,
}) {
  var left = rect.left;
  var right = rect.right;
  var top = rect.top;
  var bottom = rect.bottom;

  final adjustLeft =
      handle == ResizeHandle.left ||
      handle == ResizeHandle.topLeft ||
      handle == ResizeHandle.bottomLeft;
  final adjustRight =
      handle == ResizeHandle.right ||
      handle == ResizeHandle.topRight ||
      handle == ResizeHandle.bottomRight;
  final adjustTop =
      handle == ResizeHandle.top ||
      handle == ResizeHandle.topLeft ||
      handle == ResizeHandle.topRight;
  final adjustBottom =
      handle == ResizeHandle.bottom ||
      handle == ResizeHandle.bottomLeft ||
      handle == ResizeHandle.bottomRight;

  if (adjustLeft) {
    left = currentPoint.x.clamp(0.0, right - minWidth).toDouble();
  }
  if (adjustRight) {
    right = currentPoint.x.clamp(left + minWidth, 1.0).toDouble();
  }
  if (adjustTop) {
    top = currentPoint.y.clamp(0.0, bottom - minHeight).toDouble();
  }
  if (adjustBottom) {
    bottom = currentPoint.y.clamp(top + minHeight, 1.0).toDouble();
  }

  if (right - left < minWidth) {
    return null;
  }
  if (bottom - top < minHeight) {
    return null;
  }

  return Rect.fromLTRB(left, top, right, bottom);
}

Stroke resizeStrokeToBounds(
  Stroke stroke, {
  required Rect originalBounds,
  required Rect newBounds,
  required TextBoundsUpdater updateTextBounds,
}) {
  if (stroke.tool == DrawingTool.text) {
    return updateTextBounds(stroke, newBounds);
  }

  const epsilon = 0.000001;
  final originalWidth = originalBounds.width.abs();
  final originalHeight = originalBounds.height.abs();
  final centerX = originalBounds.center.dx;
  final centerY = originalBounds.center.dy;
  final pointCount = stroke.points.length;

  final resizedPoints = <StrokePoint>[];
  for (var i = 0; i < pointCount; i++) {
    final point = stroke.points[i];

    final relativeX = originalWidth < epsilon
        ? pointCount <= 1
              ? 0.5
              : i / (pointCount - 1)
        : (point.x - originalBounds.left) / originalWidth;
    final relativeY = originalHeight < epsilon
        ? pointCount <= 1
              ? 0.5
              : i / (pointCount - 1)
        : (point.y - originalBounds.top) / originalHeight;

    final fallbackX = point.x <= centerX ? 0.0 : 1.0;
    final fallbackY = point.y <= centerY ? 0.0 : 1.0;
    final normalizedX = (originalWidth < epsilon ? fallbackX : relativeX).clamp(
      0.0,
      1.0,
    );
    final normalizedY = (originalHeight < epsilon ? fallbackY : relativeY)
        .clamp(0.0, 1.0);

    resizedPoints.add(
      StrokePoint(
        x: newBounds.left + (newBounds.width * normalizedX),
        y: newBounds.top + (newBounds.height * normalizedY),
        timestampMs: point.timestampMs,
      ),
    );
  }

  return stroke.copyWith(points: resizedPoints, scale: 1.0);
}

bool pointIntersectsEraser(
  StrokePoint point,
  StrokePoint eraserPoint,
  double radius,
) {
  final dx = point.x - eraserPoint.x;
  final dy = point.y - eraserPoint.y;
  final distanceSquared = dx * dx + dy * dy;
  return distanceSquared <= radius * radius;
}

Stroke? findStrokeAtPoint(
  List<Stroke> visibleStrokes,
  StrokePoint point, {
  required TextBoundsResolver textBoundsForStroke,
  double selectionRadius = 0.02,
}) {
  for (int i = visibleStrokes.length - 1; i >= 0; i--) {
    final stroke = visibleStrokes[i];

    if (stroke.tool == DrawingTool.rectangle ||
        stroke.tool == DrawingTool.filledSquare) {
      if (isPointNearRectangle(stroke, point, selectionRadius)) {
        return stroke;
      }
    } else if (stroke.tool == DrawingTool.circle ||
        stroke.tool == DrawingTool.filledCircle) {
      if (isPointNearCircle(stroke, point, selectionRadius)) {
        return stroke;
      }
    } else if (stroke.tool == DrawingTool.line ||
        stroke.tool == DrawingTool.arrow) {
      if (isPointNearLine(stroke, point, selectionRadius)) {
        return stroke;
      }
    } else if (stroke.tool == DrawingTool.text) {
      if (isPointNearText(
        stroke,
        point,
        selectionRadius,
        textBoundsForStroke: textBoundsForStroke,
      )) {
        return stroke;
      }
    } else {
      for (final strokePoint in stroke.points) {
        if (pointIntersectsEraser(strokePoint, point, selectionRadius)) {
          return stroke;
        }
      }
    }
  }
  return null;
}

bool isPointNearRectangle(Stroke stroke, StrokePoint point, double threshold) {
  if (stroke.points.length < 2) return false;

  final p1 = stroke.points.first;
  final p2 = stroke.points.last;

  final left = p1.x < p2.x ? p1.x : p2.x;
  final right = p1.x > p2.x ? p1.x : p2.x;
  final top = p1.y < p2.y ? p1.y : p2.y;
  final bottom = p1.y > p2.y ? p1.y : p2.y;

  return point.x >= left - threshold &&
      point.x <= right + threshold &&
      point.y >= top - threshold &&
      point.y <= bottom + threshold;
}

bool isPointNearCircle(Stroke stroke, StrokePoint point, double threshold) {
  if (stroke.points.length < 2) return false;

  final p1 = stroke.points.first;
  final p2 = stroke.points.last;

  final centerX = (p1.x + p2.x) / 2;
  final centerY = (p1.y + p2.y) / 2;
  final radiusX = (p2.x - p1.x).abs() / 2;
  final radiusY = (p2.y - p1.y).abs() / 2;

  final dx = point.x - centerX;
  final dy = point.y - centerY;

  if (radiusX == 0 || radiusY == 0) return false;

  final distance =
      (dx * dx) / (radiusX * radiusX) + (dy * dy) / (radiusY * radiusY);
  return distance <= 1.2;
}

bool isPointNearLine(Stroke stroke, StrokePoint point, double threshold) {
  if (stroke.points.length < 2) return false;

  final p1 = stroke.points.first;
  final p2 = stroke.points.last;

  final lineLength =
      ((p2.x - p1.x) * (p2.x - p1.x) + (p2.y - p1.y) * (p2.y - p1.y));

  if (lineLength == 0) {
    return pointIntersectsEraser(p1, point, threshold);
  }

  final t =
      ((point.x - p1.x) * (p2.x - p1.x) + (point.y - p1.y) * (p2.y - p1.y)) /
      lineLength;
  final tClamped = t.clamp(0.0, 1.0);

  final projX = p1.x + tClamped * (p2.x - p1.x);
  final projY = p1.y + tClamped * (p2.y - p1.y);

  final dx = point.x - projX;
  final dy = point.y - projY;
  final distance = (dx * dx + dy * dy);

  return distance <= threshold * threshold;
}

bool isPointNearText(
  Stroke stroke,
  StrokePoint point,
  double threshold, {
  required TextBoundsResolver textBoundsForStroke,
}) {
  if (stroke.points.isEmpty || stroke.text == null || stroke.text!.isEmpty) {
    return false;
  }

  final bounds = textBoundsForStroke(stroke);

  return point.x >= bounds.left - threshold &&
      point.x <= bounds.right + threshold &&
      point.y >= bounds.top - threshold &&
      point.y <= bounds.bottom + threshold;
}

Offset clampedDragDeltaForSelectedStrokes(
  Iterable<Stroke> strokes,
  Set<String> selectedSet,
  double requestedDx,
  double requestedDy, {
  required TextBoundsResolver textBoundsForStroke,
}) {
  final selectedBounds = selectedStrokeBounds(
    strokes,
    selectedSet,
    textBoundsForStroke: textBoundsForStroke,
  );
  if (selectedBounds == null) {
    return Offset(requestedDx, requestedDy);
  }

  final minDx = -selectedBounds.left;
  final maxDx = 1.0 - selectedBounds.right;
  final minDy = -selectedBounds.top;
  final maxDy = 1.0 - selectedBounds.bottom;

  return Offset(
    clampDragAxis(requestedDx, minDx, maxDx),
    clampDragAxis(requestedDy, minDy, maxDy),
  );
}

double clampDragAxis(double requestedDelta, double minDelta, double maxDelta) {
  if (minDelta > maxDelta) {
    return 0.0;
  }
  return requestedDelta.clamp(minDelta, maxDelta).toDouble();
}

Rect? selectedStrokeBounds(
  Iterable<Stroke> strokes,
  Set<String> selectedSet, {
  required TextBoundsResolver textBoundsForStroke,
}) {
  Rect? selectedBounds;
  for (final stroke in strokes) {
    if (!selectedSet.contains(stroke.id)) continue;

    final bounds = strokeBounds(
      stroke,
      textBoundsForStroke: textBoundsForStroke,
    );
    if (bounds == null) continue;

    selectedBounds = selectedBounds == null
        ? bounds
        : selectedBounds.expandToInclude(bounds);
  }

  return selectedBounds;
}

Rect? strokeBounds(
  Stroke stroke, {
  required TextBoundsResolver textBoundsForStroke,
}) {
  if (stroke.points.isEmpty) return null;

  if (stroke.tool == DrawingTool.text) {
    return textBoundsForStroke(stroke);
  }

  double minX = double.infinity;
  double minY = double.infinity;
  double maxX = double.negativeInfinity;
  double maxY = double.negativeInfinity;

  for (final point in stroke.points) {
    if (point.x < minX) minX = point.x;
    if (point.y < minY) minY = point.y;
    if (point.x > maxX) maxX = point.x;
    if (point.y > maxY) maxY = point.y;
  }

  return Rect.fromLTRB(minX, minY, maxX, maxY);
}
