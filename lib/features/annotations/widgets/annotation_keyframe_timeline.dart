import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/timecode_formatter.dart';
import '../../player/providers/player_provider.dart';
import '../providers/annotation_keyframe_timeline_provider.dart';
import '../providers/annotation_provider.dart';

/// Separate timeline for annotation keyframes.
class AnnotationKeyframeTimeline extends ConsumerWidget {
  const AnnotationKeyframeTimeline({super.key});

  int _frameFromMs(int milliseconds, double fps) {
    if (fps <= 0) return 0;
    return ((milliseconds / 1000.0) * fps).round();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(playerProvider);
    final timelineState = ref.watch(annotationKeyframeTimelineProvider);
    final timelineNotifier = ref.read(annotationKeyframeTimelineProvider.notifier);
    final keyframeTimesMs = ref.watch(annotationKeyframeTimesProvider);
    final activeKeyframeMs = ref.watch(activeAnnotationKeyframeProvider);

    final hasVideo = playerState.player != null;
    final duration = playerState.duration;
    final displayPosition =
        timelineState.isScrubbing && timelineState.scrubbingPosition != null
            ? timelineState.scrubbingPosition!
            : playerState.position;

    double sliderValue = 0.0;
    if (hasVideo && duration.inMicroseconds > 0) {
      sliderValue = (displayPosition.inMicroseconds / duration.inMicroseconds)
          .clamp(0.0, 1.0);
    }

    final fps = playerState.metadata?.fps ?? 30.0;
    final activeFrame = activeKeyframeMs != null
        ? _frameFromMs(activeKeyframeMs, fps)
        : null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.grey[850],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Annotation Keyframes',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Count: ${keyframeTimesMs.length}',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                ),
              ),
              const Spacer(),
              if (activeKeyframeMs != null)
                Text(
                  'Active Frame $activeFrame (${TimecodeFormatter.format(Duration(milliseconds: activeKeyframeMs))})',
                  style: const TextStyle(
                    color: Colors.lightBlueAccent,
                    fontSize: 12,
                    fontFamily: 'monospace',
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          LayoutBuilder(
            builder: (context, constraints) {
              final trackWidth = constraints.maxWidth;

              return SizedBox(
                height: 30,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SliderTheme(
                      data: SliderThemeData(
                        trackHeight: 3,
                        thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 7,
                        ),
                        overlayShape: const RoundSliderOverlayShape(
                          overlayRadius: 14,
                        ),
                        activeTrackColor: Colors.lightBlueAccent,
                        inactiveTrackColor: Colors.grey[700],
                        thumbColor: Colors.blue[200],
                        overlayColor: Colors.lightBlueAccent.withValues(alpha: 0.3),
                      ),
                      child: Slider(
                        value: sliderValue,
                        min: 0.0,
                        max: 1.0,
                        onChangeStart: hasVideo
                            ? (_) => timelineNotifier.startScrubbing()
                            : null,
                        onChanged: hasVideo
                            ? (value) {
                                final position = Duration(
                                  microseconds:
                                      (value * duration.inMicroseconds).round(),
                                );
                                timelineNotifier.updateScrubbingPosition(position);
                              }
                            : null,
                        onChangeEnd: hasVideo
                            ? (_) => timelineNotifier.endScrubbing()
                            : null,
                      ),
                    ),
                    ...keyframeTimesMs.map((keyframeMs) {
                      final normalized = duration.inMilliseconds > 0
                          ? (keyframeMs / duration.inMilliseconds).clamp(0.0, 1.0)
                          : 0.0;
                      final isActive = keyframeMs == activeKeyframeMs;
                      return _KeyframeMarker(
                        normalizedPosition: normalized,
                        trackWidth: trackWidth,
                        isActive: isActive,
                        onTap: hasVideo
                            ? () => timelineNotifier.seekToKeyframeMs(
                                  keyframeMs,
                                  fps,
                                )
                            : null,
                      );
                    }),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _KeyframeMarker extends StatelessWidget {
  final double normalizedPosition;
  final double trackWidth;
  final bool isActive;
  final VoidCallback? onTap;

  const _KeyframeMarker({
    required this.normalizedPosition,
    required this.trackWidth,
    required this.isActive,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const horizontalPadding = 12.0;
    final effectiveWidth = trackWidth - (horizontalPadding * 2);
    final xPosition = horizontalPadding + (normalizedPosition * effectiveWidth);

    return Positioned(
      left: xPosition - 6,
      top: 9,
      child: GestureDetector(
        onTap: onTap,
        child: MouseRegion(
          cursor: onTap != null
              ? SystemMouseCursors.click
              : SystemMouseCursors.basic,
          child: Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive ? Colors.orangeAccent : Colors.lightBlueAccent,
              border: Border.all(
                color: Colors.black87,
                width: 1.5,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
