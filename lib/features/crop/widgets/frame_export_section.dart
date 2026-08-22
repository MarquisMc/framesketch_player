import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_palette.dart';
import '../../player/providers/player_provider.dart';
import 'crop_panel_common.dart';

/// Whether a single frame or a frame range is exported.
enum FrameExportScope { single, range }

/// Image format for exported frames.
enum FrameImageFormat { png, jpg }

/// "Frames" section of the crop & export panel: single/range scope,
/// PNG/JPG format, frame number inputs, and the export action.
class FrameExportSection extends ConsumerWidget {
  final FrameExportScope scope;
  final FrameImageFormat format;
  final TextEditingController frameCtrl;
  final TextEditingController startFrameCtrl;
  final TextEditingController endFrameCtrl;
  final TextEditingController stepCtrl;
  final String? validation;
  final void Function(FrameExportScope) onScopeChanged;
  final void Function(FrameImageFormat) onFormatChanged;
  final VoidCallback onClearValidation;
  final VoidCallback onSelectFrame;
  final VoidCallback onExport;
  final AppPalette palette;

  const FrameExportSection({
    super.key,
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
    required this.onSelectFrame,
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

        if (scope == FrameExportScope.single)
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

        SizedBox(
          height: 32,
          child: OutlinedButton.icon(
            icon: const Icon(Icons.place_outlined, size: 14),
            label: const Text('Select Frame', style: TextStyle(fontSize: 12)),
            onPressed: onSelectFrame,
            style: OutlinedButton.styleFrom(
              foregroundColor: palette.accentBright,
              side: BorderSide(color: palette.border),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ),
        ),

        const SizedBox(height: 8),

        PanelExportButton(
          label: scope == FrameExportScope.single
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

class _ScopeToggle extends StatelessWidget {
  final FrameExportScope current;
  final void Function(FrameExportScope) onChanged;
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
            isSelected: current == FrameExportScope.single,
            onTap: () => onChanged(FrameExportScope.single),
            palette: palette,
          ),
          _ScopeOption(
            label: 'Range',
            isSelected: current == FrameExportScope.range,
            onTap: () => onChanged(FrameExportScope.range),
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
  final FrameImageFormat current;
  final void Function(FrameImageFormat) onChanged;
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
            isSelected: current == FrameImageFormat.png,
            onTap: () => onChanged(FrameImageFormat.png),
            palette: palette,
          ),
          Container(width: 1, height: 20, color: palette.border),
          _FmtOption(
            label: 'JPG',
            isSelected: current == FrameImageFormat.jpg,
            onTap: () => onChanged(FrameImageFormat.jpg),
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
