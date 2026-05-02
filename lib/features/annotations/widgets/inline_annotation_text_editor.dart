import 'dart:math';

import 'package:flutter/material.dart';

import '../../../core/utils/coordinate_transformer.dart';
import '../models/stroke.dart';
import 'annotation_text_metrics.dart';

class AnnotationTextBoxDefaults {
  const AnnotationTextBoxDefaults({
    required this.minWidth,
    required this.minHeight,
    required this.fallbackBottomRight,
    required this.scaledFontSize,
  });

  final double minWidth;
  final double minHeight;
  final Offset fallbackBottomRight;
  final double scaledFontSize;
}

AnnotationTextBoxDefaults annotationTextBoxDefaults(
  Stroke stroke,
  CoordinateTransformer transformer,
  Offset anchor,
) {
  final videoScale = videoPixelScale(transformer);
  final scaledFontSize = scaledFontSizeForStroke(stroke, transformer);
  final fallbackBottomRight = Offset(
    anchor.dx + max(120 * videoScale, scaledFontSize * 4.0),
    anchor.dy + max((stroke.fontSize + 12) * videoScale, 36 * videoScale),
  );

  return AnnotationTextBoxDefaults(
    minWidth: max(120.0 * videoScale, scaledFontSize * 4.0),
    minHeight: max(36.0 * videoScale, scaledFontSize * 1.8),
    fallbackBottomRight: fallbackBottomRight,
    scaledFontSize: scaledFontSize,
  );
}

class InlineAnnotationTextEditor extends StatelessWidget {
  final Stroke stroke;
  final Size viewportSize;
  final CoordinateTransformer transformer;
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;

  const InlineAnnotationTextEditor({
    super.key,
    required this.stroke,
    required this.viewportSize,
    required this.transformer,
    required this.controller,
    required this.focusNode,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (stroke.points.isEmpty) {
      return const SizedBox.shrink();
    }

    final anchor = transformer.toViewport(stroke.points.first);
    final defaults = annotationTextBoxDefaults(stroke, transformer, anchor);
    final bottomRight = stroke.points.length >= 2
        ? transformer.toViewport(stroke.points.last)
        : defaults.fallbackBottomRight;
    final rect = Rect.fromPoints(anchor, bottomRight);
    final width = max(
      rect.width,
      defaults.minWidth,
    ).clamp(defaults.minWidth, viewportSize.width);
    final height = max(
      rect.height,
      defaults.minHeight,
    ).clamp(defaults.minHeight, viewportSize.height);
    final maxLeft = max(0.0, viewportSize.width - width);
    final maxTop = max(0.0, viewportSize.height - height);
    final left = rect.left.clamp(0.0, maxLeft);
    final top = rect.top.clamp(0.0, maxTop);

    return Positioned(
      left: left,
      top: top,
      width: width,
      height: height,
      child: Material(
        color: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.18),
            border: Border.all(
              color: stroke.color.withValues(alpha: 0.85),
              width: 1.5,
            ),
            borderRadius: BorderRadius.circular(4),
          ),
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            onChanged: onChanged,
            onSubmitted: (_) => focusNode.unfocus(),
            onTapOutside: (_) => focusNode.unfocus(),
            keyboardType: TextInputType.multiline,
            textInputAction: TextInputAction.newline,
            textAlignVertical: TextAlignVertical.top,
            minLines: 1,
            maxLines: null,
            style: textStyleForStroke(
              stroke,
              fontSize: defaults.scaledFontSize,
            ),
            decoration: InputDecoration(
              isDense: true,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 6,
                vertical: 4,
              ),
              hintText: 'Type text...',
              hintStyle: textStyleForStroke(
                stroke,
                fontSize: defaults.scaledFontSize,
                color: stroke.color.withValues(alpha: 0.6),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
