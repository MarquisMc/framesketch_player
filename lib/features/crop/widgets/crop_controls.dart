import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import '../../../core/utils/timecode_formatter.dart';
import '../providers/crop_provider.dart';
import '../../player/providers/player_provider.dart';
import '../../loop/providers/loop_provider.dart';
import '../../annotations/providers/annotation_provider.dart';

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
    final maxPanelHeight = MediaQuery.sizeOf(context).height * 0.38;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        border: Border(
          top: BorderSide(color: Colors.grey[800]!),
        ),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxPanelHeight),
        child: SingleChildScrollView(
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

              // Export range controls
              const _ExportRangeControls(),

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

              if (cropState.exportStatus != ExportStatus.idle &&
                  cropState.exportStatus != ExportStatus.exporting)
                _ExportStatusMessage(
                  status: cropState.exportStatus,
                  error: cropState.exportError,
                  exportedPath: cropState.exportedFilePath,
                  onDismiss: cropNotifier.resetExportState,
                ),
            ],
          ),
        ),
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
    final safeBaseName = _buildSafeOutputBaseName(nameWithoutExt);

    // Ask user for save location
    final result = await FilePicker.platform.saveFile(
      dialogTitle: 'Export Cropped Video',
      fileName: '${safeBaseName}_cropped.mp4',
      type: FileType.video,
    );

    if (result != null) {
      await ref.read(annotationProvider.notifier).saveAnnotations();
      final currentAnnotationData = ref.read(annotationProvider).annotationData;
      // Start export
      cropNotifier.exportCroppedVideo(
        result,
        annotationData: currentAnnotationData,
      );
    }
  }

  String _buildSafeOutputBaseName(String input) {
    final sanitized = input
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    if (sanitized.isEmpty) {
      return 'export';
    }

    const maxLen = 64;
    if (sanitized.length <= maxLen) {
      return sanitized;
    }

    return sanitized.substring(0, maxLen).trimRight();
  }
}

enum _RangeHandle {
  start,
  end,
}

/// Controls for selecting exported video segment.
class _ExportRangeControls extends ConsumerStatefulWidget {
  const _ExportRangeControls();

  @override
  ConsumerState<_ExportRangeControls> createState() => _ExportRangeControlsState();
}

class _ExportRangeControlsState extends ConsumerState<_ExportRangeControls> {
  _RangeHandle? _activeHandle;
  double? _lastStartMs;
  double? _lastEndMs;
  int? _previewedMs;
  DateTime? _lastPreviewAt;
  bool _didPauseForPreview = false;
  bool _wasPlayingBeforePreview = false;

  void _previewAt(int ms) {
    final now = DateTime.now();
    if (_lastPreviewAt != null &&
        now.difference(_lastPreviewAt!).inMilliseconds < 100 &&
        _previewedMs != null &&
        (ms - _previewedMs!).abs() < 120) {
      return;
    }

    _previewedMs = ms;
    _lastPreviewAt = now;
    ref.read(playerProvider.notifier).seek(Duration(milliseconds: ms));
  }

  void _handleRangeChangeStart(RangeValues values) {
    final playerState = ref.read(playerProvider);
    _wasPlayingBeforePreview = playerState.isPlaying;
    _didPauseForPreview = false;

    if (_wasPlayingBeforePreview) {
      _didPauseForPreview = true;
      ref.read(playerProvider.notifier).pause();
    }

    _lastStartMs = values.start;
    _lastEndMs = values.end;
  }

  void _handleRangeChanged(RangeValues values, int totalMs) {
    var startMs = values.start.round().clamp(0, totalMs);
    var endMs = values.end.round().clamp(0, totalMs);

    if (endMs - startMs < 100) {
      endMs = (startMs + 100).clamp(0, totalMs);
      if (endMs - startMs < 100) {
        startMs = (endMs - 100).clamp(0, totalMs);
      }
    }

    if (_lastStartMs != null && _lastEndMs != null) {
      final startDelta = (values.start - _lastStartMs!).abs();
      final endDelta = (values.end - _lastEndMs!).abs();
      _activeHandle = startDelta >= endDelta ? _RangeHandle.start : _RangeHandle.end;
    } else {
      _activeHandle = _RangeHandle.end;
    }

    _lastStartMs = values.start;
    _lastEndMs = values.end;

    ref.read(cropProvider.notifier).setExportRange(
          start: Duration(milliseconds: startMs),
          end: Duration(milliseconds: endMs),
        );

    final previewMs = _activeHandle == _RangeHandle.start ? startMs : endMs;
    _previewAt(previewMs);
  }

  void _handleRangeChangeEnd(RangeValues _) {
    if (_didPauseForPreview && _wasPlayingBeforePreview) {
      ref.read(playerProvider.notifier).play();
    }
    _didPauseForPreview = false;
    _wasPlayingBeforePreview = false;
  }

  @override
  Widget build(BuildContext context) {
    final cropState = ref.watch(cropProvider);
    final playerState = ref.watch(playerProvider);

    final totalDuration = playerState.duration;
    final totalMs = totalDuration.inMilliseconds;

    if (totalMs <= 0) {
      return const SizedBox.shrink();
    }

    final start = cropState.exportStart ?? Duration.zero;
    final end = cropState.exportEnd ?? totalDuration;
    final isFullRange =
        cropState.exportStart == null && cropState.exportEnd == null;
    final selectedDuration = end - start;

    final clampedStartMs = start.inMilliseconds.clamp(0, totalMs).toDouble();
    final clampedEndMs = end.inMilliseconds.clamp(0, totalMs).toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Export Segment',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Text(
              '${TimecodeFormatter.formatShort(start)} - '
              '${TimecodeFormatter.formatShort(end)}',
              style: TextStyle(
                color: isFullRange ? Colors.white : Colors.cyan[300],
                fontSize: 12,
                fontFamily: 'monospace',
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            TextButton(
              onPressed: isFullRange
                  ? null
                  : () => ref.read(cropProvider.notifier).resetExportRange(),
              child: const Text('Use Full Range'),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          'Duration: ${TimecodeFormatter.formatShort(selectedDuration)}',
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 11,
            fontFamily: 'monospace',
          ),
        ),
        const SizedBox(height: 2),
        Text(
          _activeHandle == null
              ? 'Drag either handle to preview exact start/end frames.'
              : (_activeHandle == _RangeHandle.start
                  ? 'Previewing START frame in video.'
                  : 'Previewing END frame in video.'),
          style: const TextStyle(
            color: Colors.white38,
            fontSize: 11,
          ),
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: Colors.cyan[400],
            inactiveTrackColor: Colors.grey[700],
            thumbColor: Colors.cyan[300],
            rangeThumbShape: const RoundRangeSliderThumbShape(
              enabledThumbRadius: 8,
            ),
          ),
          child: RangeSlider(
            min: 0,
            max: totalMs.toDouble(),
            values: RangeValues(clampedStartMs, clampedEndMs),
            labels: RangeLabels(
              TimecodeFormatter.formatShort(
                Duration(milliseconds: clampedStartMs.round()),
              ),
              TimecodeFormatter.formatShort(
                Duration(milliseconds: clampedEndMs.round()),
              ),
            ),
            onChangeStart: _handleRangeChangeStart,
            onChanged: totalMs <= 100
                ? null
                : (values) => _handleRangeChanged(values, totalMs),
            onChangeEnd: _handleRangeChangeEnd,
          ),
        ),
      ],
    );
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

class _ExportStatusMessage extends StatelessWidget {
  final ExportStatus status;
  final String? error;
  final String? exportedPath;
  final VoidCallback onDismiss;

  const _ExportStatusMessage({
    required this.status,
    required this.error,
    required this.exportedPath,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    Color borderColor;
    Color titleColor;
    String title;
    String message;

    switch (status) {
      case ExportStatus.success:
        borderColor = Colors.green[400]!;
        titleColor = Colors.green[300]!;
        title = 'Export complete';
        message = exportedPath ?? 'Video exported successfully.';
        break;
      case ExportStatus.cancelled:
        borderColor = Colors.orange[400]!;
        titleColor = Colors.orange[300]!;
        title = 'Export cancelled';
        message = 'The export was cancelled before completion.';
        break;
      case ExportStatus.error:
        borderColor = Colors.red[400]!;
        titleColor = Colors.red[300]!;
        title = 'Export failed';
        message = error ?? 'Unknown export error.';
        break;
      case ExportStatus.preparing:
      case ExportStatus.exporting:
      case ExportStatus.idle:
        return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor.withValues(alpha: 0.8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                title,
                style: TextStyle(
                  color: titleColor,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: onDismiss,
                tooltip: 'Dismiss',
                icon: const Icon(Icons.close, size: 18),
                color: Colors.white70,
              ),
            ],
          ),
          SelectableText(
            message,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontFamily: 'monospace',
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
          onTap: hasVideo
              ? () {
                  final wasCropModeActive = cropState.isCropModeActive;
                  cropNotifier.toggleCropMode();

                  if (!wasCropModeActive) {
                    final loopState = ref.read(loopProvider);
                    cropNotifier.setExportRange(
                      start: loopState.loopStart,
                      end: loopState.loopEnd,
                    );
                  }
                }
              : null,
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
