import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../../../core/models/video_metadata.dart';
import '../../loop/providers/loop_provider.dart';
import '../../crop/providers/crop_provider.dart';

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

/// Player provider with media_kit integration
class PlayerNotifier extends StateNotifier<PlayerState> {
  final Ref _ref;
  static const int _uiPositionUpdateIntervalMs = 33;
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<Duration>? _durationSubscription;
  StreamSubscription<bool>? _playingSubscription;
  StreamSubscription<double>? _volumeSubscription;
  StreamSubscription<int?>? _widthSubscription;
  StreamSubscription<int?>? _heightSubscription;
  double _lastNonZeroVolume = 100.0;
  bool _allowStreamDimensionUpdates = false;
  int? _streamVideoWidth;
  int? _streamVideoHeight;
  int _lastPublishedPositionMs = -1;
  // While frame-stepping (paused), the deliberately-stepped position in ms. The
  // position stream listener uses it to reject the transient, out-of-order
  // positions mpv emits during a backward frame-step's internal seek, which
  // would otherwise make the displayed frame jump back and forth (e.g.
  // 361, 360, 361, 359). Cleared by any non-frame-step move (seek/jump/play).
  int? _frameStepTargetMs;
  bool? _supportsNativeFrameStep;
  bool _stillFrameAudioMuted = false;
  Duration? _realFrameStepDuration;
  Future<void> _frameStepQueue = Future<void>.value();

  PlayerNotifier(this._ref) : super(const PlayerState());

  void _tryApplyStreamDimensions() {
    if (!_allowStreamDimensionUpdates) {
      return;
    }

    final metadata = state.metadata;
    if (metadata == null) {
      return;
    }

    final width = _streamVideoWidth;
    final height = _streamVideoHeight;
    if (width == null || height == null || width <= 0 || height <= 0) {
      return;
    }

    if (metadata.width == width && metadata.height == height) {
      _allowStreamDimensionUpdates = false;
      return;
    }

    state = state.copyWith(
      metadata: metadata.copyWith(width: width, height: height),
    );
    _allowStreamDimensionUpdates = false;
  }

  int _frameIndexFor(Duration position, double fps) {
    final seconds = position.inMicroseconds / 1000000.0;
    return (seconds * fps).round();
  }

  Duration _positionForFrameIndex(int frameIndex, double fps, int frameCount) {
    final clampedFrame = frameCount > 0
        ? frameIndex.clamp(0, frameCount)
        : (frameIndex < 0 ? 0 : frameIndex);
    final targetMicros = ((clampedFrame * 1000000.0) / fps).round();
    return _clampToDuration(Duration(microseconds: targetMicros));
  }

  /// FPS used only as a first-step fallback for frame-step math, before the
  /// real frame duration has been measured from a native frame-step.
  double get _stepFps {
    final source = state.sourceFps;
    if (source != null && source > 0) return source;
    return state.metadata?.fps ?? 30.0;
  }

  /// Position exactly one real video frame before/after [from].
  ///
  /// Once a native `frame-step` has run, the real frame duration is known by
  /// measurement and used for both directions so they move identically. Until
  /// then it falls back to FPS math — which can be wrong when the container
  /// reports a misdetected (e.g. halved) frame rate.
  Duration _frameStepTarget(
    Duration from,
    VideoMetadata metadata, {
    required bool forward,
  }) {
    final measured = _realFrameStepDuration;
    if (measured != null) {
      return _clampToDuration(forward ? from + measured : from - measured);
    }
    final fps = _stepFps;
    final baseFrame = _frameIndexFor(from, fps);
    return _positionForFrameIndex(
      forward ? baseFrame + 1 : baseFrame - 1,
      fps,
      metadata.frameCount,
    );
  }

  Duration _clampToDuration(Duration value) {
    final maxUs = state.duration.inMicroseconds;
    if (maxUs <= 0) {
      return value.isNegative ? Duration.zero : value;
    }
    final clampedUs = value.inMicroseconds.clamp(0, maxUs);
    return Duration(microseconds: clampedUs);
  }

  Future<void> _enqueueFrameStep(Future<void> Function() operation) {
    final queued = _frameStepQueue.then((_) => operation());
    _frameStepQueue = queued.catchError((_) {});
    return queued;
  }

  /// Wait until the player reports a position near [target] (or a safety
  /// deadline elapses) so the stepped frame has actually landed before the
  /// next queued step runs. This stops rapid steps from being coalesced
  /// (backward seeks) or dropped (overlapping forward frame-steps) by mpv,
  /// which otherwise skips frames or fails to advance. Polls [Player.state]
  /// directly so it cannot miss a position update that lands before a stream
  /// listener could attach.
  Future<void> _awaitPositionSettled(Duration target) async {
    final player = state.player;
    if (player == null) return;

    final fps = state.metadata?.fps ?? 30.0;
    final toleranceUs = (750000.0 / fps).round().clamp(2000, 60000);

    bool near() =>
        (player.state.position.inMicroseconds - target.inMicroseconds).abs() <=
        toleranceUs;

    final deadline = DateTime.now().add(const Duration(milliseconds: 600));
    while (!near()) {
      if (DateTime.now().isAfter(deadline)) return;
      await Future<void>.delayed(const Duration(milliseconds: 8));
    }
  }

  /// Wait until the player position moves away from [from] (or a safety
  /// deadline elapses). Used after a native `frame-step`, whose exact landing
  /// position is not known in advance.
  Future<void> _awaitPositionChanged(Duration from) async {
    final player = state.player;
    if (player == null) return;

    final deadline = DateTime.now().add(const Duration(milliseconds: 600));
    while (player.state.position == from) {
      if (DateTime.now().isAfter(deadline)) return;
      await Future<void>.delayed(const Duration(milliseconds: 8));
    }
  }

  Future<bool> _tryNativeFrameStep({required bool forward}) async {
    final player = state.player;
    if (player == null) return false;
    if (_supportsNativeFrameStep == false) return false;

    final dynamic platform = player.platform;
    if (platform == null) {
      _supportsNativeFrameStep = false;
      return false;
    }

    if (_supportsNativeFrameStep == null) {
      final runtimeName = platform.runtimeType.toString().toLowerCase();
      _supportsNativeFrameStep = runtimeName.contains('nativeplayer');
    }
    if (_supportsNativeFrameStep != true) {
      return false;
    }

    try {
      await platform.command(
        forward
            ? const <String>['frame-step']
            : const <String>['frame-back-step'],
      );
      return true;
    } catch (_) {
      _supportsNativeFrameStep = false;
      return false;
    }
  }

  String _secondsArgument(Duration value) {
    final seconds = value.inMicroseconds / 1000000.0;
    var text = seconds.toStringAsFixed(6);
    text = text.replaceFirst(RegExp(r'0+$'), '');
    text = text.replaceFirst(RegExp(r'\.$'), '');
    if (text == '-0') return '0';
    return text;
  }

  Future<bool> _tryNativeExactRelativeSeek(Duration delta) async {
    if (delta == Duration.zero) {
      return true;
    }

    final dynamic platform = state.player?.platform;
    if (platform == null) return false;

    final runtimeName = platform.runtimeType.toString().toLowerCase();
    if (!runtimeName.contains('nativeplayer')) return false;

    try {
      await platform.command(<String>[
        'seek',
        _secondsArgument(delta),
        'relative+exact',
      ]);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _setStillFrameAudioMuted(bool muted) async {
    if (_stillFrameAudioMuted == muted) return;

    final dynamic platform = state.player?.platform;
    if (platform == null) return;

    final runtimeName = platform.runtimeType.toString().toLowerCase();
    if (!runtimeName.contains('nativeplayer')) return;

    try {
      await platform.setProperty('mute', muted ? 'yes' : 'no');
      _stillFrameAudioMuted = muted;
    } catch (_) {}
  }

  /// Initialize media_kit (call once at app startup)
  static void initializeMediaKit() {
    MediaKit.ensureInitialized();
  }

  /// Load local video file
  Future<void> loadVideo(String filePath) async {
    await _loadVideoSource(
      mediaPath: filePath,
      sourceLabel: filePath,
      displayLabel: filePath,
      sourceType: PlayerSourceType.localFile,
    );
  }

  /// Load network video source (e.g. resolved YouTube stream URL).
  Future<void> loadNetworkVideo({
    required String mediaUrl,
    required String sourceLabel,
    String? displayLabel,
    String? externalAudioUrl,
  }) async {
    await _loadVideoSource(
      mediaPath: mediaUrl,
      sourceLabel: sourceLabel,
      displayLabel: displayLabel,
      sourceType: PlayerSourceType.network,
      externalAudioUrl: externalAudioUrl,
    );
  }

  Future<void> _loadVideoSource({
    required String mediaPath,
    required String sourceLabel,
    String? displayLabel,
    required PlayerSourceType sourceType,
    String? externalAudioUrl,
  }) async {
    try {
      state = state.copyWith(isLoading: true, clearError: true);

      // Reset loop state for new video
      _ref.read(loopProvider.notifier).onVideoChanged();

      // Reset crop state for new video
      _ref.read(cropProvider.notifier).onVideoChanged();

      // Dispose existing player if any
      await _disposePlayer();

      // Create new player
      final player = Player();
      final videoController = VideoController(player);
      _supportsNativeFrameStep = null;

      // Listen to streams immediately with loop boundary checking
      _positionSubscription = player.stream.position.listen((position) {
        final positionMs = position.inMilliseconds;
        final bool shouldPublishPosition;
        if (_frameStepTargetMs != null && !state.isPlaying) {
          // Frame-stepping while paused: the step already published the exact
          // target frame position. Ignore the stream's follow-up events — they
          // are either transient seek positions (from a backward frame-step's
          // internal seek) or sub-frame wobble, both of which would make the
          // displayed frame/timecode jitter. The lock is cleared by any real
          // move (seek/jump/play), after which normal publishing resumes.
          shouldPublishPosition = false;
        } else {
          shouldPublishPosition =
              !state.isPlaying ||
              _lastPublishedPositionMs < 0 ||
              (positionMs - _lastPublishedPositionMs).abs() >=
                  _uiPositionUpdateIntervalMs ||
              positionMs < _lastPublishedPositionMs;
        }
        if (shouldPublishPosition) {
          state = state.copyWith(position: position);
          _lastPublishedPositionMs = positionMs;
        }

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
        if (state.duration == duration) return;
        state = state.copyWith(duration: duration);
      });

      _playingSubscription = player.stream.playing.listen((isPlaying) {
        if (state.isPlaying == isPlaying) return;
        state = state.copyWith(isPlaying: isPlaying);
        unawaited(_setStillFrameAudioMuted(!isPlaying));
      });

      _volumeSubscription = player.stream.volume.listen((volume) {
        final muted = volume <= 0.001;
        if (state.volume == volume && state.isMuted == muted) {
          return;
        }
        if (!muted) {
          _lastNonZeroVolume = volume;
        }
        state = state.copyWith(volume: volume, isMuted: muted);
      });

      _widthSubscription = player.stream.width.listen((value) {
        if (value == null || value <= 0) return;
        _streamVideoWidth = value;
        _tryApplyStreamDimensions();
      });

      _heightSubscription = player.stream.height.listen((value) {
        if (value == null || value <= 0) return;
        _streamVideoHeight = value;
        _tryApplyStreamDimensions();
      });

      // Open paused so loading a new video does not auto-play.
      await player.open(Media(mediaPath), play: false);
      if (externalAudioUrl != null && externalAudioUrl.trim().isNotEmpty) {
        await _attachExternalAudio(
          player: player,
          audioUrl: externalAudioUrl.trim(),
        );
      }

      // Wait for first frame when possible so width/height streams settle.
      try {
        await videoController.waitUntilFirstFrameRendered.timeout(
          const Duration(seconds: 2),
        );
      } catch (_) {
        await Future.delayed(const Duration(milliseconds: 300));
      }

      final snapshot = player.state;
      final rect = videoController.rect.value;

      final widthFromPlayer =
          snapshot.width ?? snapshot.videoParams.w ?? rect?.width.round();
      final heightFromPlayer =
          snapshot.height ?? snapshot.videoParams.h ?? rect?.height.round();

      final videoDuration = snapshot.duration;
      final fps = (snapshot.track.video.fps ?? 0) > 0
          ? snapshot.track.video.fps!
          : 30.0;
      final resolvedWidth = (widthFromPlayer != null && widthFromPlayer > 0)
          ? widthFromPlayer
          : 1920;
      final resolvedHeight = (heightFromPlayer != null && heightFromPlayer > 0)
          ? heightFromPlayer
          : 1080;
      final frameCount = ((videoDuration.inMicroseconds / 1000000.0) * fps)
          .round();

      // Allow one stream-driven width/height correction only when we had to
      // fall back to placeholder dimensions.
      _allowStreamDimensionUpdates =
          widthFromPlayer == null ||
          widthFromPlayer <= 0 ||
          heightFromPlayer == null ||
          heightFromPlayer <= 0;

      // Create metadata from FFprobe/player data
      final metadata = VideoMetadata(
        filePath: sourceLabel,
        duration: videoDuration,
        fps: fps,
        width: resolvedWidth,
        height: resolvedHeight,
        codec: snapshot.track.video.codec ?? 'unknown',
        format: 'unknown',
        frameCount: frameCount,
        timeBase: null,
      );

      state = state.copyWith(
        player: player,
        videoController: videoController,
        metadata: metadata,
        isLoading: false,
        currentVideoPath: mediaPath,
        currentSourceLabel: sourceLabel,
        currentDisplayLabel: displayLabel ?? sourceLabel,
        sourceType: sourceType,
        sourceFps: fps,
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

  Future<void> _attachExternalAudio({
    required Player player,
    required String audioUrl,
  }) async {
    final dynamic platform = player.platform;
    if (platform == null) {
      throw StateError('Player platform is not ready for external audio.');
    }

    final runtimeName = platform.runtimeType.toString().toLowerCase();
    if (!runtimeName.contains('nativeplayer')) {
      throw StateError(
        'External audio streams are only supported on the native player backend.',
      );
    }

    await platform.command(<String>['audio-add', audioUrl, 'select']);
  }

  /// Play video
  Future<void> play() async {
    _frameStepTargetMs = null;
    await _setStillFrameAudioMuted(false);
    await state.player?.play();
  }

  /// Pause video
  Future<void> pause() async {
    await state.player?.pause();
    await _setStillFrameAudioMuted(true);
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
    await _setStillFrameAudioMuted(true);
    await seek(Duration.zero);
  }

  /// Seek to position
  Future<void> seek(Duration position) async {
    _frameStepTargetMs = null;
    if (!state.isPlaying) {
      await _setStillFrameAudioMuted(true);
    }
    final clampedPosition = _clampToDuration(position);
    // Optimistically publish target position so frame-step UI updates
    // immediately, then let stream events reconcile actual playback state.
    if (state.position != clampedPosition) {
      state = state.copyWith(position: clampedPosition);
    }
    await state.player?.seek(clampedPosition);
  }

  /// Step forward by one frame
  Future<void> stepForward() async {
    return _enqueueFrameStep(() async {
      final metadata = state.metadata;
      if (metadata == null) return;

      final basePosition = state.position;
      final nextPosition = _frameStepTarget(
        basePosition,
        metadata,
        forward: true,
      );

      if (state.isPlaying) {
        await pause();
        state = state.copyWith(isPlaying: false);
      } else {
        await _setStillFrameAudioMuted(true);
      }

      final positionBeforeStep = state.player?.state.position;

      if (await _tryNativeFrameStep(forward: true)) {
        if (positionBeforeStep != null) {
          await _awaitPositionChanged(positionBeforeStep);
        }
        final resolvedPosition = state.player?.state.position;
        // Measure the real frame duration so backward steps can match it
        // exactly, instead of relying on a possibly-misdetected FPS.
        if (positionBeforeStep != null &&
            resolvedPosition != null &&
            resolvedPosition > positionBeforeStep) {
          final delta = resolvedPosition - positionBeforeStep;
          if (delta < const Duration(seconds: 1)) {
            _realFrameStepDuration = delta;
          }
        }
        final targetPosition =
            (resolvedPosition != null && resolvedPosition != basePosition)
            ? _clampToDuration(resolvedPosition)
            : nextPosition;
        if (state.position != targetPosition) {
          state = state.copyWith(position: targetPosition);
        }
        _frameStepTargetMs = targetPosition.inMilliseconds;
        return;
      }

      await seek(nextPosition);
      await _awaitPositionSettled(nextPosition);
      _frameStepTargetMs = nextPosition.inMilliseconds;
    });
  }

  /// Step backward by one frame
  Future<void> stepBackward() async {
    return _enqueueFrameStep(() async {
      final metadata = state.metadata;
      if (metadata == null) return;

      if (state.isPlaying) {
        await pause();
        state = state.copyWith(isPlaying: false);
      } else {
        await _setStillFrameAudioMuted(true);
      }

      final basePosition = state.position;
      final prevPosition = _frameStepTarget(
        basePosition,
        metadata,
        forward: false,
      );

      final positionBeforeStep = state.player?.state.position;

      if (await _tryNativeFrameStep(forward: false)) {
        if (positionBeforeStep != null) {
          await _awaitPositionChanged(positionBeforeStep);
        }
        final resolvedPosition = state.player?.state.position;
        // Measure the real frame duration so forward steps can match it
        // exactly, instead of relying on a possibly-misdetected FPS.
        if (positionBeforeStep != null &&
            resolvedPosition != null &&
            resolvedPosition < positionBeforeStep) {
          final delta = positionBeforeStep - resolvedPosition;
          if (delta < const Duration(seconds: 1)) {
            _realFrameStepDuration = delta;
          }
        }
        final targetPosition =
            (resolvedPosition != null && resolvedPosition != basePosition)
            ? _clampToDuration(resolvedPosition)
            : prevPosition;
        if (state.position != targetPosition) {
          state = state.copyWith(position: targetPosition);
        }
        _frameStepTargetMs = targetPosition.inMilliseconds;
        return;
      }

      await seek(prevPosition);
      await _awaitPositionSettled(prevPosition);
      _frameStepTargetMs = prevPosition.inMilliseconds;
    });
  }

  /// Jump forward by duration
  Future<void> jumpForward(Duration amount) async {
    return _enqueueFrameStep(() async {
      _frameStepTargetMs = null;
      final basePosition = state.position;
      final newPosition = _clampToDuration(basePosition + amount);
      final delta = newPosition - basePosition;
      if (state.isPlaying) {
        await pause();
        state = state.copyWith(isPlaying: false);
      } else {
        await _setStillFrameAudioMuted(true);
      }
      if (await _tryNativeExactRelativeSeek(delta)) {
        if (state.position != newPosition) {
          state = state.copyWith(position: newPosition);
        }
        _frameStepTargetMs = newPosition.inMilliseconds;
        return;
      }
      await seek(newPosition);
    });
  }

  /// Jump backward by duration
  Future<void> jumpBackward(Duration amount) async {
    return _enqueueFrameStep(() async {
      _frameStepTargetMs = null;
      final basePosition = state.position;
      final newPosition = _clampToDuration(basePosition - amount);
      final delta = newPosition - basePosition;
      if (state.isPlaying) {
        await pause();
        state = state.copyWith(isPlaying: false);
      } else {
        await _setStillFrameAudioMuted(true);
      }
      if (await _tryNativeExactRelativeSeek(delta)) {
        if (state.position != newPosition) {
          state = state.copyWith(position: newPosition);
        }
        _frameStepTargetMs = newPosition.inMilliseconds;
        return;
      }
      await seek(newPosition);
    });
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

  /// Set effective playback FPS used for frame calculations.
  void setPlaybackFps(double fps) {
    final metadata = state.metadata;
    if (metadata == null) return;
    if (!fps.isFinite) return;
    final clamped = fps.clamp(1.0, 240.0);
    if ((metadata.fps - clamped).abs() < 0.0001) return;
    final frameCount =
        ((metadata.duration.inMicroseconds / 1000000.0) * clamped).round();
    state = state.copyWith(
      metadata: metadata.copyWith(fps: clamped, frameCount: frameCount),
    );
  }

  /// Rename the visible video title shown in the player chrome.
  void renameCurrentDisplayLabel(String label) {
    final trimmed = label.trim();
    if (trimmed.isEmpty) return;
    state = state.copyWith(currentDisplayLabel: trimmed);
  }

  /// Restore FPS to the originally detected value for the loaded video.
  void resetPlaybackFps() {
    final sourceFps = state.sourceFps;
    if (sourceFps == null) return;
    setPlaybackFps(sourceFps);
  }

  /// Set player volume (0-100).
  Future<void> setVolume(double value) async {
    final clamped = value.clamp(0.0, 100.0);
    await state.player?.setVolume(clamped);
    final muted = clamped <= 0.001;
    state = state.copyWith(volume: clamped, isMuted: muted);
    if (!muted) {
      _lastNonZeroVolume = clamped;
    }
  }

  /// Get current frame number
  int get currentFrame {
    final metadata = state.metadata;
    if (metadata == null) return 0;

    return _frameIndexFor(state.position, metadata.fps);
  }

  /// Dispose player
  Future<void> _disposePlayer() async {
    final currentVideoPath = state.currentVideoPath;
    final currentSourceLabel = state.currentSourceLabel;
    final currentDisplayLabel = state.currentDisplayLabel;
    final sourceType = state.sourceType;
    final sourceFps = state.sourceFps;
    final positionSubscription = _positionSubscription;
    final durationSubscription = _durationSubscription;
    final playingSubscription = _playingSubscription;
    final volumeSubscription = _volumeSubscription;
    final widthSubscription = _widthSubscription;
    final heightSubscription = _heightSubscription;
    final player = state.player;

    _positionSubscription = null;
    _durationSubscription = null;
    _playingSubscription = null;
    _volumeSubscription = null;
    _widthSubscription = null;
    _heightSubscription = null;
    _allowStreamDimensionUpdates = false;
    _streamVideoWidth = null;
    _streamVideoHeight = null;
    _lastPublishedPositionMs = -1;
    _frameStepTargetMs = null;
    _supportsNativeFrameStep = null;
    _realFrameStepDuration = null;
    _stillFrameAudioMuted = false;
    _frameStepQueue = Future<void>.value();

    if (mounted) {
      // Detach the disposed controller from the widget tree before tearing
      // down the underlying player internals used by media_kit_video.
      state = state.copyWith(
        clearPlayer: true,
        clearVideoController: true,
        clearMetadata: true,
        position: Duration.zero,
        duration: Duration.zero,
        isPlaying: false,
        clearError: true,
        currentVideoPath: currentVideoPath,
        currentSourceLabel: currentSourceLabel,
        currentDisplayLabel: currentDisplayLabel,
        sourceType: sourceType,
        sourceFps: sourceFps,
      );
    }

    await positionSubscription?.cancel();
    await durationSubscription?.cancel();
    await playingSubscription?.cancel();
    await volumeSubscription?.cancel();
    await widthSubscription?.cancel();
    await heightSubscription?.cancel();
    await player?.dispose();
    if (!mounted) return;
    state = state.copyWith(
      isLoading: false,
      clearError: true,
      currentVideoPath: currentVideoPath,
      currentSourceLabel: currentSourceLabel,
      currentDisplayLabel: currentDisplayLabel,
      sourceType: sourceType,
      sourceFps: sourceFps,
    );
  }

  @override
  void dispose() {
    _disposePlayer();
    super.dispose();
  }
}

/// Player provider instance
final playerProvider = StateNotifierProvider<PlayerNotifier, PlayerState>((
  ref,
) {
  return PlayerNotifier(ref);
});
