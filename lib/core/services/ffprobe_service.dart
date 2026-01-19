import 'dart:convert';
import 'dart:io';
import '../models/video_metadata.dart';

/// Service for extracting video metadata using FFprobe
class FFprobeService {
  /// Check if ffprobe is available on the system
  Future<bool> isAvailable() async {
    try {
      final result = await Process.run('ffprobe', ['-version']);
      return result.exitCode == 0;
    } catch (e) {
      return false;
    }
  }

  /// Get the path to ffprobe executable (check common locations on Windows)
  Future<String?> findFFprobePath() async {
    // Try system PATH first
    if (await isAvailable()) {
      return 'ffprobe';
    }

    // Check common Windows installation paths
    if (Platform.isWindows) {
      final commonPaths = [
        'C:\\ffmpeg\\bin\\ffprobe.exe',
        'C:\\Program Files\\ffmpeg\\bin\\ffprobe.exe',
        Platform.environment['LOCALAPPDATA'] != null
            ? '${Platform.environment['LOCALAPPDATA']}\\ffmpeg\\bin\\ffprobe.exe'
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

  /// Extract video metadata from file
  Future<VideoMetadata?> extractMetadata(String filePath) async {
    try {
      final ffprobePath = await findFFprobePath();
      if (ffprobePath == null) {
        throw Exception('FFprobe not found. Please install FFmpeg.');
      }

      // Run ffprobe with JSON output
      final result = await Process.run(
        ffprobePath,
        [
          '-v',
          'quiet',
          '-print_format',
          'json',
          '-show_format',
          '-show_streams',
          '-select_streams',
          'v:0', // First video stream
          filePath,
        ],
      );

      if (result.exitCode != 0) {
        throw Exception('FFprobe failed: ${result.stderr}');
      }

      final jsonData = json.decode(result.stdout as String);
      return _parseMetadata(filePath, jsonData);
    } catch (e) {
      print('Error extracting metadata: $e');
      return null;
    }
  }

  VideoMetadata? _parseMetadata(String filePath, Map<String, dynamic> json) {
    try {
      final streams = json['streams'] as List?;
      if (streams == null || streams.isEmpty) {
        return null;
      }

      final videoStream = streams[0] as Map<String, dynamic>;
      final format = json['format'] as Map<String, dynamic>?;

      // Extract FPS (frame rate)
      double fps = 30.0; // Default fallback
      final fpsString = videoStream['r_frame_rate'] as String?;
      if (fpsString != null && fpsString.contains('/')) {
        final parts = fpsString.split('/');
        final numerator = double.tryParse(parts[0]) ?? 30.0;
        final denominator = double.tryParse(parts[1]) ?? 1.0;
        fps = denominator > 0 ? numerator / denominator : 30.0;
      }

      // Extract duration
      final durationSeconds = double.tryParse(
            format?['duration']?.toString() ?? '0',
          ) ??
          0.0;
      final duration = Duration(milliseconds: (durationSeconds * 1000).round());

      // Calculate frame count
      final frameCount = (durationSeconds * fps).round();

      // Extract resolution
      final width = videoStream['width'] as int? ?? 1920;
      final height = videoStream['height'] as int? ?? 1080;

      // Extract codec and format
      final codec = videoStream['codec_name'] as String? ?? 'unknown';
      final formatName = format?['format_name'] as String? ?? 'unknown';
      final timeBase = videoStream['time_base'] as String?;

      return VideoMetadata(
        filePath: filePath,
        duration: duration,
        fps: fps,
        width: width,
        height: height,
        codec: codec,
        format: formatName,
        frameCount: frameCount,
        timeBase: timeBase,
      );
    } catch (e) {
      print('Error parsing metadata: $e');
      return null;
    }
  }

  /// Get frame at specific timestamp (extract thumbnail)
  Future<File?> extractFrameAt(
    String videoPath,
    Duration timestamp,
    String outputPath,
  ) async {
    try {
      final ffmpegPath = await _findFFmpegPath();
      if (ffmpegPath == null) {
        throw Exception('FFmpeg not found');
      }

      final result = await Process.run(
        ffmpegPath,
        [
          '-ss',
          timestamp.inSeconds.toString(),
          '-i',
          videoPath,
          '-frames:v',
          '1',
          '-q:v',
          '2',
          outputPath,
          '-y', // Overwrite
        ],
      );

      if (result.exitCode == 0) {
        return File(outputPath);
      }
      return null;
    } catch (e) {
      print('Error extracting frame: $e');
      return null;
    }
  }

  Future<String?> _findFFmpegPath() async {
    try {
      final result = await Process.run('ffmpeg', ['-version']);
      if (result.exitCode == 0) return 'ffmpeg';
    } catch (e) {
      // Continue to check other paths
    }

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
}
