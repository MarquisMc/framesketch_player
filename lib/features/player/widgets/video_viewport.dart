import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../providers/player_provider.dart';
import '../../annotations/widgets/annotation_overlay.dart';
import '../../crop/widgets/crop_overlay.dart';

/// Video viewport with annotation overlay
class VideoViewport extends ConsumerWidget {
  const VideoViewport({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(playerProvider);

    if (playerState.error != null) {
      return _buildError(playerState.error!);
    }

    if (playerState.isLoading) {
      return _buildLoading();
    }

    if (playerState.videoController == null) {
      return _buildEmpty();
    }

    return _buildPlayer(playerState.videoController!);
  }

  Widget _buildPlayer(VideoController controller) {
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

              // Annotation overlay layer
              const AnnotationOverlay(),

              // Crop overlay layer (on top of annotations)
              CropOverlay(
                viewportSize: Size(constraints.maxWidth, constraints.maxHeight),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmpty() {
    return Container(
      color: Colors.grey[900],
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.video_library, size: 64, color: Colors.white54),
            SizedBox(height: 16),
            Text(
              'No video loaded',
              style: TextStyle(color: Colors.white70, fontSize: 18),
            ),
            SizedBox(height: 8),
            Text(
              'Press Ctrl+O to open a video file',
              style: TextStyle(color: Colors.white54, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return Container(
      color: Colors.grey[900],
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              'Loading video...',
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError(String error) {
    return Container(
      color: Colors.grey[900],
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Error loading video',
              style: TextStyle(
                color: Colors.red[300],
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
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
