// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'frame_marker.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$FrameMarkerImpl _$$FrameMarkerImplFromJson(Map<String, dynamic> json) =>
    _$FrameMarkerImpl(
      id: json['id'] as String,
      timeMs: (json['timeMs'] as num).toInt(),
      label: json['label'] as String,
      note: json['note'] as String? ?? '',
      color: _colorFromJson((json['color'] as num).toInt()),
    );

Map<String, dynamic> _$$FrameMarkerImplToJson(_$FrameMarkerImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'timeMs': instance.timeMs,
      'label': instance.label,
      'note': instance.note,
      'color': _colorToJson(instance.color),
    };
