import 'package:flutter_test/flutter_test.dart';
import 'package:framesketch_player/core/services/annotation_overlay_renderer_service.dart';
import 'package:framesketch_player/features/annotations/models/stroke.dart';

void main() {
  group('AnnotationOverlayRendererService overlay transform', () {
    final service = AnnotationOverlayRendererService();

    test('maps points linearly when viewport and video share aspect ratio', () {
      final transform = service.createOverlayTransform(
        outputWidth: 1920,
        outputHeight: 1080,
        viewportWidth: 960,
        viewportHeight: 540,
      );

      final mapped = transform.toOutputOffset(
        const StrokePoint(x: 0.25, y: 0.75),
      );

      expect(mapped.dx, closeTo(480.0, 0.001));
      expect(mapped.dy, closeTo(810.0, 0.001));
      expect(transform.styleScaleFactor, closeTo(1.0, 0.001));
    });

    test('ignores viewport letterbox and keeps direct normalized mapping', () {
      final transform = service.createOverlayTransform(
        outputWidth: 1440,
        outputHeight: 1080,
        viewportWidth: 1920,
        viewportHeight: 1080,
      );

      final leftEdge = transform.toOutputOffset(
        const StrokePoint(x: 0.125, y: 0.5),
      );
      final center = transform.toOutputOffset(
        const StrokePoint(x: 0.5, y: 0.5),
      );
      final rightEdge = transform.toOutputOffset(
        const StrokePoint(x: 0.875, y: 0.5),
      );
      final leftBar = transform.toOutputOffset(
        const StrokePoint(x: 0.05, y: 0.5),
      );

      expect(leftEdge.dx, closeTo(180.0, 0.001));
      expect(center.dx, closeTo(720.0, 0.001));
      expect(rightEdge.dx, closeTo(1260.0, 0.001));
      expect(leftBar.dx, closeTo(72.0, 0.001));
      expect(transform.styleScaleFactor, closeTo(1.0, 0.001));
    });

    test('maps cropped source coordinates into cropped overlay output', () {
      final transform = service.createOverlayTransform(
        outputWidth: 960,
        outputHeight: 540,
        viewportWidth: 1920,
        viewportHeight: 1080,
        sourceCropLeft: 0.25,
        sourceCropTop: 0.25,
        sourceCropWidth: 0.5,
        sourceCropHeight: 0.5,
      );

      final topLeft = transform.toOutputOffset(
        const StrokePoint(x: 0.25, y: 0.25),
      );
      final center = transform.toOutputOffset(
        const StrokePoint(x: 0.5, y: 0.5),
      );
      final bottomRight = transform.toOutputOffset(
        const StrokePoint(x: 0.75, y: 0.75),
      );

      expect(topLeft.dx, closeTo(0.0, 0.001));
      expect(topLeft.dy, closeTo(0.0, 0.001));
      expect(center.dx, closeTo(480.0, 0.001));
      expect(center.dy, closeTo(270.0, 0.001));
      expect(bottomRight.dx, closeTo(960.0, 0.001));
      expect(bottomRight.dy, closeTo(540.0, 0.001));
    });
  });
}
