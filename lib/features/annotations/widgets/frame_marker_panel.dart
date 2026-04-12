import 'dart:io' show File;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/frame_marker_file_service.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/utils/timecode_formatter.dart';
import '../../player/providers/player_provider.dart';
import '../models/frame_marker.dart';
import '../providers/annotation_provider.dart';

class FrameMarkerPanel extends ConsumerStatefulWidget {
  const FrameMarkerPanel({super.key});

  @override
  ConsumerState<FrameMarkerPanel> createState() => _FrameMarkerPanelState();
}

class _FrameMarkerPanelState extends ConsumerState<FrameMarkerPanel> {
  final FrameMarkerFileService _fileService = FrameMarkerFileService();
  bool _isExpanded = true;

  int _frameFromMs(int milliseconds, double fps) {
    if (fps <= 0) return 0;
    return ((milliseconds / 1000.0) * fps).round();
  }

  Future<void> _openMarkerEditor({
    required Color defaultColor,
    FrameMarker? marker,
  }) async {
    final playerState = ref.read(playerProvider);
    final annotationData = ref.read(annotationProvider).annotationData;
    if (annotationData == null || playerState.player == null) {
      return;
    }

    final fps = playerState.metadata?.fps ?? annotationData.fps;
    final currentFrame = _frameFromMs(
      marker?.timeMs ?? playerState.position.inMilliseconds,
      fps,
    );

    final draft = await showDialog<_MarkerDraft>(
      context: context,
      builder: (dialogContext) => _MarkerEditorDialog(
        initialLabel: marker?.label ?? 'Frame $currentFrame',
        initialNote: marker?.note ?? '',
        initialColor: marker?.color ?? defaultColor,
        frameNumber: currentFrame,
        timecode: TimecodeFormatter.format(
          Duration(
            milliseconds:
                marker?.timeMs ?? playerState.position.inMilliseconds,
          ),
        ),
      ),
    );

    if (!mounted || draft == null) return;

    ref.read(annotationProvider.notifier).upsertMarker(
      markerId: marker?.id,
      label: draft.label,
      note: draft.note,
      color: draft.color,
      timeMs: marker?.timeMs,
    );
  }

  Future<void> _exportMarkers() async {
    final annotationData = ref.read(annotationProvider).annotationData;
    if (annotationData == null) return;

    final suggestedBaseName =
        _fileService.buildSuggestedBaseName(annotationData);
    final selectedPath = await FilePicker.platform.saveFile(
      dialogTitle: 'Export Marker List',
      fileName: '${suggestedBaseName}_markers.json',
      type: FileType.custom,
      allowedExtensions: ['json'],
    );

    if (selectedPath == null) return;

    final outputPath = selectedPath.toLowerCase().endsWith('.json')
        ? selectedPath
        : '$selectedPath.json';
    final encoded =
        _fileService.encodeMarkerList(annotationData: annotationData);
    await File(outputPath).writeAsString(encoded);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Marker list exported to $outputPath'),
        backgroundColor: AppPalette.of(context).success,
      ),
    );
  }

  Future<void> _importMarkers() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json', 'framesketch'],
      dialogTitle: 'Import Marker List',
    );

    if (result == null || result.files.isEmpty) return;
    final filePath = result.files.first.path;
    if (filePath == null) return;

    try {
      final rawJson = await File(filePath).readAsString();
      final importedMarkers = _fileService.decodeMarkerList(rawJson);
      final existingCount = ref.read(annotationMarkersProvider).length;
      if (!mounted) return;
      final importMode = await showDialog<_MarkerImportMode>(
        context: context,
        builder: (dialogContext) => _MarkerImportDialog(
          existingCount: existingCount,
          importedCount: importedMarkers.length,
        ),
      );

      if (!mounted || importMode == null) return;

      final notifier = ref.read(annotationProvider.notifier);
      switch (importMode) {
        case _MarkerImportMode.merge:
          notifier.mergeMarkers(importedMarkers);
          break;
        case _MarkerImportMode.replace:
          notifier.replaceMarkers(importedMarkers);
          break;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            importMode == _MarkerImportMode.merge
                ? 'Merged ${importedMarkers.length} markers'
                : 'Replaced marker list with ${importedMarkers.length} imported markers',
          ),
          backgroundColor: AppPalette.of(context).success,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to import markers: $error'),
          backgroundColor: AppPalette.of(context).error,
        ),
      );
    }
  }

  void _confirmDeleteMarker(FrameMarker marker) {
    final palette = AppPalette.of(context);
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Marker'),
        content: Text('Remove "${marker.label}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: palette.error),
            onPressed: () {
              Navigator.of(dialogContext).pop();
              ref.read(annotationProvider.notifier).deleteMarker(marker.id);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final playerState = ref.watch(playerProvider);
    final annotationData = ref.watch(
      annotationProvider.select((state) => state.annotationData),
    );
    final markers = ref.watch(annotationMarkersProvider);
    final currentMarker = ref.watch(currentAnnotationMarkerProvider);
    final annotationNotifier = ref.read(annotationProvider.notifier);

    final hasVideo = playerState.player != null && annotationData != null;
    final fps = playerState.metadata?.fps ?? annotationData?.fps ?? 30.0;
    final defaultColor = palette.annotationSwatches.first;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // --- Header row ---
        InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: () => setState(() => _isExpanded = !_isExpanded),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Row(
              children: [
                AnimatedRotation(
                  turns: _isExpanded ? 0.25 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    Icons.chevron_right,
                    size: 16,
                    color: palette.textSecondary,
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  Icons.bookmark_outline,
                  size: 15,
                  color: palette.accentBright,
                ),
                const SizedBox(width: 6),
                Text(
                  'Markers',
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                if (markers.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: palette.accentSoft,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${markers.length}',
                      style: TextStyle(
                        color: palette.accentBright,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                // Nav arrows (always visible when markers exist)
                if (markers.isNotEmpty) ...[
                  _HeaderIconButton(
                    tooltip: 'Previous marker',
                    icon: Icons.skip_previous_rounded,
                    onPressed: () => annotationNotifier.seekToPreviousMarker(),
                  ),
                  _HeaderIconButton(
                    tooltip: 'Next marker',
                    icon: Icons.skip_next_rounded,
                    onPressed: () => annotationNotifier.seekToNextMarker(),
                  ),
                  const SizedBox(width: 4),
                ],
                // Add marker
                _HeaderIconButton(
                  tooltip: 'Add marker at playhead',
                  icon: Icons.add_rounded,
                  onPressed: hasVideo
                      ? () => _openMarkerEditor(defaultColor: defaultColor)
                      : null,
                ),
                // Import / Export
                _HeaderIconButton(
                  tooltip: 'Import markers',
                  icon: Icons.file_upload_outlined,
                  onPressed: hasVideo ? _importMarkers : null,
                ),
                _HeaderIconButton(
                  tooltip: 'Export markers',
                  icon: Icons.file_download_outlined,
                  onPressed: markers.isNotEmpty ? _exportMarkers : null,
                ),
              ],
            ),
          ),
        ),

        // --- Body ---
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: _buildBody(
            palette: palette,
            hasVideo: hasVideo,
            markers: markers,
            currentMarker: currentMarker,
            annotationNotifier: annotationNotifier,
            fps: fps,
            defaultColor: defaultColor,
          ),
          crossFadeState:
              _isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 200),
          sizeCurve: Curves.easeInOut,
        ),
      ],
    );
  }

  Widget _buildBody({
    required AppPalette palette,
    required bool hasVideo,
    required List<FrameMarker> markers,
    required FrameMarker? currentMarker,
    required AnnotationNotifier annotationNotifier,
    required double fps,
    required Color defaultColor,
  }) {
    if (!hasVideo) {
      return _EmptyState(
        icon: Icons.videocam_off_outlined,
        message: 'Load a video to start bookmarking frames',
        palette: palette,
      );
    }

    if (markers.isEmpty) {
      return _EmptyState(
        icon: Icons.bookmark_add_outlined,
        message: 'No markers yet — bookmark frames for review notes or timing',
        palette: palette,
      );
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 180),
      child: ListView.builder(
        shrinkWrap: true,
        padding: const EdgeInsets.only(top: 2, bottom: 4),
        itemCount: markers.length,
        itemBuilder: (context, index) {
          final marker = markers[index];
          final isCurrent = currentMarker?.id == marker.id;
          final frameNumber = _frameFromMs(marker.timeMs, fps);
          final timecode = TimecodeFormatter.format(
            Duration(milliseconds: marker.timeMs),
          );

          return _MarkerTile(
            marker: marker,
            frameNumber: frameNumber,
            timecode: timecode,
            isCurrent: isCurrent,
            palette: palette,
            onTap: () => annotationNotifier.seekToMarker(marker),
            onEdit: () => _openMarkerEditor(
              defaultColor: defaultColor,
              marker: marker,
            ),
            onDelete: () => _confirmDeleteMarker(marker),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Header icon button — compact, consistent
// ---------------------------------------------------------------------------
class _HeaderIconButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;

  const _HeaderIconButton({
    required this.tooltip,
    required this.icon,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(4),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Icon(
              icon,
              size: 16,
              color:
                  onPressed != null ? palette.textSecondary : palette.textDisabled,
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Empty state placeholder
// ---------------------------------------------------------------------------
class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final AppPalette palette;

  const _EmptyState({
    required this.icon,
    required this.message,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: palette.textMuted),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              message,
              style: TextStyle(color: palette.textMuted, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Individual marker tile — accent bar + hover actions
// ---------------------------------------------------------------------------
class _MarkerTile extends StatefulWidget {
  final FrameMarker marker;
  final int frameNumber;
  final String timecode;
  final bool isCurrent;
  final AppPalette palette;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _MarkerTile({
    required this.marker,
    required this.frameNumber,
    required this.timecode,
    required this.isCurrent,
    required this.palette,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<_MarkerTile> createState() => _MarkerTileState();
}

class _MarkerTileState extends State<_MarkerTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final palette = widget.palette;
    final marker = widget.marker;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onSecondaryTapUp: (details) {
            _showContextMenu(context, details.globalPosition);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: BoxDecoration(
              color: widget.isCurrent
                  ? palette.accentSoft
                  : _hovered
                      ? palette.panelElevated
                      : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
              border: widget.isCurrent
                  ? Border.all(
                      color: palette.accent.withValues(alpha: 0.4),
                      width: 1,
                    )
                  : null,
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(6),
              onTap: widget.onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    // Left color accent bar
                    Container(
                      width: 3,
                      height: 28,
                      decoration: BoxDecoration(
                        color: marker.color,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Content
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            marker.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: widget.isCurrent
                                  ? palette.accentBright
                                  : palette.textPrimary,
                              fontWeight: FontWeight.w500,
                              fontSize: 12.5,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Row(
                            children: [
                              Text(
                                'F${widget.frameNumber}',
                                style: TextStyle(
                                  color: palette.textMuted,
                                  fontSize: 11,
                                  fontFamily: 'monospace',
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 4),
                                child: Text(
                                  '\u00B7',
                                  style: TextStyle(
                                    color: palette.textMuted,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                              Text(
                                widget.timecode,
                                style: TextStyle(
                                  color: palette.textMuted,
                                  fontSize: 11,
                                  fontFamily: 'monospace',
                                ),
                              ),
                              if (marker.note.trim().isNotEmpty) ...[
                                Padding(
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 4),
                                  child: Text(
                                    '\u00B7',
                                    style: TextStyle(
                                      color: palette.textMuted,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                                Flexible(
                                  child: Text(
                                    marker.note.trim(),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: palette.textSecondary,
                                      fontSize: 11,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Hover-reveal actions
                    AnimatedOpacity(
                      opacity: _hovered ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 120),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _TileAction(
                            tooltip: 'Edit',
                            icon: Icons.edit_outlined,
                            onTap: widget.onEdit,
                            palette: palette,
                          ),
                          _TileAction(
                            tooltip: 'Delete',
                            icon: Icons.close_rounded,
                            onTap: widget.onDelete,
                            palette: palette,
                            isDestructive: true,
                          ),
                          const SizedBox(width: 4),
                        ],
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

  void _showContextMenu(BuildContext context, Offset position) {
    final palette = widget.palette;
    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx,
        position.dy,
      ),
      items: [
        PopupMenuItem(
          value: 'edit',
          child: Row(
            children: [
              Icon(Icons.edit_outlined, size: 16, color: palette.textSecondary),
              const SizedBox(width: 8),
              const Text('Edit marker'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete_outline, size: 16, color: palette.error),
              const SizedBox(width: 8),
              Text('Delete', style: TextStyle(color: palette.error)),
            ],
          ),
        ),
      ],
    ).then((value) {
      if (value == 'edit') {
        widget.onEdit();
      } else if (value == 'delete') {
        widget.onDelete();
      }
    });
  }
}

// ---------------------------------------------------------------------------
// Tiny action button inside a tile
// ---------------------------------------------------------------------------
class _TileAction extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;
  final AppPalette palette;
  final bool isDestructive;

  const _TileAction({
    required this.tooltip,
    required this.icon,
    required this.onTap,
    required this.palette,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(4),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(
            icon,
            size: 14,
            color: isDestructive ? palette.error : palette.textSecondary,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Marker editor dialog
// ---------------------------------------------------------------------------
class _MarkerEditorDialog extends StatefulWidget {
  final String initialLabel;
  final String initialNote;
  final Color initialColor;
  final int frameNumber;
  final String timecode;

  const _MarkerEditorDialog({
    required this.initialLabel,
    required this.initialNote,
    required this.initialColor,
    required this.frameNumber,
    required this.timecode,
  });

  @override
  State<_MarkerEditorDialog> createState() => _MarkerEditorDialogState();
}

class _MarkerEditorDialogState extends State<_MarkerEditorDialog> {
  late final TextEditingController _labelController;
  late final TextEditingController _noteController;
  late Color _selectedColor;

  @override
  void initState() {
    super.initState();
    _labelController = TextEditingController(text: widget.initialLabel);
    _noteController = TextEditingController(text: widget.initialNote);
    _selectedColor = widget.initialColor;
  }

  @override
  void dispose() {
    _labelController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final swatches = palette.annotationSwatches;

    return AlertDialog(
      title: const Text('Marker Details'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Frame/timecode badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: palette.panelElevated,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Frame ${widget.frameNumber}  \u00B7  ${widget.timecode}',
                  style: TextStyle(
                    color: palette.textSecondary,
                    fontSize: 12,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _labelController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Label',
                  hintText: 'Bad frame, timing issue, crop start...',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _noteController,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Notes',
                  hintText: 'Optional review context',
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Color',
                style: TextStyle(
                  color: palette.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final swatch in swatches)
                    _ColorChoice(
                      color: swatch,
                      isSelected:
                          swatch.toARGB32() == _selectedColor.toARGB32(),
                      onTap: () => setState(() {
                        _selectedColor = swatch;
                      }),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final label = _labelController.text.trim();
            if (label.isEmpty) {
              return;
            }
            Navigator.of(context).pop(
              _MarkerDraft(
                label: label,
                note: _noteController.text.trim(),
                color: _selectedColor,
              ),
            );
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _ColorChoice extends StatelessWidget {
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _ColorChoice({
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? palette.accentBright : palette.border,
            width: isSelected ? 2 : 1,
          ),
        ),
      ),
    );
  }
}

class _MarkerImportDialog extends StatelessWidget {
  final int existingCount;
  final int importedCount;

  const _MarkerImportDialog({
    required this.existingCount,
    required this.importedCount,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Import Marker List'),
      content: Text(
        existingCount == 0
            ? 'Import $importedCount markers into the current review session?'
            : 'Import $importedCount markers. You currently have $existingCount markers. Choose whether to merge them or replace the current list.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        if (existingCount > 0)
          TextButton(
            onPressed: () =>
                Navigator.of(context).pop(_MarkerImportMode.merge),
            child: const Text('Merge'),
          ),
        FilledButton(
          onPressed: () =>
              Navigator.of(context).pop(_MarkerImportMode.replace),
          child: Text(existingCount > 0 ? 'Replace' : 'Import'),
        ),
      ],
    );
  }
}

class _MarkerDraft {
  final String label;
  final String note;
  final Color color;

  const _MarkerDraft({
    required this.label,
    required this.note,
    required this.color,
  });
}

enum _MarkerImportMode { merge, replace }
