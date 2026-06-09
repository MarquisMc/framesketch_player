import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/app_palette.dart';
import '../features/annotations/models/stroke.dart';
import '../features/annotations/providers/annotation_provider.dart';
import '../features/annotations/widgets/annotation_size_control.dart';
import '../features/annotations/widgets/eraser_tool_icon.dart';

/// Preset colors matching the annotation tools panel.
const _presetColors = <Color>[
  Color(0xFF58D3C4), // Default (Cyan)
  Color(0xFF11B9D6), // Blue
  Color(0xFF1FA1D6), // Dark Blue
  Color(0xFF22C55E), // Green
  Color(0xFFEAB308), // Yellow
  Color(0xFFF97316), // Orange
  Color(0xFFEF4444), // Red
  Color(0xFFEC4899), // Pink
  Color(0xFF8B5CF6), // Purple
  Color(0xFF000000), // Black
  Color(0xFFFFFFFF), // White
];

/// Horizontal row of annotation tool icons, intended to drop down from the
/// top toolbar when the left tools panel is hidden.
class HorizontalToolsStrip extends ConsumerWidget {
  const HorizontalToolsStrip({super.key});

  static const _entries = <_ToolEntry>[
    _ToolEntry(DrawingTool.select, Icons.near_me, 'Select (V)'),
    _ToolEntry(DrawingTool.pen, Icons.edit, 'Pen (P)'),
    _ToolEntry(DrawingTool.eraser, null, 'Eraser (E)'),
    _ToolEntry(DrawingTool.rectangle, Icons.crop_square, 'Rectangle (R)'),
    _ToolEntry(DrawingTool.filledSquare, Icons.square, 'Filled Rectangle'),
    _ToolEntry(DrawingTool.circle, Icons.circle_outlined, 'Circle (Shift+O)'),
    _ToolEntry(DrawingTool.filledCircle, Icons.circle, 'Filled Circle'),
    _ToolEntry(DrawingTool.line, Icons.remove, 'Line (Shift+L)'),
    _ToolEntry(DrawingTool.arrow, Icons.arrow_right_alt, 'Arrow (A)'),
    _ToolEntry(DrawingTool.text, Icons.text_fields, 'Text (T)'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = AppPalette.of(context);
    final currentTool = ref.watch(
      annotationProvider.select((s) => s.currentTool),
    );
    final currentColor = ref.watch(
      annotationProvider.select((s) => s.currentColor),
    );
    final keyframeMode = ref.watch(
      annotationProvider.select((s) => s.keyframeCreationMode),
    );
    final activeSizingTool = ref.watch(activeAnnotationSizingToolProvider);
    final strokeWidth = ref.watch(activeAnnotationStrokeWidthProvider);
    final fontSize = ref.watch(activeAnnotationFontSizeProvider);
    final canUndo = ref.watch(
      annotationProvider.select((s) => s.allStrokes.isNotEmpty),
    );
    final canRedo = ref.watch(
      annotationProvider.select((s) => s.undoStack.isNotEmpty),
    );
    final notifier = ref.read(annotationProvider.notifier);
    final showTextSizeControl = activeSizingTool == DrawingTool.text;

    return Container(
      color: palette.panel,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _KeyframeModeMenu(
            mode: keyframeMode,
            onChanged: notifier.setKeyframeCreationMode,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: SizedBox(
              height: 28,
              child: VerticalDivider(width: 1, color: palette.border),
            ),
          ),
          // Tool buttons
          for (var i = 0; i < _entries.length; i++) ...[
            if (i > 0) const SizedBox(width: 2),
            _StripButton(
              icon: _entries[i].icon,
              customIcon: _entries[i].tool == DrawingTool.eraser
                  ? EraserToolIcon(
                      color: currentTool == DrawingTool.eraser
                          ? palette.accentBright
                          : palette.textSecondary,
                    )
                  : null,
              tooltip: _entries[i].tooltip,
              selected: currentTool == _entries[i].tool,
              onTap: () => notifier.setTool(_entries[i].tool),
            ),
          ],
          const SizedBox(width: 6),
          ColorPickerButton(
            color: currentColor,
            presets: _presetColors,
            onColorChanged: (color) => notifier.setColor(color),
          ),

          // Divider
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: SizedBox(
              height: 28,
              child: VerticalDivider(width: 1, color: palette.border),
            ),
          ),

          // Adaptive sizing control
          Row(
            children: [
              Icon(
                showTextSizeControl ? Icons.text_fields : Icons.line_weight,
                size: 16,
                color: palette.textSecondary,
              ),
              const SizedBox(width: 6),
              AnnotationSizeControl(
                label: showTextSizeControl ? 'Text Size' : 'Stroke Width',
                value: showTextSizeControl ? fontSize : strokeWidth,
                min: showTextSizeControl ? 12.0 : 1.0,
                max: showTextSizeControl ? 100.0 : 10.0,
                divisions: showTextSizeControl ? 44 : 18,
                isTextSize: showTextSizeControl,
                compact: true,
                onChanged: showTextSizeControl
                    ? notifier.setFontSize
                    : notifier.setStrokeWidth,
              ),
            ],
          ),

          // Divider
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: SizedBox(
              height: 28,
              child: VerticalDivider(width: 1, color: palette.border),
            ),
          ),

          // Actions
          _StripIconButton(
            icon: Icons.undo,
            tooltip: 'Undo',
            enabled: canUndo,
            onTap: () => notifier.undo(),
          ),
          const SizedBox(width: 2),
          _StripIconButton(
            icon: Icons.redo,
            tooltip: 'Redo',
            enabled: canRedo,
            onTap: () => notifier.redo(),
          ),
          const SizedBox(width: 2),
          _StripIconButton(
            icon: Icons.clear_all,
            tooltip: 'Clear All',
            enabled: canUndo,
            onTap: () => _showClearConfirm(context, notifier, palette),
          ),
        ],
      ),
    );
  }

  void _showClearConfirm(
    BuildContext context,
    AnnotationNotifier notifier,
    AppPalette palette,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear All Annotations'),
        content: const Text(
          'Are you sure you want to clear all annotations? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              notifier.clearAll();
              Navigator.of(ctx).pop();
            },
            child: Text('Clear All', style: TextStyle(color: palette.error)),
          ),
        ],
      ),
    );
  }
}

class _ToolEntry {
  final DrawingTool tool;
  final IconData? icon;
  final String tooltip;
  const _ToolEntry(this.tool, this.icon, this.tooltip);
}

class _KeyframeModeMenu extends StatelessWidget {
  final KeyframeCreationMode mode;
  final ValueChanged<KeyframeCreationMode> onChanged;

  const _KeyframeModeMenu({required this.mode, required this.onChanged});

  static const _modes = <KeyframeCreationMode>[
    KeyframeCreationMode.automatic,
    KeyframeCreationMode.manual,
    KeyframeCreationMode.whiteboard,
  ];

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);

    return PopupMenuButton<KeyframeCreationMode>(
      tooltip: 'Keyframe Mode (M)',
      initialValue: mode,
      onSelected: onChanged,
      color: palette.panelElevated,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      itemBuilder: (context) => _modes
          .map((entry) {
            final selected = entry == mode;
            return PopupMenuItem<KeyframeCreationMode>(
              value: entry,
              child: Row(
                children: [
                  SizedBox(
                    width: 18,
                    child: selected
                        ? Icon(
                            Icons.check,
                            size: 16,
                            color: palette.accentBright,
                          )
                        : null,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _keyframeModeLabel(entry),
                    style: TextStyle(color: palette.textPrimary, fontSize: 13),
                  ),
                ],
              ),
            );
          })
          .toList(growable: false),
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: palette.accentSoft,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: palette.accent, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _keyframeModeLabel(mode),
              style: TextStyle(
                color: palette.accentBright,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 6),
            Icon(Icons.expand_more, size: 16, color: palette.accentBright),
          ],
        ),
      ),
    );
  }

  static String _keyframeModeLabel(KeyframeCreationMode mode) {
    return switch (mode) {
      KeyframeCreationMode.automatic => 'Automatic',
      KeyframeCreationMode.manual => 'Manual',
      KeyframeCreationMode.whiteboard => 'Whiteboard',
    };
  }
}

class _StripButton extends StatelessWidget {
  final IconData? icon;
  final Widget? customIcon;
  final String tooltip;
  final bool selected;
  final VoidCallback onTap;

  const _StripButton({
    this.icon,
    this.customIcon,
    required this.tooltip,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 500),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          width: 36,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? palette.accentSoft : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            border: selected
                ? Border.all(color: palette.accent, width: 1)
                : null,
          ),
          child:
              customIcon ??
              Icon(
                icon,
                size: 18,
                color: selected ? palette.accentBright : palette.textSecondary,
              ),
        ),
      ),
    );
  }
}

class _StripIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool enabled;
  final VoidCallback onTap;

  const _StripIconButton({
    required this.icon,
    required this.tooltip,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 500),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          width: 36,
          height: 32,
          alignment: Alignment.center,
          child: Icon(
            icon,
            size: 18,
            color: enabled ? palette.textSecondary : palette.textDisabled,
          ),
        ),
      ),
    );
  }
}

/// Inline swatch button that expands into a horizontal preset color strip.
class ColorPickerButton extends StatefulWidget {
  final Color color;
  final List<Color> presets;
  final ValueChanged<Color> onColorChanged;
  final double size;

  const ColorPickerButton({
    super.key,
    required this.color,
    required this.presets,
    required this.onColorChanged,
    this.size = 32,
  });

  @override
  State<ColorPickerButton> createState() => _ColorPickerButtonState();
}

class _ColorPickerButtonState extends State<ColorPickerButton> {
  bool _isOpen = false;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final swatchButtonWidth = widget.size + 8;
    final trayWidth = (widget.presets.length * 28.0) + 34.0;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Tooltip(
          message: _isOpen ? 'Close Colors' : 'Stroke Color',
          waitDuration: const Duration(milliseconds: 500),
          child: InkWell(
            onTap: () => setState(() => _isOpen = !_isOpen),
            borderRadius: BorderRadius.circular(6),
            child: Container(
              width: swatchButtonWidth,
              height: widget.size,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: _isOpen ? palette.accent : palette.border,
                  width: 1,
                ),
              ),
              child: _ColorSwatch(
                color: widget.color,
                selected: false,
                size: widget.size * 0.625,
                borderRadius: 4,
              ),
            ),
          ),
        ),
        ClipRect(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            width: _isOpen ? trayWidth : 0,
            height: widget.size,
            child: Align(
              alignment: Alignment.centerLeft,
              widthFactor: 1,
              child: Padding(
                padding: const EdgeInsets.only(left: 6),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: palette.panelElevated,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: palette.border),
                  ),
                  child: SizedBox(
                    height: widget.size,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(width: 5),
                          for (final preset in widget.presets) ...[
                            _InlineColorChoice(
                              color: preset,
                              selected:
                                  preset.toARGB32() == widget.color.toARGB32(),
                              onTap: () => widget.onColorChanged(preset),
                            ),
                            const SizedBox(width: 4),
                          ],
                          Tooltip(
                            message: 'Close Colors',
                            waitDuration: const Duration(milliseconds: 500),
                            child: InkWell(
                              onTap: () => setState(() => _isOpen = false),
                              borderRadius: BorderRadius.circular(4),
                              child: SizedBox(
                                width: 26,
                                height: widget.size,
                                child: Icon(
                                  Icons.close,
                                  size: 16,
                                  color: palette.textSecondary,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 2),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _InlineColorChoice extends StatelessWidget {
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _InlineColorChoice({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '#${color.toARGB32().toRadixString(16).padLeft(8, '0')}',
      waitDuration: const Duration(milliseconds: 500),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: SizedBox(
          width: 24,
          height: 28,
          child: Center(
            child: _ColorSwatch(
              color: color,
              selected: selected,
              size: 18,
              borderRadius: 999,
            ),
          ),
        ),
      ),
    );
  }
}

class _ColorSwatch extends StatelessWidget {
  final Color color;
  final bool selected;
  final double size;
  final double borderRadius;

  const _ColorSwatch({
    required this.color,
    required this.selected,
    required this.size,
    required this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final borderColor = selected
        ? palette.accentBright
        : (color.computeLuminance() > 0.5
              ? Colors.black.withValues(alpha: 0.3)
              : Colors.white.withValues(alpha: 0.3));
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: borderColor, width: selected ? 2 : 0.5),
        boxShadow: [
          if (selected)
            BoxShadow(
              color: palette.accentBright.withValues(alpha: 0.26),
              blurRadius: 5,
            ),
        ],
      ),
    );
  }
}
