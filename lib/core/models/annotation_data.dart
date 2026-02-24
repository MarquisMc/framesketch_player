import 'package:freezed_annotation/freezed_annotation.dart';
import '../../features/annotations/models/stroke.dart';

part 'annotation_data.freezed.dart';
part 'annotation_data.g.dart';

/// Complete annotation data for a video file
@freezed
class AnnotationData with _$AnnotationData {
  const factory AnnotationData({
    required String videoId,
    required String videoPath,
    String? youtubeUrl,
    required double fps,
    required DateTime createdAt,
    required DateTime updatedAt,
    @Default([]) List<Stroke> strokes,
    @Default(1920) int viewportWidth,
    @Default(1080) int viewportHeight,
  }) = _AnnotationData;

  factory AnnotationData.fromJson(Map<String, dynamic> json) =>
      _$AnnotationDataFromJson(json);
}
