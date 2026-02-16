import 'dart:io';
import '../models/annotation_data.dart';

/// Service for FFmpeg operations (export annotated videos)
class FFmpegService {
  /// Check if ffmpeg is available on the system
  Future<bool> isAvailable() async {
    try {
      final result = await Process.run('ffmpeg', ['-version']);
      return result.exitCode == 0;
    } catch (e) {
      return false;
    }
  }

  /// Find FFmpeg executable path
  Future<String?> findFFmpegPath() async {
    // Try system PATH first
    if (await isAvailable()) {
      return 'ffmpeg';
    }

    // Check common Windows installation paths
    if (Platform.isWindows) {
      final commonPaths = [
        'C:\\ffmpeg\\bin\\ffmpeg.exe',
        'C:\\Program Files\\ffmpeg\\bin\\ffmpeg.exe',
        Platform.environment['LOCALAPPDATA'] != null
            ? '${Platform.environment['LOCALAPPDATA']}\\ffmpeg\\bin\\ffmpeg.exe'
            : null,
      ];

      for (final path in commonPaths) {
        if (path != null && await File(path).exists()) {
          return path;
        }
      }
    }

    return null;
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
        throw Exception('FFmpeg not found. Please install FFmpeg.');
      }

      // TODO: Full implementation would:
      // 1. Generate overlay images from annotations
      // 2. Create complex filter for time-based overlays
      // 3. Run ffmpeg with progress monitoring

      // For now, just copy the video as placeholder
      stderr.writeln('Export functionality requires advanced FFmpeg filter implementation');

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
