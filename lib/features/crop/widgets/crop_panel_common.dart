import 'package:flutter/material.dart';

import '../../../core/theme/app_palette.dart';

/// Shared building blocks for the crop & export panel sections.

class PanelSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final AppPalette palette;
  final Widget child;

  const PanelSection({
    super.key,
    required this.title,
    required this.icon,
    required this.palette,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(icon, size: 15, color: palette.accentBright),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                color: palette.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        child,
      ],
    );
  }
}

class PanelExportButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final AppPalette palette;

  const PanelExportButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: ElevatedButton.icon(
        icon: Icon(icon, size: 15),
        label: Text(label, style: const TextStyle(fontSize: 13)),
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: palette.accent,
          foregroundColor: palette.textPrimary,
          disabledBackgroundColor: palette.panelElevated,
          disabledForegroundColor: palette.textDisabled,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
      ),
    );
  }
}

Widget panelSectionLabel(String text, AppPalette palette) {
  return Text(
    text,
    style: TextStyle(
      color: palette.textMuted,
      fontSize: 10,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.7,
    ),
  );
}
