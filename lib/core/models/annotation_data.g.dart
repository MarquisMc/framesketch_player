// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'annotation_data.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$AnnotationDataImpl _$$AnnotationDataImplFromJson(Map<String, dynamic> json) =>
    _$AnnotationDataImpl(
      videoId: json['videoId'] as String,
      videoPath: json['videoPath'] as String,
      youtubeUrl: json['youtubeUrl'] as String?,
      fps: (json['fps'] as num).toDouble(),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      strokes:
          (json['strokes'] as List<dynamic>?)
              ?.map((e) => Stroke.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      viewportWidth: (json['viewportWidth'] as num?)?.toInt() ?? 1920,
      viewportHeight: (json['viewportHeight'] as num?)?.toInt() ?? 1080,
    );

Map<String, dynamic> _$$AnnotationDataImplToJson(
  _$AnnotationDataImpl instance,
) => <String, dynamic>{
  'videoId': instance.videoId,
  'videoPath': instance.videoPath,
  'youtubeUrl': instance.youtubeUrl,
  'fps': instance.fps,
  'createdAt': instance.createdAt.toIso8601String(),
  'updatedAt': instance.updatedAt.toIso8601String(),
  'strokes': instance.strokes,
  'viewportWidth': instance.viewportWidth,
  'viewportHeight': instance.viewportHeight,
};
