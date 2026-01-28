import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'stroke.freezed.dart';
part 'stroke.g.dart';

/// A point in normalized coordinates (0.0 to 1.0)
@freezed
class StrokePoint with _$StrokePoint {
  const factory StrokePoint({
    required double x,
    required double y,
    @Default(0) int timestampMs,
  }) = _StrokePoint;

  factory StrokePoint.fromJson(Map<String, dynamic> json) =>
      _$StrokePointFromJson(json);
}

/// Drawing tool types
enum DrawingTool { pen, eraser, rectangle, circle, line, arrow, text, select }

/// A complete stroke (pen path or shape)
@freezed
class Stroke with _$Stroke {
  const factory Stroke({
    required String id,
    required DrawingTool tool,
    // ignore: invalid_annotation_target
    @JsonKey(fromJson: _colorFromJson, toJson: _colorToJson)
    required Color color,
    required double strokeWidth,
    required List<StrokePoint> points,
    @Default(0) int startTimeMs,
    @Default(0) int endTimeMs,
    String? text,
    @Default(16.0) double fontSize,
    @Default(1.0) double scale,
  }) = _Stroke;

  factory Stroke.fromJson(Map<String, dynamic> json) => _$StrokeFromJson(json);
}

// Color serialization helpers
Color _colorFromJson(int value) => Color(value);
int _colorToJson(Color color) => color.toARGB32();
