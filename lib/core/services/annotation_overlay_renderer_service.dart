import 'dart:io';
import 'dart:math' show atan2, cos, sin;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../features/annotations/models/stroke.dart';

const double _textReferenceVideoHeight = 720.0;

@immutable
class OverlayTransform {
  final int outputWidth;
  final int outputHeight;
  final int viewportWidth;
  final int viewportHeight;
  final double videoLeftInViewport;
  final double videoTopInViewport;
  final double videoWidthInViewport;
  final double videoHeightInViewport;
  final double styleScaleFactor;
  final bool usesViewportProjection;
  final double sourceCropLeft;
  final double sourceCropTop;
  final double sourceCropWidth;
  final double sourceCropHeight;

  const OverlayTransform({
    required this.outputWidth,
    required this.outputHeight,
    required this.viewportWidth,
    required this.viewportHeight,
    required this.videoLeftInViewport,
    required this.videoTopInViewport,
    required this.videoWidthInViewport,
    required this.videoHeightInViewport,
    required this.styleScaleFactor,
    required this.usesViewportProjection,
    this.sourceCropLeft = 0.0,
    this.sourceCropTop = 0.0,
    this.sourceCropWidth = 1.0,
    this.sourceCropHeight = 1.0,
  }) : assert(sourceCropWidth > 0, 'sourceCropWidth must be positive'),
       assert(sourceCropHeight > 0, 'sourceCropHeight must be positive');

  Offset toOutputOffset(StrokePoint point) {
    // Annotation points are stored in video-normalized space.
    // Export should mirror in-app rendering exactly while allowing cropped
    // overlay buffers to avoid full-source-size transparent frames.
    return Offset(
      ((point.x - sourceCropLeft) / sourceCropWidth) * outputWidth,
      ((point.y - sourceCropTop) / sourceCropHeight) * outputHeight,
    );
  }
}

class AnnotationOverlayRendererService {
  Future<void> renderOverlayImage({
    required String outputPath,
    required List<Stroke> strokes,
    required int width,
    required int height,
    required int viewportWidth,
    required int viewportHeight,
    double sourceCropLeft = 0.0,
    double sourceCropTop = 0.0,
    double sourceCropWidth = 1.0,
    double sourceCropHeight = 1.0,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(
      recorder,
      Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    );
    final transform = createOverlayTransform(
      outputWidth: width,
      outputHeight: height,
      viewportWidth: viewportWidth,
      viewportHeight: viewportHeight,
      sourceCropLeft: sourceCropLeft,
      sourceCropTop: sourceCropTop,
      sourceCropWidth: sourceCropWidth,
      sourceCropHeight: sourceCropHeight,
    );

    for (final stroke in strokes) {
      _drawStroke(canvas, stroke, transform);
    }

    final picture = recorder.endRecording();
    final image = await picture.toImage(width, height);
    final pngBytes = await image.toByteData(format: ui.ImageByteFormat.png);

    if (pngBytes == null) {
      throw Exception('Failed to encode annotation overlay as PNG.');
    }

    await File(
      outputPath,
    ).writeAsBytes(pngBytes.buffer.asUint8List(), flush: true);
  }

  @visibleForTesting
  OverlayTransform createOverlayTransform({
    required int outputWidth,
    required int outputHeight,
    required int viewportWidth,
    required int viewportHeight,
    double sourceCropLeft = 0.0,
    double sourceCropTop = 0.0,
    double sourceCropWidth = 1.0,
    double sourceCropHeight = 1.0,
  }) {
    final safeOutputWidth = outputWidth > 0 ? outputWidth : 1;
    final safeOutputHeight = outputHeight > 0 ? outputHeight : 1;
    final safeCropWidth = sourceCropWidth > 0 ? sourceCropWidth : 1.0;
    final safeCropHeight = sourceCropHeight > 0 ? sourceCropHeight : 1.0;

    return OverlayTransform(
      outputWidth: safeOutputWidth,
      outputHeight: safeOutputHeight,
      viewportWidth: viewportWidth,
      viewportHeight: viewportHeight,
      videoLeftInViewport: 0.0,
      videoTopInViewport: 0.0,
      videoWidthInViewport: safeOutputWidth.toDouble(),
      videoHeightInViewport: safeOutputHeight.toDouble(),
      styleScaleFactor: (safeOutputHeight / _textReferenceVideoHeight)
          .clamp(0.01, double.infinity)
          .toDouble(),
      usesViewportProjection: false,
      sourceCropLeft: sourceCropLeft,
      sourceCropTop: sourceCropTop,
      sourceCropWidth: safeCropWidth,
      sourceCropHeight: safeCropHeight,
    );
  }

  void _drawStroke(Canvas canvas, Stroke stroke, OverlayTransform transform) {
    if (stroke.points.isEmpty) return;

    final strokeWidth = (stroke.strokeWidth * transform.styleScaleFactor).clamp(
      1.0,
      64.0,
    );
    final fontSize = (stroke.fontSize * transform.styleScaleFactor).clamp(
      6.0,
      256.0,
    );

    if (stroke.tool == DrawingTool.text) {
      _drawText(canvas, stroke, transform, fontSize);
      return;
    }

    if (stroke.points.length < 2) {
      final point = _toOffset(stroke.points.first, transform);
      final paint = Paint()
        ..color = stroke.color
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.fill;
      canvas.drawCircle(point, strokeWidth / 2, paint);
      return;
    }

    switch (stroke.tool) {
      case DrawingTool.pen:
        _drawPen(canvas, stroke, transform, strokeWidth);
        break;
      case DrawingTool.rectangle:
        _drawRectangle(canvas, stroke, transform, strokeWidth);
        break;
      case DrawingTool.filledSquare:
        _drawFilledSquare(canvas, stroke, transform);
        break;
      case DrawingTool.circle:
        _drawCircle(canvas, stroke, transform, strokeWidth);
        break;
      case DrawingTool.filledCircle:
        _drawFilledCircle(canvas, stroke, transform);
        break;
      case DrawingTool.line:
        _drawLine(canvas, stroke, transform, strokeWidth);
        break;
      case DrawingTool.arrow:
        _drawArrow(canvas, stroke, transform, strokeWidth);
        break;
      case DrawingTool.text:
        break;
      case DrawingTool.eraser:
      case DrawingTool.select:
        break;
    }
  }

  Offset _toOffset(StrokePoint p, OverlayTransform transform) {
    return transform.toOutputOffset(p);
  }

  void _drawPen(
    Canvas canvas,
    Stroke stroke,
    OverlayTransform transform,
    double strokeWidth,
  ) {
    final paint = Paint()
      ..color = stroke.color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final path = Path();
    final first = _toOffset(stroke.points.first, transform);
    path.moveTo(first.dx, first.dy);
    for (int i = 1; i < stroke.points.length; i++) {
      final p = _toOffset(stroke.points[i], transform);
      path.lineTo(p.dx, p.dy);
    }

    canvas.drawPath(path, paint);
  }

  void _drawRectangle(
    Canvas canvas,
    Stroke stroke,
    OverlayTransform transform,
    double strokeWidth,
  ) {
    final p1 = _toOffset(stroke.points.first, transform);
    final p2 = _toOffset(stroke.points.last, transform);
    final paint = Paint()
      ..color = stroke.color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;
    canvas.drawRect(Rect.fromPoints(p1, p2), paint);
  }

  void _drawCircle(
    Canvas canvas,
    Stroke stroke,
    OverlayTransform transform,
    double strokeWidth,
  ) {
    final p1 = _toOffset(stroke.points.first, transform);
    final p2 = _toOffset(stroke.points.last, transform);
    final center = Offset((p1.dx + p2.dx) / 2, (p1.dy + p2.dy) / 2);
    final rx = (p2.dx - p1.dx).abs() / 2;
    final ry = (p2.dy - p1.dy).abs() / 2;
    final paint = Paint()
      ..color = stroke.color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;
    canvas.drawOval(
      Rect.fromCenter(center: center, width: rx * 2, height: ry * 2),
      paint,
    );
  }

  void _drawFilledSquare(
    Canvas canvas,
    Stroke stroke,
    OverlayTransform transform,
  ) {
    final p1 = _toOffset(stroke.points.first, transform);
    final p2 = _toOffset(stroke.points.last, transform);
    final paint = Paint()
      ..color = stroke.color
      ..style = PaintingStyle.fill;
    canvas.drawRect(Rect.fromPoints(p1, p2), paint);
  }

  void _drawFilledCircle(
    Canvas canvas,
    Stroke stroke,
    OverlayTransform transform,
  ) {
    final p1 = _toOffset(stroke.points.first, transform);
    final p2 = _toOffset(stroke.points.last, transform);
    final center = Offset((p1.dx + p2.dx) / 2, (p1.dy + p2.dy) / 2);
    final rx = (p2.dx - p1.dx).abs() / 2;
    final ry = (p2.dy - p1.dy).abs() / 2;
    final paint = Paint()
      ..color = stroke.color
      ..style = PaintingStyle.fill;
    canvas.drawOval(
      Rect.fromCenter(center: center, width: rx * 2, height: ry * 2),
      paint,
    );
  }

  void _drawLine(
    Canvas canvas,
    Stroke stroke,
    OverlayTransform transform,
    double strokeWidth,
  ) {
    final p1 = _toOffset(stroke.points.first, transform);
    final p2 = _toOffset(stroke.points.last, transform);
    final paint = Paint()
      ..color = stroke.color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawLine(p1, p2, paint);
  }

  void _drawArrow(
    Canvas canvas,
    Stroke stroke,
    OverlayTransform transform,
    double strokeWidth,
  ) {
    final p1 = _toOffset(stroke.points.first, transform);
    final p2 = _toOffset(stroke.points.last, transform);
    final paint = Paint()
      ..color = stroke.color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawLine(p1, p2, paint);

    final dx = p2.dx - p1.dx;
    final dy = p2.dy - p1.dy;
    final angle = atan2(dy, dx);
    final arrowSize = strokeWidth * 3;
    const arrowAngle = 0.5235987756; // pi/6
    final a1 = Offset(
      p2.dx - arrowSize * cos(angle - arrowAngle),
      p2.dy - arrowSize * sin(angle - arrowAngle),
    );
    final a2 = Offset(
      p2.dx - arrowSize * cos(angle + arrowAngle),
      p2.dy - arrowSize * sin(angle + arrowAngle),
    );
    final path = Path()
      ..moveTo(a1.dx, a1.dy)
      ..lineTo(p2.dx, p2.dy)
      ..lineTo(a2.dx, a2.dy);
    canvas.drawPath(path, paint);
  }

  void _drawText(
    Canvas canvas,
    Stroke stroke,
    OverlayTransform transform,
    double fontSize,
  ) {
    if (stroke.text == null || stroke.text!.trim().isEmpty) return;
    final anchor = _toOffset(stroke.points.first, transform);
    final span = TextSpan(
      text: stroke.text!,
      style: TextStyle(color: stroke.color, fontSize: fontSize, height: 1.2),
    );
    final painter = TextPainter(
      text: span,
      textDirection: TextDirection.ltr,
      maxLines: null,
    );

    if (stroke.points.length >= 2) {
      final textRect = Rect.fromPoints(
        anchor,
        _toOffset(stroke.points.last, transform),
      );
      final maxWidth = textRect.width <= 1 ? 1.0 : textRect.width;
      painter.layout(maxWidth: maxWidth);

      canvas.save();
      canvas.clipRect(textRect);
      painter.paint(canvas, textRect.topLeft);
      canvas.restore();
      return;
    }

    painter.layout();
    painter.paint(canvas, anchor);
  }
}
