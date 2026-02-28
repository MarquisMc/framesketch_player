import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/app_palette.dart';
import '../core/utils/timecode_formatter.dart';
import '../features/player/providers/player_provider.dart';
import '../features/loop/providers/loop_provider.dart';
import '../features/annotations/models/stroke.dart';
import '../features/annotations/providers/annotation_provider.dart';

/// Right-side inspector panel showing video properties and annotation info.
class InspectorPanel extends ConsumerWidget {
  const InspectorPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = AppPalette.of(context);
    final hasVideo = ref.watch(
      playerProvider.select((state) => state.metadata != null),
    );

    return Container(
      color: palette.panel,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SectionHeader(label: 'Inspector', palette: palette),

            if (!hasVideo)
              _EmptyHint(palette: palette)
            else ...[
              const _PlaybackSection(),

              _Divider(palette),

              const _VideoSection(),

              _Divider(palette),

              const _LoopSection(),

              _Divider(palette),

              const _AnnotationsSection(),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Sub-widgets ─────────────────────────────────────────────────────────────

class _PlaybackSection extends ConsumerWidget {
  const _PlaybackSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = AppPalette.of(context);
    final playback = ref.watch(
      playerProvider.select(
        (state) => (
          position: state.position,
          duration: state.duration,
          metadata: state.metadata,
        ),
      ),
    );

    final metadata = playback.metadata;
    if (metadata == null) return const SizedBox.shrink();

    final playerNotifier = ref.read(playerProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionLabel(label: 'Playback', palette: palette),
        _Row(
          label: 'Position',
          value: TimecodeFormatter.format(playback.position),
          palette: palette,
          mono: true,
        ),
        _Row(
          label: 'Duration',
          value: TimecodeFormatter.format(playback.duration),
          palette: palette,
          mono: true,
        ),
        _Row(
          label: 'Frame',
          value: '${playerNotifier.currentFrame} / ${metadata.frameCount}',
          palette: palette,
          mono: true,
        ),
        _Row(
          label: 'FPS',
          value: metadata.fps.toStringAsFixed(2),
          palette: palette,
          mono: true,
        ),
      ],
    );
  }
}

class _VideoSection extends ConsumerWidget {
  const _VideoSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = AppPalette.of(context);
    final video = ref.watch(
      playerProvider.select(
        (state) =>
            (metadata: state.metadata, sourceLabel: state.currentSourceLabel),
      ),
    );

    final metadata = video.metadata;
    if (metadata == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionLabel(label: 'Video', palette: palette),
        _Row(
          label: 'Size',
          value: '${metadata.width} × ${metadata.height}',
          palette: palette,
        ),
        _Row(label: 'Codec', value: metadata.codec, palette: palette),
        if (video.sourceLabel != null)
          _Row(
            label: 'Source',
            value: _shortenLabel(video.sourceLabel!),
            palette: palette,
            wrap: true,
          ),
      ],
    );
  }
}

class _LoopSection extends ConsumerWidget {
  const _LoopSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = AppPalette.of(context);
    final loop = ref.watch(
      loopProvider.select(
        (state) => (
          loopStartMs: state.loopStartMs,
          loopEndMs: state.loopEndMs,
          isSectionLoopActive: state.isSectionLoopActive,
          isFullVideoLoopActive: state.isFullVideoLoopActive,
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionLabel(label: 'Loop', palette: palette),
        _Row(
          label: 'In',
          value: loop.loopStartMs != null
              ? TimecodeFormatter.format(
                  Duration(milliseconds: loop.loopStartMs!),
                )
              : '—',
          palette: palette,
          mono: true,
        ),
        _Row(
          label: 'Out',
          value: loop.loopEndMs != null
              ? TimecodeFormatter.format(
                  Duration(milliseconds: loop.loopEndMs!),
                )
              : '—',
          palette: palette,
          mono: true,
        ),
        _Row(
          label: 'Active',
          value: loop.isSectionLoopActive
              ? 'A–B loop'
              : loop.isFullVideoLoopActive
              ? 'Full loop'
              : 'Off',
          palette: palette,
        ),
      ],
    );
  }
}

class _AnnotationsSection extends ConsumerWidget {
  const _AnnotationsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = AppPalette.of(context);
    final currentTool = ref.watch(
      annotationProvider.select((state) => state.currentTool),
    );
    final keyframeCount = ref.watch(
      annotationKeyframeTimesProvider.select((times) => times.length),
    );
    final activeKeyframeMs = ref.watch(activeAnnotationKeyframeProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionLabel(label: 'Annotations', palette: palette),
        _Row(label: 'Tool', value: _toolName(currentTool), palette: palette),
        _Row(label: 'Keyframes', value: '$keyframeCount', palette: palette),
        if (activeKeyframeMs != null)
          _Row(
            label: 'Active KF',
            value: TimecodeFormatter.format(
              Duration(milliseconds: activeKeyframeMs),
            ),
            palette: palette,
            mono: true,
          ),
      ],
    );
  }
}

String _shortenLabel(String label) {
  final s = label.replaceAll('\\', '/').split('/');
  if (s.length > 1) return s.last;
  return label;
}

String _toolName(DrawingTool tool) {
  return switch (tool) {
    DrawingTool.select => 'Select',
    DrawingTool.pen => 'Pen',
    DrawingTool.eraser => 'Eraser',
    DrawingTool.rectangle => 'Rectangle',
    DrawingTool.filledSquare => 'Filled Rect',
    DrawingTool.circle => 'Circle',
    DrawingTool.filledCircle => 'Filled Circle',
    DrawingTool.line => 'Line',
    DrawingTool.arrow => 'Arrow',
    DrawingTool.text => 'Text',
  };
}

class _SectionHeader extends StatelessWidget {
  final String label;
  final AppPalette palette;
  const _SectionHeader({required this.label, required this.palette});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: Text(
        label,
        style: TextStyle(
          color: palette.textPrimary,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  final AppPalette palette;
  const _SectionLabel({required this.label, required this.palette});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: palette.textMuted,
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  final AppPalette palette;
  final bool mono;
  final bool wrap;

  const _Row({
    required this.label,
    required this.value,
    required this.palette,
    this.mono = false,
    this.wrap = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: TextStyle(color: palette.textMuted, fontSize: 11),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: palette.textSecondary,
                fontSize: 11,
                fontFamily: mono ? 'monospace' : null,
              ),
              softWrap: wrap,
              overflow: wrap ? TextOverflow.visible : TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  final AppPalette palette;
  const _Divider(this.palette);

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 16,
      thickness: 1,
      color: palette.border,
      indent: 12,
      endIndent: 12,
    );
  }
}

class _EmptyHint extends StatelessWidget {
  final AppPalette palette;
  const _EmptyHint({required this.palette});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Text(
        'No video loaded.\nOpen a video to see details.',
        style: TextStyle(color: palette.textDisabled, fontSize: 11),
        textAlign: TextAlign.center,
      ),
    );
  }
}
