import 'package:flutter_test/flutter_test.dart';
import 'package:framesketch_player/features/player/widgets/source_open_actions.dart';

void main() {
  group('isSupportedVideoPath', () {
    test('accepts common local video extensions case-insensitively', () {
      expect(isSupportedVideoPath(r'C:\media\demo.MP4'), isTrue);
      expect(isSupportedVideoPath('/media/session.mkv'), isTrue);
      expect(isSupportedVideoPath('/media/capture.m2ts'), isTrue);
    });

    test('does not accept unrelated dropped files', () {
      expect(isSupportedVideoPath('/media/notes.json'), isFalse);
      expect(isSupportedVideoPath('/media/still.png'), isFalse);
      expect(isSupportedVideoPath('/media/video.mp4.txt'), isFalse);
    });
  });
}
