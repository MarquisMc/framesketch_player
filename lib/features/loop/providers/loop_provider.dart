import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../player/providers/player_provider.dart';

/// Represents the type of loop currently active
enum LoopMode {
  /// No looping - video stops at end
  none,

  /// Full video loop - restart from beginning when end is reached
  fullVideo,

  /// Section loop (A-B) - loop between two set points
  section,
}

/// State for loop functionality
class LoopState {
  /// Current loop mode
  final LoopMode mode;

  /// A point (start of section loop) in milliseconds
  final int? loopStartMs;

  /// B point (end of section loop) in milliseconds
  final int? loopEndMs;

  /// Whether we're in the process of setting the A point
  final bool isSettingAPoint;

  /// Whether we're in the process of setting the B point
  final bool isSettingBPoint;

  const LoopState({
    this.mode = LoopMode.none,
    this.loopStartMs,
    this.loopEndMs,
    this.isSettingAPoint = false,
    this.isSettingBPoint = false,
  });

  /// Check if section loop is properly configured (A < B)
  bool get isSectionLoopValid =>
      loopStartMs != null &&
      loopEndMs != null &&
      loopStartMs! < loopEndMs!;

  /// Check if full video loop is active
  bool get isFullVideoLoopActive => mode == LoopMode.fullVideo;

  /// Check if section loop is active
  bool get isSectionLoopActive =>
      mode == LoopMode.section && isSectionLoopValid;

  /// Get loop start as Duration
  Duration? get loopStart =>
      loopStartMs != null ? Duration(milliseconds: loopStartMs!) : null;

  /// Get loop end as Duration
  Duration? get loopEnd =>
      loopEndMs != null ? Duration(milliseconds: loopEndMs!) : null;

  LoopState copyWith({
    LoopMode? mode,
    int? loopStartMs,
    int? loopEndMs,
    bool? isSettingAPoint,
    bool? isSettingBPoint,
    bool clearLoopPoints = false,
  }) {
    return LoopState(
      mode: mode ?? this.mode,
      loopStartMs: clearLoopPoints ? null : (loopStartMs ?? this.loopStartMs),
      loopEndMs: clearLoopPoints ? null : (loopEndMs ?? this.loopEndMs),
      isSettingAPoint: isSettingAPoint ?? this.isSettingAPoint,
      isSettingBPoint: isSettingBPoint ?? this.isSettingBPoint,
    );
  }

  @override
  String toString() {
    return 'LoopState(mode: $mode, A: ${loopStartMs}ms, B: ${loopEndMs}ms)';
  }
}

/// Notifier for loop state management
class LoopNotifier extends StateNotifier<LoopState> {
  final Ref ref;

  LoopNotifier(this.ref) : super(const LoopState());

  /// Toggle full video loop on/off
  /// Automatically disables section loop when enabling full video loop
  void toggleFullVideoLoop() {
    if (state.mode == LoopMode.fullVideo) {
      // Turn off loop
      state = state.copyWith(mode: LoopMode.none);
    } else {
      // Enable full video loop, clear section loop points
      state = state.copyWith(
        mode: LoopMode.fullVideo,
        clearLoopPoints: true,
      );
    }
  }

  /// Set A point (loop start) at current playback position
  void setAPoint() {
    final playerState = ref.read(playerProvider);
    final currentMs = playerState.position.inMilliseconds;

    // If B point exists and new A would be >= B, reset B
    int? newEndMs = state.loopEndMs;
    if (newEndMs != null && currentMs >= newEndMs) {
      newEndMs = null;
    }

    state = state.copyWith(
      loopStartMs: currentMs,
      loopEndMs: newEndMs,
      isSettingAPoint: false,
      // Enable section loop if both points are now valid
      mode: (newEndMs != null && currentMs < newEndMs)
          ? LoopMode.section
          : state.mode,
    );
  }

  /// Set B point (loop end) at current playback position
  void setBPoint() {
    final playerState = ref.read(playerProvider);
    final currentMs = playerState.position.inMilliseconds;

    // Validate B > A
    if (state.loopStartMs != null && currentMs <= state.loopStartMs!) {
      // B must be after A - don't set invalid point
      return;
    }

    state = state.copyWith(
      loopEndMs: currentMs,
      isSettingBPoint: false,
      // Enable section loop if A is already set
      mode: state.loopStartMs != null ? LoopMode.section : state.mode,
    );
  }

  /// Set A point at specific position (for scrubber interaction)
  void setAPointAt(Duration position) {
    final posMs = position.inMilliseconds;

    // If B point exists and new A would be >= B, reset B
    int? newEndMs = state.loopEndMs;
    if (newEndMs != null && posMs >= newEndMs) {
      newEndMs = null;
    }

    state = state.copyWith(
      loopStartMs: posMs,
      loopEndMs: newEndMs,
      mode: (newEndMs != null && posMs < newEndMs)
          ? LoopMode.section
          : state.mode,
    );
  }

  /// Set B point at specific position (for scrubber interaction)
  void setBPointAt(Duration position) {
    final posMs = position.inMilliseconds;

    // Validate B > A
    if (state.loopStartMs != null && posMs <= state.loopStartMs!) {
      return;
    }

    state = state.copyWith(
      loopEndMs: posMs,
      mode: state.loopStartMs != null ? LoopMode.section : state.mode,
    );
  }

  /// Toggle section loop on/off (only if valid A-B points exist)
  void toggleSectionLoop() {
    if (!state.isSectionLoopValid) {
      // Can't enable without valid points
      return;
    }

    if (state.mode == LoopMode.section) {
      state = state.copyWith(mode: LoopMode.none);
    } else {
      state = state.copyWith(mode: LoopMode.section);
    }
  }

  /// Clear all loop points and disable looping
  void clearLoop() {
    state = const LoopState();
  }

  /// Clear only section loop points (keeps loop mode)
  void clearSectionPoints() {
    state = state.copyWith(
      clearLoopPoints: true,
      mode: state.mode == LoopMode.section ? LoopMode.none : state.mode,
    );
  }

  /// Check if current position requires loop handling
  /// Returns the position to seek to, or null if no seek needed
  /// This is called by the player provider's position listener
  Duration? checkLoopBoundary(Duration currentPosition) {
    if (state.mode == LoopMode.none) {
      return null;
    }

    if (state.mode == LoopMode.fullVideo) {
      final playerState = ref.read(playerProvider);
      final duration = playerState.duration;

      // Check if we've reached the end (within 100ms tolerance)
      if (duration.inMilliseconds > 0 &&
          currentPosition.inMilliseconds >= duration.inMilliseconds - 100) {
        return Duration.zero;
      }
    }

    if (state.mode == LoopMode.section && state.isSectionLoopValid) {
      // Check if we've passed the B point
      if (currentPosition.inMilliseconds >= state.loopEndMs!) {
        return Duration(milliseconds: state.loopStartMs!);
      }

      // Also check if we're before A point (user may have seeked)
      // In this case, let playback continue normally until B is reached
    }

    return null;
  }

  /// Reset loop state when video changes
  void onVideoChanged() {
    state = const LoopState();
  }
}

/// Loop provider instance
final loopProvider = StateNotifierProvider<LoopNotifier, LoopState>((ref) {
  return LoopNotifier(ref);
});
