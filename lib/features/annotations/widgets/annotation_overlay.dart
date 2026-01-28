import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/stroke.dart';
import '../providers/annotation_provider.dart';
import '../../../core/utils/coordinate_transformer.dart';

/// Annotation overlay widget for drawing on video
class AnnotationOverlay extends ConsumerStatefulWidget {
  const AnnotationOverlay({super.key});

  @override
  ConsumerState<AnnotationOverlay> createState() => _AnnotationOverlayState();
}

class _AnnotationOverlayState extends ConsumerState<AnnotationOverlay> {
  Offset? _currentCursorPosition;

  @override
  Widget build(BuildContext context) {
    final annotationState = ref.watch(annotationProvider);

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
              : MouseCursor.defer,
          child: GestureDetector(
            onPanStart: (details) => _handlePanStart(details, viewportSize),
            onPanUpdate: (details) => _handlePanUpdate(details, viewportSize),
            onPanEnd: (_) => _handlePanEnd(),
            onPanCancel: () => _handlePanCancel(),
            child: CustomPaint(
              size: Size.infinite,
              painter: AnnotationPainter(
                strokes: annotationState.allStrokes,
                currentStroke: annotationState.currentStroke,
                viewportSize: viewportSize,
                currentTool: annotationState.currentTool,
                eraserPosition: _currentCursorPosition,
                selectedStrokeId: annotationState.selectedStrokeId,
              ),
            ),
          ),
        );
      },
    );
  }

  void _handlePanStart(DragStartDetails details, Size viewportSize) {
    final transformer = CoordinateTransformer(viewportSize);
    final normalizedPoint = transformer.toNormalized(details.localPosition);

    ref.read(annotationProvider.notifier).startStroke(normalizedPoint);
  }

  void _handlePanUpdate(DragUpdateDetails details, Size viewportSize) {
    final transformer = CoordinateTransformer(viewportSize);
    final normalizedPoint = transformer.toNormalized(details.localPosition);

    // Update cursor position for eraser visual feedback
    setState(() {
      _currentCursorPosition = details.localPosition;
    });

    ref.read(annotationProvider.notifier).addPointToStroke(normalizedPoint);
  }

  void _handlePanEnd() {
    ref.read(annotationProvider.notifier).finishStroke();
  }

  void _handlePanCancel() {
    ref.read(annotationProvider.notifier).cancelStroke();
  }
}

/// Custom painter for rendering annotations
class AnnotationPainter extends CustomPainter {
  final List<Stroke> strokes;
  final Stroke? currentStroke;
  final Size viewportSize;
  final DrawingTool currentTool;
  final Offset? eraserPosition;
  final String? selectedStrokeId;

  AnnotationPainter({
    required this.strokes,
    required this.currentStroke,
    required this.viewportSize,
    required this.currentTool,
    this.eraserPosition,
    this.selectedStrokeId,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final transformer = CoordinateTransformer(viewportSize);

    // Draw completed strokes
    for (final stroke in strokes) {
      _drawStroke(canvas, stroke, transformer);

      // Draw selection highlight if this stroke is selected
      if (selectedStrokeId != null && stroke.id == selectedStrokeId) {
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
  }

  void _drawStroke(Canvas canvas, Stroke stroke, CoordinateTransformer transformer) {
    if (stroke.points.isEmpty) return;

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
      case DrawingTool.eraser:
      case DrawingTool.select:
        // Eraser and select strokes shouldn't be drawn
        break;
    }
  }

  void _drawPenStroke(Canvas canvas, Stroke stroke, CoordinateTransformer transformer) {
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

  void _drawRectangle(Canvas canvas, Stroke stroke, CoordinateTransformer transformer) {
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

  void _drawCircle(Canvas canvas, Stroke stroke, CoordinateTransformer transformer) {
    if (stroke.points.length < 2) return;

    final start = transformer.toViewport(stroke.points.first);
    final end = transformer.toViewport(stroke.points.last);

    final center = Offset(
      (start.dx + end.dx) / 2,
      (start.dy + end.dy) / 2,
    );

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

  void _drawLine(Canvas canvas, Stroke stroke, CoordinateTransformer transformer) {
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

  void _drawArrow(Canvas canvas, Stroke stroke, CoordinateTransformer transformer) {
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

  void _drawSelectionHighlight(Canvas canvas, Stroke stroke, CoordinateTransformer transformer) {
    if (stroke.points.isEmpty) return;

    final highlightPaint = Paint()
      ..color = Colors.blue.withValues(alpha: 0.3)
      ..strokeWidth = stroke.strokeWidth + 6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

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
        canvas.drawCircle(Offset(selectionRect.left, selectionRect.top), handleSize, handlePaint);
        canvas.drawCircle(Offset(selectionRect.left, selectionRect.top), handleSize, borderPaint);

        // Top-right
        canvas.drawCircle(Offset(selectionRect.right, selectionRect.top), handleSize, handlePaint);
        canvas.drawCircle(Offset(selectionRect.right, selectionRect.top), handleSize, borderPaint);

        // Bottom-left
        canvas.drawCircle(Offset(selectionRect.left, selectionRect.bottom), handleSize, handlePaint);
        canvas.drawCircle(Offset(selectionRect.left, selectionRect.bottom), handleSize, borderPaint);

        // Bottom-right
        canvas.drawCircle(Offset(selectionRect.right, selectionRect.bottom), handleSize, handlePaint);
        canvas.drawCircle(Offset(selectionRect.right, selectionRect.bottom), handleSize, borderPaint);
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
        oldDelegate.currentTool != currentTool ||
        oldDelegate.eraserPosition != eraserPosition ||
        oldDelegate.selectedStrokeId != selectedStrokeId;
  }
}
