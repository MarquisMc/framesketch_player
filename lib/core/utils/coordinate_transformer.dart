import 'dart:ui';
import '../../features/annotations/models/stroke.dart';

/// Transforms between normalized (0-1) and viewport pixel coordinates
class CoordinateTransformer {
  final Size viewportSize;

  CoordinateTransformer(this.viewportSize);

  /// Convert normalized point (0-1) to viewport pixels
  Offset toViewport(StrokePoint point) {
    return Offset(
      point.x * viewportSize.width,
      point.y * viewportSize.height,
    );
  }

  /// Convert viewport pixels to normalized point (0-1)
  StrokePoint toNormalized(Offset offset, {int timestampMs = 0}) {
    return StrokePoint(
      x: offset.dx / viewportSize.width,
      y: offset.dy / viewportSize.height,
      timestampMs: timestampMs,
    );
  }

  /// Convert list of normalized points to viewport offsets
  List<Offset> strokeToOffsets(Stroke stroke) {
    return stroke.points.map(toViewport).toList();
  }

  /// Check if normalized point is within valid bounds (0-1)
  bool isValidNormalized(StrokePoint point) {
    return point.x >= 0 && point.x <= 1 && point.y >= 0 && point.y <= 1;
  }

  /// Clamp normalized coordinates to valid range
  StrokePoint clampNormalized(StrokePoint point) {
    return StrokePoint(
      x: point.x.clamp(0.0, 1.0),
      y: point.y.clamp(0.0, 1.0),
      timestampMs: point.timestampMs,
    );
  }
}
