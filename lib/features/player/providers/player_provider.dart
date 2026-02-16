import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../../../core/models/video_metadata.dart';
import '../../loop/providers/loop_provider.dart';
import '../../crop/providers/crop_provider.dart';

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
  }) {
    return PlayerState(
      player: player ?? this.player,
      videoController: videoController ?? this.videoController,
      metadata: metadata ?? this.metadata,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      isPlaying: isPlaying ?? this.isPlaying,
      isLoading: isLoading ?? this.isLoading,
      volume: volume ?? this.volume,
      isMuted: isMuted ?? this.isMuted,
      error: error,
      currentVideoPath: currentVideoPath ?? this.currentVideoPath,
    );
  }
}

/// Player provider with media_kit integration
class PlayerNotifier extends StateNotifier<PlayerState> {
  final Ref _ref;
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<Duration>? _durationSubscription;
  StreamSubscription<bool>? _playingSubscription;
  StreamSubscription<double>? _volumeSubscription;
  double _lastNonZeroVolume = 100.0;

  PlayerNotifier(this._ref) : super(const PlayerState());

  /// Initialize media_kit (call once at app startup)
  static void initializeMediaKit() {
    MediaKit.ensureInitialized();
  }

  /// Load video file
  Future<void> loadVideo(String filePath) async {
    try {
      state = state.copyWith(isLoading: true, error: null);

      // Reset loop state for new video
      _ref.read(loopProvider.notifier).onVideoChanged();

      // Reset crop state for new video
      _ref.read(cropProvider.notifier).onVideoChanged();

      // Dispose existing player if any
      await _disposePlayer();

      // Create new player
      final player = Player();
      final videoController = VideoController(player);

      // Listen to streams immediately with loop boundary checking
      _positionSubscription = player.stream.position.listen((position) {
        state = state.copyWith(position: position);

        // Check loop boundaries and seek if needed
        final loopNotifier = _ref.read(loopProvider.notifier);
        final seekPosition = loopNotifier.checkLoopBoundary(position);
        if (seekPosition != null) {
          final wasPlaying = state.isPlaying;
          // Use Future.microtask to avoid state update during build
          Future.microtask(() async {
            await seek(seekPosition);
            // Resume playback if it was playing before the loop
            if (wasPlaying) {
              await play();
              // Ensure state reflects playing status
              state = state.copyWith(isPlaying: true);
            }
          });
        }
      });

      _durationSubscription = player.stream.duration.listen((duration) {
        state = state.copyWith(duration: duration);
      });

      _playingSubscription = player.stream.playing.listen((isPlaying) {
        state = state.copyWith(isPlaying: isPlaying);
      });

      _volumeSubscription = player.stream.volume.listen((volume) {
        final muted = volume <= 0.001;
        if (!muted) {
          _lastNonZeroVolume = volume;
        }
        state = state.copyWith(
          volume: volume,
          isMuted: muted,
        );
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

      // Ensure player starts with the app's current volume preference.
      await player.setVolume(state.volume);
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

  /// Toggle mute/unmute for app-only audio control.
  Future<void> toggleMute() async {
    if (state.isMuted || state.volume <= 0.001) {
      final restore = _lastNonZeroVolume <= 0.001 ? 100.0 : _lastNonZeroVolume;
      await setVolume(restore);
    } else {
      _lastNonZeroVolume = state.volume;
      await setVolume(0.0);
    }
  }

  /// Set player volume (0-100).
  Future<void> setVolume(double value) async {
    final clamped = value.clamp(0.0, 100.0);
    await state.player?.setVolume(clamped);
    final muted = clamped <= 0.001;
    state = state.copyWith(
      volume: clamped,
      isMuted: muted,
    );
    if (!muted) {
      _lastNonZeroVolume = clamped;
    }
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
    final positionSubscription = _positionSubscription;
    final durationSubscription = _durationSubscription;
    final playingSubscription = _playingSubscription;
    final volumeSubscription = _volumeSubscription;
    final player = state.player;

    _positionSubscription = null;
    _durationSubscription = null;
    _playingSubscription = null;
    _volumeSubscription = null;

    await positionSubscription?.cancel();
    await durationSubscription?.cancel();
    await playingSubscription?.cancel();
    await volumeSubscription?.cancel();
    await player?.dispose();
  }

  @override
  void dispose() {
    _disposePlayer();
    super.dispose();
  }
}

/// Player provider instance
final playerProvider = StateNotifierProvider<PlayerNotifier, PlayerState>((ref) {
  return PlayerNotifier(ref);
});
