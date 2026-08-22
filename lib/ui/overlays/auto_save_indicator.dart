import 'package:flutter/material.dart';
import '../../core/theme/app_palette.dart';

/// Small "Auto saving" badge shown in the top-right corner while a save is
/// pending or in flight.
class AutoSaveIndicator extends StatelessWidget {
  final bool isVisible;
  final AppPalette palette;

  const AutoSaveIndicator({
    super.key,
    required this.isVisible,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    if (!isVisible) {
      return const SizedBox.shrink();
    }

    return Positioned(
      top: 14,
      right: 14,
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: palette.panelElevated.withValues(alpha: 0.96),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: palette.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: palette.accentBright,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Auto saving',
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
