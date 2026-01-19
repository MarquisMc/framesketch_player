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
  @override
  Widget build(BuildContext context) {
    final annotationState = ref.watch(annotationProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        final viewportSize = Size(constraints.maxWidth, constraints.maxHeight);

        return GestureDetector(
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

  AnnotationPainter({
    required this.strokes,
    required this.currentStroke,
    required this.viewportSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final transformer = CoordinateTransformer(viewportSize);

    // Draw completed strokes
    for (final stroke in strokes) {
      _drawStroke(canvas, stroke, transformer);
    }

    // Draw current stroke being drawn
    if (currentStroke != null) {
      _drawStroke(canvas, currentStroke!, transformer);
    }
  }

  void _drawStroke(Canvas canvas, Stroke stroke, CoordinateTransformer transformer) {
    if (stroke.points.length < 2) {
      // Draw single point as a circle
      if (stroke.points.isNotEmpty) {
        final point = transformer.toViewport(stroke.points.first);
        final paint = Paint()
          ..color = stroke.color
          ..strokeWidth = stroke.strokeWidth
          ..style = PaintingStyle.fill;

        canvas.drawCircle(point, stroke.strokeWidth / 2, paint);
      }
      return;
    }

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

  @override
  bool shouldRepaint(AnnotationPainter oldDelegate) {
    return oldDelegate.strokes != strokes ||
        oldDelegate.currentStroke != currentStroke ||
        oldDelegate.viewportSize != viewportSize;
  }
}
