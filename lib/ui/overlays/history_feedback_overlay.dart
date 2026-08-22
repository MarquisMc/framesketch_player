import 'package:flutter/material.dart';
import '../../core/theme/app_palette.dart';

/// Transient toast shown near the top of the editor after an undo/redo.
class HistoryFeedbackOverlay extends StatelessWidget {
  final String? label;
  final IconData? icon;
  final bool isVisible;
  final AppPalette palette;

  const HistoryFeedbackOverlay({
    super.key,
    required this.label,
    required this.icon,
    required this.isVisible,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 72,
      left: 0,
      right: 0,
      child: IgnorePointer(
        child: AnimatedOpacity(
          opacity: isVisible ? 1 : 0,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          child: AnimatedScale(
            scale: isVisible ? 1 : 0.92,
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOut,
            child: Center(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: palette.panelElevated.withValues(alpha: 0.94),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: palette.accentBright),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.22),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 9,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        icon ?? Icons.undo,
                        size: 18,
                        color: palette.accentBright,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        label ?? '',
                        style: TextStyle(
                          color: palette.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
