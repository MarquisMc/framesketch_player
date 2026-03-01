import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../player/providers/player_provider.dart';

/// State for the annotation keyframe timeline scrubber.
class AnnotationKeyframeTimelineState {
  static const List<double> zoomLevels = [1.0, 2.0, 4.0, 8.0];

  final bool isScrubbing;
  final Duration? scrubbingPosition;
  final Duration? pendingSeekPosition;
  final int zoomLevelIndex;
  final Duration? windowCenter;

  const AnnotationKeyframeTimelineState({
    this.isScrubbing = false,
    this.scrubbingPosition,
    this.pendingSeekPosition,
    this.zoomLevelIndex = 0,
    this.windowCenter,
  });

  double get zoomFactor {
    assert(
      zoomLevelIndex >= 0 && zoomLevelIndex < zoomLevels.length,
      'Invalid zoomLevelIndex ($zoomLevelIndex) for zoomLevels length '
      '${zoomLevels.length}.',
    );
    return zoomLevels[zoomLevelIndex];
  }

  AnnotationKeyframeTimelineState copyWith({
    bool? isScrubbing,
    Duration? scrubbingPosition,
    Duration? pendingSeekPosition,
    int? zoomLevelIndex,
    Duration? windowCenter,
    bool clearWindowCenter = false,
  }) {
    return AnnotationKeyframeTimelineState(
      isScrubbing: isScrubbing ?? this.isScrubbing,
      scrubbingPosition: scrubbingPosition,
      pendingSeekPosition: pendingSeekPosition,
      zoomLevelIndex: zoomLevelIndex ?? this.zoomLevelIndex,
      windowCenter: clearWindowCenter
          ? null
          : (windowCenter ?? this.windowCenter),
    );
  }
}

/// Separate timeline controller for annotation keyframe navigation.
/// This intentionally does not share state with the main playback scrubber.
class AnnotationKeyframeTimelineNotifier
    extends StateNotifier<AnnotationKeyframeTimelineState> {
  final Ref ref;
  Timer? _throttleTimer;
  bool _seekPending = false;
  Duration? _latestPosition;
  static const _throttleInterval = Duration(milliseconds: 80);

  AnnotationKeyframeTimelineNotifier(this.ref)
    : super(const AnnotationKeyframeTimelineState());

  void startScrubbing() {
    state = state.copyWith(isScrubbing: true);
  }

  void updateScrubbingPosition(Duration position) {
    state = state.copyWith(
      scrubbingPosition: position,
      pendingSeekPosition: position,
    );

    _latestPosition = position;

    if (!_seekPending) {
      _seekPending = true;
      _performSeek(position);
      _throttleTimer = Timer(_throttleInterval, () {
        _seekPending = false;
        if (_latestPosition != null && _latestPosition != position) {
          _performSeek(_latestPosition!);
        }
      });
    }
  }

  void endScrubbing() {
    _throttleTimer?.cancel();
    _seekPending = false;

    final finalPosition = state.pendingSeekPosition;
    if (finalPosition != null) {
      _performSeek(finalPosition);
    }

    _latestPosition = null;
    state = state.copyWith(
      isScrubbing: false,
      scrubbingPosition: null,
      pendingSeekPosition: null,
    );
  }

  void cancelScrubbing() {
    _throttleTimer?.cancel();
    _seekPending = false;
    _latestPosition = null;
    state = const AnnotationKeyframeTimelineState();
  }

  void seekTo(Duration position) {
    state = state.copyWith(
      scrubbingPosition: position,
      pendingSeekPosition: position,
    );
    _performSeek(position);
  }

  void seekToKeyframeMs(int keyframeMs, double fps) {
    final targetPosition = _toExactFramePosition(keyframeMs, fps);
    state = state.copyWith(
      scrubbingPosition: targetPosition,
      pendingSeekPosition: targetPosition,
    );
    _performSeek(targetPosition);
  }

  void zoomIn() {
    if (state.zoomLevelIndex >=
        AnnotationKeyframeTimelineState.zoomLevels.length - 1) {
      return;
    }
    state = state.copyWith(zoomLevelIndex: state.zoomLevelIndex + 1);
  }

  void zoomOut() {
    if (state.zoomLevelIndex <= 0) return;
    state = state.copyWith(zoomLevelIndex: state.zoomLevelIndex - 1);
  }

  void resetZoom() {
    state = state.copyWith(zoomLevelIndex: 0, clearWindowCenter: true);
  }

  void setWindowCenter(Duration center) {
    state = state.copyWith(windowCenter: center);
  }

  Duration _toExactFramePosition(int positionMs, double fps) {
    if (fps <= 0) {
      return Duration(milliseconds: positionMs);
    }

    final frameIndex = ((positionMs / 1000.0) * fps).round();
    final targetMicros = ((frameIndex * 1000000.0) / fps).round();
    return Duration(microseconds: targetMicros);
  }

  void _performSeek(Duration position) {
    ref.read(playerProvider.notifier).seek(position);
  }

  @override
  void dispose() {
    _throttleTimer?.cancel();
    super.dispose();
  }
}

final annotationKeyframeTimelineProvider =
    StateNotifierProvider<
      AnnotationKeyframeTimelineNotifier,
      AnnotationKeyframeTimelineState
    >((ref) {
      return AnnotationKeyframeTimelineNotifier(ref);
    });

/// Controls visibility of the annotation keyframe timeline UI.
/// Defaults to hidden until explicitly toggled by the user.
final annotationKeyframeTimelineVisibleProvider = StateProvider<bool>((ref) {
  return false;
});
