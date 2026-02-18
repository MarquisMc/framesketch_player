import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_palette.dart';
import '../providers/loop_provider.dart';
import '../../player/providers/player_provider.dart';
import '../../../core/utils/timecode_formatter.dart';

/// Loop controls widget for playback controls bar
/// Provides buttons for full video loop, A-B section loop, and clear
class LoopControls extends ConsumerWidget {
  const LoopControls({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = AppPalette.of(context);
    final loopState = ref.watch(loopProvider);
    final playerState = ref.watch(playerProvider);
    final loopNotifier = ref.read(loopProvider.notifier);

    final hasVideo = playerState.player != null;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Divider
        Container(
          width: 1,
          height: 24,
          color: palette.border,
          margin: const EdgeInsets.symmetric(horizontal: 8),
        ),

        // Full video loop toggle
        _LoopButton(
          icon: Icons.repeat,
          tooltip: 'Loop entire video (L)',
          isActive: loopState.isFullVideoLoopActive,
          isEnabled: hasVideo,
          onPressed: hasVideo ? loopNotifier.toggleFullVideoLoop : null,
        ),

        const SizedBox(width: 4),

        // Set A point (loop start)
        _LoopButton(
          icon: Icons.first_page,
          tooltip: 'Set loop start point (I)',
          isActive: loopState.loopStartMs != null,
          isEnabled: hasVideo,
          activeColor: palette.loopA,
          onPressed: hasVideo ? loopNotifier.setAPoint : null,
        ),

        // Set B point (loop end)
        _LoopButton(
          icon: Icons.last_page,
          tooltip: 'Set loop end point (O)',
          isActive: loopState.loopEndMs != null,
          isEnabled: hasVideo,
          activeColor: palette.loopB,
          onPressed: hasVideo ? loopNotifier.setBPoint : null,
        ),

        const SizedBox(width: 4),

        // Toggle section loop (only when A-B are set)
        _LoopButton(
          icon: Icons.repeat_one,
          tooltip: 'Toggle A-B loop ([)',
          isActive: loopState.isSectionLoopActive,
          isEnabled: hasVideo && loopState.isSectionLoopValid,
          onPressed: hasVideo && loopState.isSectionLoopValid
              ? loopNotifier.toggleSectionLoop
              : null,
        ),

        // Clear loop points
        _LoopButton(
          icon: Icons.clear,
          tooltip: 'Clear loop points',
          isActive: false,
          isEnabled:
              hasVideo &&
              (loopState.loopStartMs != null || loopState.loopEndMs != null),
          onPressed:
              hasVideo &&
                  (loopState.loopStartMs != null || loopState.loopEndMs != null)
              ? loopNotifier.clearSectionPoints
              : null,
        ),

        // Loop info display
        if (loopState.loopStartMs != null || loopState.loopEndMs != null)
          Container(
            margin: const EdgeInsets.only(left: 8),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: loopState.isSectionLoopActive
                  ? palette.loopA.withValues(alpha: 0.2)
                  : palette.panelElevated,
              borderRadius: BorderRadius.circular(4),
              border: loopState.isSectionLoopActive
                  ? Border.all(color: palette.loopA.withValues(alpha: 0.45))
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // A point time
                Text(
                  'A: ${loopState.loopStart != null ? TimecodeFormatter.formatShort(loopState.loopStart!) : '--:--'}',
                  style: TextStyle(
                    color: loopState.loopStartMs != null
                        ? palette.loopA
                        : palette.textMuted,
                    fontSize: 11,
                    fontFamily: 'monospace',
                  ),
                ),
                const SizedBox(width: 8),
                // B point time
                Text(
                  'B: ${loopState.loopEnd != null ? TimecodeFormatter.formatShort(loopState.loopEnd!) : '--:--'}',
                  style: TextStyle(
                    color: loopState.loopEndMs != null
                        ? palette.loopB
                        : palette.textMuted,
                    fontSize: 11,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Individual loop control button with active state styling
class _LoopButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool isActive;
  final bool isEnabled;
  final Color? activeColor;
  final VoidCallback? onPressed;

  const _LoopButton({
    required this.icon,
    required this.tooltip,
    required this.isActive,
    required this.isEnabled,
    this.activeColor,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final effectiveActiveColor = activeColor ?? palette.accent;

    return Tooltip(
      message: tooltip,
      child: Material(
        color: isActive
            ? effectiveActiveColor.withValues(alpha: 0.24)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(4),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(4),
          child: Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            child: Icon(
              icon,
              size: 20,
              color: isActive
                  ? effectiveActiveColor
                  : (isEnabled ? palette.textSecondary : palette.textDisabled),
            ),
          ),
        ),
      ),
    );
  }
}
