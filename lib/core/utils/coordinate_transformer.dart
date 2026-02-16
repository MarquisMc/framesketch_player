import 'dart:ui';
import '../../features/annotations/models/stroke.dart';

/// Transforms between normalized video coordinates (0-1) and viewport pixels.
/// The visible video can be letterboxed/pillarboxed inside the viewport.
class CoordinateTransformer {
  final Size viewportSize;
  final Size? videoSize;
  final Rect _videoRectInViewport;

  CoordinateTransformer(this.viewportSize, {this.videoSize})
    : _videoRectInViewport = _computeVideoRectInViewport(
        viewportSize: viewportSize,
        videoSize: videoSize,
      );

  /// Convert normalized video point (0-1) to viewport pixels.
  Offset toViewport(StrokePoint point) {
    final rect = _videoRectInViewport;
    return Offset(
      rect.left + point.x * rect.width,
      rect.top + point.y * rect.height,
    );
  }

  /// Convert viewport pixels to normalized video point (0-1).
  /// Values are intentionally unclamped so points outside the video can be
  /// represented (e.g., if user draws in the letterbox area).
  StrokePoint toNormalized(Offset offset, {int timestampMs = 0}) {
    final rect = _videoRectInViewport;
    return StrokePoint(
      x: rect.width == 0 ? 0 : (offset.dx - rect.left) / rect.width,
      y: rect.height == 0 ? 0 : (offset.dy - rect.top) / rect.height,
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

  Rect get videoRectInViewport => _videoRectInViewport;

  /// Converts a legacy point that was normalized against the full viewport to
  /// video-normalized coordinates.
  static StrokePoint legacyViewportNormalizedToVideoNormalized({
    required StrokePoint point,
    required int legacyViewportWidth,
    required int legacyViewportHeight,
    required int videoWidth,
    required int videoHeight,
  }) {
    if (legacyViewportWidth <= 0 ||
        legacyViewportHeight <= 0 ||
        videoWidth <= 0 ||
        videoHeight <= 0) {
      return point;
    }

    final rect = _computeVideoRectInViewport(
      viewportSize: Size(
        legacyViewportWidth.toDouble(),
        legacyViewportHeight.toDouble(),
      ),
      videoSize: Size(videoWidth.toDouble(), videoHeight.toDouble()),
    );

    final viewportX = point.x * legacyViewportWidth;
    final viewportY = point.y * legacyViewportHeight;

    return StrokePoint(
      x: (viewportX - rect.left) / rect.width,
      y: (viewportY - rect.top) / rect.height,
      timestampMs: point.timestampMs,
    );
  }

  static Rect _computeVideoRectInViewport({
    required Size viewportSize,
    required Size? videoSize,
  }) {
    if (viewportSize.width <= 0 || viewportSize.height <= 0) {
      return Rect.zero;
    }

    if (videoSize == null || videoSize.width <= 0 || videoSize.height <= 0) {
      return Rect.fromLTWH(0, 0, viewportSize.width, viewportSize.height);
    }

    final scale =
        (viewportSize.width / videoSize.width) <
            (viewportSize.height / videoSize.height)
        ? viewportSize.width / videoSize.width
        : viewportSize.height / videoSize.height;

    final fittedWidth = videoSize.width * scale;
    final fittedHeight = videoSize.height * scale;
    final left = (viewportSize.width - fittedWidth) / 2;
    final top = (viewportSize.height - fittedHeight) / 2;

    return Rect.fromLTWH(left, top, fittedWidth, fittedHeight);
  }
}
