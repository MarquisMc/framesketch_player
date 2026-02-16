import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:framesketch_player/core/utils/coordinate_transformer.dart';
import 'package:framesketch_player/features/annotations/models/stroke.dart';

void main() {
  group('CoordinateTransformer', () {
    test('maps video-normalized points through fitted video rect', () {
      final transformer = CoordinateTransformer(
        const Size(1920, 1200),
        videoSize: const Size(1920, 1080),
      );

      final topLeft = transformer.toViewport(const StrokePoint(x: 0, y: 0));
      final center = transformer.toViewport(const StrokePoint(x: 0.5, y: 0.5));
      final roundTrip = transformer.toNormalized(center);

      expect(topLeft.dx, closeTo(0, 0.001));
      expect(topLeft.dy, closeTo(60, 0.001));
      expect(center.dx, closeTo(960, 0.001));
      expect(center.dy, closeTo(600, 0.001));
      expect(roundTrip.x, closeTo(0.5, 0.001));
      expect(roundTrip.y, closeTo(0.5, 0.001));
    });

    test('converts legacy viewport-normalized points to video-normalized', () {
      const legacyPoint = StrokePoint(
        // x = 480 / 1920
        x: 0.25,
        // y = 276 / 1200, where 276 = 60(top bar) + 216(video y)
        y: 0.23,
      );

      final converted =
          CoordinateTransformer.legacyViewportNormalizedToVideoNormalized(
            point: legacyPoint,
            legacyViewportWidth: 1920,
            legacyViewportHeight: 1200,
            videoWidth: 1920,
            videoHeight: 1080,
          );

      expect(converted.x, closeTo(0.25, 0.001));
      expect(converted.y, closeTo(0.2, 0.001));
    });
  });
}
