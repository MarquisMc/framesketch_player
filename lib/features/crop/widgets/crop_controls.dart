import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import '../../../core/theme/app_palette.dart';
import '../../../core/utils/timecode_formatter.dart';
import '../../../core/services/video_export_models.dart';
import '../providers/crop_provider.dart';
import '../../player/providers/player_provider.dart';
import '../../loop/providers/loop_provider.dart';
import '../../annotations/providers/annotation_provider.dart';

enum _FrameExportScope { single, range }

enum _FrameFormat { png, jpg }

enum _AnnotationExportFormat { framesketch, json }

// ─── Floating crop/export panel ───────────────────────────────────────────────

/// Floating panel that overlays the canvas, opened via the toolbar crop button.
/// Two top-level tabs: Crop and Export.
class CropExportPanel extends ConsumerStatefulWidget {
  final VoidCallback onClose;
  final void Function({
    required int startFrame,
    required int endFrame,
    required int step,
    required bool isPng,
  })?
  onExportFrames;

  const CropExportPanel({
    super.key,
    required this.onClose,
    this.onExportFrames,
  });

  @override
  ConsumerState<CropExportPanel> createState() => _CropExportPanelState();
}

class _CropExportPanelState extends ConsumerState<CropExportPanel>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final ProviderSubscription<dynamic> _metadataSubscription;

  _FrameExportScope _frameScope = _FrameExportScope.single;
  _FrameFormat _frameFormat = _FrameFormat.png;
  late final TextEditingController _frameCtrl;
  late final TextEditingController _startFrameCtrl;
  late final TextEditingController _endFrameCtrl;
  late final TextEditingController _stepCtrl;
  String? _frameValidation;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _frameCtrl = TextEditingController();
    _startFrameCtrl = TextEditingController(text: '0');
    _endFrameCtrl = TextEditingController(text: '0');
    _stepCtrl = TextEditingController(text: '1');
    _syncFrameDefaults();
    _metadataSubscription = ref.listenManual(
      playerProvider.select((state) => state.metadata),
      (previous, next) {
        if (previous == null && next != null) {
          _syncFrameDefaults();
        }
      },
    );
  }

  @override
  void dispose() {
    _metadataSubscription.close();
    _tabController.dispose();
    _frameCtrl.dispose();
    _startFrameCtrl.dispose();
    _endFrameCtrl.dispose();
    _stepCtrl.dispose();
    super.dispose();
  }

  void _syncFrameDefaults() {
    final playerState = ref.read(playerProvider);
    final meta = playerState.metadata;
    if (meta == null) return;
    final currentFrame = ref.read(playerProvider.notifier).currentFrame;
    final maxFrame = meta.frameCount > 0 ? meta.frameCount - 1 : 0;
    _frameCtrl.text = currentFrame.toString();
    _startFrameCtrl.text = '0';
    _endFrameCtrl.text = maxFrame.toString();
  }

  void _submitFrameExport() {
    final meta = ref.read(playerProvider).metadata;
    if (meta == null) return;
    final maxFrame = meta.frameCount > 0 ? meta.frameCount - 1 : 0;

    if (_frameScope == _FrameExportScope.single) {
      final frame = int.tryParse(_frameCtrl.text.trim());
      if (frame == null || frame < 0 || frame > maxFrame) {
        setState(
          () => _frameValidation =
              'Enter a frame number between 0 and $maxFrame.',
        );
        return;
      }
      setState(() => _frameValidation = null);
      widget.onExportFrames?.call(
        startFrame: frame,
        endFrame: frame,
        step: 1,
        isPng: _frameFormat == _FrameFormat.png,
      );
    } else {
      final start = int.tryParse(_startFrameCtrl.text.trim());
      final end = int.tryParse(_endFrameCtrl.text.trim());
      final step = int.tryParse(_stepCtrl.text.trim());
      if (start == null ||
          end == null ||
          start < 0 ||
          end > maxFrame ||
          start > end) {
        setState(
          () =>
              _frameValidation = 'Range must be 0–$maxFrame with start ≤ end.',
        );
        return;
      }
      if (step == null || step <= 0) {
        setState(() => _frameValidation = 'Step must be 1 or greater.');
        return;
      }
      setState(() => _frameValidation = null);
      widget.onExportFrames?.call(
        startFrame: start,
        endFrame: end,
        step: step,
        isPng: _frameFormat == _FrameFormat.png,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);

    return ColoredBox(
      color: palette.panel,
      child: Column(
        children: [
          // ── Title bar with tabs ──────────────────────────────────
          _PanelTitleBar(
            tabController: _tabController,
            onClose: widget.onClose,
            palette: palette,
          ),
          Divider(height: 1, thickness: 1, color: palette.border),
          // ── Tab content ─────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: AnimatedBuilder(
                animation: _tabController,
                builder: (context, _) {
                  return switch (_tabController.index) {
                    0 => _CropTabContent(palette: palette),
                    1 => _FramesContent(
                      scope: _frameScope,
                      format: _frameFormat,
                      frameCtrl: _frameCtrl,
                      startFrameCtrl: _startFrameCtrl,
                      endFrameCtrl: _endFrameCtrl,
                      stepCtrl: _stepCtrl,
                      validation: _frameValidation,
                      onScopeChanged: (s) => setState(() {
                        _frameScope = s;
                        _frameValidation = null;
                      }),
                      onFormatChanged: (f) => setState(() => _frameFormat = f),
                      onClearValidation: () =>
                          setState(() => _frameValidation = null),
                      onExport: _submitFrameExport,
                      palette: palette,
                    ),
                    2 => const _VideoContent(),
                    _ => const SizedBox.shrink(),
                  };
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Title bar with tabs ──────────────────────────────────────────────────────

class _PanelTitleBar extends StatelessWidget {
  final TabController tabController;
  final VoidCallback onClose;
  final AppPalette palette;

  const _PanelTitleBar({
    required this.tabController,
    required this.onClose,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      color: palette.panelElevated,
      child: Row(
        children: [
          const SizedBox(width: 8),
          Expanded(
            child: TabBar(
              controller: tabController,
              isScrollable: false,
              indicatorColor: palette.accentBright,
              indicatorWeight: 2,
              labelColor: palette.accentBright,
              unselectedLabelColor: palette.textSecondary,
              labelStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              unselectedLabelStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w400,
              ),
              dividerColor: Colors.transparent,
              tabs: const [
                Tab(text: 'Crop'),
                Tab(text: 'Frames'),
                Tab(text: 'Video'),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.close, size: 16, color: palette.textMuted),
            onPressed: onClose,
            tooltip: 'Close (C)',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }
}

// ─── Crop tab ─────────────────────────────────────────────────────────────────

class _CropTabContent extends ConsumerWidget {
  final AppPalette palette;
  const _CropTabContent({required this.palette});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cropState = ref.watch(cropProvider);
    final cropNotifier = ref.read(cropProvider.notifier);
    final playerState = ref.watch(playerProvider);
    final hasVideo =
        playerState.isLocalFileSource || playerState.hasLoadedSource;
    final isCropActive = cropState.isCropModeActive;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Crop enable toggle
        _CropEnableRow(
          isCropActive: isCropActive,
          hasVideo: hasVideo,
          onToggle: () {
            if (isCropActive) {
              cropNotifier.exitCropMode();
            } else {
              cropNotifier.enterCropMode();
              final loopState = ref.read(loopProvider);
              cropNotifier.setExportRange(
                start: loopState.loopStart,
                end: loopState.loopEnd,
              );
            }
          },
          palette: palette,
        ),

        if (isCropActive) ...[
          const SizedBox(height: 16),
          _sectionLabel('ASPECT RATIO', palette),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: CropAspectRatio.values.map((ratio) {
              final isSelected = cropState.aspectRatio == ratio;
              return _RatioChip(
                label: ratio.displayName,
                isSelected: isSelected,
                onTap: () => cropNotifier.setAspectRatio(ratio),
                palette: palette,
              );
            }).toList(),
          ),

          const SizedBox(height: 16),
          _CropInfoBox(palette: palette),

          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              icon: const Icon(Icons.refresh, size: 14),
              label: const Text('Reset crop', style: TextStyle(fontSize: 12)),
              onPressed: cropNotifier.resetCrop,
              style: TextButton.styleFrom(
                foregroundColor: palette.textSecondary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
        ] else ...[
          const SizedBox(height: 12),
          Text(
            'Enable crop to define the output region of your video.',
            style: TextStyle(color: palette.textMuted, fontSize: 12),
          ),
        ],
      ],
    );
  }
}

class _CropEnableRow extends StatelessWidget {
  final bool isCropActive;
  final bool hasVideo;
  final VoidCallback onToggle;
  final AppPalette palette;

  const _CropEnableRow({
    required this.isCropActive,
    required this.hasVideo,
    required this.onToggle,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: hasVideo ? onToggle : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isCropActive ? palette.accentSoft : palette.panelOverlay,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isCropActive ? palette.accentBright : palette.border,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.crop,
              size: 16,
              color: isCropActive
                  ? palette.accentBright
                  : (hasVideo ? palette.textSecondary : palette.textDisabled),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                isCropActive ? 'Crop enabled' : 'Crop disabled',
                style: TextStyle(
                  color: isCropActive
                      ? palette.accentBright
                      : palette.textSecondary,
                  fontSize: 13,
                  fontWeight: isCropActive ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
            Switch(
              value: isCropActive,
              onChanged: hasVideo ? (_) => onToggle() : null,
              activeThumbColor: palette.accentBright,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ],
        ),
      ),
    );
  }
}

class _CropInfoBox extends ConsumerWidget {
  final AppPalette palette;
  const _CropInfoBox({required this.palette});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cropState = ref.watch(cropProvider);
    final meta = ref.watch(playerProvider).metadata;
    if (meta == null) return const SizedBox.shrink();

    final pixels = cropState.cropRect.toPixels(meta.width, meta.height);
    final isFull = pixels.width == meta.width && pixels.height == meta.height;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: palette.panelOverlay,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionLabel('OUTPUT', palette),
                const SizedBox(height: 4),
                Text(
                  '${pixels.width} × ${pixels.height}',
                  style: TextStyle(
                    color: isFull
                        ? palette.textSecondary
                        : palette.accentBright,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _sectionLabel('SOURCE', palette),
              const SizedBox(height: 4),
              Text(
                '${meta.width} × ${meta.height}',
                style: TextStyle(
                  color: palette.textMuted,
                  fontSize: 12,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Frames export content ────────────────────────────────────────────────────

class _FramesContent extends ConsumerWidget {
  final _FrameExportScope scope;
  final _FrameFormat format;
  final TextEditingController frameCtrl;
  final TextEditingController startFrameCtrl;
  final TextEditingController endFrameCtrl;
  final TextEditingController stepCtrl;
  final String? validation;
  final void Function(_FrameExportScope) onScopeChanged;
  final void Function(_FrameFormat) onFormatChanged;
  final VoidCallback onClearValidation;
  final VoidCallback onExport;
  final AppPalette palette;

  const _FramesContent({
    required this.scope,
    required this.format,
    required this.frameCtrl,
    required this.startFrameCtrl,
    required this.endFrameCtrl,
    required this.stepCtrl,
    required this.validation,
    required this.onScopeChanged,
    required this.onFormatChanged,
    required this.onClearValidation,
    required this.onExport,
    required this.palette,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasVideo = ref.watch(
      playerProvider.select((s) => s.hasLoadedSource && s.metadata != null),
    );
    if (!hasVideo) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: palette.panelOverlay,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          'Open a video to enable frame export.',
          style: TextStyle(color: palette.textMuted, fontSize: 12),
        ),
      );
    }

    final meta = ref.watch(playerProvider).metadata;
    final maxFrame = meta != null && meta.frameCount > 0
        ? meta.frameCount - 1
        : 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Scope + format row
        Row(
          children: [
            Expanded(
              child: _ScopeToggle(
                current: scope,
                onChanged: onScopeChanged,
                palette: palette,
              ),
            ),
            const SizedBox(width: 8),
            _FormatToggle(
              current: format,
              onChanged: onFormatChanged,
              palette: palette,
            ),
          ],
        ),

        const SizedBox(height: 12),

        if (scope == _FrameExportScope.single)
          _FrameField(
            controller: frameCtrl,
            label: 'Frame number',
            hint: '0–$maxFrame',
            palette: palette,
            onChanged: (_) => onClearValidation(),
            suffix: _UseCurrentBtn(
              onTap: () {
                final cur = ref.read(playerProvider.notifier).currentFrame;
                frameCtrl.text = cur.toString();
                onClearValidation();
              },
              palette: palette,
            ),
          )
        else ...[
          Row(
            children: [
              Expanded(
                child: _FrameField(
                  controller: startFrameCtrl,
                  label: 'Start',
                  hint: '0',
                  palette: palette,
                  onChanged: (_) => onClearValidation(),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _FrameField(
                  controller: endFrameCtrl,
                  label: 'End',
                  hint: '$maxFrame',
                  palette: palette,
                  onChanged: (_) => onClearValidation(),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 64,
                child: _FrameField(
                  controller: stepCtrl,
                  label: 'Step',
                  hint: '1',
                  palette: palette,
                  onChanged: (_) => onClearValidation(),
                ),
              ),
            ],
          ),
        ],

        if (validation != null) ...[
          const SizedBox(height: 6),
          Text(
            validation!,
            style: TextStyle(color: palette.error, fontSize: 11),
          ),
        ],

        const SizedBox(height: 12),

        _ExportButton(
          label: scope == _FrameExportScope.single
              ? 'Export Frame'
              : 'Export Frames',
          icon: Icons.download_outlined,
          onPressed: onExport,
          palette: palette,
        ),
      ],
    );
  }
}

// ─── Video export content ─────────────────────────────────────────────────────

class _VideoContent extends ConsumerStatefulWidget {
  const _VideoContent();

  @override
  ConsumerState<_VideoContent> createState() => _VideoContentState();
}

class _VideoContentState extends ConsumerState<_VideoContent> {
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

        _ExportButton(
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
            _sectionLabel('EXPORT RANGE', palette),
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

// ─── Small shared widgets ─────────────────────────────────────────────────────

class _RatioChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final AppPalette palette;

  const _RatioChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? palette.accent : palette.panelElevated,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? palette.accentBright : palette.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? palette.textPrimary : palette.textSecondary,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

class _ScopeToggle extends StatelessWidget {
  final _FrameExportScope current;
  final void Function(_FrameExportScope) onChanged;
  final AppPalette palette;

  const _ScopeToggle({
    required this.current,
    required this.onChanged,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 30,
      decoration: BoxDecoration(
        color: palette.panelOverlay,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          _ScopeOption(
            label: 'Single',
            isSelected: current == _FrameExportScope.single,
            onTap: () => onChanged(_FrameExportScope.single),
            palette: palette,
          ),
          _ScopeOption(
            label: 'Range',
            isSelected: current == _FrameExportScope.range,
            onTap: () => onChanged(_FrameExportScope.range),
            palette: palette,
          ),
        ],
      ),
    );
  }
}

class _ScopeOption extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final AppPalette palette;

  const _ScopeOption({
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          margin: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: isSelected ? palette.panel : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? palette.accentBright : palette.textSecondary,
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}

class _FormatToggle extends StatelessWidget {
  final _FrameFormat current;
  final void Function(_FrameFormat) onChanged;
  final AppPalette palette;

  const _FormatToggle({
    required this.current,
    required this.onChanged,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 30,
      decoration: BoxDecoration(
        color: palette.panelOverlay,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _FmtOption(
            label: 'PNG',
            isSelected: current == _FrameFormat.png,
            onTap: () => onChanged(_FrameFormat.png),
            palette: palette,
          ),
          Container(width: 1, height: 20, color: palette.border),
          _FmtOption(
            label: 'JPG',
            isSelected: current == _FrameFormat.jpg,
            onTap: () => onChanged(_FrameFormat.jpg),
            palette: palette,
          ),
        ],
      ),
    );
  }
}

class _FmtOption extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final AppPalette palette;

  const _FmtOption({
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        padding: const EdgeInsets.symmetric(horizontal: 9),
        height: double.infinity,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? palette.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(5),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? palette.textPrimary : palette.textSecondary,
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

class _FrameField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final AppPalette palette;
  final void Function(String)? onChanged;
  final Widget? suffix;

  const _FrameField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.palette,
    this.onChanged,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      onChanged: onChanged,
      style: TextStyle(
        color: palette.textPrimary,
        fontSize: 13,
        fontFamily: 'monospace',
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: palette.textMuted, fontSize: 12),
        hintText: hint,
        hintStyle: TextStyle(color: palette.textDisabled, fontSize: 12),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        filled: true,
        fillColor: palette.panelElevated,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: palette.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: palette.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: palette.accentBright),
        ),
        suffixIcon: suffix,
        isDense: true,
      ),
    );
  }
}

class _UseCurrentBtn extends StatelessWidget {
  final VoidCallback onTap;
  final AppPalette palette;

  const _UseCurrentBtn({required this.onTap, required this.palette});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Use current frame',
      child: IconButton(
        icon: Icon(Icons.my_location, size: 15, color: palette.textMuted),
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
        onPressed: onTap,
      ),
    );
  }
}

class _ExportButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final AppPalette palette;

  const _ExportButton({
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

Widget _sectionLabel(String text, AppPalette palette) {
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

// ─── Toolbar crop button ──────────────────────────────────────────────────────

/// Toolbar button that opens/closes the crop & export panel.
class CropModeToggleButton extends ConsumerWidget {
  final VoidCallback? onTogglePanel;
  final bool isPanelOpen;

  const CropModeToggleButton({
    super.key,
    this.onTogglePanel,
    this.isPanelOpen = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = AppPalette.of(context);
    final cropState = ref.watch(cropProvider);
    final hasVideo = ref.watch(playerProvider.select((s) => s.player != null));
    final isActive = isPanelOpen || cropState.isCropModeActive;

    return Tooltip(
      message: isPanelOpen ? 'Close crop & export (C)' : 'Crop & Export (C)',
      child: Material(
        color: isActive ? palette.accent : palette.panelElevated,
        borderRadius: BorderRadius.circular(4),
        child: InkWell(
          onTap: hasVideo ? onTogglePanel : null,
          borderRadius: BorderRadius.circular(4),
          child: Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            child: Icon(
              Icons.crop,
              size: 24,
              color: isActive
                  ? palette.textPrimary
                  : (hasVideo ? palette.textSecondary : palette.textDisabled),
            ),
          ),
        ),
      ),
    );
  }
}
