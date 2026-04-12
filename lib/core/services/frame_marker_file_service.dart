import 'dart:convert';

import '../models/annotation_data.dart';
import '../../features/annotations/models/frame_marker.dart';

class FrameMarkerFileService {
  static const String payloadType = 'framesketch_markers';
  static const int payloadVersion = 1;

  String encodeMarkerList({required AnnotationData annotationData}) {
    final payload = <String, dynamic>{
      'type': payloadType,
      'version': payloadVersion,
      'videoId': annotationData.videoId,
      'videoPath': annotationData.videoPath,
      'youtubeUrl': annotationData.youtubeUrl,
      'fps': annotationData.fps,
      'exportedAt': DateTime.now().toIso8601String(),
      'markers': annotationData.markers.map((marker) => marker.toJson()).toList(),
    };

    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  List<FrameMarker> decodeMarkerList(String rawJson) {
    final decoded = jsonDecode(rawJson);

    if (decoded is List) {
      return _parseMarkers(decoded);
    }

    if (decoded is Map<String, dynamic>) {
      final markers = decoded['markers'];
      if (markers is List) {
        return _parseMarkers(markers);
      }
    }

    throw const FormatException('Marker file is missing a valid markers array.');
  }

  String buildSuggestedBaseName(AnnotationData annotationData) {
    final youtubeUrl = annotationData.youtubeUrl?.trim();
    if (youtubeUrl != null && youtubeUrl.isNotEmpty) {
      final uri = Uri.tryParse(youtubeUrl);
      final segments = uri?.pathSegments.where((segment) => segment.isNotEmpty);
      final videoId =
          uri?.queryParameters['v'] ??
          (uri?.host.toLowerCase().contains('youtu.be') == true
              ? segments?.isNotEmpty == true
                    ? segments!.last
                    : null
              : null);
      return _sanitizeBaseName(videoId == null || videoId.isEmpty
          ? 'youtube_markers'
          : 'youtube_$videoId');
    }

    final videoPath = annotationData.videoPath.trim();
    if (videoPath.isEmpty) {
      return 'markers';
    }

    final normalized = videoPath.replaceAll('\\', '/');
    final fileName = normalized.split('/').last;
    final dotIndex = fileName.lastIndexOf('.');
    final baseName = dotIndex > 0 ? fileName.substring(0, dotIndex) : fileName;
    return _sanitizeBaseName(baseName.isEmpty ? 'markers' : baseName);
  }

  List<FrameMarker> _parseMarkers(List<dynamic> rawMarkers) {
    return rawMarkers
        .whereType<Map>()
        .map((marker) => FrameMarker.fromJson(Map<String, dynamic>.from(marker)))
        .toList();
  }

  String _sanitizeBaseName(String input) {
    final sanitized = input
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    if (sanitized.isEmpty) {
      return 'markers';
    }

    const maxLength = 64;
    if (sanitized.length <= maxLength) {
      return sanitized;
    }

    return sanitized.substring(0, maxLength).trimRight();
  }
}
