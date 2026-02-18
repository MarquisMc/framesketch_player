import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/utils/timecode_formatter.dart';
import '../../player/providers/player_provider.dart';
import '../providers/annotation_keyframe_timeline_provider.dart';
import '../providers/annotation_provider.dart';

/// Separate timeline for annotation keyframes.
class AnnotationKeyframeTimeline extends ConsumerStatefulWidget {
  const AnnotationKeyframeTimeline({super.key});

  @override
  ConsumerState<AnnotationKeyframeTimeline> createState() =>
      _AnnotationKeyframeTimelineState();
}

class _AnnotationKeyframeTimelineState
    extends ConsumerState<AnnotationKeyframeTimeline> {
  int? _draggingKeyframeMs;
  double? _draggingNormalizedPosition;
  bool _dragMoved = false;

  int _frameFromMs(int milliseconds, double fps) {
    if (fps <= 0) return 0;
    return ((milliseconds / 1000.0) * fps).round();
  }

  void _startKeyframeDrag(int keyframeMs, double normalizedPosition) {
    setState(() {
      _draggingKeyframeMs = keyframeMs;
      _draggingNormalizedPosition = normalizedPosition.clamp(0.0, 1.0);
      _dragMoved = false;
    });
  }

  void _updateKeyframeDrag(double deltaDx, double trackWidth) {
    final draggingNormalizedPosition = _draggingNormalizedPosition;
    if (draggingNormalizedPosition == null) return;

    const horizontalPadding = 12.0;
    final effectiveWidth = (trackWidth - (horizontalPadding * 2)).clamp(
      1.0,
      double.infinity,
    );
    final deltaNormalized = deltaDx / effectiveWidth;

    setState(() {
      _draggingNormalizedPosition =
          (draggingNormalizedPosition + deltaNormalized).clamp(0.0, 1.0);
      _dragMoved = true;
    });
  }

  void _endKeyframeDrag(Duration duration) {
    final fromKeyframeMs = _draggingKeyframeMs;
    final normalizedPosition = _draggingNormalizedPosition;
    if (fromKeyframeMs == null || normalizedPosition == null) {
      return _clearKeyframeDragState();
    }

    if (duration.inMilliseconds <= 0) {
      return _clearKeyframeDragState();
    }

    final toKeyframeMs = (normalizedPosition * duration.inMilliseconds).round();
    ref
        .read(annotationProvider.notifier)
        .moveKeyframe(
          fromKeyframeMs: fromKeyframeMs,
          toKeyframeMs: toKeyframeMs,
        );

    _clearKeyframeDragState();
  }

  void _clearKeyframeDragState() {
    if (!mounted) return;
    setState(() {
      _draggingKeyframeMs = null;
      _draggingNormalizedPosition = null;
      _dragMoved = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final playerState = ref.watch(playerProvider);
    final timelineNotifier = ref.read(
      annotationKeyframeTimelineProvider.notifier,
    );
    final annotationNotifier = ref.read(annotationProvider.notifier);
    final keyframeMode = ref.watch(annotationKeyframeModeProvider);
    final canCreateManualKeyframe = ref.watch(canCreateManualKeyframeProvider);
    final keyframeTimesMs = ref.watch(annotationKeyframeTimesProvider);
    final activeKeyframeMs = ref.watch(activeAnnotationKeyframeProvider);

    final hasVideo = playerState.player != null;
    final duration = playerState.duration;
    final displayPosition = playerState.position;

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
      color: palette.panel,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Annotation Keyframes',
                style: TextStyle(
                  color: palette.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Count: ${keyframeTimesMs.length}',
                style: TextStyle(color: palette.textSecondary, fontSize: 12),
              ),
              const SizedBox(width: 8),
              Tooltip(
                message: keyframeMode == KeyframeCreationMode.manual
                    ? 'Manual mode: drawing edits the active keyframe. Use New Frame to create an empty keyframe at the playhead.'
                    : 'Automatic mode: drawing on a frame automatically creates or uses that frame keyframe.',
                child: TextButton(
                  onPressed: () {
                    annotationNotifier.setKeyframeCreationMode(
                      keyframeMode == KeyframeCreationMode.manual
                          ? KeyframeCreationMode.automatic
                          : KeyframeCreationMode.manual,
                    );
                  },
                  style: TextButton.styleFrom(
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    backgroundColor: keyframeMode == KeyframeCreationMode.manual
                        ? palette.loopB.withValues(alpha: 0.24)
                        : palette.accentSoft,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    keyframeMode == KeyframeCreationMode.manual
                        ? 'Manual'
                        : 'Automatic',
                    style: TextStyle(
                      color: keyframeMode == KeyframeCreationMode.manual
                          ? palette.loopB
                          : palette.accentBright,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              if (keyframeMode == KeyframeCreationMode.manual) ...[
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: hasVideo && canCreateManualKeyframe
                      ? () => annotationNotifier
                            .createManualKeyframeAtCurrentFrame()
                      : null,
                  icon: Icon(Icons.add_circle_outline, size: 16),
                  label: Text('New Frame'),
                  style: TextButton.styleFrom(
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                  ),
                ),
              ],
              const Spacer(),
              if (activeKeyframeMs != null)
                Text(
                  'Active Frame $activeFrame (${TimecodeFormatter.format(Duration(milliseconds: activeKeyframeMs))})',
                  style: TextStyle(
                    color: palette.accentBright,
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
                        activeTrackColor: palette.accent,
                        inactiveTrackColor: palette.border,
                        thumbColor: palette.accentBright,
                        overlayColor: palette.accentSoft,
                      ),
                      child: IgnorePointer(
                        // Annotation timeline is read-only for scrubbing.
                        // Playback timeline controls position; keyframe markers
                        // remain interactive for exact keyframe jumps.
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
                                        (value * duration.inMicroseconds)
                                            .round(),
                                  );
                                  timelineNotifier.updateScrubbingPosition(
                                    position,
                                  );
                                }
                              : null,
                          onChangeEnd: hasVideo
                              ? (_) => timelineNotifier.endScrubbing()
                              : null,
                        ),
                      ),
                    ),
                    ...keyframeTimesMs.map((keyframeMs) {
                      final computedNormalized = duration.inMilliseconds > 0
                          ? (keyframeMs / duration.inMilliseconds).clamp(
                              0.0,
                              1.0,
                            )
                          : 0.0;
                      final isBeingDragged = keyframeMs == _draggingKeyframeMs;
                      final normalized =
                          isBeingDragged && _draggingNormalizedPosition != null
                          ? _draggingNormalizedPosition!
                          : computedNormalized;
                      final isActive = keyframeMs == activeKeyframeMs;
                      return _KeyframeMarker(
                        normalizedPosition: normalized,
                        trackWidth: trackWidth,
                        isActive: isActive,
                        isDragging: isBeingDragged,
                        onDragStart: hasVideo
                            ? () => _startKeyframeDrag(
                                keyframeMs,
                                computedNormalized,
                              )
                            : null,
                        onDragUpdate: hasVideo
                            ? (deltaDx) =>
                                  _updateKeyframeDrag(deltaDx, trackWidth)
                            : null,
                        onDragEnd: hasVideo
                            ? () => _endKeyframeDrag(duration)
                            : null,
                        onTap: hasVideo
                            ? () {
                                // Ignore tap if this interaction was a drag.
                                if (_dragMoved) {
                                  _dragMoved = false;
                                  return;
                                }
                                timelineNotifier.seekToKeyframeMs(
                                  keyframeMs,
                                  fps,
                                );
                              }
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
  final bool isDragging;
  final VoidCallback? onDragStart;
  final ValueChanged<double>? onDragUpdate;
  final VoidCallback? onDragEnd;
  final VoidCallback? onTap;

  const _KeyframeMarker({
    required this.normalizedPosition,
    required this.trackWidth,
    required this.isActive,
    required this.isDragging,
    this.onDragStart,
    this.onDragUpdate,
    this.onDragEnd,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    const horizontalPadding = 12.0;
    final effectiveWidth = trackWidth - (horizontalPadding * 2);
    final xPosition = horizontalPadding + (normalizedPosition * effectiveWidth);

    return Positioned(
      left: xPosition - 6,
      top: 9,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragStart: onDragStart != null
            ? (_) => onDragStart!()
            : null,
        onHorizontalDragUpdate: onDragUpdate != null
            ? (details) => onDragUpdate!(details.delta.dx)
            : null,
        onHorizontalDragEnd: onDragEnd != null ? (_) => onDragEnd!() : null,
        onHorizontalDragCancel: onDragEnd,
        onTap: onTap,
        child: MouseRegion(
          cursor: onDragUpdate != null
              ? (isDragging
                    ? SystemMouseCursors.grabbing
                    : SystemMouseCursors.click)
              : onTap != null
              ? SystemMouseCursors.click
              : SystemMouseCursors.basic,
          child: Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive ? palette.loopB : palette.accent,
              border: Border.all(color: palette.background, width: 1.5),
            ),
          ),
        ),
      ),
    );
  }
}
