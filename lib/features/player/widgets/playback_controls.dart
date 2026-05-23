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

class _EditableFpsDisplay extends ConsumerStatefulWidget {
  const _EditableFpsDisplay();

  @override
  ConsumerState<_EditableFpsDisplay> createState() => _EditableFpsDisplayState();
}

class _EditableFpsDisplayState extends ConsumerState<_EditableFpsDisplay> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _isEditing = false;

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _startEditing(double fps) {
    setState(() {
      _isEditing = true;
      _controller.text = fps.toStringAsFixed(2);
      _controller.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _controller.text.length,
      );
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
  }

  void _commit() {
    if (!_isEditing) return;
    final raw = _controller.text.trim();
    final parsed = double.tryParse(raw);
    if (parsed != null && parsed.isFinite && parsed > 0) {
      ref.read(playerProvider.notifier).setPlaybackFps(parsed);
    }
    if (!mounted) return;
    setState(() {
      _isEditing = false;
    });
  }

  void _cancel() {
    if (!mounted) return;
    setState(() {
      _isEditing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final playerState = ref.watch(playerProvider);
    final metadata = playerState.metadata;
    if (metadata == null) {
      return const SizedBox.shrink();
    }

    final sourceFps = playerState.sourceFps;
    final isModified =
        sourceFps != null && (metadata.fps - sourceFps).abs() > 0.0001;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: palette.panelElevated,
            borderRadius: BorderRadius.circular(4),
          ),
          child: _isEditing
              ? SizedBox(
                  width: 72,
                  height: 22,
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    autofocus: true,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: palette.textSecondary,
                      fontSize: 12,
                      fontFamily: 'monospace',
                    ),
                    decoration: const InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                    onSubmitted: (_) => _commit(),
                    onTapOutside: (_) => _commit(),
                    onEditingComplete: _commit,
                  ),
                )
              : MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: () => _startEditing(metadata.fps),
                    child: Text(
                      '${metadata.fps.toStringAsFixed(2)} FPS',
                      style: TextStyle(
                        color: palette.textSecondary,
                        fontSize: 12,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ),
        ),
        const SizedBox(width: 4),
        IconButton(
          icon: Icon(
            Icons.replay,
            size: 18,
            color: isModified ? palette.textSecondary : palette.textDisabled,
          ),
          onPressed: isModified
              ? () {
                  _cancel();
                  ref.read(playerProvider.notifier).resetPlaybackFps();
                }
              : null,
          tooltip: 'Reset FPS to detected default',
          constraints: const BoxConstraints(minHeight: 28, minWidth: 28),
          padding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
        ),
      ],
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
              repeatInterval: const Duration(milliseconds: 70),
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

            // FPS display (click to edit) + reset button
            if (hasVideo && playerState.metadata != null) const _EditableFpsDisplay(),

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
