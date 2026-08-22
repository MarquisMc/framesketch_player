import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_palette.dart';
import '../../player/providers/player_provider.dart';
import '../providers/crop_provider.dart';
import 'crop_panel_common.dart';
import 'crop_section.dart';
import 'frame_export_section.dart';
import 'video_export_section.dart';

// ─── Floating crop/export panel ───────────────────────────────────────────────

/// Floating panel that overlays the canvas, opened via the toolbar crop button.
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

class _CropExportPanelState extends ConsumerState<CropExportPanel> {
  late final ProviderSubscription<dynamic> _metadataSubscription;
  late final ProviderSubscription<Duration?> _exportFrameSelectionSubscription;

  FrameExportScope _frameScope = FrameExportScope.single;
  FrameImageFormat _frameFormat = FrameImageFormat.png;
  late final TextEditingController _frameCtrl;
  late final TextEditingController _startFrameCtrl;
  late final TextEditingController _endFrameCtrl;
  late final TextEditingController _stepCtrl;
  String? _frameValidation;

  @override
  void initState() {
    super.initState();
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
    _exportFrameSelectionSubscription = ref.listenManual(
      cropProvider.select((state) => state.exportFrameSelection),
      (previous, next) {
        if (next == null) return;
        _frameCtrl.text = _frameFromPosition(next).toString();
      },
    );
  }

  @override
  void dispose() {
    _metadataSubscription.close();
    _exportFrameSelectionSubscription.close();
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

  int _frameFromPosition(Duration position) {
    final fps = ref.read(playerProvider).metadata?.fps ?? 30.0;
    return ((position.inMilliseconds / 1000.0) * fps).round();
  }

  void _selectFrameForExport() {
    final playerState = ref.read(playerProvider);
    if (playerState.metadata == null || playerState.duration <= Duration.zero) {
      return;
    }

    setState(() {
      _frameScope = FrameExportScope.single;
      _frameValidation = null;
    });
    ref
        .read(cropProvider.notifier)
        .setExportFrameSelection(playerState.position);
  }

  void _submitFrameExport() {
    final meta = ref.read(playerProvider).metadata;
    if (meta == null) return;
    final maxFrame = meta.frameCount > 0 ? meta.frameCount - 1 : 0;

    if (_frameScope == FrameExportScope.single) {
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
        isPng: _frameFormat == FrameImageFormat.png,
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
        isPng: _frameFormat == FrameImageFormat.png,
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
          // ── Title bar ────────────────────────────────────────────
          _PanelTitleBar(onClose: widget.onClose, palette: palette),
          Divider(height: 1, thickness: 1, color: palette.border),
          // ── Panel content ────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  PanelSection(
                    title: 'Crop',
                    icon: Icons.crop,
                    palette: palette,
                    child: CropSection(palette: palette),
                  ),
                  const SizedBox(height: 18),
                  PanelSection(
                    title: 'Frames',
                    icon: Icons.filter_frames_outlined,
                    palette: palette,
                    child: FrameExportSection(
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
                      onSelectFrame: _selectFrameForExport,
                      onExport: _submitFrameExport,
                      palette: palette,
                    ),
                  ),
                  const SizedBox(height: 18),
                  PanelSection(
                    title: 'Video',
                    icon: Icons.movie_creation_outlined,
                    palette: palette,
                    child: const VideoExportSection(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Title bar ────────────────────────────────────────────────────────────────

class _PanelTitleBar extends StatelessWidget {
  final VoidCallback onClose;
  final AppPalette palette;

  const _PanelTitleBar({required this.onClose, required this.palette});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      color: palette.panelElevated,
      child: Row(
        children: [
          const SizedBox(width: 12),
          Expanded(
            child: Row(
              children: [
                Icon(
                  Icons.ios_share_outlined,
                  size: 15,
                  color: palette.textMuted,
                ),
                const SizedBox(width: 8),
                Text(
                  'Crop & Export',
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
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
