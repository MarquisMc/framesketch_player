import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/coordinate_transformer.dart';
import '../providers/crop_provider.dart';
import '../../player/providers/player_provider.dart';

/// Overlay widget for crop mode
/// Displays a draggable, resizable crop rectangle over the video
class CropOverlay extends ConsumerStatefulWidget {
  /// Size of the video viewport
  final Size viewportSize;

  const CropOverlay({super.key, required this.viewportSize});

  @override
  ConsumerState<CropOverlay> createState() => _CropOverlayState();
}

class _CropOverlayState extends ConsumerState<CropOverlay> {
  @override
  Widget build(BuildContext context) {
    final cropState = ref.watch(cropProvider);
    final cropNotifier = ref.read(cropProvider.notifier);
    final playerState = ref.watch(playerProvider);

    if (!cropState.isCropModeActive) {
      return const SizedBox.shrink();
    }

    final rect = cropState.cropRect;
    final vw = widget.viewportSize.width;
    final vh = widget.viewportSize.height;
    final videoRect = CoordinateTransformer(
      widget.viewportSize,
      videoSize: _resolveVideoSize(playerState),
    ).videoRectInViewport;
    final safeVideoRect = videoRect.width > 0 && videoRect.height > 0
        ? videoRect
        : Rect.fromLTWH(0, 0, vw, vh);

    // Convert normalized rect to pixel coordinates
    final left = safeVideoRect.left + rect.left * safeVideoRect.width;
    final top = safeVideoRect.top + rect.top * safeVideoRect.height;
    final right = safeVideoRect.left + rect.right * safeVideoRect.width;
    final bottom = safeVideoRect.top + rect.bottom * safeVideoRect.height;
    final width = right - left;
    final height = bottom - top;

    return Stack(
      children: [
        // Darkened areas outside crop region
        _buildDarkenedOverlay(left, top, right, bottom, vw, vh),

        // Crop rectangle border and handles
        Positioned(
          left: left,
          top: top,
          width: width,
          height: height,
          child: _CropRectangle(
            width: width,
            height: height,
            onDragStart: cropNotifier.startDrag,
            onDragUpdate: (deltaX, deltaY) {
              // Convert pixel delta to normalized delta
              cropNotifier.updateDrag(
                safeVideoRect.width == 0 ? 0 : deltaX / safeVideoRect.width,
                safeVideoRect.height == 0 ? 0 : deltaY / safeVideoRect.height,
              );
            },
            onDragEnd: cropNotifier.endDrag,
            activeHandle: cropState.activeHandle,
          ),
        ),

        // Grid lines (rule of thirds)
        Positioned(
          left: left,
          top: top,
          width: width,
          height: height,
          child: IgnorePointer(
            child: CustomPaint(
              size: Size(width, height),
              painter: _GridPainter(),
            ),
          ),
        ),

        // Dimension label
        Positioned(
          left: left,
          bottom: vh - top + 4,
          child: _DimensionLabel(
            cropRect: rect,
            viewportWidth: safeVideoRect.width.round(),
            viewportHeight: safeVideoRect.height.round(),
          ),
        ),
      ],
    );
  }

  /// Build the darkened overlay outside the crop area
  Widget _buildDarkenedOverlay(
    double left,
    double top,
    double right,
    double bottom,
    double vw,
    double vh,
  ) {
    return IgnorePointer(
      child: CustomPaint(
        size: Size(vw, vh),
        painter: _DarkenedOverlayPainter(
          cropLeft: left,
          cropTop: top,
          cropRight: right,
          cropBottom: bottom,
        ),
      ),
    );
  }

  Size? _resolveVideoSize(PlayerState playerState) {
    final rect = playerState.videoController?.rect.value;
    if (rect != null && rect.width > 1 && rect.height > 1) {
      return Size(rect.width, rect.height);
    }

    final metadata = playerState.metadata;
    if (metadata == null || metadata.width <= 0 || metadata.height <= 0) {
      return null;
    }

    return Size(metadata.width.toDouble(), metadata.height.toDouble());
  }
}

/// Paints the darkened area outside the crop region
class _DarkenedOverlayPainter extends CustomPainter {
  final double cropLeft;
  final double cropTop;
  final double cropRight;
  final double cropBottom;

  _DarkenedOverlayPainter({
    required this.cropLeft,
    required this.cropTop,
    required this.cropRight,
    required this.cropBottom,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withAlpha(180)
      ..style = PaintingStyle.fill;

    // Create a path for the entire area
    final fullPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));

    // Create path for the crop area (to exclude)
    final cropPath = Path()
      ..addRect(Rect.fromLTRB(cropLeft, cropTop, cropRight, cropBottom));

    // Combine paths to create the darkened region
    final combinedPath = Path.combine(
      PathOperation.difference,
      fullPath,
      cropPath,
    );

    canvas.drawPath(combinedPath, paint);
  }

  @override
  bool shouldRepaint(_DarkenedOverlayPainter oldDelegate) {
    return oldDelegate.cropLeft != cropLeft ||
        oldDelegate.cropTop != cropTop ||
        oldDelegate.cropRight != cropRight ||
        oldDelegate.cropBottom != cropBottom;
  }
}

/// The interactive crop rectangle with handles
class _CropRectangle extends StatelessWidget {
  final double width;
  final double height;
  final void Function(CropHandle) onDragStart;
  final void Function(double deltaX, double deltaY) onDragUpdate;
  final VoidCallback onDragEnd;
  final CropHandle? activeHandle;

  const _CropRectangle({
    required this.width,
    required this.height,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
    this.activeHandle,
  });

  @override
  Widget build(BuildContext context) {
    const handleSize = 12.0;
    const handleOffset = handleSize / 2;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Main border
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white, width: 2),
            ),
          ),
        ),

        // Center move area
        Positioned.fill(
          child: _DragHandle(
            handle: CropHandle.move,
            cursor: SystemMouseCursors.move,
            onDragStart: onDragStart,
            onDragUpdate: onDragUpdate,
            onDragEnd: onDragEnd,
            child: Container(color: Colors.transparent),
          ),
        ),

        // Corner handles
        // Top-left
        Positioned(
          left: -handleOffset,
          top: -handleOffset,
          child: _CornerHandle(
            handle: CropHandle.topLeft,
            isActive: activeHandle == CropHandle.topLeft,
            onDragStart: onDragStart,
            onDragUpdate: onDragUpdate,
            onDragEnd: onDragEnd,
          ),
        ),

        // Top-right
        Positioned(
          right: -handleOffset,
          top: -handleOffset,
          child: _CornerHandle(
            handle: CropHandle.topRight,
            isActive: activeHandle == CropHandle.topRight,
            onDragStart: onDragStart,
            onDragUpdate: onDragUpdate,
            onDragEnd: onDragEnd,
          ),
        ),

        // Bottom-left
        Positioned(
          left: -handleOffset,
          bottom: -handleOffset,
          child: _CornerHandle(
            handle: CropHandle.bottomLeft,
            isActive: activeHandle == CropHandle.bottomLeft,
            onDragStart: onDragStart,
            onDragUpdate: onDragUpdate,
            onDragEnd: onDragEnd,
          ),
        ),

        // Bottom-right
        Positioned(
          right: -handleOffset,
          bottom: -handleOffset,
          child: _CornerHandle(
            handle: CropHandle.bottomRight,
            isActive: activeHandle == CropHandle.bottomRight,
            onDragStart: onDragStart,
            onDragUpdate: onDragUpdate,
            onDragEnd: onDragEnd,
          ),
        ),

        // Edge handles
        // Top edge
        Positioned(
          left: handleSize,
          right: handleSize,
          top: -8,
          height: 16,
          child: _EdgeHandle(
            handle: CropHandle.top,
            isHorizontal: true,
            onDragStart: onDragStart,
            onDragUpdate: onDragUpdate,
            onDragEnd: onDragEnd,
          ),
        ),

        // Bottom edge
        Positioned(
          left: handleSize,
          right: handleSize,
          bottom: -8,
          height: 16,
          child: _EdgeHandle(
            handle: CropHandle.bottom,
            isHorizontal: true,
            onDragStart: onDragStart,
            onDragUpdate: onDragUpdate,
            onDragEnd: onDragEnd,
          ),
        ),

        // Left edge
        Positioned(
          left: -8,
          top: handleSize,
          bottom: handleSize,
          width: 16,
          child: _EdgeHandle(
            handle: CropHandle.left,
            isHorizontal: false,
            onDragStart: onDragStart,
            onDragUpdate: onDragUpdate,
            onDragEnd: onDragEnd,
          ),
        ),

        // Right edge
        Positioned(
          right: -8,
          top: handleSize,
          bottom: handleSize,
          width: 16,
          child: _EdgeHandle(
            handle: CropHandle.right,
            isHorizontal: false,
            onDragStart: onDragStart,
            onDragUpdate: onDragUpdate,
            onDragEnd: onDragEnd,
          ),
        ),
      ],
    );
  }
}

/// Generic drag handle wrapper
class _DragHandle extends StatelessWidget {
  final CropHandle handle;
  final MouseCursor cursor;
  final void Function(CropHandle) onDragStart;
  final void Function(double deltaX, double deltaY) onDragUpdate;
  final VoidCallback onDragEnd;
  final Widget child;

  const _DragHandle({
    required this.handle,
    required this.cursor,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: cursor,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: (_) => onDragStart(handle),
        onPanUpdate: (details) =>
            onDragUpdate(details.delta.dx, details.delta.dy),
        onPanEnd: (_) => onDragEnd(),
        child: child,
      ),
    );
  }
}

/// Corner handle widget
class _CornerHandle extends StatelessWidget {
  final CropHandle handle;
  final bool isActive;
  final void Function(CropHandle) onDragStart;
  final void Function(double deltaX, double deltaY) onDragUpdate;
  final VoidCallback onDragEnd;

  const _CornerHandle({
    required this.handle,
    required this.isActive,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
  });

  MouseCursor get _cursor {
    switch (handle) {
      case CropHandle.topLeft:
      case CropHandle.bottomRight:
        return SystemMouseCursors.resizeUpLeftDownRight;
      case CropHandle.topRight:
      case CropHandle.bottomLeft:
        return SystemMouseCursors.resizeUpRightDownLeft;
      default:
        return SystemMouseCursors.basic;
    }
  }

  @override
  Widget build(BuildContext context) {
    return _DragHandle(
      handle: handle,
      cursor: _cursor,
      onDragStart: onDragStart,
      onDragUpdate: onDragUpdate,
      onDragEnd: onDragEnd,
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: isActive ? Colors.white : Colors.white.withAlpha(200),
          border: Border.all(color: Colors.black54, width: 1),
          borderRadius: BorderRadius.circular(4),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(100),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
      ),
    );
  }
}

/// Edge handle widget (invisible hit area)
class _EdgeHandle extends StatelessWidget {
  final CropHandle handle;
  final bool isHorizontal;
  final void Function(CropHandle) onDragStart;
  final void Function(double deltaX, double deltaY) onDragUpdate;
  final VoidCallback onDragEnd;

  const _EdgeHandle({
    required this.handle,
    required this.isHorizontal,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
  });

  MouseCursor get _cursor {
    return isHorizontal
        ? SystemMouseCursors.resizeUpDown
        : SystemMouseCursors.resizeLeftRight;
  }

  @override
  Widget build(BuildContext context) {
    return _DragHandle(
      handle: handle,
      cursor: _cursor,
      onDragStart: onDragStart,
      onDragUpdate: onDragUpdate,
      onDragEnd: onDragEnd,
      child: Container(color: Colors.transparent),
    );
  }
}

/// Paints rule-of-thirds grid
class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withAlpha(80)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    // Vertical lines (thirds)
    canvas.drawLine(
      Offset(size.width / 3, 0),
      Offset(size.width / 3, size.height),
      paint,
    );
    canvas.drawLine(
      Offset(size.width * 2 / 3, 0),
      Offset(size.width * 2 / 3, size.height),
      paint,
    );

    // Horizontal lines (thirds)
    canvas.drawLine(
      Offset(0, size.height / 3),
      Offset(size.width, size.height / 3),
      paint,
    );
    canvas.drawLine(
      Offset(0, size.height * 2 / 3),
      Offset(size.width, size.height * 2 / 3),
      paint,
    );
  }

  @override
  bool shouldRepaint(_GridPainter oldDelegate) => false;
}

/// Shows crop dimensions
class _DimensionLabel extends ConsumerWidget {
  final CropRect cropRect;
  final int viewportWidth;
  final int viewportHeight;

  const _DimensionLabel({
    required this.cropRect,
    required this.viewportWidth,
    required this.viewportHeight,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(playerProvider);
    final metadata = playerState.metadata;

    if (metadata == null) return const SizedBox.shrink();

    // Calculate actual pixel dimensions
    final pixels = cropRect.toPixels(metadata.width, metadata.height);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(180),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '${pixels.width} × ${pixels.height}',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontFamily: 'monospace',
        ),
      ),
    );
  }
}
