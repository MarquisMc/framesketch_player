import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/utils/timecode_formatter.dart';
import '../../timeline/providers/timeline_provider.dart';
import '../../player/providers/player_provider.dart';
import '../providers/crop_provider.dart';

enum _ExportDragTarget { start, end, frame }

class ExportTimeline extends ConsumerStatefulWidget {
  const ExportTimeline({super.key});

  @override
  ConsumerState<ExportTimeline> createState() => _ExportTimelineState();
}

class _ExportTimelineState extends ConsumerState<ExportTimeline> {
  static const _commitInterval = Duration(milliseconds: 80);

  Timer? _commitTimer;
  final GlobalKey _trackKey = GlobalKey();
  _ExportDragTarget? _dragTarget;
  int? _previewStartMs;
  int? _previewEndMs;
  int? _previewFrameMs;
  double _dragGrabOffsetPx = 0.0;

  @override
  void dispose() {
    _commitTimer?.cancel();
    super.dispose();
  }

  void _beginPreviewDrag({
    required _ExportDragTarget target,
    required int startMs,
    required int endMs,
    required int totalMs,
    required double globalX,
    int? frameMs,
  }) {
    _commitTimer?.cancel();
    _dragGrabOffsetPx = _calculateGrabOffsetPx(
      target: target,
      globalX: globalX,
      startMs: startMs,
      endMs: endMs,
      frameMs: frameMs,
      totalMs: totalMs,
    );
    setState(() {
      _dragTarget = target;
      _previewStartMs = startMs;
      _previewEndMs = endMs;
      _previewFrameMs = frameMs;
    });
    ref.read(timelineProvider.notifier).startScrubbing();
  }

  double _calculateGrabOffsetPx({
    required _ExportDragTarget target,
    required double globalX,
    required int startMs,
    required int endMs,
    required int totalMs,
    int? frameMs,
  }) {
    final box = _trackKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize || totalMs <= 0) return 0.0;

    const horizontalPadding = 12.0;
    final trackWidth = (box.size.width - horizontalPadding * 2).clamp(
      1.0,
      double.infinity,
    );
    final localX = box.globalToLocal(Offset(globalX, 0)).dx;
    final targetMs = switch (target) {
      _ExportDragTarget.start => startMs,
      _ExportDragTarget.end => endMs,
      _ExportDragTarget.frame => frameMs ?? startMs,
    };
    final handleCenterX = horizontalPadding + (targetMs / totalMs) * trackWidth;
    return handleCenterX - localX;
  }

  void _updatePreviewDragAt({required double globalX, required int totalMs}) {
    final target = _dragTarget;
    final startMs = _previewStartMs;
    final endMs = _previewEndMs;
    if (target == null || startMs == null || endMs == null) return;

    final box = _trackKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;

    const minSegmentMs = 100;
    const horizontalPadding = 12.0;
    final trackWidth = (box.size.width - horizontalPadding * 2).clamp(
      1.0,
      double.infinity,
    );
    final localX = box.globalToLocal(Offset(globalX, 0)).dx + _dragGrabOffsetPx;
    final pointerMs =
        (((localX - horizontalPadding) / trackWidth).clamp(0.0, 1.0) * totalMs)
            .round();

    setState(() {
      switch (target) {
        case _ExportDragTarget.start:
          final maxStart = (endMs - minSegmentMs).clamp(0, totalMs);
          _previewStartMs = pointerMs.clamp(0, maxStart);
          if (_previewFrameMs != null && _previewFrameMs! < _previewStartMs!) {
            _previewFrameMs = _previewStartMs;
          }
        case _ExportDragTarget.end:
          final minEnd = (startMs + minSegmentMs).clamp(0, totalMs);
          _previewEndMs = pointerMs.clamp(minEnd, totalMs);
          if (_previewFrameMs != null && _previewFrameMs! > _previewEndMs!) {
            _previewFrameMs = _previewEndMs;
          }
        case _ExportDragTarget.frame:
          _previewFrameMs = pointerMs.clamp(startMs, endMs);
      }
    });

    final previewMs = switch (target) {
      _ExportDragTarget.start => _previewStartMs,
      _ExportDragTarget.end => _previewEndMs,
      _ExportDragTarget.frame => _previewFrameMs,
    };
    if (previewMs != null) {
      ref
          .read(timelineProvider.notifier)
          .updateScrubbingPosition(Duration(milliseconds: previewMs));
    }

    if (target == _ExportDragTarget.frame) {
      _scheduleCommit();
    } else {
      _commitPreview();
    }
  }

  void _endPreviewDrag() {
    _commitTimer?.cancel();
    _commitPreview();
    ref.read(timelineProvider.notifier).endScrubbing();
    if (!mounted) return;
    setState(() {
      _dragTarget = null;
      _previewStartMs = null;
      _previewEndMs = null;
      _previewFrameMs = null;
      _dragGrabOffsetPx = 0.0;
    });
  }

  void _scheduleCommit() {
    if (_commitTimer?.isActive ?? false) return;
    _commitTimer = Timer(_commitInterval, _commitPreview);
  }

  void _commitPreview() {
    final target = _dragTarget;
    final startMs = _previewStartMs;
    final endMs = _previewEndMs;
    if (target == null || startMs == null || endMs == null) return;

    final cropNotifier = ref.read(cropProvider.notifier);
    switch (target) {
      case _ExportDragTarget.start:
      case _ExportDragTarget.end:
        cropNotifier.setExportRange(
          start: Duration(milliseconds: startMs),
          end: Duration(milliseconds: endMs),
        );
      case _ExportDragTarget.frame:
        final frameMs = _previewFrameMs;
        if (frameMs == null) return;
        cropNotifier.setExportFrameSelection(
          Duration(milliseconds: frameMs),
          seek: false,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final playerState = ref.watch(playerProvider);
    final cropState = ref.watch(cropProvider);
    final metadata = playerState.metadata;
    final duration = playerState.duration;
    final totalMs = duration.inMilliseconds;
    final hasVideo = playerState.hasLoadedSource && totalMs > 0;

    if (!hasVideo) {
      return Container(
        height: 54,
        color: palette.background,
        alignment: Alignment.center,
        child: Text(
          'Export Timeline',
          style: TextStyle(color: palette.textMuted, fontSize: 12),
        ),
      );
    }

    final start = cropState.exportStart ?? Duration.zero;
    final end = cropState.exportEnd ?? duration;
    final providerStartMs = start.inMilliseconds.clamp(0, totalMs);
    final providerEndMs = end.inMilliseconds.clamp(providerStartMs, totalMs);
    final startMs = _previewStartMs ?? providerStartMs;
    final endMs = _previewEndMs ?? providerEndMs;
    final selectedMs =
        _previewFrameMs ??
        cropState.exportFrameSelection?.inMilliseconds.clamp(startMs, endMs);
    final positionMs = playerState.position.inMilliseconds.clamp(0, totalMs);
    final fps = metadata?.fps ?? 30.0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: palette.background,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                Icons.ios_share_outlined,
                size: 14,
                color: palette.textMuted,
              ),
              const SizedBox(width: 8),
              Text(
                'Export Timeline',
                style: TextStyle(
                  color: palette.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                '${TimecodeFormatter.formatShort(start)} - ${TimecodeFormatter.formatShort(end)}',
                style: TextStyle(
                  color: palette.textMuted,
                  fontSize: 11,
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
                height: 34,
                child: Stack(
                  key: _trackKey,
                  alignment: Alignment.center,
                  children: [
                    Positioned.fill(
                      child: _ExportRangePainter(
                        startNorm: startMs / totalMs,
                        endNorm: endMs / totalMs,
                        playheadNorm: positionMs / totalMs,
                        rangeColor: palette.accent,
                        playheadColor: palette.textSecondary,
                        borderColor: palette.border,
                      ),
                    ),
                    _RangeHandle(
                      normalizedPosition: startMs / totalMs,
                      trackWidth: trackWidth,
                      label: 'IN',
                      color: palette.loopA,
                      onDragStart: (globalX) => _beginPreviewDrag(
                        target: _ExportDragTarget.start,
                        startMs: startMs,
                        endMs: endMs,
                        totalMs: totalMs,
                        globalX: globalX,
                        frameMs: selectedMs,
                      ),
                      onDrag: (globalX) {
                        _updatePreviewDragAt(
                          globalX: globalX,
                          totalMs: totalMs,
                        );
                      },
                      onDragEnd: _endPreviewDrag,
                    ),
                    _RangeHandle(
                      normalizedPosition: endMs / totalMs,
                      trackWidth: trackWidth,
                      label: 'OUT',
                      color: palette.loopB,
                      onDragStart: (globalX) => _beginPreviewDrag(
                        target: _ExportDragTarget.end,
                        startMs: startMs,
                        endMs: endMs,
                        totalMs: totalMs,
                        globalX: globalX,
                        frameMs: selectedMs,
                      ),
                      onDrag: (globalX) {
                        _updatePreviewDragAt(
                          globalX: globalX,
                          totalMs: totalMs,
                        );
                      },
                      onDragEnd: _endPreviewDrag,
                    ),
                    if (selectedMs != null)
                      _SelectedFrameMarker(
                        normalizedPosition: selectedMs / totalMs,
                        trackWidth: trackWidth,
                        frame: ((selectedMs / 1000.0) * fps).round(),
                        timecode: TimecodeFormatter.format(
                          Duration(milliseconds: selectedMs),
                        ),
                        color: palette.accentBright,
                        onDragStart: (globalX) => _beginPreviewDrag(
                          target: _ExportDragTarget.frame,
                          startMs: startMs,
                          endMs: endMs,
                          totalMs: totalMs,
                          globalX: globalX,
                          frameMs: selectedMs,
                        ),
                        onDrag: (globalX) {
                          _updatePreviewDragAt(
                            globalX: globalX,
                            totalMs: totalMs,
                          );
                        },
                        onDragEnd: _endPreviewDrag,
                      ),
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

class _ExportRangePainter extends StatelessWidget {
  final double startNorm;
  final double endNorm;
  final double playheadNorm;
  final Color rangeColor;
  final Color playheadColor;
  final Color borderColor;

  const _ExportRangePainter({
    required this.startNorm,
    required this.endNorm,
    required this.playheadNorm,
    required this.rangeColor,
    required this.playheadColor,
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _ExportRangeCustomPainter(
        startNorm: startNorm,
        endNorm: endNorm,
        playheadNorm: playheadNorm,
        rangeColor: rangeColor,
        playheadColor: playheadColor,
        borderColor: borderColor,
      ),
    );
  }
}

class _ExportRangeCustomPainter extends CustomPainter {
  final double startNorm;
  final double endNorm;
  final double playheadNorm;
  final Color rangeColor;
  final Color playheadColor;
  final Color borderColor;

  _ExportRangeCustomPainter({
    required this.startNorm,
    required this.endNorm,
    required this.playheadNorm,
    required this.rangeColor,
    required this.playheadColor,
    required this.borderColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const horizontalPadding = 12.0;
    final trackWidth = size.width - horizontalPadding * 2;
    final trackStart = horizontalPadding;
    final centerY = size.height / 2;

    final trackPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.fill;
    final rangePaint = Paint()
      ..color = rangeColor.withValues(alpha: 0.24)
      ..style = PaintingStyle.fill;
    final rangeBorderPaint = Paint()
      ..color = rangeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final playheadPaint = Paint()
      ..color = playheadColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    final trackRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(trackStart, centerY - 3, trackWidth, 6),
      const Radius.circular(3),
    );
    canvas.drawRRect(trackRect, trackPaint);

    final startX = trackStart + startNorm.clamp(0.0, 1.0) * trackWidth;
    final endX = trackStart + endNorm.clamp(0.0, 1.0) * trackWidth;
    final rangeRect = RRect.fromRectAndRadius(
      Rect.fromLTRB(startX, centerY - 8, endX, centerY + 8),
      const Radius.circular(4),
    );
    canvas.drawRRect(rangeRect, rangePaint);
    canvas.drawRRect(rangeRect, rangeBorderPaint);

    final playheadX = trackStart + playheadNorm.clamp(0.0, 1.0) * trackWidth;
    canvas.drawLine(
      Offset(playheadX, centerY - 14),
      Offset(playheadX, centerY + 14),
      playheadPaint,
    );
  }

  @override
  bool shouldRepaint(_ExportRangeCustomPainter oldDelegate) {
    return oldDelegate.startNorm != startNorm ||
        oldDelegate.endNorm != endNorm ||
        oldDelegate.playheadNorm != playheadNorm ||
        oldDelegate.rangeColor != rangeColor ||
        oldDelegate.playheadColor != playheadColor ||
        oldDelegate.borderColor != borderColor;
  }
}

class _RangeHandle extends StatefulWidget {
  final double normalizedPosition;
  final double trackWidth;
  final String label;
  final Color color;
  final void Function(double globalX)? onDragStart;
  final void Function(double globalX)? onDrag;
  final VoidCallback? onDragEnd;

  const _RangeHandle({
    required this.normalizedPosition,
    required this.trackWidth,
    required this.label,
    required this.color,
    this.onDragStart,
    this.onDrag,
    this.onDragEnd,
  });

  @override
  State<_RangeHandle> createState() => _RangeHandleState();
}

class _RangeHandleState extends State<_RangeHandle> {
  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    const horizontalPadding = 12.0;
    final effectiveWidth = widget.trackWidth - horizontalPadding * 2;
    final x =
        horizontalPadding +
        widget.normalizedPosition.clamp(0.0, 1.0) * effectiveWidth;

    return Positioned(
      left: x - 8,
      top: 0,
      bottom: 0,
      child: GestureDetector(
        onHorizontalDragStart: widget.onDrag != null
            ? (details) {
                widget.onDragStart?.call(details.globalPosition.dx);
                setState(() => _isDragging = true);
              }
            : null,
        onHorizontalDragUpdate: widget.onDrag != null
            ? (details) => widget.onDrag!(details.globalPosition.dx)
            : null,
        onHorizontalDragEnd: widget.onDrag != null
            ? (_) {
                widget.onDragEnd?.call();
                setState(() => _isDragging = false);
              }
            : null,
        onHorizontalDragCancel: widget.onDrag != null
            ? () {
                widget.onDragEnd?.call();
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
                CustomPaint(
                  size: const Size(10, 6),
                  painter: _MarkerTrianglePainter(
                    color: widget.color,
                    pointDown: true,
                  ),
                ),
                Container(width: 2, height: 12, color: widget.color),
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

class _SelectedFrameMarker extends StatelessWidget {
  final double normalizedPosition;
  final double trackWidth;
  final int frame;
  final String timecode;
  final Color color;
  final void Function(double globalX) onDragStart;
  final void Function(double globalX) onDrag;
  final VoidCallback onDragEnd;

  const _SelectedFrameMarker({
    required this.normalizedPosition,
    required this.trackWidth,
    required this.frame,
    required this.timecode,
    required this.color,
    required this.onDragStart,
    required this.onDrag,
    required this.onDragEnd,
  });

  @override
  Widget build(BuildContext context) {
    const horizontalPadding = 12.0;
    final effectiveWidth = trackWidth - horizontalPadding * 2;
    final x =
        horizontalPadding + normalizedPosition.clamp(0.0, 1.0) * effectiveWidth;

    return Positioned(
      left: x - 11,
      top: 0,
      bottom: 0,
      child: Tooltip(
        message: 'Frame $frame\n$timecode',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragStart: (details) =>
              onDragStart(details.globalPosition.dx),
          onHorizontalDragUpdate: (details) =>
              onDrag(details.globalPosition.dx),
          onHorizontalDragEnd: (_) => onDragEnd(),
          onHorizontalDragCancel: onDragEnd,
          child: MouseRegion(
            cursor: SystemMouseCursors.resizeLeftRight,
            child: SizedBox(
              width: 22,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.place, size: 18, color: color),
                  Container(width: 2, height: 10, color: color),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

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
