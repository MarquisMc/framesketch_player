import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import '../providers/crop_provider.dart';
import '../../player/providers/player_provider.dart';

/// Crop controls panel widget
/// Shows when crop mode is active, provides aspect ratio selection and export
class CropControlsPanel extends ConsumerWidget {
  const CropControlsPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cropState = ref.watch(cropProvider);
    final cropNotifier = ref.read(cropProvider.notifier);
    final playerState = ref.watch(playerProvider);

    if (!cropState.isCropModeActive) {
      return const SizedBox.shrink();
    }

    final hasVideo = playerState.currentVideoPath != null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        border: Border(
          top: BorderSide(color: Colors.grey[800]!),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Row(
            children: [
              const Icon(Icons.crop, color: Colors.white70, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Crop Mode',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              // Exit crop mode button
              IconButton(
                icon: const Icon(Icons.close),
                tooltip: 'Exit crop mode (Esc)',
                onPressed: cropNotifier.exitCropMode,
                color: Colors.white70,
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Aspect ratio selection
          const Text(
            'Aspect Ratio',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: CropAspectRatio.values.map((ratio) {
              final isSelected = cropState.aspectRatio == ratio;
              return ChoiceChip(
                label: Text(ratio.displayName),
                selected: isSelected,
                onSelected: hasVideo
                    ? (selected) {
                        if (selected) {
                          cropNotifier.setAspectRatio(ratio);
                        }
                      }
                    : null,
                selectedColor: Colors.cyan[700],
                backgroundColor: Colors.grey[800],
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : Colors.white70,
                  fontSize: 12,
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 16),

          // Crop info
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(8),
            ),
            child: _CropInfo(),
          ),

          const SizedBox(height: 16),

          // Action buttons
          Row(
            children: [
              // Reset button
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Reset'),
                  onPressed: hasVideo ? cropNotifier.resetCrop : null,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white70,
                    side: BorderSide(color: Colors.grey[700]!),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Export button
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.file_download, size: 18),
                  label: const Text('Export Cropped Video'),
                  onPressed: hasVideo &&
                          cropState.exportStatus != ExportStatus.exporting
                      ? () => _showExportDialog(context, ref)
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.cyan[700],
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),

          // Export progress
          if (cropState.exportStatus == ExportStatus.exporting)
            _ExportProgress(
              progress: cropState.exportProgress,
              onCancel: cropNotifier.cancelExport,
            ),
        ],
      ),
    );
  }

  /// Show export dialog to choose output file
  Future<void> _showExportDialog(BuildContext context, WidgetRef ref) async {
    final playerState = ref.read(playerProvider);
    final cropNotifier = ref.read(cropProvider.notifier);

    if (playerState.currentVideoPath == null) return;

    // Suggest output filename
    final inputFile = File(playerState.currentVideoPath!);
    final inputName = inputFile.uri.pathSegments.last;
    final nameWithoutExt = inputName.substring(
      0,
      inputName.lastIndexOf('.'),
    );
    final ext = inputName.substring(inputName.lastIndexOf('.'));

    // Ask user for save location
    final result = await FilePicker.platform.saveFile(
      dialogTitle: 'Export Cropped Video',
      fileName: '${nameWithoutExt}_cropped$ext',
      type: FileType.video,
    );

    if (result != null) {
      // Start export
      cropNotifier.exportCroppedVideo(result);
    }
  }
}

/// Displays crop information
class _CropInfo extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cropState = ref.watch(cropProvider);
    final playerState = ref.watch(playerProvider);
    final metadata = playerState.metadata;

    if (metadata == null) {
      return const Text(
        'No video loaded',
        style: TextStyle(color: Colors.white54, fontSize: 12),
      );
    }

    final pixels = cropState.cropRect.toPixels(metadata.width, metadata.height);
    final aspectRatio = pixels.width / pixels.height;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _InfoRow(
          label: 'Original',
          value: '${metadata.width} × ${metadata.height}',
        ),
        const SizedBox(height: 4),
        _InfoRow(
          label: 'Cropped',
          value: '${pixels.width} × ${pixels.height}',
          valueColor: Colors.cyan[300],
        ),
        const SizedBox(height: 4),
        _InfoRow(
          label: 'Ratio',
          value: aspectRatio.toStringAsFixed(2),
        ),
        const SizedBox(height: 4),
        _InfoRow(
          label: 'Position',
          value: '(${pixels.x}, ${pixels.y})',
        ),
      ],
    );
  }
}

/// Info row widget
class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 12,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? Colors.white,
            fontSize: 12,
            fontFamily: 'monospace',
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

/// Export progress indicator
class _ExportProgress extends StatelessWidget {
  final double progress;
  final VoidCallback onCancel;

  const _ExportProgress({
    required this.progress,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Text(
                'Exporting...',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Text(
                '${(progress * 100).toStringAsFixed(1)}%',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.grey[800],
              valueColor: AlwaysStoppedAnimation(Colors.cyan[400]!),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            icon: const Icon(Icons.cancel, size: 16),
            label: const Text('Cancel Export'),
            onPressed: onCancel,
            style: TextButton.styleFrom(
              foregroundColor: Colors.red[300],
            ),
          ),
        ],
      ),
    );
  }
}

/// Floating crop mode toggle button (shows when not in crop mode)
class CropModeToggleButton extends ConsumerWidget {
  const CropModeToggleButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cropState = ref.watch(cropProvider);
    final playerState = ref.watch(playerProvider);
    final cropNotifier = ref.read(cropProvider.notifier);

    final hasVideo = playerState.player != null;

    return Tooltip(
      message: 'Toggle crop mode (C)',
      child: Material(
        color: cropState.isCropModeActive
            ? Colors.cyan[700]
            : Colors.grey[800],
        borderRadius: BorderRadius.circular(4),
        child: InkWell(
          onTap: hasVideo ? cropNotifier.toggleCropMode : null,
          borderRadius: BorderRadius.circular(4),
          child: Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            child: Icon(
              Icons.crop,
              size: 24,
              color: cropState.isCropModeActive
                  ? Colors.white
                  : (hasVideo ? Colors.white70 : Colors.white24),
            ),
          ),
        ),
      ),
    );
  }
}
