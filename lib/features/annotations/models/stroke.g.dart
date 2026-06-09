// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'stroke.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$StrokePointImpl _$$StrokePointImplFromJson(Map<String, dynamic> json) =>
    _$StrokePointImpl(
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      timestampMs: (json['timestampMs'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$$StrokePointImplToJson(_$StrokePointImpl instance) =>
    <String, dynamic>{
      'x': instance.x,
      'y': instance.y,
      'timestampMs': instance.timestampMs,
    };

_$StrokeImpl _$$StrokeImplFromJson(Map<String, dynamic> json) => _$StrokeImpl(
  id: json['id'] as String,
  tool: $enumDecode(_$DrawingToolEnumMap, json['tool']),
  color: _colorFromJson((json['color'] as num).toInt()),
  strokeWidth: (json['strokeWidth'] as num).toDouble(),
  points: (json['points'] as List<dynamic>)
      .map((e) => StrokePoint.fromJson(e as Map<String, dynamic>))
      .toList(),
  startTimeMs: (json['startTimeMs'] as num?)?.toInt() ?? 0,
  endTimeMs: (json['endTimeMs'] as num?)?.toInt() ?? 0,
  timingMode:
      $enumDecodeNullable(_$StrokeTimingModeEnumMap, json['timingMode']) ??
      StrokeTimingMode.keyframe,
  text: json['text'] as String?,
  fontSize: (json['fontSize'] as num?)?.toDouble() ?? 16.0,
  scale: (json['scale'] as num?)?.toDouble() ?? 1.0,
);

Map<String, dynamic> _$$StrokeImplToJson(_$StrokeImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'tool': _$DrawingToolEnumMap[instance.tool]!,
      'color': _colorToJson(instance.color),
      'strokeWidth': instance.strokeWidth,
      'points': instance.points,
      'startTimeMs': instance.startTimeMs,
      'endTimeMs': instance.endTimeMs,
      'timingMode': _$StrokeTimingModeEnumMap[instance.timingMode]!,
      'text': instance.text,
      'fontSize': instance.fontSize,
      'scale': instance.scale,
    };

const _$DrawingToolEnumMap = {
  DrawingTool.pen: 'pen',
  DrawingTool.eraser: 'eraser',
  DrawingTool.rectangle: 'rectangle',
  DrawingTool.filledSquare: 'filledSquare',
  DrawingTool.circle: 'circle',
  DrawingTool.filledCircle: 'filledCircle',
  DrawingTool.line: 'line',
  DrawingTool.arrow: 'arrow',
  DrawingTool.text: 'text',
  DrawingTool.select: 'select',
};

const _$StrokeTimingModeEnumMap = {
  StrokeTimingMode.keyframe: 'keyframe',
  StrokeTimingMode.whiteboard: 'whiteboard',
};
