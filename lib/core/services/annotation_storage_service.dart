import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/annotation_data.dart';

/// Service for saving and loading annotation data
class AnnotationStorageService {
  static const String _recentFilesKey = 'recent_video_files';
  static const int _maxRecentFiles = 10;
  static const String _youtubeKeyPrefix = 'yt:';

  bool isYouTubeAnnotationKey(String sourceKey) {
    return sourceKey.startsWith(_youtubeKeyPrefix);
  }

  String buildYouTubeAnnotationKey(String videoId) {
    return '$_youtubeKeyPrefix$videoId';
  }

  Future<Directory> _youtubeAnnotationDirectory() async {
    final appSupportDir = await getApplicationSupportDirectory();
    final dir = Directory(path.join(appSupportDir.path, 'youtube_annotations'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Get annotation file path for a video
  Future<String> getAnnotationPath(String videoPath) async {
    if (isYouTubeAnnotationKey(videoPath)) {
      final dir = await _youtubeAnnotationDirectory();
      final safeKey = videoPath.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
      return path.join(dir.path, '$safeKey.annotations.json');
    }

    final videoDir = path.dirname(videoPath);
    final videoName = path.basenameWithoutExtension(videoPath);
    return path.join(videoDir, '$videoName.annotations.json');
  }

  /// Generate unique ID for video based on file path
  String generateVideoId(String videoPath) {
    final bytes = utf8.encode(videoPath);
    final digest = sha256.convert(bytes);
    return digest.toString().substring(0, 16);
  }

  /// Save annotation data to file
  Future<bool> saveAnnotations(AnnotationData data) async {
    try {
      final annotationPath = await getAnnotationPath(data.videoPath);
      return saveAnnotationsToFile(data, annotationPath);
    } catch (e) {
      stderr.writeln('Error saving annotations: $e');
      return false;
    }
  }

  /// Save annotation data to an explicit file path (share/export flow).
  Future<bool> saveAnnotationsToFile(
    AnnotationData data,
    String outputPath,
  ) async {
    try {
      final file = File(outputPath);
      final parent = file.parent;
      if (!await parent.exists()) {
        await parent.create(recursive: true);
      }

      final updatedData = data.copyWith(updatedAt: DateTime.now());
      final jsonString =
          const JsonEncoder.withIndent('  ').convert(updatedData.toJson());
      await file.writeAsString(jsonString);
      return true;
    } catch (e) {
      stderr.writeln('Error saving annotations to file: $e');
      return false;
    }
  }

  /// Load annotation data from file
  Future<AnnotationData?> loadAnnotations(String videoPath) async {
    try {
      final annotationPath = await getAnnotationPath(videoPath);
      final file = File(annotationPath);

      if (!await file.exists()) {
        return null;
      }

      final jsonString = await file.readAsString();
      final jsonData = json.decode(jsonString) as Map<String, dynamic>;

      return AnnotationData.fromJson(jsonData);
    } catch (e) {
      stderr.writeln('Error loading annotations: $e');
      return null;
    }
  }

  /// Check if annotations exist for video
  Future<bool> hasAnnotations(String videoPath) async {
    final annotationPath = await getAnnotationPath(videoPath);
    return await File(annotationPath).exists();
  }

  /// Delete annotations for video
  Future<bool> deleteAnnotations(String videoPath) async {
    try {
      final annotationPath = await getAnnotationPath(videoPath);
      final file = File(annotationPath);

      if (await file.exists()) {
        await file.delete();
      }

      return true;
    } catch (e) {
      stderr.writeln('Error deleting annotations: $e');
      return false;
    }
  }

  /// Load annotations directly from a chosen JSON file.
  Future<AnnotationData?> loadAnnotationsFromFile(String annotationFilePath) async {
    try {
      final file = File(annotationFilePath);
      if (!await file.exists()) {
        return null;
      }

      final jsonString = await file.readAsString();
      final jsonData = json.decode(jsonString) as Map<String, dynamic>;
      return AnnotationData.fromJson(jsonData);
    } catch (e) {
      stderr.writeln('Error loading annotation file: $e');
      return null;
    }
  }

  /// Add video to recent files list
  Future<void> addToRecentFiles(String videoPath) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final recentFiles = prefs.getStringList(_recentFilesKey) ?? [];

      // Remove if already exists
      recentFiles.remove(videoPath);

      // Add to front
      recentFiles.insert(0, videoPath);

      // Keep only max recent files
      if (recentFiles.length > _maxRecentFiles) {
        recentFiles.removeRange(_maxRecentFiles, recentFiles.length);
      }

      await prefs.setStringList(_recentFilesKey, recentFiles);
    } catch (e) {
      stderr.writeln('Error adding to recent files: $e');
    }
  }

  /// Get list of recent video files
  Future<List<String>> getRecentFiles() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final recentFiles = prefs.getStringList(_recentFilesKey) ?? [];

      // Filter out files that no longer exist
      final existingFiles = <String>[];
      for (final filePath in recentFiles) {
        if (await File(filePath).exists()) {
          existingFiles.add(filePath);
        }
      }

      // Update if list changed
      if (existingFiles.length != recentFiles.length) {
        await prefs.setStringList(_recentFilesKey, existingFiles);
      }

      return existingFiles;
    } catch (e) {
      stderr.writeln('Error getting recent files: $e');
      return [];
    }
  }

  /// Clear recent files list
  Future<void> clearRecentFiles() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_recentFilesKey);
  }
}
