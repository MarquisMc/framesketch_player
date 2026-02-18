import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_palette.dart';
import '../providers/player_provider.dart';
import '../../../core/utils/timecode_formatter.dart';
import '../../loop/widgets/loop_controls.dart';

/// Button that repeats action when held down
class _HoldableButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final Icon icon;
  final String tooltip;
  final Duration initialDelay;
  final Duration repeatInterval;

  const _HoldableButton({
    required this.onPressed,
    required this.icon,
    required this.tooltip,
    this.initialDelay = const Duration(milliseconds: 500),
    this.repeatInterval = const Duration(milliseconds: 50),
  });

  @override
  State<_HoldableButton> createState() => _HoldableButtonState();
}

class _HoldableButtonState extends State<_HoldableButton> {
  Timer? _timer;

  void _startHolding() {
    if (widget.onPressed == null) return;

    // Execute immediately
    widget.onPressed!();

    // Start repeating after initial delay
    _timer = Timer(widget.initialDelay, () {
      _timer = Timer.periodic(widget.repeatInterval, (timer) {
        if (widget.onPressed != null) {
          widget.onPressed!();
        }
      });
    });
  }

  void _stopHolding() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _startHolding(),
      onTapUp: (_) => _stopHolding(),
      onTapCancel: _stopHolding,
      child: IconButton(
        icon: widget.icon,
        iconSize: 24,
        onPressed: widget.onPressed,
        tooltip: widget.tooltip,
      ),
    );
  }
}

/// Playback controls widget
class PlaybackControls extends ConsumerWidget {
  final bool isFullscreen;
  final VoidCallback? onToggleFullscreen;

  const PlaybackControls({
    super.key,
    this.isFullscreen = false,
    this.onToggleFullscreen,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(playerProvider);
    final playerNotifier = ref.read(playerProvider.notifier);
    final palette = AppPalette.of(context);

    final hasVideo = playerState.player != null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: palette.panel,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Play/Pause button
            IconButton(
              icon: Icon(
                playerState.isPlaying ? Icons.pause : Icons.play_arrow,
                color: hasVideo ? palette.textPrimary : palette.textDisabled,
              ),
              iconSize: 32,
              onPressed: hasVideo
                  ? () => playerNotifier.togglePlayPause()
                  : null,
              tooltip: playerState.isPlaying ? 'Pause (Space)' : 'Play (Space)',
            ),

            const SizedBox(width: 8),

            // Stop button
            IconButton(
              icon: Icon(
                Icons.stop,
                color: hasVideo ? palette.textPrimary : palette.textDisabled,
              ),
              onPressed: hasVideo ? () => playerNotifier.stop() : null,
              tooltip: 'Stop',
            ),

            const SizedBox(width: 8),

            // Mute toggle button
            IconButton(
              icon: Icon(
                playerState.isMuted || playerState.volume <= 0.001
                    ? Icons.volume_off
                    : Icons.volume_up,
                color: hasVideo ? palette.textPrimary : palette.textDisabled,
              ),
              onPressed: hasVideo ? () => playerNotifier.toggleMute() : null,
              tooltip: playerState.isMuted ? 'Unmute' : 'Mute',
            ),

            const SizedBox(width: 16),

            // Frame step backward
            _HoldableButton(
              icon: Icon(
                Icons.skip_previous,
                color: hasVideo ? palette.textPrimary : palette.textDisabled,
              ),
              onPressed: hasVideo ? () => playerNotifier.stepBackward() : null,
              tooltip: 'Previous Frame (,) - Hold to repeat',
            ),

            // Frame step forward
            _HoldableButton(
              icon: Icon(
                Icons.skip_next,
                color: hasVideo ? palette.textPrimary : palette.textDisabled,
              ),
              onPressed: hasVideo ? () => playerNotifier.stepForward() : null,
              tooltip: 'Next Frame (.) - Hold to repeat',
            ),

            const SizedBox(width: 16),

            // Jump backward 1 second
            _HoldableButton(
              icon: Icon(
                Icons.fast_rewind,
                color: hasVideo ? palette.textPrimary : palette.textDisabled,
              ),
              onPressed: hasVideo
                  ? () =>
                        playerNotifier.jumpBackward(const Duration(seconds: 1))
                  : null,
              tooltip: 'Jump back 1s (Shift+←) - Hold to repeat',
              initialDelay: const Duration(milliseconds: 300),
              repeatInterval: const Duration(milliseconds: 100),
            ),

            // Jump forward 1 second
            _HoldableButton(
              icon: Icon(
                Icons.fast_forward,
                color: hasVideo ? palette.textPrimary : palette.textDisabled,
              ),
              onPressed: hasVideo
                  ? () => playerNotifier.jumpForward(const Duration(seconds: 1))
                  : null,
              tooltip: 'Jump forward 1s (Shift+→) - Hold to repeat',
              initialDelay: const Duration(milliseconds: 300),
              repeatInterval: const Duration(milliseconds: 100),
            ),

            const SizedBox(width: 24),

            // Timecode display
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: palette.panelElevated,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                hasVideo
                    ? '${TimecodeFormatter.format(playerState.position)} / ${TimecodeFormatter.format(playerState.duration)}'
                    : '00:00:00.000 / 00:00:00.000',
                style: TextStyle(
                  color: palette.textPrimary,
                  fontSize: 14,
                  fontFamily: 'monospace',
                ),
              ),
            ),

            const SizedBox(width: 16),

            // Frame counter
            if (hasVideo && playerState.metadata != null)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: palette.panelElevated,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Frame ${playerNotifier.currentFrame} / ${playerState.metadata!.frameCount}',
                  style: TextStyle(
                    color: palette.textSecondary,
                    fontSize: 12,
                    fontFamily: 'monospace',
                  ),
                ),
              ),

            // Loop controls
            const LoopControls(),

            const SizedBox(width: 24),

            // FPS display
            if (hasVideo && playerState.metadata != null)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: palette.panelElevated,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${playerState.metadata!.fps.toStringAsFixed(2)} FPS',
                  style: TextStyle(
                    color: palette.textSecondary,
                    fontSize: 12,
                    fontFamily: 'monospace',
                  ),
                ),
              ),

            const SizedBox(width: 12),

            IconButton(
              icon: Icon(
                isFullscreen ? Icons.fullscreen_exit : Icons.fullscreen,
                color: palette.textSecondary,
              ),
              onPressed: onToggleFullscreen,
              tooltip: isFullscreen
                  ? 'Exit Fullscreen (Esc)'
                  : 'Enter Fullscreen (F11)',
            ),
          ],
        ),
      ),
    );
  }
}
