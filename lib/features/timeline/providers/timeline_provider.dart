import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../player/providers/player_provider.dart';

/// Timeline state for scrubbing
class TimelineState {
  final bool isScrubbing;
  final Duration? scrubbingPosition;
  final Duration? pendingSeekPosition;

  const TimelineState({
    this.isScrubbing = false,
    this.scrubbingPosition,
    this.pendingSeekPosition,
  });

  TimelineState copyWith({
    bool? isScrubbing,
    Duration? scrubbingPosition,
    Duration? pendingSeekPosition,
  }) {
    return TimelineState(
      isScrubbing: isScrubbing ?? this.isScrubbing,
      scrubbingPosition: scrubbingPosition,
      pendingSeekPosition: pendingSeekPosition,
    );
  }
}

/// Timeline notifier for smooth scrubbing
class TimelineNotifier extends StateNotifier<TimelineState> {
  final Ref ref;
  Timer? _throttleTimer;
  bool _seekPending = false;
  Duration? _latestPosition;
  static const _throttleInterval = Duration(milliseconds: 80);

  TimelineNotifier(this.ref) : super(const TimelineState());

  /// Start scrubbing (user pressed down on timeline)
  void startScrubbing() {
    state = state.copyWith(isScrubbing: true);
  }

  /// Update scrubbing position (user is dragging)
  /// Uses throttling to seek at regular intervals for real-time video preview
  void updateScrubbingPosition(Duration position) {
    state = state.copyWith(
      scrubbingPosition: position,
      pendingSeekPosition: position,
    );

    _latestPosition = position;

    // Throttle: if no seek is pending, seek immediately and start cooldown
    if (!_seekPending) {
      _seekPending = true;
      _performSeek(position);
      _throttleTimer = Timer(_throttleInterval, () {
        _seekPending = false;
        // If position changed during cooldown, fire one more seek
        if (_latestPosition != null && _latestPosition != position) {
          _performSeek(_latestPosition!);
        }
      });
    }
  }

  /// End scrubbing (user released)
  void endScrubbing() {
    _throttleTimer?.cancel();
    _seekPending = false;

    // Perform final seek if there's a pending position
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

  /// Cancel scrubbing (user canceled gesture)
  void cancelScrubbing() {
    _throttleTimer?.cancel();
    _seekPending = false;
    _latestPosition = null;
    state = const TimelineState();
  }

  /// Perform actual seek operation
  void _performSeek(Duration position) {
    final playerNotifier = ref.read(playerProvider.notifier);
    playerNotifier.seek(position);
  }

  /// Get display position (scrubbing or actual position)
  Duration getDisplayPosition() {
    if (state.isScrubbing && state.scrubbingPosition != null) {
      return state.scrubbingPosition!;
    }
    return ref.read(playerProvider).position;
  }

  @override
  void dispose() {
    _throttleTimer?.cancel();
    super.dispose();
  }
}

/// Timeline provider instance
final timelineProvider = StateNotifierProvider<TimelineNotifier, TimelineState>((ref) {
  return TimelineNotifier(ref);
});
