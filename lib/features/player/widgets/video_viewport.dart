import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../../../core/theme/app_palette.dart';
import '../providers/player_provider.dart';
import '../../annotations/widgets/annotation_overlay.dart';
import '../../crop/widgets/crop_overlay.dart';

/// Video viewport with annotation overlay
class VideoViewport extends ConsumerWidget {
  final bool showOverlays;

  const VideoViewport({super.key, this.showOverlays = true});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = AppPalette.of(context);
    final error = ref.watch(playerProvider.select((state) => state.error));
    final isLoading = ref.watch(
      playerProvider.select((state) => state.isLoading),
    );
    final videoController = ref.watch(
      playerProvider.select((state) => state.videoController),
    );
    final sourceIdentity = ref.watch(
      playerProvider.select(
        (state) => state.currentSourceLabel ?? state.currentVideoPath,
      ),
    );

    if (error != null) {
      return _buildError(error, palette);
    }

    if (isLoading) {
      return _buildLoading(palette);
    }

    if (videoController == null) {
      return _buildEmpty(palette);
    }

    return _buildPlayer(
      videoController,
      showOverlays: showOverlays,
      sourceIdentity: sourceIdentity,
    );
  }

  Widget _buildPlayer(
    VideoController controller, {
    required bool showOverlays,
    required String? sourceIdentity,
  }) {
    return Container(
      color: Colors.black,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return _ZoomableVideoSurface(
            sourceIdentity: sourceIdentity,
            controller: controller,
            viewportSize: Size(constraints.maxWidth, constraints.maxHeight),
            showOverlays: showOverlays,
          );
        },
      ),
    );
  }

  Widget _buildEmpty(AppPalette palette) {
    return Container(
      color: palette.background,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.video_library, size: 64, color: palette.textMuted),
            SizedBox(height: 16),
            Text(
              'No video loaded',
              style: TextStyle(color: palette.textSecondary, fontSize: 18),
            ),
            SizedBox(height: 8),
            Text(
              'Press Ctrl+O to open a video file',
              style: TextStyle(color: palette.textMuted, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoading(AppPalette palette) {
    return Container(
      color: palette.background,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              'Loading video...',
              style: TextStyle(color: palette.textSecondary, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError(String error, AppPalette palette) {
    return Container(
      color: palette.background,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: palette.error),
            const SizedBox(height: 16),
            Text(
              'Error loading video',
              style: TextStyle(
                color: palette.error,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
              child: Text(
                error,
                textAlign: TextAlign.center,
                style: TextStyle(color: palette.textSecondary, fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ZoomableVideoSurface extends StatefulWidget {
  final String? sourceIdentity;
  final VideoController controller;
  final Size viewportSize;
  final bool showOverlays;

  const _ZoomableVideoSurface({
    required this.sourceIdentity,
    required this.controller,
    required this.viewportSize,
    required this.showOverlays,
  });

  @override
  State<_ZoomableVideoSurface> createState() => _ZoomableVideoSurfaceState();
}

class _ZoomableVideoSurfaceState extends State<_ZoomableVideoSurface> {
  static const double _minScale = 1.0;
  static const double _maxScale = 8.0;

  double _scale = _minScale;
  Offset _offset = Offset.zero;
  int? _panPointer;
  bool _isControlPressed = HardwareKeyboard.instance.isControlPressed;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
  }

  @override
  void didUpdateWidget(covariant _ZoomableVideoSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sourceIdentity != widget.sourceIdentity) {
      _resetTransform();
      return;
    }
    final clampedOffset = _clampOffset(_offset, _scale, widget.viewportSize);
    if (clampedOffset != _offset) {
      _offset = clampedOffset;
    }
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    super.dispose();
  }

  bool _handleKeyEvent(KeyEvent event) {
    final isControlPressed = HardwareKeyboard.instance.isControlPressed;
    if (isControlPressed != _isControlPressed) {
      setState(() {
        _isControlPressed = isControlPressed;
        if (!isControlPressed) {
          _panPointer = null;
        }
      });
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final content = Stack(
      fit: StackFit.expand,
      children: [
        RepaintBoundary(
          child: Video(
            key: ValueKey(widget.sourceIdentity ?? widget.controller.hashCode),
            controller: widget.controller,
            controls: null,
          ),
        ),
        if (widget.showOverlays) ...[
          const AnnotationOverlay(),
          CropOverlay(viewportSize: widget.viewportSize),
        ],
      ],
    );

    return Listener(
      onPointerSignal: _handlePointerSignal,
      child: ClipRect(
        child: Stack(
          fit: StackFit.expand,
          children: [
            Transform(
              transform: Matrix4.diagonal3Values(_scale, _scale, 1)
                ..setTranslationRaw(_offset.dx, _offset.dy, 0),
              child: content,
            ),
            if (_isControlPressed || _panPointer != null)
              Positioned.fill(
                child: MouseRegion(
                  cursor: SystemMouseCursors.move,
                  child: Listener(
                    behavior: HitTestBehavior.opaque,
                    onPointerDown: _handlePanPointerDown,
                    onPointerMove: _handlePanPointerMove,
                    onPointerUp: _handlePanPointerEnd,
                    onPointerCancel: _handlePanPointerEnd,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _handlePointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;

    final zoomFactor = math.pow(1.0015, -event.scrollDelta.dy).toDouble();
    final nextScale = (_scale * zoomFactor)
        .clamp(_minScale, _maxScale)
        .toDouble();
    if ((nextScale - _scale).abs() < 0.0001) return;

    final anchor = event.localPosition;
    final contentAnchor = (anchor - _offset) / _scale;
    final nextOffset = anchor - contentAnchor * nextScale;

    setState(() {
      _scale = nextScale;
      _offset = _clampOffset(nextOffset, nextScale, widget.viewportSize);
    });
  }

  void _handlePanPointerDown(PointerDownEvent event) {
    if (!_isControlPressed || event.buttons & kPrimaryMouseButton == 0) {
      return;
    }
    _panPointer = event.pointer;
  }

  void _handlePanPointerMove(PointerMoveEvent event) {
    if (_panPointer != event.pointer) return;

    setState(() {
      _offset = _clampOffset(
        _offset + event.delta,
        _scale,
        widget.viewportSize,
      );
    });
  }

  void _handlePanPointerEnd(PointerEvent event) {
    if (_panPointer == event.pointer) {
      setState(() {
        _panPointer = null;
      });
    }
  }

  void _resetTransform() {
    _scale = _minScale;
    _offset = Offset.zero;
    _panPointer = null;
  }

  Offset _clampOffset(Offset offset, double scale, Size viewportSize) {
    if (scale <= _minScale) {
      return Offset.zero;
    }

    final minX = viewportSize.width * (1 - scale);
    final minY = viewportSize.height * (1 - scale);
    return Offset(
      offset.dx.clamp(minX, 0.0).toDouble(),
      offset.dy.clamp(minY, 0.0).toDouble(),
    );
  }
}
