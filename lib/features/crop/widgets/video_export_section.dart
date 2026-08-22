import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/video_export_models.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/utils/timecode_formatter.dart';
import '../../annotations/providers/annotation_provider.dart';
import '../../player/providers/player_provider.dart';
import '../providers/crop_provider.dart';
import 'crop_panel_common.dart';

enum _AnnotationExportFormat { framesketch, json }

/// "Video" section of the crop & export panel: export range, annotation file
/// format, the export action, and progress/status reporting.
class VideoExportSection extends ConsumerStatefulWidget {
  const VideoExportSection({super.key});

  @override
  ConsumerState<VideoExportSection> createState() => _VideoExportSectionState();
}

class _VideoExportSectionState extends ConsumerState<VideoExportSection> {
  _AnnotationExportFormat _localAnnotationFormat = _AnnotationExportFormat.json;
  _AnnotationExportFormat _youtubeAnnotationFormat =
      _AnnotationExportFormat.framesketch;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final cropState = ref.watch(cropProvider);
    final cropNotifier = ref.read(cropProvider.notifier);
    final playerState = ref.watch(playerProvider);
    final annotationData = ref.watch(annotationProvider).annotationData;
    final isLocalVideo = playerState.isLocalFileSource;
    final youtubeUrl = annotationData?.youtubeUrl;
    final isYouTubeSource =
        !isLocalVideo && (youtubeUrl?.trim().isNotEmpty ?? false);
    final canUseExportButton = isLocalVideo || isYouTubeSource;
    final isExportingOrPreparing =
        cropState.exportStatus == ExportStatus.exporting ||
        cropState.exportStatus == ExportStatus.preparing;
    final exportButtonLabel = isYouTubeSource
        ? 'Export Annotation'
        : 'Export Video';
    final annotationFormat = isLocalVideo
        ? _localAnnotationFormat
        : _youtubeAnnotationFormat;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (isLocalVideo) ...[
          const _ExportRangeControls(),
          const SizedBox(height: 14),
        ],
        if (isLocalVideo || isYouTubeSource) ...[
          DropdownButtonFormField<_AnnotationExportFormat>(
            initialValue: annotationFormat,
            decoration: const InputDecoration(
              labelText: 'Annotation File Format',
            ),
            items: _annotationFormatItems(recommendJson: isLocalVideo),
            onChanged: (value) {
              if (value == null) return;
              setState(() {
                if (isLocalVideo) {
                  _localAnnotationFormat = value;
                } else {
                  _youtubeAnnotationFormat = value;
                }
              });
            },
          ),
          const SizedBox(height: 14),
        ],

        PanelExportButton(
          label: isExportingOrPreparing ? 'Exporting…' : exportButtonLabel,
          icon: isExportingOrPreparing
              ? Icons.hourglass_top
              : Icons.download_outlined,
          onPressed: canUseExportButton && !isExportingOrPreparing
              ? () => isYouTubeSource
                    ? _exportYouTubeAnnotationFile(context, ref)
                    : _showPresetDialog(context, ref)
              : null,
          palette: palette,
        ),

        if (cropState.exportStatus == ExportStatus.preparing)
          _ExportProgress(
            title: 'Preparing…',
            progress: cropState.preparationProgress,
            detail: cropState.preparationMessage ?? 'Locating FFmpeg…',
          ),

        if (cropState.exportStatus == ExportStatus.exporting)
          _ExportProgress(
            title: 'Exporting…',
            progress: cropState.exportProgress,
            onCancel: cropNotifier.cancelExport,
          ),

        if (cropState.exportStatus != ExportStatus.idle &&
            !isExportingOrPreparing)
          _ExportStatusMessage(
            status: cropState.exportStatus,
            error: cropState.exportError,
            exportedPath: cropState.exportedFilePath,
            onDismiss: cropNotifier.resetExportState,
          ),
      ],
    );
  }

  List<DropdownMenuItem<_AnnotationExportFormat>> _annotationFormatItems({
    required bool recommendJson,
  }) {
    return recommendJson
        ? const [
            DropdownMenuItem(
              value: _AnnotationExportFormat.json,
              child: Text('.json (recommended)'),
            ),
            DropdownMenuItem(
              value: _AnnotationExportFormat.framesketch,
              child: Text('.framesketch'),
            ),
          ]
        : const [
            DropdownMenuItem(
              value: _AnnotationExportFormat.framesketch,
              child: Text('.framesketch (recommended)'),
            ),
            DropdownMenuItem(
              value: _AnnotationExportFormat.json,
              child: Text('.json'),
            ),
          ];
  }

  Future<void> _exportYouTubeAnnotationFile(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final annotationData = ref.read(annotationProvider).annotationData;
    if (annotationData == null ||
        annotationData.youtubeUrl == null ||
        annotationData.youtubeUrl!.trim().isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('No YouTube video data available to export'),
            backgroundColor: AppPalette.of(context).error,
          ),
        );
      }
      return;
    }

    final playerState = ref.read(playerProvider);
    final sourceLabel =
        playerState.currentDisplayLabel?.trim().isNotEmpty == true
        ? playerState.currentDisplayLabel!
        : playerState.currentSourceLabel ?? annotationData.videoPath;
    final safeBase = _safeName(sourceLabel);
    final extension = _annotationExtension(_youtubeAnnotationFormat);
    final selectedPath = await FilePicker.platform.saveFile(
      dialogTitle: 'Export Annotation File',
      fileName: '$safeBase.$extension',
      type: FileType.custom,
      allowedExtensions: const ['framesketch', 'json'],
    );
    if (selectedPath == null) return;

    final outputPath = _ensureAnnotationExtension(
      selectedPath,
      _youtubeAnnotationFormat,
    );
    final success = await ref
        .read(annotationProvider.notifier)
        .saveAnnotationsToFile(outputPath);
    if (!context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    if (success) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Annotation file exported: $outputPath'),
          backgroundColor: AppPalette.of(context).success,
        ),
      );
    } else {
      messenger.showSnackBar(
        SnackBar(
          content: const Text('Failed to export annotation file'),
          backgroundColor: AppPalette.of(context).error,
        ),
      );
    }
  }

  Future<void> _showPresetDialog(BuildContext context, WidgetRef ref) async {
    final playerState = ref.read(playerProvider);
    if (playerState.currentVideoPath == null) return;

    final inputFile = File(playerState.currentVideoPath!);
    final inputName = inputFile.uri.pathSegments.last;
    final dotIndex = inputName.lastIndexOf('.');
    final nameWithoutExt = dotIndex > 0
        ? inputName.substring(0, dotIndex)
        : inputName;
    final safeBase = _safeName(nameWithoutExt);

    final preset = await showDialog<VideoExportPreset>(
      context: context,
      builder: (_) => const _VideoExportPresetDialog(),
    );
    if (preset == null) return;
    if (!context.mounted) return;

    final result = await FilePicker.platform.saveFile(
      dialogTitle: 'Export Video',
      fileName: '${safeBase}_export.mp4',
      type: FileType.custom,
      allowedExtensions: const ['mp4'],
    );
    if (result != null) {
      await ref.read(annotationProvider.notifier).saveAnnotations();
      final annotationData = ref.read(annotationProvider).annotationData;
      ref
          .read(cropProvider.notifier)
          .exportCroppedVideo(
            result,
            annotationData: annotationData,
            preset: preset,
            annotationSidecarExtension: _annotationExtension(
              _localAnnotationFormat,
            ),
          );
    }
  }

  static String _safeName(String input) {
    final s = input
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (s.isEmpty) return 'export';
    return s.length <= 64 ? s : s.substring(0, 64).trimRight();
  }

  static String _annotationExtension(_AnnotationExportFormat format) {
    return switch (format) {
      _AnnotationExportFormat.framesketch => 'framesketch',
      _AnnotationExportFormat.json => 'json',
    };
  }

  static String _ensureAnnotationExtension(
    String input,
    _AnnotationExportFormat format,
  ) {
    final extension = _annotationExtension(format);
    final lower = input.toLowerCase();
    if (lower.endsWith('.$extension')) {
      return input;
    }
    if (lower.endsWith('.framesketch')) {
      return '${input.substring(0, input.length - '.framesketch'.length)}.$extension';
    }
    if (lower.endsWith('.json')) {
      return '${input.substring(0, input.length - '.json'.length)}.$extension';
    }
    return '$input.$extension';
  }
}

// ─── Video export preset dialog ───────────────────────────────────────────────

class _VideoExportPresetDialog extends StatefulWidget {
  const _VideoExportPresetDialog();

  @override
  State<_VideoExportPresetDialog> createState() =>
      _VideoExportPresetDialogState();
}

class _VideoExportPresetDialogState extends State<_VideoExportPresetDialog> {
  VideoExportPreset _preset = VideoExportPreset.compatible;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Export Video'),
      content: SizedBox(
        width: 340,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<VideoExportPreset>(
              initialValue: _preset,
              decoration: const InputDecoration(labelText: 'Speed / Quality'),
              items: VideoExportPreset.values
                  .map(
                    (p) =>
                        DropdownMenuItem(value: p, child: Text(p.displayName)),
                  )
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _preset = v);
              },
            ),
            const SizedBox(height: 8),
            Text(
              _preset.description,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_preset),
          child: const Text('Export'),
        ),
      ],
    );
  }
}

// ─── Export range slider ──────────────────────────────────────────────────────

enum _RangeHandle { start, end }

class _ExportRangeControls extends ConsumerStatefulWidget {
  const _ExportRangeControls();

  @override
  ConsumerState<_ExportRangeControls> createState() =>
      _ExportRangeControlsState();
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
    _wasPlayingBeforePreview = ref.read(playerProvider).isPlaying;
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
      if (endMs - startMs < 100) startMs = (endMs - 100).clamp(0, totalMs);
    }
    if (_lastStartMs != null && _lastEndMs != null) {
      final sd = (values.start - _lastStartMs!).abs();
      final ed = (values.end - _lastEndMs!).abs();
      _activeHandle = sd >= ed ? _RangeHandle.start : _RangeHandle.end;
    } else {
      _activeHandle = _RangeHandle.end;
    }
    _lastStartMs = values.start;
    _lastEndMs = values.end;
    ref
        .read(cropProvider.notifier)
        .setExportRange(
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
    final palette = AppPalette.of(context);
    final cropState = ref.watch(cropProvider);
    final totalDuration = ref.watch(playerProvider.select((s) => s.duration));
    final totalMs = totalDuration.inMilliseconds;
    if (totalMs <= 0) return const SizedBox.shrink();

    final start = cropState.exportStart ?? Duration.zero;
    final end = cropState.exportEnd ?? totalDuration;
    final isFullRange =
        cropState.exportStart == null && cropState.exportEnd == null;
    final selectedDuration = end - start;
    final clampedStart = start.inMilliseconds.clamp(0, totalMs).toDouble();
    final clampedEnd = end.inMilliseconds.clamp(0, totalMs).toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            panelSectionLabel('EXPORT RANGE', palette),
            const Spacer(),
            if (!isFullRange)
              TextButton(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () =>
                    ref.read(cropProvider.notifier).resetExportRange(),
                child: Text(
                  'Full range',
                  style: TextStyle(fontSize: 11, color: palette.accentBright),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Text(
              TimecodeFormatter.formatShort(start),
              style: TextStyle(
                color: palette.textPrimary,
                fontSize: 12,
                fontFamily: 'monospace',
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              '  –  ',
              style: TextStyle(color: palette.textMuted, fontSize: 12),
            ),
            Text(
              TimecodeFormatter.formatShort(end),
              style: TextStyle(
                color: palette.textPrimary,
                fontSize: 12,
                fontFamily: 'monospace',
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '(${TimecodeFormatter.formatShort(selectedDuration)})',
              style: TextStyle(
                color: palette.textMuted,
                fontSize: 11,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: palette.accent,
            inactiveTrackColor: palette.border,
            thumbColor: palette.accentBright,
            rangeThumbShape: const RoundRangeSliderThumbShape(
              enabledThumbRadius: 7,
            ),
          ),
          child: RangeSlider(
            min: 0,
            max: totalMs.toDouble(),
            values: RangeValues(clampedStart, clampedEnd),
            labels: RangeLabels(
              TimecodeFormatter.formatShort(
                Duration(milliseconds: clampedStart.round()),
              ),
              TimecodeFormatter.formatShort(
                Duration(milliseconds: clampedEnd.round()),
              ),
            ),
            onChangeStart: _handleRangeChangeStart,
            onChanged: totalMs <= 100
                ? null
                : (v) => _handleRangeChanged(v, totalMs),
            onChangeEnd: _handleRangeChangeEnd,
          ),
        ),
        Text(
          _activeHandle == null
              ? 'Drag handles to preview start/end frames.'
              : (_activeHandle == _RangeHandle.start
                    ? 'Previewing START frame.'
                    : 'Previewing END frame.'),
          style: TextStyle(color: palette.textMuted, fontSize: 11),
        ),
      ],
    );
  }
}

// ─── Progress / status ────────────────────────────────────────────────────────

class _ExportProgress extends StatelessWidget {
  final String title;
  final double? progress;
  final String? detail;
  final VoidCallback? onCancel;

  const _ExportProgress({
    required this.title,
    required this.progress,
    this.detail,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final pv = progress?.clamp(0.0, 1.0);
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.panelOverlay,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                title,
                style: TextStyle(
                  color: palette.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              if (pv != null)
                Text(
                  '${(pv * 100).toStringAsFixed(1)}%',
                  style: TextStyle(
                    color: palette.textSecondary,
                    fontSize: 12,
                    fontFamily: 'monospace',
                  ),
                ),
            ],
          ),
          if (detail != null) ...[
            const SizedBox(height: 4),
            Text(
              detail!,
              style: TextStyle(color: palette.textMuted, fontSize: 11),
            ),
          ],
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pv,
              backgroundColor: palette.border,
              valueColor: AlwaysStoppedAnimation(palette.accent),
              minHeight: 5,
            ),
          ),
          if (onCancel != null) ...[
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                icon: const Icon(Icons.cancel_outlined, size: 13),
                label: const Text('Cancel'),
                onPressed: onCancel,
                style: TextButton.styleFrom(
                  foregroundColor: palette.error,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ),
          ],
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
    final palette = AppPalette.of(context);
    late Color borderColor;
    late Color titleColor;
    late String title;
    late String message;

    switch (status) {
      case ExportStatus.success:
        borderColor = palette.success;
        titleColor = palette.success;
        title = 'Export complete';
        message = exportedPath ?? 'Video exported successfully.';
      case ExportStatus.cancelled:
        borderColor = palette.warning;
        titleColor = palette.warning;
        title = 'Cancelled';
        message = 'Export was cancelled.';
      case ExportStatus.error:
        borderColor = palette.error;
        titleColor = palette.error;
        title = 'Export failed';
        message = error ?? 'Unknown error.';
      case ExportStatus.preparing:
      case ExportStatus.exporting:
      case ExportStatus.idle:
        return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.panelOverlay,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor.withValues(alpha: 0.7)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: titleColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                SelectableText(
                  message,
                  style: TextStyle(
                    color: palette.textSecondary,
                    fontSize: 11,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onDismiss,
            icon: const Icon(Icons.close, size: 15),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
            color: palette.textSecondary,
          ),
        ],
      ),
    );
  }
}
