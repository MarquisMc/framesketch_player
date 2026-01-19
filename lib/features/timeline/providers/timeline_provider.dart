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
  Timer? _seekDebounceTimer;
  static const _debounceDelay = Duration(milliseconds: 60);

  TimelineNotifier(this.ref) : super(const TimelineState());

  /// Start scrubbing (user pressed down on timeline)
  void startScrubbing() {
    state = state.copyWith(isScrubbing: true);
  }

  /// Update scrubbing position (user is dragging)
  void updateScrubbingPosition(Duration position) {
    state = state.copyWith(
      scrubbingPosition: position,
      pendingSeekPosition: position,
    );

    // Debounce the actual seek operation
    _seekDebounceTimer?.cancel();
    _seekDebounceTimer = Timer(_debounceDelay, () {
      _performSeek(position);
    });
  }

  /// End scrubbing (user released)
  void endScrubbing() {
    _seekDebounceTimer?.cancel();

    // Perform final seek if there's a pending position
    final finalPosition = state.pendingSeekPosition;
    if (finalPosition != null) {
      _performSeek(finalPosition);
    }

    state = state.copyWith(
      isScrubbing: false,
      scrubbingPosition: null,
      pendingSeekPosition: null,
    );
  }

  /// Cancel scrubbing (user canceled gesture)
  void cancelScrubbing() {
    _seekDebounceTimer?.cancel();
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
    _seekDebounceTimer?.cancel();
    super.dispose();
  }
}

/// Timeline provider instance
final timelineProvider = StateNotifierProvider<TimelineNotifier, TimelineState>((ref) {
  return TimelineNotifier(ref);
});
