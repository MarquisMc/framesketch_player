// ignore_for_file: invalid_annotation_target

import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'frame_marker.freezed.dart';
part 'frame_marker.g.dart';

@freezed
class FrameMarker with _$FrameMarker {
  const factory FrameMarker({
    required String id,
    required int timeMs,
    required String label,
    @Default('') String note,
    @JsonKey(fromJson: _colorFromJson, toJson: _colorToJson)
    required Color color,
  }) = _FrameMarker;

  factory FrameMarker.fromJson(Map<String, dynamic> json) =>
      _$FrameMarkerFromJson(json);
}

Color _colorFromJson(int value) => Color(value);
int _colorToJson(Color color) => color.toARGB32();
