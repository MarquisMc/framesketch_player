import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_palette.dart';
import '../providers/timeline_provider.dart';
import '../../player/providers/player_provider.dart';
import '../../loop/providers/loop_provider.dart';
import '../../annotations/providers/annotation_keyframe_timeline_provider.dart';

/// Timeline scrubber widget with loop markers and section highlighting
class TimelineScrubber extends ConsumerStatefulWidget {
  final bool showAnnotationTimelineToggle;

  const TimelineScrubber({super.key, this.showAnnotationTimelineToggle = true});

  @override
  ConsumerState<TimelineScrubber> createState() => _TimelineScrubberState();
}

class _TimelineScrubberState extends ConsumerState<TimelineScrubber> {
  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final playerState = ref.watch(playerProvider);
    final timelineState = ref.watch(timelineProvider);
    final loopState = ref.watch(loopProvider);
    final timelineNotifier = ref.read(timelineProvider.notifier);
    final loopNotifier = ref.read(loopProvider.notifier);
    final showAnnotationTimeline = ref.watch(
      annotationKeyframeTimelineVisibleProvider,
    );

    final hasVideo = playerState.player != null;
    final duration = playerState.duration;
    final position =
        timelineState.isScrubbing && timelineState.scrubbingPosition != null
        ? timelineState.scrubbingPosition!
        : playerState.position;

    // Calculate slider value (0.0 to 1.0)
    double sliderValue = 0.0;
    if (hasVideo && duration.inMicroseconds > 0) {
      sliderValue = position.inMicroseconds / duration.inMicroseconds;
      sliderValue = sliderValue.clamp(0.0, 1.0);
    }

    // Calculate loop marker positions (normalized 0-1)
    double? loopStartNorm;
    double? loopEndNorm;
    if (loopState.loopStartMs != null && duration.inMilliseconds > 0) {
      loopStartNorm = loopState.loopStartMs! / duration.inMilliseconds;
    }
    if (loopState.loopEndMs != null && duration.inMilliseconds > 0) {
      loopEndNorm = loopState.loopEndMs! / duration.inMilliseconds;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: palette.background,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Main scrubber with loop overlay
              Row(
                children: [
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, timelineConstraints) {
                        final trackWidth = timelineConstraints.maxWidth;
                        return SizedBox(
                          height: 32,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Loop region highlight (behind the slider)
                              if (loopState.isSectionLoopActive &&
                                  loopStartNorm != null &&
                                  loopEndNorm != null)
                                Positioned.fill(
                                  child: _LoopRegionPainter(
                                    startNorm: loopStartNorm,
                                    endNorm: loopEndNorm,
                                    isActive:
                                        loopState.mode == LoopMode.section,
                                    loopColor: palette.loopA,
                                  ),
                                ),

                              // Main slider
                              SliderTheme(
                                data: SliderThemeData(
                                  trackHeight: 4,
                                  thumbShape: const RoundSliderThumbShape(
                                    enabledThumbRadius: 8,
                                  ),
                                  overlayShape: const RoundSliderOverlayShape(
                                    overlayRadius: 16,
                                  ),
                                  activeTrackColor: palette.accent,
                                  inactiveTrackColor: palette.border,
                                  thumbColor: palette.accentBright,
                                  overlayColor: palette.accentSoft,
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
                                                (value *
                                                        duration.inMicroseconds)
                                                    .round(),
                                          );
                                          timelineNotifier
                                              .updateScrubbingPosition(
                                                newPosition,
                                              );
                                        }
                                      : null,
                                  onChangeEnd: hasVideo
                                      ? (value) {
                                          timelineNotifier.endScrubbing();
                                        }
                                      : null,
                                ),
                              ),

                              // A marker (loop start)
                              if (loopStartNorm != null)
                                _LoopMarker(
                                  normalizedPosition: loopStartNorm,
                                  trackWidth: trackWidth,
                                  label: 'A',
                                  color: palette.loopA,
                                  onDrag: hasVideo
                                      ? (delta) {
                                          final newNorm =
                                              (loopStartNorm! +
                                                      delta / trackWidth)
                                                  .clamp(0.0, 1.0);
                                          final newPos = Duration(
                                            milliseconds:
                                                (newNorm *
                                                        duration.inMilliseconds)
                                                    .round(),
                                          );
                                          loopNotifier.setAPointAt(newPos);
                                        }
                                      : null,
                                ),

                              // B marker (loop end)
                              if (loopEndNorm != null)
                                _LoopMarker(
                                  normalizedPosition: loopEndNorm,
                                  trackWidth: trackWidth,
                                  label: 'B',
                                  color: palette.loopB,
                                  onDrag: hasVideo
                                      ? (delta) {
                                          final newNorm =
                                              (loopEndNorm! +
                                                      delta / trackWidth)
                                                  .clamp(0.0, 1.0);
                                          final newPos = Duration(
                                            milliseconds:
                                                (newNorm *
                                                        duration.inMilliseconds)
                                                    .round(),
                                          );
                                          loopNotifier.setBPointAt(newPos);
                                        }
                                      : null,
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  if (widget.showAnnotationTimelineToggle) ...[
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: showAnnotationTimeline
                          ? 'Hide Annotation Keyframe Timeline'
                          : 'Show Annotation Keyframe Timeline',
                      icon: Icon(
                        showAnnotationTimeline
                            ? Icons.timeline
                            : Icons.timeline_outlined,
                        color: showAnnotationTimeline
                            ? palette.accentBright
                            : palette.textSecondary,
                      ),
                      onPressed: hasVideo
                          ? () {
                              ref
                                      .read(
                                        annotationKeyframeTimelineVisibleProvider
                                            .notifier,
                                      )
                                      .state =
                                  !showAnnotationTimeline;
                            }
                          : null,
                    ),
                  ],
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Paints the highlighted loop region on the timeline
class _LoopRegionPainter extends StatelessWidget {
  final double startNorm;
  final double endNorm;
  final bool isActive;
  final Color loopColor;

  const _LoopRegionPainter({
    required this.startNorm,
    required this.endNorm,
    required this.isActive,
    required this.loopColor,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _LoopRegionCustomPainter(
        startNorm: startNorm,
        endNorm: endNorm,
        isActive: isActive,
        loopColor: loopColor,
      ),
    );
  }
}

class _LoopRegionCustomPainter extends CustomPainter {
  final double startNorm;
  final double endNorm;
  final bool isActive;
  final Color loopColor;

  _LoopRegionCustomPainter({
    required this.startNorm,
    required this.endNorm,
    required this.isActive,
    required this.loopColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Account for slider padding (horizontal padding from SliderTheme)
    const horizontalPadding = 12.0;
    final trackWidth = size.width - (horizontalPadding * 2);
    final trackStart = horizontalPadding;

    final startX = trackStart + (startNorm * trackWidth);
    final endX = trackStart + (endNorm * trackWidth);

    final paint = Paint()
      ..color = isActive
          ? loopColor.withValues(alpha: 0.24)
          : loopColor.withValues(alpha: 0.1)
      ..style = PaintingStyle.fill;

    // Draw the highlighted region
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTRB(startX, size.height / 2 - 8, endX, size.height / 2 + 8),
      const Radius.circular(4),
    );
    canvas.drawRRect(rect, paint);

    // Draw border
    final borderPaint = Paint()
      ..color = isActive ? loopColor : loopColor.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawRRect(rect, borderPaint);
  }

  @override
  bool shouldRepaint(_LoopRegionCustomPainter oldDelegate) {
    return oldDelegate.startNorm != startNorm ||
        oldDelegate.endNorm != endNorm ||
        oldDelegate.isActive != isActive ||
        oldDelegate.loopColor != loopColor;
  }
}

/// Draggable marker for loop points (A or B)
class _LoopMarker extends StatefulWidget {
  final double normalizedPosition;
  final double trackWidth;
  final String label;
  final Color color;
  final void Function(double delta)? onDrag;

  const _LoopMarker({
    required this.normalizedPosition,
    required this.trackWidth,
    required this.label,
    required this.color,
    this.onDrag,
  });

  @override
  State<_LoopMarker> createState() => _LoopMarkerState();
}

class _LoopMarkerState extends State<_LoopMarker> {
  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    // Account for slider padding
    const horizontalPadding = 12.0;
    final trackWidth = widget.trackWidth - (horizontalPadding * 2);
    final trackStart = horizontalPadding;
    final xPosition = trackStart + (widget.normalizedPosition * trackWidth);

    return Positioned(
      left: xPosition - 8, // Center the 16px wide marker
      top: 0,
      bottom: 0,
      child: GestureDetector(
        onHorizontalDragStart: widget.onDrag != null
            ? (details) {
                setState(() => _isDragging = true);
              }
            : null,
        onHorizontalDragUpdate: widget.onDrag != null
            ? (details) {
                widget.onDrag!(details.delta.dx);
              }
            : null,
        onHorizontalDragEnd: widget.onDrag != null
            ? (details) {
                setState(() => _isDragging = false);
              }
            : null,
        child: MouseRegion(
          cursor: widget.onDrag != null
              ? SystemMouseCursors.resizeLeftRight
              : SystemMouseCursors.basic,
          child: Container(
            width: 16,
            decoration: BoxDecoration(
              color: _isDragging
                  ? widget.color.withValues(alpha: 0.3)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Top marker triangle
                CustomPaint(
                  size: const Size(10, 6),
                  painter: _MarkerTrianglePainter(
                    color: widget.color,
                    pointDown: true,
                  ),
                ),
                // Vertical line
                Container(width: 2, height: 12, color: widget.color),
                // Label
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 1),
                  decoration: BoxDecoration(
                    color: widget.color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: Text(
                    widget.label,
                    style: TextStyle(
                      color: AppPalette.of(context).textPrimary,
                      fontSize: 7,
                      height: 1.0,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Paints a triangle marker
class _MarkerTrianglePainter extends CustomPainter {
  final Color color;
  final bool pointDown;

  _MarkerTrianglePainter({required this.color, required this.pointDown});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    if (pointDown) {
      path.moveTo(0, 0);
      path.lineTo(size.width, 0);
      path.lineTo(size.width / 2, size.height);
    } else {
      path.moveTo(size.width / 2, 0);
      path.lineTo(size.width, size.height);
      path.lineTo(0, size.height);
    }
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_MarkerTrianglePainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.pointDown != pointDown;
  }
}
