import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/timeline_provider.dart';
import '../../player/providers/player_provider.dart';

/// Timeline scrubber widget for seeking
class TimelineScrubber extends ConsumerWidget {
  const TimelineScrubber({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(playerProvider);
    final timelineState = ref.watch(timelineProvider);
    final timelineNotifier = ref.read(timelineProvider.notifier);

    final hasVideo = playerState.player != null;
    final duration = playerState.duration;
    final position = timelineState.isScrubbing && timelineState.scrubbingPosition != null
        ? timelineState.scrubbingPosition!
        : playerState.position;

    // Calculate slider value (0.0 to 1.0)
    double sliderValue = 0.0;
    if (hasVideo && duration.inMicroseconds > 0) {
      sliderValue = position.inMicroseconds / duration.inMicroseconds;
      sliderValue = sliderValue.clamp(0.0, 1.0);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.grey[900],
      child: Row(
        children: [
          Expanded(
            child: SliderTheme(
              data: SliderThemeData(
                trackHeight: 4,
                thumbShape: const RoundSliderThumbShape(
                  enabledThumbRadius: 8,
                ),
                overlayShape: const RoundSliderOverlayShape(
                  overlayRadius: 16,
                ),
                activeTrackColor: Colors.red[400],
                inactiveTrackColor: Colors.grey[700],
                thumbColor: Colors.red[300],
                overlayColor: Colors.red.withOpacity(0.3),
              ),
              child: Slider(
                value: sliderValue,
                min: 0.0,
                max: 1.0,
                onChangeStart: hasVideo
                    ? (value) {
                        timelineNotifier.startScrubbing();
                      }
                    : null,
                onChanged: hasVideo
                    ? (value) {
                        final newPosition = Duration(
                          microseconds:
                              (value * duration.inMicroseconds).round(),
                        );
                        timelineNotifier.updateScrubbingPosition(newPosition);
                      }
                    : null,
                onChangeEnd: hasVideo
                    ? (value) {
                        timelineNotifier.endScrubbing();
                      }
                    : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
