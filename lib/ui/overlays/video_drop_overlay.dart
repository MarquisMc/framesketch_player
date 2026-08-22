import 'package:flutter/material.dart';
import '../../core/theme/app_palette.dart';

/// Fullscreen hint shown while a video file is being dragged over the window.
class VideoDropOverlay extends StatelessWidget {
  final AppPalette palette;

  const VideoDropOverlay({super.key, required this.palette});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: palette.background.withValues(alpha: 0.78),
            border: Border.all(color: palette.accentBright, width: 3),
          ),
          child: Center(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: palette.panelElevated.withValues(alpha: 0.98),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: palette.accentBright),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 30,
                  vertical: 24,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.file_download_outlined,
                      size: 44,
                      color: palette.accentBright,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Drop video to open',
                      style: TextStyle(
                        color: palette.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'MP4, MOV, MKV, AVI, WebM, WMV and more',
                      style: TextStyle(
                        color: palette.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
