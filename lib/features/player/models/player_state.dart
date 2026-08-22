import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../../core/models/video_metadata.dart';

enum PlayerSourceType { localFile, network }

/// Player state
class PlayerState {
  final Player? player;
  final VideoController? videoController;
  final VideoMetadata? metadata;
  final Duration position;
  final Duration duration;
  final bool isPlaying;
  final bool isLoading;
  final double volume;
  final bool isMuted;
  final String? error;
  final String? currentVideoPath;
  final String? currentSourceLabel;
  final String? currentDisplayLabel;
  final PlayerSourceType? sourceType;
  final double? sourceFps;

  const PlayerState({
    this.player,
    this.videoController,
    this.metadata,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.isPlaying = false,
    this.isLoading = false,
    this.volume = 100.0,
    this.isMuted = false,
    this.error,
    this.currentVideoPath,
    this.currentSourceLabel,
    this.currentDisplayLabel,
    this.sourceType,
    this.sourceFps,
  });

  PlayerState copyWith({
    Player? player,
    VideoController? videoController,
    VideoMetadata? metadata,
    Duration? position,
    Duration? duration,
    bool? isPlaying,
    bool? isLoading,
    double? volume,
    bool? isMuted,
    String? error,
    String? currentVideoPath,
    String? currentSourceLabel,
    String? currentDisplayLabel,
    PlayerSourceType? sourceType,
    double? sourceFps,
    bool clearPlayer = false,
    bool clearVideoController = false,
    bool clearMetadata = false,
    bool clearCurrentVideoPath = false,
    bool clearCurrentSourceLabel = false,
    bool clearCurrentDisplayLabel = false,
    bool clearSourceType = false,
    bool clearSourceFps = false,
    bool clearError = false,
  }) {
    return PlayerState(
      player: clearPlayer ? null : (player ?? this.player),
      videoController: clearVideoController
          ? null
          : (videoController ?? this.videoController),
      metadata: clearMetadata ? null : (metadata ?? this.metadata),
      position: position ?? this.position,
      duration: duration ?? this.duration,
      isPlaying: isPlaying ?? this.isPlaying,
      isLoading: isLoading ?? this.isLoading,
      volume: volume ?? this.volume,
      isMuted: isMuted ?? this.isMuted,
      error: clearError ? null : (error ?? this.error),
      currentVideoPath: clearCurrentVideoPath
          ? null
          : (currentVideoPath ?? this.currentVideoPath),
      currentSourceLabel: clearCurrentSourceLabel
          ? null
          : (currentSourceLabel ?? this.currentSourceLabel),
      currentDisplayLabel: clearCurrentDisplayLabel
          ? null
          : (currentDisplayLabel ?? this.currentDisplayLabel),
      sourceType: clearSourceType ? null : (sourceType ?? this.sourceType),
      sourceFps: clearSourceFps ? null : (sourceFps ?? this.sourceFps),
    );
  }

  bool get hasLoadedSource => currentVideoPath != null;
  bool get isLocalFileSource => sourceType == PlayerSourceType.localFile;
}
