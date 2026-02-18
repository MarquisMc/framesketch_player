import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../../../core/theme/app_palette.dart';
import '../providers/player_provider.dart';
import '../../annotations/widgets/annotation_overlay.dart';
import '../../crop/widgets/crop_overlay.dart';

/// Video viewport with annotation overlay
class VideoViewport extends ConsumerWidget {
  final bool showOverlays;

  const VideoViewport({super.key, this.showOverlays = true});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = AppPalette.of(context);
    final error = ref.watch(playerProvider.select((state) => state.error));
    final isLoading = ref.watch(
      playerProvider.select((state) => state.isLoading),
    );
    final videoController = ref.watch(
      playerProvider.select((state) => state.videoController),
    );

    if (error != null) {
      return _buildError(error, palette);
    }

    if (isLoading) {
      return _buildLoading(palette);
    }

    if (videoController == null) {
      return _buildEmpty(palette);
    }

    return _buildPlayer(videoController, showOverlays: showOverlays);
  }

  Widget _buildPlayer(
    VideoController controller, {
    required bool showOverlays,
  }) {
    return Container(
      color: Colors.black,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            fit: StackFit.expand,
            children: [
              // Video player layer
              RepaintBoundary(
                child: Video(
                  controller: controller,
                  controls: null, // No built-in controls
                ),
              ),

              if (showOverlays) ...[
                // Annotation overlay layer
                const AnnotationOverlay(),

                // Crop overlay layer (on top of annotations)
                CropOverlay(
                  viewportSize: Size(
                    constraints.maxWidth,
                    constraints.maxHeight,
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmpty(AppPalette palette) {
    return Container(
      color: palette.background,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.video_library, size: 64, color: palette.textMuted),
            SizedBox(height: 16),
            Text(
              'No video loaded',
              style: TextStyle(color: palette.textSecondary, fontSize: 18),
            ),
            SizedBox(height: 8),
            Text(
              'Press Ctrl+O to open a video file',
              style: TextStyle(color: palette.textMuted, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoading(AppPalette palette) {
    return Container(
      color: palette.background,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              'Loading video...',
              style: TextStyle(color: palette.textSecondary, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError(String error, AppPalette palette) {
    return Container(
      color: palette.background,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: palette.error),
            const SizedBox(height: 16),
            Text(
              'Error loading video',
              style: TextStyle(
                color: palette.error,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
              child: Text(
                error,
                textAlign: TextAlign.center,
                style: TextStyle(color: palette.textSecondary, fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
