import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/stroke.dart';
import '../providers/annotation_provider.dart';
import '../../player/providers/player_provider.dart';
import '../../../core/utils/coordinate_transformer.dart';

/// Annotation overlay widget for drawing on video
class AnnotationOverlay extends ConsumerStatefulWidget {
  const AnnotationOverlay({super.key});

  @override
  ConsumerState<AnnotationOverlay> createState() => _AnnotationOverlayState();
}

class _AnnotationOverlayState extends ConsumerState<AnnotationOverlay> {
  Offset? _currentCursorPosition;
  DateTime? _lastTapTime;
  Offset? _lastTapPosition;

  Size? _resolveVideoSize() {
    final playerState = ref.read(playerProvider);
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

  @override
  Widget build(BuildContext context) {
    final annotationState = ref.watch(annotationProvider);
    final visibleStrokes = ref.watch(visibleAnnotationStrokesProvider);
    final videoRect = ref.watch(
      playerProvider.select((state) => state.videoController?.rect.value),
    );
    final fallbackMetadata = ref.watch(
      playerProvider.select((state) => state.metadata),
    );
    final videoSize = (videoRect != null && videoRect.width > 1 && videoRect.height > 1)
        ? Size(videoRect.width, videoRect.height)
        : (fallbackMetadata == null
              ? null
              : Size(
                  fallbackMetadata.width.toDouble(),
                  fallbackMetadata.height.toDouble(),
                ));

    // Listen for pending text stroke changes to show dialog
    ref.listen<AnnotationState>(annotationProvider, (previous, next) {
      if (next.pendingTextStrokeId != null &&
          (previous?.pendingTextStrokeId != next.pendingTextStrokeId)) {
        _showTextInputDialog(context, next.pendingTextStrokeId!);
      }
    });

    return LayoutBuilder(
      builder: (context, constraints) {
        final viewportSize = Size(constraints.maxWidth, constraints.maxHeight);

        return MouseRegion(
          onHover: (event) {
            if (annotationState.currentTool == DrawingTool.eraser) {
              setState(() {
                _currentCursorPosition = event.localPosition;
              });
            }
          },
          onExit: (_) {
            setState(() {
              _currentCursorPosition = null;
            });
          },
          cursor: annotationState.currentTool == DrawingTool.eraser
              ? SystemMouseCursors.precise
              : annotationState.currentTool == DrawingTool.text
              ? SystemMouseCursors.text
              : MouseCursor.defer,
          child: GestureDetector(
            onPanStart: (details) => _handlePanStart(details, viewportSize),
            onPanUpdate: (details) => _handlePanUpdate(details, viewportSize),
            onPanEnd: (_) => _handlePanEnd(),
            onPanCancel: () => _handlePanCancel(),
            child: CustomPaint(
              size: Size.infinite,
              painter: AnnotationPainter(
                strokes: visibleStrokes,
                currentStroke: annotationState.currentStroke,
                viewportSize: viewportSize,
                videoSize: videoSize,
                currentTool: annotationState.currentTool,
                eraserPosition: _currentCursorPosition,
                selectedStrokeId: annotationState.selectedStrokeId,
                selectedStrokeIds: annotationState.selectedStrokeIds,
                selectionBoxStartPoint: annotationState.selectionBoxStartPoint,
                selectionBoxEndPoint: annotationState.selectionBoxEndPoint,
                isBoxSelecting: annotationState.isBoxSelecting,
              ),
            ),
          ),
        );
      },
    );
  }

  CoordinateTransformer _createTransformer(Size viewportSize) {
    final videoSize = _resolveVideoSize();
    return CoordinateTransformer(viewportSize, videoSize: videoSize);
  }

  void _handlePanStart(DragStartDetails details, Size viewportSize) {
    final now = DateTime.now();
    final position = details.localPosition;

    // Check for double-tap to edit text annotations
    if (_lastTapTime != null &&
        _lastTapPosition != null &&
        now.difference(_lastTapTime!).inMilliseconds < 300 &&
        (position - _lastTapPosition!).distance < 20) {
      _handleDoubleTap(position, viewportSize);
      _lastTapTime = null;
      _lastTapPosition = null;
      return;
    }

    _lastTapTime = now;
    _lastTapPosition = position;

    final transformer = _createTransformer(viewportSize);
    final normalizedPoint = transformer.toNormalized(details.localPosition);
    final annotationState = ref.read(annotationProvider);
    final notifier = ref.read(annotationProvider.notifier);

    // Check if user clicked on a corner handle of a selected stroke
    if (annotationState.currentTool == DrawingTool.select &&
        annotationState.selectedStrokeId != null &&
        annotationState.selectedStrokeIds.length <= 1) {
      final selectedStroke = ref
          .read(visibleAnnotationStrokesProvider)
          .where((s) => s.id == annotationState.selectedStrokeId)
          .firstOrNull;

      if (selectedStroke != null) {
        final corner = _getCornerAtPoint(
          selectedStroke,
          position,
          viewportSize,
        );
        if (corner != null) {
          notifier.startScaling(corner, normalizedPoint);
          return;
        }
      }
    }

    notifier.startStroke(normalizedPoint);
  }

  void _handleDoubleTap(Offset position, Size viewportSize) {
    final transformer = _createTransformer(viewportSize);
    final normalizedPoint = transformer.toNormalized(position);
    final notifier = ref.read(annotationProvider.notifier);

    // Search for a text stroke at this position (reverse order = topmost first)
    final visibleStrokes = ref.read(visibleAnnotationStrokesProvider);
    for (int i = visibleStrokes.length - 1; i >= 0; i--) {
      final stroke = visibleStrokes[i];
      if (stroke.tool == DrawingTool.text &&
          stroke.text != null &&
          stroke.text!.isNotEmpty) {
        // Approximate hit-test for text bounding box
        final anchor = stroke.points.first;
        final textLength = stroke.text!.length;
        final estimatedWidth = textLength * 0.008 * (stroke.fontSize / 16.0);
        final estimatedHeight = 0.025 * (stroke.fontSize / 16.0);
        const threshold = 0.02;

        if (normalizedPoint.x >= anchor.x - threshold &&
            normalizedPoint.x <= anchor.x + estimatedWidth + threshold &&
            normalizedPoint.y >= anchor.y - threshold &&
            normalizedPoint.y <= anchor.y + estimatedHeight + threshold) {
          notifier.editTextStroke(stroke.id);
          return;
        }
      }
    }
  }

  void _showTextInputDialog(BuildContext context, String strokeId) {
    final notifier = ref.read(annotationProvider.notifier);
    final existingStroke = ref
        .read(annotationProvider)
        .allStrokes
        .where((s) => s.id == strokeId)
        .firstOrNull;
    final existingText = existingStroke?.text ?? '';

    final controller = TextEditingController(text: existingText);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Text(existingText.isEmpty ? 'Add Text' : 'Edit Text'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Enter annotation text...',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
          onSubmitted: (value) {
            if (value.trim().isNotEmpty) {
              notifier.confirmTextStroke(value.trim());
            } else {
              notifier.cancelTextStroke();
            }
            Navigator.of(dialogContext).pop();
          },
        ),
        actions: [
          TextButton(
            onPressed: () {
              notifier.cancelTextStroke();
              Navigator.of(dialogContext).pop();
            },
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.isNotEmpty) {
                notifier.confirmTextStroke(value);
              } else {
                notifier.cancelTextStroke();
              }
              Navigator.of(dialogContext).pop();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _handlePanUpdate(DragUpdateDetails details, Size viewportSize) {
    final transformer = _createTransformer(viewportSize);
    final normalizedPoint = transformer.toNormalized(details.localPosition);

    // Update cursor position for eraser visual feedback
    setState(() {
      _currentCursorPosition = details.localPosition;
    });

    final annotationState = ref.read(annotationProvider);
    final notifier = ref.read(annotationProvider.notifier);

    // If scaling, update the scale
    if (annotationState.isScaling) {
      notifier.updateScaling(normalizedPoint);
      return;
    }

    notifier.addPointToStroke(normalizedPoint);
  }

  void _handlePanEnd() {
    final annotationState = ref.read(annotationProvider);
    final notifier = ref.read(annotationProvider.notifier);

    if (annotationState.isScaling) {
      notifier.finishScaling();
      return;
    }

    notifier.finishStroke();
  }

  void _handlePanCancel() {
    final annotationState = ref.read(annotationProvider);
    final notifier = ref.read(annotationProvider.notifier);

    if (annotationState.isScaling) {
      notifier.finishScaling();
      return;
    }

    notifier.cancelStroke();
  }

  /// Get which corner handle (if any) is at the given point
  String? _getCornerAtPoint(Stroke stroke, Offset point, Size viewportSize) {
    if (stroke.points.isEmpty) return null;

    final transformer = _createTransformer(viewportSize);
    const handleSize = 12.0; // Hit area for corner handles

    // Calculate bounding box based on stroke type
    Rect? boundingBox;

    if (stroke.tool == DrawingTool.text &&
        stroke.text != null &&
        stroke.text!.isNotEmpty) {
      // Text bounding box
      final position = transformer.toViewport(stroke.points.first);
      final textSpan = TextSpan(
        text: stroke.text!,
        style: TextStyle(color: stroke.color, fontSize: stroke.fontSize),
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      boundingBox = Rect.fromLTWH(
        position.dx - 4,
        position.dy - 4,
        textPainter.width + 8,
        textPainter.height + 8,
      );
    } else if (stroke.tool == DrawingTool.rectangle ||
        stroke.tool == DrawingTool.circle ||
        stroke.tool == DrawingTool.line ||
        stroke.tool == DrawingTool.arrow) {
      // Shape bounding box
      if (stroke.points.length >= 2) {
        final start = transformer.toViewport(stroke.points.first);
        final end = transformer.toViewport(stroke.points.last);
        final left = start.dx < end.dx ? start.dx : end.dx;
        final top = start.dy < end.dy ? start.dy : end.dy;
        final right = start.dx > end.dx ? start.dx : end.dx;
        final bottom = start.dy > end.dy ? start.dy : end.dy;
        boundingBox = Rect.fromLTRB(left - 4, top - 4, right + 4, bottom + 4);
      }
    } else if (stroke.tool == DrawingTool.pen) {
      // Pen stroke bounding box
      if (stroke.points.isNotEmpty) {
        double minX = double.infinity;
        double minY = double.infinity;
        double maxX = double.negativeInfinity;
        double maxY = double.negativeInfinity;

        for (final p in stroke.points) {
          final viewportPoint = transformer.toViewport(p);
          if (viewportPoint.dx < minX) minX = viewportPoint.dx;
          if (viewportPoint.dy < minY) minY = viewportPoint.dy;
          if (viewportPoint.dx > maxX) maxX = viewportPoint.dx;
          if (viewportPoint.dy > maxY) maxY = viewportPoint.dy;
        }

        boundingBox = Rect.fromLTRB(minX - 4, minY - 4, maxX + 4, maxY + 4);
      }
    }

    if (boundingBox == null) return null;

    // Check each corner
    if ((point - Offset(boundingBox.left, boundingBox.top)).distance <
        handleSize) {
      return 'topLeft';
    }
    if ((point - Offset(boundingBox.right, boundingBox.top)).distance <
        handleSize) {
      return 'topRight';
    }
    if ((point - Offset(boundingBox.left, boundingBox.bottom)).distance <
        handleSize) {
      return 'bottomLeft';
    }
    if ((point - Offset(boundingBox.right, boundingBox.bottom)).distance <
        handleSize) {
      return 'bottomRight';
    }

    return null;
  }
}

/// Custom painter for rendering annotations
class AnnotationPainter extends CustomPainter {
  final List<Stroke> strokes;
  final Stroke? currentStroke;
  final Size viewportSize;
  final Size? videoSize;
  final DrawingTool currentTool;
  final Offset? eraserPosition;
  final String? selectedStrokeId;
  final List<String> selectedStrokeIds;
  final StrokePoint? selectionBoxStartPoint;
  final StrokePoint? selectionBoxEndPoint;
  final bool isBoxSelecting;

  AnnotationPainter({
    required this.strokes,
    required this.currentStroke,
    required this.viewportSize,
    this.videoSize,
    required this.currentTool,
    this.eraserPosition,
    this.selectedStrokeId,
    this.selectedStrokeIds = const [],
    this.selectionBoxStartPoint,
    this.selectionBoxEndPoint,
    this.isBoxSelecting = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final transformer = CoordinateTransformer(
      viewportSize,
      videoSize: videoSize,
    );

    // Draw completed strokes
    final selectedSet = selectedStrokeIds.toSet();
    for (final stroke in strokes) {
      _drawStroke(canvas, stroke, transformer);

      // Draw selection highlight if this stroke is selected
      if (selectedSet.contains(stroke.id) ||
          (selectedSet.isEmpty &&
              selectedStrokeId != null &&
              stroke.id == selectedStrokeId)) {
        _drawSelectionHighlight(canvas, stroke, transformer);
      }
    }

    // Draw current stroke being drawn
    if (currentStroke != null) {
      _drawStroke(canvas, currentStroke!, transformer);
    }

    // Draw eraser cursor
    if (currentTool == DrawingTool.eraser && eraserPosition != null) {
      _drawEraserCursor(canvas, eraserPosition!);
    }

    // Draw marquee selection rectangle
    if (isBoxSelecting &&
        selectionBoxStartPoint != null &&
        selectionBoxEndPoint != null) {
      _drawSelectionBox(canvas, transformer);
    }
  }

  void _drawSelectionBox(Canvas canvas, CoordinateTransformer transformer) {
    final start = transformer.toViewport(selectionBoxStartPoint!);
    final end = transformer.toViewport(selectionBoxEndPoint!);
    final rect = Rect.fromPoints(start, end);

    final fillPaint = Paint()
      ..color = Colors.lightBlueAccent.withValues(alpha: 0.12)
      ..style = PaintingStyle.fill;
    final borderPaint = Paint()
      ..color = Colors.lightBlueAccent.withValues(alpha: 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    canvas.drawRect(rect, fillPaint);
    canvas.drawRect(rect, borderPaint);
  }

  void _drawStroke(
    Canvas canvas,
    Stroke stroke,
    CoordinateTransformer transformer,
  ) {
    if (stroke.points.isEmpty) return;

    // Text strokes have a single point but should be rendered as text, not a dot
    if (stroke.tool == DrawingTool.text) {
      _drawText(canvas, stroke, transformer);
      return;
    }

    // Handle single point
    if (stroke.points.length < 2) {
      final point = transformer.toViewport(stroke.points.first);
      final paint = Paint()
        ..color = stroke.color
        ..strokeWidth = stroke.strokeWidth
        ..style = PaintingStyle.fill;

      canvas.drawCircle(point, stroke.strokeWidth / 2, paint);
      return;
    }

    // Dispatch to appropriate drawing method based on tool type
    switch (stroke.tool) {
      case DrawingTool.pen:
        _drawPenStroke(canvas, stroke, transformer);
        break;
      case DrawingTool.rectangle:
        _drawRectangle(canvas, stroke, transformer);
        break;
      case DrawingTool.circle:
        _drawCircle(canvas, stroke, transformer);
        break;
      case DrawingTool.line:
        _drawLine(canvas, stroke, transformer);
        break;
      case DrawingTool.arrow:
        _drawArrow(canvas, stroke, transformer);
        break;
      case DrawingTool.text:
        // Handled above before the points.length check
        break;
      case DrawingTool.eraser:
      case DrawingTool.select:
        // Eraser and select strokes shouldn't be drawn
        break;
    }
  }

  void _drawPenStroke(
    Canvas canvas,
    Stroke stroke,
    CoordinateTransformer transformer,
  ) {
    final paint = Paint()
      ..color = stroke.color
      ..strokeWidth = stroke.strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final path = Path();
    final offsets = transformer.strokeToOffsets(stroke);

    path.moveTo(offsets.first.dx, offsets.first.dy);

    for (int i = 1; i < offsets.length; i++) {
      path.lineTo(offsets[i].dx, offsets[i].dy);
    }

    canvas.drawPath(path, paint);
  }

  void _drawRectangle(
    Canvas canvas,
    Stroke stroke,
    CoordinateTransformer transformer,
  ) {
    if (stroke.points.length < 2) return;

    final start = transformer.toViewport(stroke.points.first);
    final end = transformer.toViewport(stroke.points.last);

    final rect = Rect.fromPoints(start, end);

    final paint = Paint()
      ..color = stroke.color
      ..strokeWidth = stroke.strokeWidth
      ..style = PaintingStyle.stroke;

    canvas.drawRect(rect, paint);
  }

  void _drawCircle(
    Canvas canvas,
    Stroke stroke,
    CoordinateTransformer transformer,
  ) {
    if (stroke.points.length < 2) return;

    final start = transformer.toViewport(stroke.points.first);
    final end = transformer.toViewport(stroke.points.last);

    final center = Offset((start.dx + end.dx) / 2, (start.dy + end.dy) / 2);

    final radiusX = (end.dx - start.dx).abs() / 2;
    final radiusY = (end.dy - start.dy).abs() / 2;

    final paint = Paint()
      ..color = stroke.color
      ..strokeWidth = stroke.strokeWidth
      ..style = PaintingStyle.stroke;

    // Draw ellipse
    canvas.drawOval(
      Rect.fromCenter(center: center, width: radiusX * 2, height: radiusY * 2),
      paint,
    );
  }

  void _drawLine(
    Canvas canvas,
    Stroke stroke,
    CoordinateTransformer transformer,
  ) {
    if (stroke.points.length < 2) return;

    final start = transformer.toViewport(stroke.points.first);
    final end = transformer.toViewport(stroke.points.last);

    final paint = Paint()
      ..color = stroke.color
      ..strokeWidth = stroke.strokeWidth
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    canvas.drawLine(start, end, paint);
  }

  void _drawArrow(
    Canvas canvas,
    Stroke stroke,
    CoordinateTransformer transformer,
  ) {
    if (stroke.points.length < 2) return;

    final start = transformer.toViewport(stroke.points.first);
    final end = transformer.toViewport(stroke.points.last);

    final paint = Paint()
      ..color = stroke.color
      ..strokeWidth = stroke.strokeWidth
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // Draw line
    canvas.drawLine(start, end, paint);

    // Calculate arrowhead
    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;
    final angle = atan2(dy, dx);

    final arrowSize = stroke.strokeWidth * 3;
    const arrowAngle = pi / 6; // 30 degrees

    // Arrowhead points
    final arrowPoint1 = Offset(
      end.dx - arrowSize * cos(angle - arrowAngle),
      end.dy - arrowSize * sin(angle - arrowAngle),
    );

    final arrowPoint2 = Offset(
      end.dx - arrowSize * cos(angle + arrowAngle),
      end.dy - arrowSize * sin(angle + arrowAngle),
    );

    // Draw arrowhead
    final arrowPath = Path()
      ..moveTo(arrowPoint1.dx, arrowPoint1.dy)
      ..lineTo(end.dx, end.dy)
      ..lineTo(arrowPoint2.dx, arrowPoint2.dy);

    canvas.drawPath(arrowPath, paint);
  }

  void _drawText(
    Canvas canvas,
    Stroke stroke,
    CoordinateTransformer transformer,
  ) {
    if (stroke.points.isEmpty || stroke.text == null || stroke.text!.isEmpty)
      return;

    final position = transformer.toViewport(stroke.points.first);

    final textSpan = TextSpan(
      text: stroke.text!,
      style: TextStyle(color: stroke.color, fontSize: stroke.fontSize),
    );

    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    );

    textPainter.layout();
    textPainter.paint(canvas, position);
  }

  void _drawSelectionHighlight(
    Canvas canvas,
    Stroke stroke,
    CoordinateTransformer transformer,
  ) {
    if (stroke.points.isEmpty) return;

    final highlightPaint = Paint()
      ..color = Colors.blue.withValues(alpha: 0.3)
      ..strokeWidth = stroke.strokeWidth + 6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    // Draw bounding box for text strokes
    if (stroke.tool == DrawingTool.text) {
      if (stroke.points.isNotEmpty &&
          stroke.text != null &&
          stroke.text!.isNotEmpty) {
        final position = transformer.toViewport(stroke.points.first);

        final textSpan = TextSpan(
          text: stroke.text!,
          style: TextStyle(color: stroke.color, fontSize: stroke.fontSize),
        );
        final textPainter = TextPainter(
          text: textSpan,
          textDirection: TextDirection.ltr,
        );
        textPainter.layout();

        final selectionRect = Rect.fromLTWH(
          position.dx - 4,
          position.dy - 4,
          textPainter.width + 8,
          textPainter.height + 8,
        );

        final selectionPaint = Paint()
          ..color = Colors.blue.withValues(alpha: 0.5)
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke;
        canvas.drawRect(selectionRect, selectionPaint);

        final handlePaint = Paint()
          ..color = Colors.white
          ..style = PaintingStyle.fill;
        final borderPaint = Paint()
          ..color = Colors.blue
          ..strokeWidth = 1
          ..style = PaintingStyle.stroke;
        const handleSize = 6.0;

        canvas.drawCircle(
          Offset(selectionRect.left, selectionRect.top),
          handleSize,
          handlePaint,
        );
        canvas.drawCircle(
          Offset(selectionRect.left, selectionRect.top),
          handleSize,
          borderPaint,
        );
        canvas.drawCircle(
          Offset(selectionRect.right, selectionRect.top),
          handleSize,
          handlePaint,
        );
        canvas.drawCircle(
          Offset(selectionRect.right, selectionRect.top),
          handleSize,
          borderPaint,
        );
        canvas.drawCircle(
          Offset(selectionRect.left, selectionRect.bottom),
          handleSize,
          handlePaint,
        );
        canvas.drawCircle(
          Offset(selectionRect.left, selectionRect.bottom),
          handleSize,
          borderPaint,
        );
        canvas.drawCircle(
          Offset(selectionRect.right, selectionRect.bottom),
          handleSize,
          handlePaint,
        );
        canvas.drawCircle(
          Offset(selectionRect.right, selectionRect.bottom),
          handleSize,
          borderPaint,
        );
      }
    } else
    // Draw bounding box for shapes
    if (stroke.tool == DrawingTool.rectangle ||
        stroke.tool == DrawingTool.circle ||
        stroke.tool == DrawingTool.line ||
        stroke.tool == DrawingTool.arrow) {
      if (stroke.points.length >= 2) {
        final start = transformer.toViewport(stroke.points.first);
        final end = transformer.toViewport(stroke.points.last);

        final left = start.dx < end.dx ? start.dx : end.dx;
        final right = start.dx > end.dx ? start.dx : end.dx;
        final top = start.dy < end.dy ? start.dy : end.dy;
        final bottom = start.dy > end.dy ? start.dy : end.dy;

        final selectionRect = Rect.fromLTRB(
          left - 8,
          top - 8,
          right + 8,
          bottom + 8,
        );

        final selectionPaint = Paint()
          ..color = Colors.blue.withValues(alpha: 0.5)
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke;

        canvas.drawRect(selectionRect, selectionPaint);

        // Draw corner handles
        final handlePaint = Paint()
          ..color = Colors.white
          ..style = PaintingStyle.fill;

        final borderPaint = Paint()
          ..color = Colors.blue
          ..strokeWidth = 1
          ..style = PaintingStyle.stroke;

        const handleSize = 6.0;

        // Top-left
        canvas.drawCircle(
          Offset(selectionRect.left, selectionRect.top),
          handleSize,
          handlePaint,
        );
        canvas.drawCircle(
          Offset(selectionRect.left, selectionRect.top),
          handleSize,
          borderPaint,
        );

        // Top-right
        canvas.drawCircle(
          Offset(selectionRect.right, selectionRect.top),
          handleSize,
          handlePaint,
        );
        canvas.drawCircle(
          Offset(selectionRect.right, selectionRect.top),
          handleSize,
          borderPaint,
        );

        // Bottom-left
        canvas.drawCircle(
          Offset(selectionRect.left, selectionRect.bottom),
          handleSize,
          handlePaint,
        );
        canvas.drawCircle(
          Offset(selectionRect.left, selectionRect.bottom),
          handleSize,
          borderPaint,
        );

        // Bottom-right
        canvas.drawCircle(
          Offset(selectionRect.right, selectionRect.bottom),
          handleSize,
          handlePaint,
        );
        canvas.drawCircle(
          Offset(selectionRect.right, selectionRect.bottom),
          handleSize,
          borderPaint,
        );
      }
    } else {
      // For pen strokes, draw a highlighted version
      final path = Path();
      final offsets = transformer.strokeToOffsets(stroke);

      if (offsets.isNotEmpty) {
        path.moveTo(offsets.first.dx, offsets.first.dy);

        for (int i = 1; i < offsets.length; i++) {
          path.lineTo(offsets[i].dx, offsets[i].dy);
        }

        canvas.drawPath(path, highlightPaint);
      }
    }
  }

  void _drawEraserCursor(Canvas canvas, Offset position) {
    // Draw eraser circle outline
    final eraserPaint = Paint()
      ..color = Colors.red.withValues(alpha: 0.5)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    // Eraser radius in pixels (proportional to viewport)
    final eraserRadiusPx = viewportSize.width * 0.02;

    canvas.drawCircle(position, eraserRadiusPx, eraserPaint);

    // Draw crosshair
    final crosshairPaint = Paint()
      ..color = Colors.red.withValues(alpha: 0.7)
      ..strokeWidth = 1.0;

    canvas.drawLine(
      Offset(position.dx - eraserRadiusPx, position.dy),
      Offset(position.dx + eraserRadiusPx, position.dy),
      crosshairPaint,
    );
    canvas.drawLine(
      Offset(position.dx, position.dy - eraserRadiusPx),
      Offset(position.dx, position.dy + eraserRadiusPx),
      crosshairPaint,
    );
  }

  @override
  bool shouldRepaint(AnnotationPainter oldDelegate) {
    return oldDelegate.strokes != strokes ||
        oldDelegate.currentStroke != currentStroke ||
        oldDelegate.viewportSize != viewportSize ||
        oldDelegate.videoSize != videoSize ||
        oldDelegate.currentTool != currentTool ||
        oldDelegate.eraserPosition != eraserPosition ||
        oldDelegate.selectedStrokeId != selectedStrokeId ||
        oldDelegate.selectedStrokeIds != selectedStrokeIds ||
        oldDelegate.selectionBoxStartPoint != selectionBoxStartPoint ||
        oldDelegate.selectionBoxEndPoint != selectionBoxEndPoint ||
        oldDelegate.isBoxSelecting != isBoxSelecting;
  }
}
