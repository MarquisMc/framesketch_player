import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_palette.dart';
import '../../loop/providers/loop_provider.dart';
import '../../player/providers/player_provider.dart';
import '../providers/crop_provider.dart';
import 'crop_panel_common.dart';

/// "Crop" section of the crop & export panel: enable toggle, aspect-ratio
/// presets, and the output-size summary.
class CropSection extends ConsumerWidget {
  final AppPalette palette;
  const CropSection({super.key, required this.palette});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cropState = ref.watch(cropProvider);
    final cropNotifier = ref.read(cropProvider.notifier);
    final playerState = ref.watch(playerProvider);
    final hasVideo =
        playerState.isLocalFileSource || playerState.hasLoadedSource;
    final isCropActive = cropState.isCropModeActive;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Crop enable toggle
        _CropEnableRow(
          isCropActive: isCropActive,
          hasVideo: hasVideo,
          onToggle: () {
            if (isCropActive) {
              cropNotifier.exitCropMode();
            } else {
              cropNotifier.enterCropMode();
              final loopState = ref.read(loopProvider);
              cropNotifier.setExportRange(
                start: loopState.loopStart,
                end: loopState.loopEnd,
              );
            }
          },
          palette: palette,
        ),

        if (isCropActive) ...[
          const SizedBox(height: 16),
          panelSectionLabel('ASPECT RATIO', palette),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: CropAspectRatio.values.map((ratio) {
              final isSelected = cropState.aspectRatio == ratio;
              return _RatioChip(
                label: ratio.displayName,
                isSelected: isSelected,
                onTap: () => cropNotifier.setAspectRatio(ratio),
                palette: palette,
              );
            }).toList(),
          ),

          const SizedBox(height: 16),
          _CropInfoBox(palette: palette),

          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              icon: const Icon(Icons.refresh, size: 14),
              label: const Text('Reset crop', style: TextStyle(fontSize: 12)),
              onPressed: cropNotifier.resetCrop,
              style: TextButton.styleFrom(
                foregroundColor: palette.textSecondary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
        ] else ...[
          const SizedBox(height: 12),
          Text(
            'Enable crop to define the output region of your video.',
            style: TextStyle(color: palette.textMuted, fontSize: 12),
          ),
        ],
      ],
    );
  }
}

class _CropEnableRow extends StatelessWidget {
  final bool isCropActive;
  final bool hasVideo;
  final VoidCallback onToggle;
  final AppPalette palette;

  const _CropEnableRow({
    required this.isCropActive,
    required this.hasVideo,
    required this.onToggle,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: hasVideo ? onToggle : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isCropActive ? palette.accentSoft : palette.panelOverlay,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isCropActive ? palette.accentBright : palette.border,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.crop,
              size: 16,
              color: isCropActive
                  ? palette.accentBright
                  : (hasVideo ? palette.textSecondary : palette.textDisabled),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                isCropActive ? 'Crop enabled' : 'Crop disabled',
                style: TextStyle(
                  color: isCropActive
                      ? palette.accentBright
                      : palette.textSecondary,
                  fontSize: 13,
                  fontWeight: isCropActive ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
            Switch(
              value: isCropActive,
              onChanged: hasVideo ? (_) => onToggle() : null,
              activeThumbColor: palette.accentBright,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ],
        ),
      ),
    );
  }
}

class _CropInfoBox extends ConsumerWidget {
  final AppPalette palette;
  const _CropInfoBox({required this.palette});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cropState = ref.watch(cropProvider);
    final meta = ref.watch(playerProvider).metadata;
    if (meta == null) return const SizedBox.shrink();

    final pixels = cropState.cropRect.toPixels(meta.width, meta.height);
    final isFull = pixels.width == meta.width && pixels.height == meta.height;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: palette.panelOverlay,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                panelSectionLabel('OUTPUT', palette),
                const SizedBox(height: 4),
                Text(
                  '${pixels.width} × ${pixels.height}',
                  style: TextStyle(
                    color: isFull
                        ? palette.textSecondary
                        : palette.accentBright,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              panelSectionLabel('SOURCE', palette),
              const SizedBox(height: 4),
              Text(
                '${meta.width} × ${meta.height}',
                style: TextStyle(
                  color: palette.textMuted,
                  fontSize: 12,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RatioChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final AppPalette palette;

  const _RatioChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? palette.accent : palette.panelElevated,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? palette.accentBright : palette.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? palette.textPrimary : palette.textSecondary,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}
