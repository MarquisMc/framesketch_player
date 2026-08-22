import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_palette.dart';
import '../../player/providers/player_provider.dart';
import '../providers/crop_provider.dart';

/// Toolbar button that opens/closes the crop & export panel.
class CropModeToggleButton extends ConsumerWidget {
  final VoidCallback? onTogglePanel;
  final bool isPanelOpen;

  const CropModeToggleButton({
    super.key,
    this.onTogglePanel,
    this.isPanelOpen = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = AppPalette.of(context);
    final cropState = ref.watch(cropProvider);
    final hasVideo = ref.watch(playerProvider.select((s) => s.player != null));
    final isActive = isPanelOpen || cropState.isCropModeActive;

    return Tooltip(
      message: isPanelOpen ? 'Close crop & export (C)' : 'Crop & Export (C)',
      child: Material(
        color: isActive ? palette.accent : palette.panelElevated,
        borderRadius: BorderRadius.circular(4),
        child: InkWell(
          onTap: hasVideo ? onTogglePanel : null,
          borderRadius: BorderRadius.circular(4),
          child: Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            child: Icon(
              Icons.crop,
              size: 24,
              color: isActive
                  ? palette.textPrimary
                  : (hasVideo ? palette.textSecondary : palette.textDisabled),
            ),
          ),
        ),
      ),
    );
  }
}
