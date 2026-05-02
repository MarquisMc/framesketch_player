import 'package:flutter/material.dart';

import '../../../core/utils/coordinate_transformer.dart';
import '../models/stroke.dart';
import 'annotation_text_metrics.dart';

const double kResizeHandleSize = 12.0;
const double kResizeHandleEdgeWidth = 28.0;
const double kResizeHandleEdgeThickness = 16.0;

enum ResizeHandle {
  topLeft,
  topRight,
  bottomLeft,
  bottomRight,
  top,
  bottom,
  left,
  right,
}

Size estimateAnnotationTextSize(
  Stroke stroke,
  CoordinateTransformer transformer,
) {
  final effectiveFontSize = scaledFontSizeForStroke(stroke, transformer);
  final textSpan = TextSpan(
    text: stroke.text ?? '',
    style: textStyleForStroke(stroke, fontSize: effectiveFontSize),
  );
  final textPainter = TextPainter(
    text: textSpan,
    textDirection: TextDirection.ltr,
    maxLines: null,
  );
  try {
    textPainter.layout();
    return Size(textPainter.width, textPainter.height);
  } finally {
    textPainter.dispose();
  }
}

Rect? textBoundsNormalized(Stroke stroke, CoordinateTransformer transformer) {
  if (stroke.points.isEmpty) return null;

  final anchor = stroke.points.first;
  if (stroke.points.length >= 2) {
    final p2 = stroke.points.last;
    final left = anchor.x < p2.x ? anchor.x : p2.x;
    final right = anchor.x > p2.x ? anchor.x : p2.x;
    final top = anchor.y < p2.y ? anchor.y : p2.y;
    final bottom = anchor.y > p2.y ? anchor.y : p2.y;
    return Rect.fromLTRB(left, top, right, bottom);
  }

  final estimatedSize = estimateAnnotationTextSize(stroke, transformer);
  final anchorOffset = transformer.toViewport(anchor);
  final bottomRight = transformer.toNormalized(
    anchorOffset + Offset(estimatedSize.width, estimatedSize.height),
  );
  return Rect.fromLTRB(anchor.x, anchor.y, bottomRight.x, bottomRight.y);
}

Rect? selectionRectForStroke(
  Stroke stroke,
  CoordinateTransformer transformer, {
  double padding = 8,
}) {
  if (stroke.points.isEmpty) return null;

  if (stroke.tool == DrawingTool.text &&
      stroke.text != null &&
      stroke.text!.isNotEmpty) {
    if (stroke.points.length >= 2) {
      return Rect.fromPoints(
        transformer.toViewport(stroke.points.first),
        transformer.toViewport(stroke.points.last),
      );
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
      textDirection: TextDirection.ltr,
      maxLines: null,
    )..layout();
    final rect = Rect.fromLTWH(
      position.dx,
      position.dy,
      textPainter.width,
      textPainter.height,
    );
    textPainter.dispose();
    return rect;
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

  return Rect.fromLTRB(
    minX - padding,
    minY - padding,
    maxX + padding,
    maxY + padding,
  );
}

ResizeHandle? resizeHandleAtPoint(
  Stroke stroke,
  Offset point,
  CoordinateTransformer transformer,
) {
  if (stroke.points.isEmpty) return null;

  final boundingBox = selectionRectForStroke(
    stroke,
    transformer,
    padding: stroke.tool == DrawingTool.text ? 0 : 8,
  );

  if (boundingBox == null) return null;

  if ((point - Offset(boundingBox.left, boundingBox.top)).distance <
      kResizeHandleSize) {
    return ResizeHandle.topLeft;
  }
  if ((point - Offset(boundingBox.right, boundingBox.top)).distance <
      kResizeHandleSize) {
    return ResizeHandle.topRight;
  }
  if ((point - Offset(boundingBox.left, boundingBox.bottom)).distance <
      kResizeHandleSize) {
    return ResizeHandle.bottomLeft;
  }
  if ((point - Offset(boundingBox.right, boundingBox.bottom)).distance <
      kResizeHandleSize) {
    return ResizeHandle.bottomRight;
  }

  if (stroke.tool == DrawingTool.text) {
    return null;
  }

  final topHandle = Rect.fromCenter(
    center: Offset(boundingBox.center.dx, boundingBox.top),
    width: kResizeHandleEdgeWidth,
    height: kResizeHandleEdgeThickness,
  );
  if (topHandle.contains(point)) {
    return ResizeHandle.top;
  }

  final bottomHandle = Rect.fromCenter(
    center: Offset(boundingBox.center.dx, boundingBox.bottom),
    width: kResizeHandleEdgeWidth,
    height: kResizeHandleEdgeThickness,
  );
  if (bottomHandle.contains(point)) {
    return ResizeHandle.bottom;
  }

  final leftHandle = Rect.fromCenter(
    center: Offset(boundingBox.left, boundingBox.center.dy),
    width: kResizeHandleEdgeThickness,
    height: kResizeHandleEdgeWidth,
  );
  if (leftHandle.contains(point)) {
    return ResizeHandle.left;
  }

  final rightHandle = Rect.fromCenter(
    center: Offset(boundingBox.right, boundingBox.center.dy),
    width: kResizeHandleEdgeThickness,
    height: kResizeHandleEdgeWidth,
  );
  if (rightHandle.contains(point)) {
    return ResizeHandle.right;
  }

  return null;
}
