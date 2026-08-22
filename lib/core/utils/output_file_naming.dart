import 'dart:io' show File;

import '../models/annotation_data.dart';

/// Sanitizes [input] into a file-system-safe base name for exported files.
String buildSafeOutputBaseName(String input) {
  final sanitized = input
      .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  if (sanitized.isEmpty) {
    return 'export';
  }

  const maxLen = 64;
  if (sanitized.length <= maxLen) {
    return sanitized;
  }

  return sanitized.substring(0, maxLen).trimRight();
}

/// Ensures an annotation save path carries a supported extension, defaulting
/// to `.framesketch`.
String normalizeAnnotationJsonOutputPath(String rawPath) {
  final lower = rawPath.toLowerCase();
  if (lower.endsWith('.framesketch') ||
      lower.endsWith('.annotations.json') ||
      lower.endsWith('.json')) {
    return rawPath;
  }
  return '$rawPath.framesketch';
}

/// Derives a suggested base name for annotation/export files from the loaded
/// source: the YouTube video id when available, otherwise the video file name.
String buildSuggestedAnnotationFileBaseName({
  required AnnotationData annotationData,
  required String? playerSourceLabel,
}) {
  final youtubeUrl = annotationData.youtubeUrl;
  if (youtubeUrl != null && youtubeUrl.trim().isNotEmpty) {
    final uri = Uri.tryParse(youtubeUrl);
    final shortSegments = uri?.pathSegments.where((s) => s.isNotEmpty).toList();
    final videoId =
        uri?.queryParameters['v'] ??
        (uri?.host.toLowerCase().contains('youtu.be') == true
            ? ((shortSegments != null && shortSegments.isNotEmpty)
                  ? shortSegments.last
                  : null)
            : null);
    final label = videoId == null || videoId.isEmpty
        ? (playerSourceLabel ?? 'youtube_video')
        : 'youtube_$videoId';
    return buildSafeOutputBaseName(label);
  }

  final videoPath = annotationData.videoPath;
  if (videoPath.isNotEmpty) {
    final fileName = File(videoPath).uri.pathSegments.isNotEmpty
        ? File(videoPath).uri.pathSegments.last
        : videoPath;
    final dot = fileName.lastIndexOf('.');
    final base = dot > 0 ? fileName.substring(0, dot) : fileName;
    return buildSafeOutputBaseName(base);
  }

  return 'annotations';
}
