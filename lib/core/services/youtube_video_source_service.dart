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
  final Uri? externalAudioUri;
  final String? selectedQualityLabel;
  final int? selectedWidth;
  final int? selectedHeight;
  final bool usesHls;

  const YouTubeResolvedSource({
    required this.originalUrl,
    required this.canonicalUrl,
    required this.videoId,
    required this.title,
    required this.streamUri,
    this.externalAudioUri,
    this.selectedQualityLabel,
    this.selectedWidth,
    this.selectedHeight,
    this.usesHls = false,
    this.duration,
  });
}

/// Resolves a YouTube page URL to a directly playable media URL for mpv/media_kit.
class YouTubeVideoSourceService {
  static const int _preferredMinimumHeight = 720;
  static final List<YoutubeApiClient> _manifestClients = <YoutubeApiClient>[
    YoutubeApiClient.safari,
    YoutubeApiClient.androidVr,
    YoutubeApiClient.ios,
    YoutubeApiClient.tv,
    YoutubeApiClient.android,
  ];

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
      final manifest = await yt.videos.streamsClient.getManifest(
        video.id,
        ytClients: _manifestClients,
      );
      final selected = _selectPreferredStream(manifest);

      return YouTubeResolvedSource(
        originalUrl: raw,
        canonicalUrl: 'https://www.youtube.com/watch?v=${video.id.value}',
        videoId: video.id.value,
        title: video.title,
        duration: video.duration,
        streamUri: selected.video.url,
        externalAudioUri: selected.externalAudio?.url,
        selectedQualityLabel: selected.video.qualityLabel,
        selectedWidth: selected.video.videoResolution.width,
        selectedHeight: selected.video.videoResolution.height,
        usesHls:
            selected.video is HlsMuxedStreamInfo ||
            selected.video is HlsVideoStreamInfo,
      );
    } on YouTubeSourceLoadException {
      rethrow;
    } catch (e) {
      throw _classifyError(e);
    } finally {
      yt.close();
    }
  }

  _SelectedYouTubeStream _selectPreferredStream(StreamManifest manifest) {
    final hlsMuxed = manifest.hls.whereType<HlsMuxedStreamInfo>().toList();
    final hdHlsMuxed = hlsMuxed
        .where(
          (stream) => stream.videoResolution.height >= _preferredMinimumHeight,
        )
        .toList();
    if (hdHlsMuxed.isNotEmpty) {
      return _SelectedYouTubeStream(
        video: hdHlsMuxed.sortByVideoQuality().first,
      );
    }

    final hlsVideoOnly = manifest.hls.whereType<HlsVideoStreamInfo>().toList();
    final hdHlsVideoOnly = hlsVideoOnly
        .where(
          (stream) => stream.videoResolution.height >= _preferredMinimumHeight,
        )
        .toList();
    if (hdHlsVideoOnly.isNotEmpty) {
      final selectedVideo = hdHlsVideoOnly.sortByVideoQuality().first;
      final selectedAudio = _selectHlsCompanionAudio(
        selectedVideo,
        manifest.hls.whereType<HlsAudioStreamInfo>(),
      );
      if (selectedAudio != null) {
        return _SelectedYouTubeStream(
          video: selectedVideo,
          externalAudio: selectedAudio,
        );
      }
    }

    final hdAdaptiveVideoOnly = manifest.videoOnly
        .where(
          (stream) => stream.videoResolution.height >= _preferredMinimumHeight,
        )
        .toList();
    if (hdAdaptiveVideoOnly.isNotEmpty) {
      final selectedVideo = hdAdaptiveVideoOnly.sortByVideoQuality().first;
      final selectedAudio = _selectAdaptiveCompanionAudio(
        selectedVideo,
        manifest.audioOnly,
      );
      if (selectedAudio != null) {
        return _SelectedYouTubeStream(
          video: selectedVideo,
          externalAudio: selectedAudio,
        );
      }
    }

    throw const YouTubeSourceLoadException(
      code: YouTubeSourceLoadErrorCode.unavailable,
      userMessage:
          'This video does not have a playable 720p+ stream in this app right now.',
      technicalMessage:
          'Manifest did not include a 720p+ stream with attachable audio.',
    );
  }

  HlsAudioStreamInfo? _selectHlsCompanionAudio(
    HlsVideoStreamInfo video,
    Iterable<HlsAudioStreamInfo> candidates,
  ) {
    final audioStreams = candidates.toList();
    if (audioStreams.isEmpty) {
      return null;
    }

    final linkedTag = video.audioItag;
    if (linkedTag != null) {
      final linked = audioStreams
          .where((stream) => stream.tag == linkedTag)
          .toList();
      if (linked.isNotEmpty) {
        return linked.withHighestBitrate();
      }
    }

    return audioStreams.withHighestBitrate();
  }

  AudioOnlyStreamInfo? _selectAdaptiveCompanionAudio(
    VideoOnlyStreamInfo video,
    Iterable<AudioOnlyStreamInfo> candidates,
  ) {
    final audioStreams = candidates.toList();
    if (audioStreams.isEmpty) {
      return null;
    }

    final sameContainer = audioStreams
        .where((stream) => stream.container == video.container)
        .toList();
    if (sameContainer.isNotEmpty) {
      return sameContainer.withHighestBitrate();
    }

    return audioStreams.withHighestBitrate();
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

class _SelectedYouTubeStream {
  final VideoStreamInfo video;
  final AudioStreamInfo? externalAudio;

  const _SelectedYouTubeStream({required this.video, this.externalAudio});
}
