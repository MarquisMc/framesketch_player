import 'package:flutter/material.dart';
import '../../core/theme/app_palette.dart';

/// Modal overlay shown while a blocking operation (open, export, download)
/// is in progress. Optionally exposes a cancel action.
class GlobalLoadingOverlay extends StatelessWidget {
  final String message;
  final String? cancelLabel;
  final VoidCallback? onCancel;

  const GlobalLoadingOverlay({
    super.key,
    required this.message,
    this.cancelLabel,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Positioned.fill(
      child: IgnorePointer(
        ignoring: false,
        child: Container(
          color: palette.panelOverlay,
          alignment: Alignment.center,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
            decoration: BoxDecoration(
              color: palette.panelElevated,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: palette.border),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 34,
                  height: 34,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: palette.accentBright,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  message,
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Please wait...',
                  style: TextStyle(color: palette.textSecondary, fontSize: 12),
                ),
                if (onCancel != null) ...[
                  const SizedBox(height: 14),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.cancel_outlined, size: 16),
                    label: Text(cancelLabel ?? 'Cancel'),
                    onPressed: onCancel,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
