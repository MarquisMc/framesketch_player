import 'dart:math';

import 'package:flutter/material.dart';

import '../../../core/utils/coordinate_transformer.dart';
import '../models/stroke.dart';
import 'annotation_text_metrics.dart';

/// Custom painter for rendering annotations.
class AnnotationPainter extends CustomPainter {
  static const Color _selectionAccentColor = Color(0xFF4FC3F7);
  static final Paint _selectionHandleFillPaint = Paint()
    ..color = Colors.white
    ..style = PaintingStyle.fill;
  static final Paint _selectionHandleBorderPaint = Paint()
    ..color = _selectionAccentColor
    ..strokeWidth = 1.5
    ..style = PaintingStyle.stroke;
  static final Paint _selectionHandleShadowPaint = Paint()
    ..color = Colors.black.withValues(alpha: 0.28)
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);

  final List<Stroke> strokes;
  final Stroke? currentStroke;
  final Size viewportSize;
  final Size? videoSize;
  final DrawingTool currentTool;
  final Offset? eraserPosition;
  final double eraserRadius;
  final String? selectedStrokeId;
  final List<String> selectedStrokeIds;
  final StrokePoint? selectionBoxStartPoint;
  final StrokePoint? selectionBoxEndPoint;
  final bool isBoxSelecting;
  final String? editingTextStrokeId;
  final TextDirection textDirection;

  AnnotationPainter({
    required this.strokes,
    required this.currentStroke,
    required this.viewportSize,
    this.videoSize,
    required this.currentTool,
    this.eraserPosition,
    this.eraserRadius = 0.02,
    this.selectedStrokeId,
    this.selectedStrokeIds = const [],
    this.selectionBoxStartPoint,
    this.selectionBoxEndPoint,
    this.isBoxSelecting = false,
    this.editingTextStrokeId,
    required this.textDirection,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final transformer = CoordinateTransformer(
      viewportSize,
      videoSize: videoSize,
    );

    final selectedSet = selectedStrokeIds.toSet();
    for (final stroke in strokes) {
      final isEditingTextStroke =
          editingTextStrokeId != null &&
          stroke.id == editingTextStrokeId &&
          stroke.tool == DrawingTool.text;
      if (isEditingTextStroke) {
        continue;
      }

      _drawStroke(canvas, stroke, transformer);

      if (selectedSet.contains(stroke.id) ||
          (selectedSet.isEmpty &&
              selectedStrokeId != null &&
              stroke.id == selectedStrokeId)) {
        _drawSelectionHighlight(canvas, stroke, transformer);
      }
    }

    if (currentStroke != null) {
      _drawStroke(canvas, currentStroke!, transformer);
    }

    if (currentTool == DrawingTool.eraser && eraserPosition != null) {
      _drawEraserCursor(canvas, eraserPosition!);
    }

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

    if (stroke.tool == DrawingTool.text) {
      _drawText(canvas, stroke, transformer);
      return;
    }

    if (stroke.points.length < 2) {
      final point = transformer.toViewport(stroke.points.first);
      final paint = Paint()
        ..color = stroke.color
        ..strokeWidth = stroke.strokeWidth
        ..style = PaintingStyle.fill;

      canvas.drawCircle(point, stroke.strokeWidth / 2, paint);
      return;
    }

    switch (stroke.tool) {
      case DrawingTool.pen:
        _drawPenStroke(canvas, stroke, transformer);
        break;
      case DrawingTool.rectangle:
        _drawRectangle(canvas, stroke, transformer);
        break;
      case DrawingTool.filledSquare:
        _drawFilledSquare(canvas, stroke, transformer);
        break;
      case DrawingTool.circle:
        _drawCircle(canvas, stroke, transformer);
        break;
      case DrawingTool.filledCircle:
        _drawFilledCircle(canvas, stroke, transformer);
        break;
      case DrawingTool.line:
        _drawLine(canvas, stroke, transformer);
        break;
      case DrawingTool.arrow:
        _drawArrow(canvas, stroke, transformer);
        break;
      case DrawingTool.text:
        break;
      case DrawingTool.eraser:
        break;
      case DrawingTool.select:
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

    canvas.drawOval(
      Rect.fromCenter(center: center, width: radiusX * 2, height: radiusY * 2),
      paint,
    );
  }

  void _drawFilledSquare(
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
      ..style = PaintingStyle.fill;

    canvas.drawRect(rect, paint);
  }

  void _drawFilledCircle(
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
      ..style = PaintingStyle.fill;

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

    canvas.drawLine(start, end, paint);

    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;
    final angle = atan2(dy, dx);

    final arrowSize = stroke.strokeWidth * 3;
    const arrowAngle = pi / 6;
    final arrowPoint1 = Offset(
      end.dx - arrowSize * cos(angle - arrowAngle),
      end.dy - arrowSize * sin(angle - arrowAngle),
    );
    final arrowPoint2 = Offset(
      end.dx - arrowSize * cos(angle + arrowAngle),
      end.dy - arrowSize * sin(angle + arrowAngle),
    );

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
    if (stroke.points.isEmpty || stroke.text == null || stroke.text!.isEmpty) {
      return;
    }

    final position = transformer.toViewport(stroke.points.first);
    final textSpan = TextSpan(
      text: stroke.text!,
      style: textStyleForStroke(
        stroke,
        fontSize: scaledFontSizeForStroke(stroke, transformer),
      ),
    );
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: textDirection,
      maxLines: null,
    );

    if (stroke.points.length >= 2) {
      final textRect = Rect.fromPoints(
        transformer.toViewport(stroke.points.first),
        transformer.toViewport(stroke.points.last),
      );
      final maxWidth = textRect.width <= 1 ? 1.0 : textRect.width;
      textPainter.layout(maxWidth: maxWidth);

      canvas.save();
      canvas.clipRect(textRect);
      textPainter.paint(canvas, textRect.topLeft);
      canvas.restore();
      return;
    }

    textPainter.layout();
    textPainter.paint(canvas, position);
  }

  void _drawSelectionHighlight(
    Canvas canvas,
    Stroke stroke,
    CoordinateTransformer transformer,
  ) {
    if (stroke.points.isEmpty) return;

    final selectionRect = _selectionRect(stroke, transformer);
    if (selectionRect == null) return;

    canvas.drawRect(
      selectionRect,
      Paint()
        ..color = _selectionAccentColor.withValues(alpha: 0.07)
        ..style = PaintingStyle.fill,
    );

    final glowPaint = Paint()
      ..color = _selectionAccentColor.withValues(alpha: 0.22)
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawRect(selectionRect, glowPaint);

    final borderPaint = Paint()
      ..color = _selectionAccentColor.withValues(alpha: 0.9)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    canvas.drawRect(selectionRect, borderPaint);

    _drawCornerHandle(canvas, Offset(selectionRect.left, selectionRect.top));
    _drawCornerHandle(canvas, Offset(selectionRect.right, selectionRect.top));
    _drawCornerHandle(canvas, Offset(selectionRect.left, selectionRect.bottom));
    _drawCornerHandle(
      canvas,
      Offset(selectionRect.right, selectionRect.bottom),
    );

    if (stroke.tool != DrawingTool.text) {
      _drawEdgeHandle(
        canvas,
        Rect.fromCenter(
          center: Offset(selectionRect.center.dx, selectionRect.top),
          width: 20,
          height: 7,
        ),
      );
      _drawEdgeHandle(
        canvas,
        Rect.fromCenter(
          center: Offset(selectionRect.center.dx, selectionRect.bottom),
          width: 20,
          height: 7,
        ),
      );
      _drawEdgeHandle(
        canvas,
        Rect.fromCenter(
          center: Offset(selectionRect.left, selectionRect.center.dy),
          width: 7,
          height: 20,
        ),
      );
      _drawEdgeHandle(
        canvas,
        Rect.fromCenter(
          center: Offset(selectionRect.right, selectionRect.center.dy),
          width: 7,
          height: 20,
        ),
      );
    }
  }

  Rect? _selectionRect(Stroke stroke, CoordinateTransformer transformer) {
    if (stroke.tool == DrawingTool.text) {
      if (stroke.text == null || stroke.text!.isEmpty) return null;
      final position = transformer.toViewport(stroke.points.first);
      final textSpan = TextSpan(
        text: stroke.text!,
        style: textStyleForStroke(
          stroke,
          fontSize: scaledFontSizeForStroke(stroke, transformer),
        ),
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: textDirection,
        maxLines: null,
      );
      if (stroke.points.length < 2) {
        textPainter.layout();
      }

      return stroke.points.length >= 2
          ? Rect.fromPoints(
              transformer.toViewport(stroke.points.first),
              transformer.toViewport(stroke.points.last),
            )
          : Rect.fromLTWH(
              position.dx - 4,
              position.dy - 4,
              textPainter.width + 8,
              textPainter.height + 8,
            );
    }

    double minX = double.infinity;
    double minY = double.infinity;
    double maxX = double.negativeInfinity;
    double maxY = double.negativeInfinity;

    for (final point in stroke.points) {
      final viewportPoint = transformer.toViewport(point);
      if (viewportPoint.dx < minX) minX = viewportPoint.dx;
      if (viewportPoint.dy < minY) minY = viewportPoint.dy;
      if (viewportPoint.dx > maxX) maxX = viewportPoint.dx;
      if (viewportPoint.dy > maxY) maxY = viewportPoint.dy;
    }

    return Rect.fromLTRB(minX - 8, minY - 8, maxX + 8, maxY + 8);
  }

  void _drawCornerHandle(Canvas canvas, Offset center) {
    const halfSize = 5.0;
    const radius = Radius.circular(3);
    final rect = Rect.fromCenter(
      center: center,
      width: halfSize * 2,
      height: halfSize * 2,
    );
    final rrect = RRect.fromRectAndRadius(rect, radius);
    canvas.drawRRect(rrect, _selectionHandleShadowPaint);
    canvas.drawRRect(rrect, _selectionHandleFillPaint);
    canvas.drawRRect(rrect, _selectionHandleBorderPaint);
  }

  void _drawEdgeHandle(Canvas canvas, Rect rect) {
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(4));
    canvas.drawRRect(rrect, _selectionHandleShadowPaint);
    canvas.drawRRect(rrect, _selectionHandleFillPaint);
    canvas.drawRRect(rrect, _selectionHandleBorderPaint);
  }

  void _drawEraserCursor(Canvas canvas, Offset position) {
    final eraserPaint = Paint()
      ..color = Colors.red.withValues(alpha: 0.5)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;
    final eraserRadiusPx = viewportSize.width * eraserRadius;

    canvas.drawCircle(position, eraserRadiusPx, eraserPaint);

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
        oldDelegate.textDirection != textDirection ||
        oldDelegate.currentTool != currentTool ||
        oldDelegate.eraserPosition != eraserPosition ||
        oldDelegate.eraserRadius != eraserRadius ||
        oldDelegate.selectedStrokeId != selectedStrokeId ||
        oldDelegate.selectedStrokeIds != selectedStrokeIds ||
        oldDelegate.selectionBoxStartPoint != selectionBoxStartPoint ||
        oldDelegate.selectionBoxEndPoint != selectionBoxEndPoint ||
        oldDelegate.isBoxSelecting != isBoxSelecting ||
        oldDelegate.editingTextStrokeId != editingTextStrokeId;
  }
}
