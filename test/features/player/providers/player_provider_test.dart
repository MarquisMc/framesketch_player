import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:framesketch_player/core/models/video_metadata.dart';
import 'package:framesketch_player/features/player/providers/player_provider.dart';

class _SeededPlayerNotifier extends PlayerNotifier {
  _SeededPlayerNotifier(super.ref, PlayerState initialState) {
    state = initialState;
  }
}

void main() {
  group('PlayerNotifier playback FPS', () {
    test('recalculates total frames when playback FPS changes or resets', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifierProvider = Provider<PlayerNotifier>((ref) {
        return _SeededPlayerNotifier(
          ref,
          PlayerState(
            metadata: const VideoMetadata(
              filePath: 'clip.mp4',
              duration: Duration(seconds: 10),
              fps: 24,
              width: 1920,
              height: 1080,
              codec: 'h264',
              format: 'mp4',
              frameCount: 240,
            ),
            sourceFps: 24,
          ),
        );
      });
      final notifier = container.read(notifierProvider);
      addTearDown(notifier.dispose);

      notifier.setPlaybackFps(30);

      expect(notifier.state.metadata!.fps, 30);
      expect(notifier.state.metadata!.frameCount, 300);

      notifier.resetPlaybackFps();

      expect(notifier.state.metadata!.fps, 24);
      expect(notifier.state.metadata!.frameCount, 240);
    });

    test('uses clamped FPS to calculate total frames', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifierProvider = Provider<PlayerNotifier>((ref) {
        return _SeededPlayerNotifier(
          ref,
          PlayerState(
            metadata: const VideoMetadata(
              filePath: 'clip.mp4',
              duration: Duration(seconds: 2),
              fps: 30,
              width: 1280,
              height: 720,
              codec: 'h264',
              format: 'mp4',
              frameCount: 60,
            ),
          ),
        );
      });
      final notifier = container.read(notifierProvider);
      addTearDown(notifier.dispose);

      notifier.setPlaybackFps(500);

      expect(notifier.state.metadata!.fps, 240);
      expect(notifier.state.metadata!.frameCount, 480);
    });
  });
}
