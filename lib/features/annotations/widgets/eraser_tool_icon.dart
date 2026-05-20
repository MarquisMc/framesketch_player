import 'package:flutter/material.dart';

class EraserToolIcon extends StatelessWidget {
  final Color color;
  final double size;

  const EraserToolIcon({super.key, required this.color, this.size = 18});

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _EraserToolIconPainter(color)),
    );
  }
}

class _EraserToolIconPainter extends CustomPainter {
  final Color color;

  const _EraserToolIconPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.shortestSide / 18.0;
    canvas.save();
    canvas.scale(scale);
    canvas.translate(1.5, 3.0);

    final body = RRect.fromRectAndRadius(
      const Rect.fromLTWH(2, 0, 12, 10),
      const Radius.circular(2),
    );
    canvas.save();
    canvas.translate(8, 5);
    canvas.rotate(-0.65);
    canvas.translate(-8, -5);

    final fillPaint = Paint()
      ..color = color.withValues(alpha: 0.16)
      ..style = PaintingStyle.fill;
    final strokePaint = Paint()
      ..color = color
      ..strokeWidth = 1.7
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round;

    canvas.drawRRect(body, fillPaint);
    canvas.drawRRect(body, strokePaint);
    canvas.drawLine(const Offset(5, 0), const Offset(5, 10), strokePaint);
    canvas.restore();

    final crumbPaint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(1.5, 13), const Offset(15.5, 13), crumbPaint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _EraserToolIconPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
