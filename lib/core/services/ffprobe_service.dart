import 'dart:convert';
import 'dart:io';
import '../models/video_metadata.dart';
import 'ffmpeg_binaries_service.dart';

/// Service for extracting video metadata using FFprobe
class FFprobeService {
  final FFmpegBinariesService _binaries = FFmpegBinariesService();

  /// Check if ffprobe is available via app-managed binaries.
  Future<bool> isAvailable() async {
    try {
      return await findFFprobePath() != null;
    } catch (e) {
      return false;
    }
  }

  /// Get the ffprobe executable path from app-managed binaries.
  Future<String?> findFFprobePath() async {
    return _binaries.findFFprobePath();
  }

  /// Extract video metadata from file
  Future<VideoMetadata?> extractMetadata(String filePath) async {
    try {
      final ffprobePath = await findFFprobePath();
      if (ffprobePath == null) {
        throw Exception(
          'FFprobe not found. Automatic provisioning failed. Check internet access and try again.',
        );
      }

      // Run ffprobe with JSON output
      final result = await Process.run(ffprobePath, [
        '-v',
        'quiet',
        '-print_format',
        'json',
        '-show_format',
        '-show_streams',
        '-select_streams',
        'v:0', // First video stream
        filePath,
      ]);

      if (result.exitCode != 0) {
        throw Exception('FFprobe failed: ${result.stderr}');
      }

      final jsonData = json.decode(result.stdout as String);
      return _parseMetadata(filePath, jsonData);
    } catch (e) {
      stderr.writeln('Error extracting metadata: $e');
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
      final durationSeconds =
          double.tryParse(format?['duration']?.toString() ?? '0') ?? 0.0;
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
      stderr.writeln('Error parsing metadata: $e');
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

      final result = await Process.run(ffmpegPath, [
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
      ]);

      if (result.exitCode == 0) {
        return File(outputPath);
      }
      return null;
    } catch (e) {
      stderr.writeln('Error extracting frame: $e');
      return null;
    }
  }

  Future<String?> _findFFmpegPath() async {
    return _binaries.findFFmpegPath();
  }
}
