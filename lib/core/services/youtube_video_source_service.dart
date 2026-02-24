import 'package:youtube_explode_dart/youtube_explode_dart.dart';

enum YouTubeSourceLoadErrorCode {
  invalidUrl,
  privateVideo,
  ageRestricted,
  regionLocked,
  liveUnsupported,
  unavailable,
  networkError,
  unknown,
}

class YouTubeSourceLoadException implements Exception {
  final YouTubeSourceLoadErrorCode code;
  final String userMessage;
  final String technicalMessage;

  const YouTubeSourceLoadException({
    required this.code,
    required this.userMessage,
    required this.technicalMessage,
  });

  @override
  String toString() => technicalMessage;
}

class YouTubeResolvedSource {
  final String originalUrl;
  final String canonicalUrl;
  final String videoId;
  final String title;
  final Duration? duration;
  final Uri streamUri;

  const YouTubeResolvedSource({
    required this.originalUrl,
    required this.canonicalUrl,
    required this.videoId,
    required this.title,
    required this.streamUri,
    this.duration,
  });
}

/// Resolves a YouTube page URL to a directly playable media URL for mpv/media_kit.
class YouTubeVideoSourceService {
  Future<YouTubeResolvedSource> resolve(String inputUrl) async {
    final raw = inputUrl.trim();
    if (raw.isEmpty) {
      throw const YouTubeSourceLoadException(
        code: YouTubeSourceLoadErrorCode.invalidUrl,
        userMessage: 'Please paste a valid YouTube URL.',
        technicalMessage: 'YouTube URL is empty',
      );
    }

    final yt = YoutubeExplode();
    try {
      final video = await yt.videos.get(raw);
      final manifest = await yt.videos.streamsClient.getManifest(video.id);
      final muxed = manifest.muxed.withHighestBitrate();

      return YouTubeResolvedSource(
        originalUrl: raw,
        canonicalUrl: 'https://www.youtube.com/watch?v=${video.id.value}',
        videoId: video.id.value,
        title: video.title,
        duration: video.duration,
        streamUri: muxed.url,
      );
    } on YouTubeSourceLoadException {
      rethrow;
    } catch (e) {
      throw _classifyError(e);
    } finally {
      yt.close();
    }
  }

  YouTubeSourceLoadException _classifyError(Object error) {
    final text = error.toString();
    final lower = text.toLowerCase();

    if (lower.contains('private')) {
      return YouTubeSourceLoadException(
        code: YouTubeSourceLoadErrorCode.privateVideo,
        userMessage: 'This YouTube video is private and cannot be loaded.',
        technicalMessage: text,
      );
    }

    if (lower.contains('age') &&
        (lower.contains('restricted') || lower.contains('restriction'))) {
      return YouTubeSourceLoadException(
        code: YouTubeSourceLoadErrorCode.ageRestricted,
        userMessage:
            'This YouTube video is age-restricted and requires sign-in, which is not supported in the app.',
        technicalMessage: text,
      );
    }

    if (lower.contains('region') ||
        lower.contains('country') && lower.contains('available')) {
      return YouTubeSourceLoadException(
        code: YouTubeSourceLoadErrorCode.regionLocked,
        userMessage:
            'This YouTube video appears to be region-locked and cannot be played from your location.',
        technicalMessage: text,
      );
    }

    if (lower.contains('live') ||
        lower.contains('livestream') ||
        lower.contains('broadcast')) {
      return YouTubeSourceLoadException(
        code: YouTubeSourceLoadErrorCode.liveUnsupported,
        userMessage:
            'Live YouTube streams are not supported by this feature right now.',
        technicalMessage: text,
      );
    }

    if (lower.contains('unavailable') ||
        lower.contains('not available') ||
        lower.contains('removed') ||
        lower.contains('deleted')) {
      return YouTubeSourceLoadException(
        code: YouTubeSourceLoadErrorCode.unavailable,
        userMessage:
            'This YouTube video is unavailable (removed, deleted, or not accessible).',
        technicalMessage: text,
      );
    }

    if (lower.contains('socket') ||
        lower.contains('timed out') ||
        lower.contains('timeout') ||
        lower.contains('connection') ||
        lower.contains('network') ||
        lower.contains('http')) {
      return YouTubeSourceLoadException(
        code: YouTubeSourceLoadErrorCode.networkError,
        userMessage:
            'Could not connect to YouTube. Check your internet connection and try again.',
        technicalMessage: text,
      );
    }

    return YouTubeSourceLoadException(
      code: YouTubeSourceLoadErrorCode.unknown,
      userMessage:
          'The YouTube video could not be loaded. It may be restricted or temporarily unavailable.',
      technicalMessage: text,
    );
  }
}
