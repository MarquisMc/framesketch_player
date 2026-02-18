import 'dart:io';
import '../models/annotation_data.dart';
import 'ffmpeg_binaries_service.dart';

/// Service for FFmpeg operations (export annotated videos)
class FFmpegService {
  final FFmpegBinariesService _binaries = FFmpegBinariesService();

  /// Check if ffmpeg is available via app-managed binaries.
  Future<bool> isAvailable() async {
    try {
      return await findFFmpegPath() != null;
    } catch (e) {
      return false;
    }
  }

  /// Find FFmpeg executable path from app-managed binaries.
  Future<String?> findFFmpegPath() async {
    return _binaries.findFFmpegPath();
  }

  /// Export video with burned-in annotations
  /// This is a placeholder for future implementation
  /// Full implementation would require:
  /// 1. Render annotations to overlay images per timestamp
  /// 2. Use FFmpeg overlay filter to composite
  /// 3. Re-encode video with annotations
  Future<bool> exportAnnotatedVideo({
    required String inputPath,
    required String outputPath,
    required AnnotationData annotations,
    Function(double)? onProgress,
  }) async {
    try {
      final ffmpegPath = await findFFmpegPath();
      if (ffmpegPath == null) {
        throw Exception(
          'FFmpeg not found. Automatic provisioning failed. Check internet access and try again.',
        );
      }

      // TODO: Full implementation would:
      // 1. Generate overlay images from annotations
      // 2. Create complex filter for time-based overlays
      // 3. Run ffmpeg with progress monitoring

      // For now, just copy the video as placeholder
      stderr.writeln(
        'Export functionality requires advanced FFmpeg filter implementation',
      );

      return false;
    } catch (e) {
      stderr.writeln('Error exporting video: $e');
      return false;
    }
  }

  /// Get FFmpeg version info
  Future<String?> getVersion() async {
    try {
      final ffmpegPath = await findFFmpegPath();
      if (ffmpegPath == null) return null;

      final result = await Process.run(ffmpegPath, ['-version']);
      if (result.exitCode == 0) {
        final output = result.stdout as String;
        final firstLine = output.split('\n').first;
        return firstLine;
      }
    } catch (e) {
      stderr.writeln('Error getting FFmpeg version: $e');
    }
    return null;
  }
}
