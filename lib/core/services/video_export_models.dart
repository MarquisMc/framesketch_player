import '../models/annotation_data.dart';

enum VideoExportPreset {
  fast(
    displayName: 'Fast',
    ffmpegPreset: 'veryfast',
    crf: '23',
    useBaselineProfile: false,
  ),
  balanced(
    displayName: 'Balanced',
    ffmpegPreset: 'medium',
    crf: '21',
    useBaselineProfile: false,
  ),
  compatible(
    displayName: 'Compatible',
    ffmpegPreset: 'medium',
    crf: '20',
    useBaselineProfile: true,
  );

  final String displayName;
  final String ffmpegPreset;
  final String crf;
  final bool useBaselineProfile;

  const VideoExportPreset({
    required this.displayName,
    required this.ffmpegPreset,
    required this.crf,
    required this.useBaselineProfile,
  });

  String get description {
    switch (this) {
      case VideoExportPreset.fast:
        return 'Faster export, smaller file, slightly lower quality.';
      case VideoExportPreset.balanced:
        return 'Good quality with moderate export speed.';
      case VideoExportPreset.compatible:
        return 'Current conservative MP4 settings for broad playback support.';
    }
  }

  String get encoderSummary {
    final profile = useBaselineProfile ? ' profile=baseline level=3.0' : '';
    return 'libx264 preset=$ffmpegPreset crf=$crf$profile pix_fmt=yuv420p; audio=aac 192k';
  }
}

class VideoExportCropRect {
  final double left;
  final double top;
  final double right;
  final double bottom;

  const VideoExportCropRect({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  }) : assert(left <= right, 'left must be <= right'),
       assert(top <= bottom, 'top must be <= bottom'),
       assert(
         left >= 0 && right <= 1,
         'horizontal coordinates must be in [0, 1]',
       ),
       assert(
         top >= 0 && bottom <= 1,
         'vertical coordinates must be in [0, 1]',
       );

  double get width => right - left;
  double get height => bottom - top;

  bool get isFullFrame {
    const epsilon = 0.0005;
    return left.abs() <= epsilon &&
        top.abs() <= epsilon &&
        (1.0 - right).abs() <= epsilon &&
        (1.0 - bottom).abs() <= epsilon;
  }

  @override
  String toString() =>
      'CropRect(left: ${left.toStringAsFixed(3)}, top: ${top.toStringAsFixed(3)}, '
      'right: ${right.toStringAsFixed(3)}, bottom: ${bottom.toStringAsFixed(3)})';
}

class VideoExportRequest {
  final String inputPath;
  final String outputPath;
  final VideoExportCropRect cropRect;
  final int videoWidth;
  final int videoHeight;
  final Duration fullDuration;
  final Duration? start;
  final Duration? end;
  final AnnotationData? annotationData;
  final VideoExportPreset preset;

  const VideoExportRequest({
    required this.inputPath,
    required this.outputPath,
    required this.cropRect,
    required this.videoWidth,
    required this.videoHeight,
    required this.fullDuration,
    this.start,
    this.end,
    this.annotationData,
    this.preset = VideoExportPreset.compatible,
  }) : assert(
         start == null || start >= Duration.zero,
         'VideoExportRequest.start must be >= Duration.zero',
       ),
       assert(
         end == null || end >= Duration.zero,
         'VideoExportRequest.end must be >= Duration.zero',
       ),
       assert(
         start == null || start <= fullDuration,
         'VideoExportRequest.start must be <= VideoExportRequest.fullDuration',
       ),
       assert(
         end == null || end <= fullDuration,
         'VideoExportRequest.end must be <= VideoExportRequest.fullDuration',
       ),
       assert(
         start == null || end == null || start < end,
         'VideoExportRequest.start must be < VideoExportRequest.end',
       );
}

enum VideoExportResultStatus { success, cancelled, error }

class VideoExportResult {
  final VideoExportResultStatus status;
  final String outputPath;
  final String? errorMessage;

  const VideoExportResult._({
    required this.status,
    required this.outputPath,
    this.errorMessage,
  });

  const VideoExportResult.success({required String outputPath})
    : this._(status: VideoExportResultStatus.success, outputPath: outputPath);

  const VideoExportResult.cancelled({required String outputPath})
    : this._(status: VideoExportResultStatus.cancelled, outputPath: outputPath);

  const VideoExportResult.error({
    required String outputPath,
    required String errorMessage,
  }) : this._(
         status: VideoExportResultStatus.error,
         outputPath: outputPath,
         errorMessage: errorMessage,
       );
}
