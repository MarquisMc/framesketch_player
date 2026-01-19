import 'package:freezed_annotation/freezed_annotation.dart';

part 'video_metadata.freezed.dart';
part 'video_metadata.g.dart';

/// Metadata extracted from video file using FFprobe
@freezed
class VideoMetadata with _$VideoMetadata {
  const factory VideoMetadata({
    required String filePath,
    required Duration duration,
    required double fps,
    required int width,
    required int height,
    required String codec,
    required String format,
    @Default(0) int frameCount,
    String? timeBase,
  }) = _VideoMetadata;

  factory VideoMetadata.fromJson(Map<String, dynamic> json) =>
      _$VideoMetadataFromJson(json);
}
