import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/app_palette.dart';
import '../features/annotations/models/stroke.dart';
import '../features/annotations/providers/annotation_provider.dart';

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
    _ToolEntry(DrawingTool.select, Icons.near_me_outlined, 'Select (V)'),
    _ToolEntry(DrawingTool.pen, Icons.edit_outlined, 'Pen (P)'),
    _ToolEntry(
      DrawingTool.eraser,
      Icons.cleaning_services_outlined,
      'Eraser (E)',
    ),
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
    final strokeWidth = ref.watch(
      annotationProvider.select((s) => s.currentStrokeWidth),
    );
    final canUndo = ref.watch(
      annotationProvider.select((s) => s.allStrokes.isNotEmpty),
    );
    final canRedo = ref.watch(
      annotationProvider.select((s) => s.undoStack.isNotEmpty),
    );
    final notifier = ref.read(annotationProvider.notifier);

    return Container(
      color: palette.panel,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Tool buttons
          for (var i = 0; i < _entries.length; i++) ...[
            if (i > 0) const SizedBox(width: 2),
            _StripButton(
              icon: _entries[i].icon,
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

          // Stroke width
          Tooltip(
            message: 'Stroke Width: ${strokeWidth.toStringAsFixed(1)}',
            waitDuration: const Duration(milliseconds: 500),
            child: Row(
              children: [
                Icon(Icons.line_weight, size: 16, color: palette.textSecondary),
                SizedBox(
                  width: 100,
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 2,
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 6,
                      ),
                      overlayShape: const RoundSliderOverlayShape(
                        overlayRadius: 12,
                      ),
                    ),
                    child: Slider(
                      value: strokeWidth,
                      min: 1.0,
                      max: 10.0,
                      divisions: 18,
                      onChanged: (v) => notifier.setStrokeWidth(v),
                    ),
                  ),
                ),
                Text(
                  strokeWidth.toStringAsFixed(1),
                  style: TextStyle(fontSize: 11, color: palette.textSecondary),
                ),
              ],
            ),
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
  final IconData icon;
  final String tooltip;
  const _ToolEntry(this.tool, this.icon, this.tooltip);
}

class _StripButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool selected;
  final VoidCallback onTap;

  const _StripButton({
    required this.icon,
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
          child: Icon(
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

/// Single-swatch button that opens a preset color grid in a dialog.
/// Used by both the horizontal tools strip and the annotation tools panel
/// so the picker looks and behaves identically in both places.
class ColorPickerButton extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Tooltip(
      message: 'Stroke Color',
      waitDuration: const Duration(milliseconds: 500),
      child: InkWell(
        onTap: () => _showColorPicker(context, palette),
        borderRadius: BorderRadius.circular(6),
        child: Container(
          width: size + 8,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: palette.border, width: 1),
          ),
          child: Container(
            width: size * 0.625,
            height: size * 0.625,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: color.computeLuminance() > 0.5
                    ? Colors.black.withValues(alpha: 0.3)
                    : Colors.white.withValues(alpha: 0.3),
                width: 0.5,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showColorPicker(BuildContext context, AppPalette palette) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Pick Stroke Color'),
          content: SizedBox(
            width: 280,
            child: GridView.count(
              crossAxisCount: 4,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              shrinkWrap: true,
              children: presets.map((c) {
                final isSelected = c.toARGB32() == color.toARGB32();
                return GestureDetector(
                  onTap: () {
                    onColorChanged(c);
                    Navigator.of(dialogContext).pop();
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: isSelected
                          ? Border.all(color: palette.accentBright, width: 3)
                          : Border.all(
                              color: c.computeLuminance() < 0.08
                                  ? palette.border
                                  : Colors.transparent,
                              width: 1,
                            ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.22),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Done'),
            ),
          ],
        );
      },
    );
  }
}
