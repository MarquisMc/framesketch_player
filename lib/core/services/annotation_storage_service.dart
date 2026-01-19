import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/annotation_data.dart';

/// Service for saving and loading annotation data
class AnnotationStorageService {
  static const String _recentFilesKey = 'recent_video_files';
  static const int _maxRecentFiles = 10;

  /// Get annotation file path for a video
  String getAnnotationPath(String videoPath) {
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
      final annotationPath = getAnnotationPath(data.videoPath);
      final file = File(annotationPath);

      // Update timestamp
      final updatedData = data.copyWith(updatedAt: DateTime.now());

      // Convert to JSON
      final jsonString = const JsonEncoder.withIndent('  ')
          .convert(updatedData.toJson());

      // Write to file
      await file.writeAsString(jsonString);

      return true;
    } catch (e) {
      print('Error saving annotations: $e');
      return false;
    }
  }

  /// Load annotation data from file
  Future<AnnotationData?> loadAnnotations(String videoPath) async {
    try {
      final annotationPath = getAnnotationPath(videoPath);
      final file = File(annotationPath);

      if (!await file.exists()) {
        return null;
      }

      final jsonString = await file.readAsString();
      final jsonData = json.decode(jsonString) as Map<String, dynamic>;

      return AnnotationData.fromJson(jsonData);
    } catch (e) {
      print('Error loading annotations: $e');
      return null;
    }
  }

  /// Check if annotations exist for video
  Future<bool> hasAnnotations(String videoPath) async {
    final annotationPath = getAnnotationPath(videoPath);
    return await File(annotationPath).exists();
  }

  /// Delete annotations for video
  Future<bool> deleteAnnotations(String videoPath) async {
    try {
      final annotationPath = getAnnotationPath(videoPath);
      final file = File(annotationPath);

      if (await file.exists()) {
        await file.delete();
      }

      return true;
    } catch (e) {
      print('Error deleting annotations: $e');
      return false;
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
      print('Error adding to recent files: $e');
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
      print('Error getting recent files: $e');
      return [];
    }
  }

  /// Clear recent files list
  Future<void> clearRecentFiles() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_recentFilesKey);
  }
}
