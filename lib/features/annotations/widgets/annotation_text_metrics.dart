import 'dart:math';

import 'package:flutter/material.dart';

import '../../../core/utils/coordinate_transformer.dart';
import '../models/stroke.dart';

const double textReferenceVideoHeight = 720.0;

TextStyle textStyleForStroke(Stroke stroke, {double? fontSize, Color? color}) {
  return TextStyle(
    color: color ?? stroke.color,
    fontSize: fontSize ?? stroke.fontSize,
    height: 1.2,
  );
}

double videoPixelScale(CoordinateTransformer transformer) {
  final videoRect = transformer.videoRectInViewport;
  if (videoRect.width <= 0 || videoRect.height <= 0) {
    return 1.0;
  }

  return (videoRect.height / textReferenceVideoHeight).clamp(
    0.01,
    double.infinity,
  );
}

double scaledFontSizeForStroke(
  Stroke stroke,
  CoordinateTransformer transformer,
) {
  return max(1.0, stroke.fontSize * videoPixelScale(transformer));
}
