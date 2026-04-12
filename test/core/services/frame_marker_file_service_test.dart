import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:framesketch_player/core/models/annotation_data.dart';
import 'package:framesketch_player/core/services/frame_marker_file_service.dart';
import 'package:framesketch_player/features/annotations/models/frame_marker.dart';

void main() {
  group('FrameMarkerFileService', () {
    final service = FrameMarkerFileService();

    test('encodes and decodes marker payloads', () {
      final annotationData = AnnotationData(
        videoId: 'abc123',
        videoPath: r'C:\clips\shot.mov',
        fps: 24,
        createdAt: DateTime.parse('2026-03-21T12:00:00Z'),
        updatedAt: DateTime.parse('2026-03-21T12:05:00Z'),
        markers: const [
          FrameMarker(
            id: 'm1',
            timeMs: 500,
            label: 'Timing issue',
            note: 'Ease-in starts late',
            color: Color(0xFFD8474B),
          ),
        ],
      );

      final encoded = service.encodeMarkerList(annotationData: annotationData);
      final decoded = service.decodeMarkerList(encoded);

      expect(decoded, hasLength(1));
      expect(decoded.first.id, 'm1');
      expect(decoded.first.label, 'Timing issue');
      expect(decoded.first.note, 'Ease-in starts late');
      expect(decoded.first.timeMs, 500);
      expect(decoded.first.color.toARGB32(), const Color(0xFFD8474B).toARGB32());
    });

    test('decodes files that are a plain marker array', () {
      const raw = '''
[
  {
    "id": "m2",
    "timeMs": 750,
    "label": "Crop start",
    "note": "",
    "color": 4294940462
  }
]
''';

      final decoded = service.decodeMarkerList(raw);

      expect(decoded, hasLength(1));
      expect(decoded.first.label, 'Crop start');
      expect(decoded.first.timeMs, 750);
    });
  });
}
