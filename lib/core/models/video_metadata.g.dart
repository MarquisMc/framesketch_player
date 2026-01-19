// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'video_metadata.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$VideoMetadataImpl _$$VideoMetadataImplFromJson(Map<String, dynamic> json) =>
    _$VideoMetadataImpl(
      filePath: json['filePath'] as String,
      duration: Duration(microseconds: (json['duration'] as num).toInt()),
      fps: (json['fps'] as num).toDouble(),
      width: (json['width'] as num).toInt(),
      height: (json['height'] as num).toInt(),
      codec: json['codec'] as String,
      format: json['format'] as String,
      frameCount: (json['frameCount'] as num?)?.toInt() ?? 0,
      timeBase: json['timeBase'] as String?,
    );

Map<String, dynamic> _$$VideoMetadataImplToJson(_$VideoMetadataImpl instance) =>
    <String, dynamic>{
      'filePath': instance.filePath,
      'duration': instance.duration.inMicroseconds,
      'fps': instance.fps,
      'width': instance.width,
      'height': instance.height,
      'codec': instance.codec,
      'format': instance.format,
      'frameCount': instance.frameCount,
      'timeBase': instance.timeBase,
    };
