import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../../../core/models/video_metadata.dart';

/// Player state
class PlayerState {
  final Player? player;
  final VideoController? videoController;
  final VideoMetadata? metadata;
  final Duration position;
  final Duration duration;
  final bool isPlaying;
  final bool isLoading;
  final String? error;
  final String? currentVideoPath;

  const PlayerState({
    this.player,
    this.videoController,
    this.metadata,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.isPlaying = false,
    this.isLoading = false,
    this.error,
    this.currentVideoPath,
  });

  PlayerState copyWith({
    Player? player,
    VideoController? videoController,
    VideoMetadata? metadata,
    Duration? position,
    Duration? duration,
    bool? isPlaying,
    bool? isLoading,
    String? error,
    String? currentVideoPath,
  }) {
    return PlayerState(
      player: player ?? this.player,
      videoController: videoController ?? this.videoController,
      metadata: metadata ?? this.metadata,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      isPlaying: isPlaying ?? this.isPlaying,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      currentVideoPath: currentVideoPath ?? this.currentVideoPath,
    );
  }
}

/// Player provider with media_kit integration
class PlayerNotifier extends StateNotifier<PlayerState> {
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<Duration>? _durationSubscription;
  StreamSubscription<bool>? _playingSubscription;

  PlayerNotifier() : super(const PlayerState());

  /// Initialize media_kit (call once at app startup)
  static void initializeMediaKit() {
    MediaKit.ensureInitialized();
  }

  /// Load video file
  Future<void> loadVideo(String filePath) async {
    try {
      state = state.copyWith(isLoading: true, error: null);

      // Dispose existing player if any
      await _disposePlayer();

      // Create new player
      final player = Player();
      final videoController = VideoController(player);

      // Listen to streams immediately
      _positionSubscription = player.stream.position.listen((position) {
        state = state.copyWith(position: position);
      });

      _durationSubscription = player.stream.duration.listen((duration) {
        state = state.copyWith(duration: duration);
      });

      _playingSubscription = player.stream.playing.listen((isPlaying) {
        state = state.copyWith(isPlaying: isPlaying);
      });

      // Open video first to get metadata from media_kit
      await player.open(Media(filePath));

      // Wait a moment for streams to populate
      await Future.delayed(const Duration(milliseconds: 500));

      // Get metadata from player streams
      final videoDuration = player.state.duration;
      final videoWidth = player.state.width;
      final videoHeight = player.state.height;

      // Estimate FPS (default to 30 if not available)
      // Note: media_kit doesn't directly expose FPS, so we use a reasonable default
      const double fps = 30.0;

      // Calculate frame count
      final frameCount = (videoDuration.inSeconds * fps).round();

      // Create metadata from media_kit data
      final metadata = VideoMetadata(
        filePath: filePath,
        duration: videoDuration,
        fps: fps,
        width: videoWidth ?? 1920,
        height: videoHeight ?? 1080,
        codec: 'unknown', // media_kit doesn't expose codec easily
        format: 'unknown', // media_kit doesn't expose format easily
        frameCount: frameCount,
        timeBase: null,
      );

      state = state.copyWith(
        player: player,
        videoController: videoController,
        metadata: metadata,
        isLoading: false,
        currentVideoPath: filePath,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Error loading video: $e',
      );
    }
  }

  /// Play video
  Future<void> play() async {
    await state.player?.play();
  }

  /// Pause video
  Future<void> pause() async {
    await state.player?.pause();
  }

  /// Toggle play/pause
  Future<void> togglePlayPause() async {
    if (state.isPlaying) {
      await pause();
    } else {
      await play();
    }
  }

  /// Stop and reset to beginning
  Future<void> stop() async {
    await state.player?.pause();
    await seek(Duration.zero);
  }

  /// Seek to position
  Future<void> seek(Duration position) async {
    final clampedPosition = Duration(
      milliseconds: position.inMilliseconds.clamp(
        0,
        state.duration.inMilliseconds,
      ),
    );
    await state.player?.seek(clampedPosition);
  }

  /// Step forward by one frame
  Future<void> stepForward() async {
    final metadata = state.metadata;
    if (metadata == null) return;

    // Calculate frame duration
    final frameDuration = Duration(
      microseconds: (1000000 / metadata.fps).round(),
    );

    // Calculate next frame position
    final nextPosition = state.position + frameDuration;

    // Clamp to video duration
    final clampedPosition = Duration(
      milliseconds: nextPosition.inMilliseconds.clamp(
        0,
        state.duration.inMilliseconds,
      ),
    );

    // Pause if playing
    if (state.isPlaying) {
      await pause();
    }

    // Seek to next frame
    await seek(clampedPosition);
  }

  /// Step backward by one frame
  Future<void> stepBackward() async {
    final metadata = state.metadata;
    if (metadata == null) return;

    // Calculate frame duration
    final frameDuration = Duration(
      microseconds: (1000000 / metadata.fps).round(),
    );

    // Calculate previous frame position
    final prevPosition = state.position - frameDuration;

    // Clamp to 0
    final clampedPosition = Duration(
      milliseconds: prevPosition.inMilliseconds.clamp(
        0,
        state.duration.inMilliseconds,
      ),
    );

    // Pause if playing
    if (state.isPlaying) {
      await pause();
    }

    // Seek to previous frame
    await seek(clampedPosition);
  }

  /// Jump forward by duration
  Future<void> jumpForward(Duration amount) async {
    final newPosition = state.position + amount;
    await seek(newPosition);
  }

  /// Jump backward by duration
  Future<void> jumpBackward(Duration amount) async {
    final newPosition = state.position - amount;
    await seek(newPosition);
  }

  /// Get current frame number
  int get currentFrame {
    final metadata = state.metadata;
    if (metadata == null) return 0;

    final seconds = state.position.inMicroseconds / 1000000.0;
    return (seconds * metadata.fps).round();
  }

  /// Dispose player
  Future<void> _disposePlayer() async {
    await _positionSubscription?.cancel();
    await _durationSubscription?.cancel();
    await _playingSubscription?.cancel();
    _positionSubscription = null;
    _durationSubscription = null;
    _playingSubscription = null;

    await state.player?.dispose();
  }

  @override
  void dispose() {
    _disposePlayer();
    super.dispose();
  }
}

/// Player provider instance
final playerProvider = StateNotifierProvider<PlayerNotifier, PlayerState>((ref) {
  return PlayerNotifier();
});
