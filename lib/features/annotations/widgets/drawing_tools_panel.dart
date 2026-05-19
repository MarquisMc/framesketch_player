import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_palette.dart';
import '../models/stroke.dart';
import '../providers/annotation_provider.dart';
import 'annotation_size_control.dart';
import '../../player/providers/player_provider.dart';

/// Drawing tools panel
class DrawingToolsPanel extends ConsumerStatefulWidget {
  const DrawingToolsPanel({super.key});

  @override
  ConsumerState<DrawingToolsPanel> createState() => _DrawingToolsPanelState();
}

class _DrawingToolsPanelState extends ConsumerState<DrawingToolsPanel> {
  bool _showMoreTools = false;
  AppPalette get _palette => AppPalette.of(context);

  @override
  Widget build(BuildContext context) {
    final annotationState = ref.watch(annotationProvider);
    final annotationNotifier = ref.read(annotationProvider.notifier);
    final keyframeMode = ref.watch(annotationKeyframeModeProvider);
    final keyframeTimesMs = ref.watch(annotationKeyframeTimesProvider);
    final activeKeyframeMs = ref.watch(activeAnnotationKeyframeProvider);
    final drawingTargetKeyframeMs = ref.watch(
      drawingTargetAnnotationKeyframeProvider,
    );
    final activeSizingTool = ref.watch(activeAnnotationSizingToolProvider);
    final activeStrokeWidth = ref.watch(activeAnnotationStrokeWidthProvider);
    final activeFontSize = ref.watch(activeAnnotationFontSizeProvider);
    final canCreateManualKeyframe = ref.watch(canCreateManualKeyframeProvider);
    final fps =
        ref.watch(playerProvider.select((state) => state.metadata?.fps)) ??
        30.0;
    final showTextSizeControl = activeSizingTool == DrawingTool.text;

    return Container(
      width: 250,
      color: _palette.panel,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Annotation Tools',
                style: TextStyle(
                  color: _palette.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            Divider(height: 1, color: _palette.border),

            // Keyframe mode
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Keyframe Mode',
                    style: TextStyle(
                      color: _palette.textSecondary,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _buildKeyframeModeButton(
                        label: 'Automatic',
                        isSelected:
                            keyframeMode == KeyframeCreationMode.automatic,
                        onTap: () => annotationNotifier.setKeyframeCreationMode(
                          KeyframeCreationMode.automatic,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _buildKeyframeModeButton(
                        label: 'Manual',
                        isSelected: keyframeMode == KeyframeCreationMode.manual,
                        onTap: () => annotationNotifier.setKeyframeCreationMode(
                          KeyframeCreationMode.manual,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    keyframeMode == KeyframeCreationMode.automatic
                        ? 'Drawing on a frame automatically creates/uses that frame keyframe.'
                        : 'Drawing edits the active keyframe. Use New Frame to create an empty keyframe at the playhead.',
                    style: TextStyle(
                      color: _palette.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  if (keyframeMode == KeyframeCreationMode.manual) ...[
                    const SizedBox(height: 10),
                    ElevatedButton.icon(
                      onPressed: canCreateManualKeyframe
                          ? () => annotationNotifier
                                .createManualKeyframeAtCurrentFrame()
                          : null,
                      icon: const Icon(Icons.add_circle_outline),
                      label: Text('New Frame'),
                      style: ElevatedButton.styleFrom(
                        alignment: Alignment.centerLeft,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      canCreateManualKeyframe
                          ? 'Creates a new empty keyframe at the current frame.'
                          : keyframeTimesMs.isEmpty
                          ? 'Create your first annotation to establish an initial keyframe.'
                          : 'A keyframe already exists at the current frame.',
                      style: TextStyle(color: _palette.textMuted, fontSize: 11),
                    ),
                  ],
                ],
              ),
            ),

            Divider(height: 1, color: _palette.border),

            // Tool selection
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tool',
                    style: TextStyle(
                      color: _palette.textSecondary,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildToolButton(
                    icon: Icons.near_me,
                    label: 'Select',
                    tool: DrawingTool.select,
                    isSelected:
                        annotationState.currentTool == DrawingTool.select,
                    onTap: () => annotationNotifier.setTool(DrawingTool.select),
                  ),
                  const SizedBox(height: 8),
                  _buildToolButton(
                    icon: Icons.edit,
                    label: 'Pen',
                    tool: DrawingTool.pen,
                    isSelected: annotationState.currentTool == DrawingTool.pen,
                    onTap: () => annotationNotifier.setTool(DrawingTool.pen),
                  ),
                  const SizedBox(height: 8),
                  _buildToolButton(
                    icon: Icons.auto_fix_high,
                    label: 'Eraser',
                    tool: DrawingTool.eraser,
                    isSelected:
                        annotationState.currentTool == DrawingTool.eraser,
                    onTap: () => annotationNotifier.setTool(DrawingTool.eraser),
                  ),
                  const SizedBox(height: 12),
                  // More Tools expandable section
                  InkWell(
                    onTap: () {
                      setState(() {
                        _showMoreTools = !_showMoreTools;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 12,
                      ),
                      decoration: BoxDecoration(
                        color: _palette.panelElevated,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'More Tools',
                            style: TextStyle(
                              color: _palette.textPrimary,
                              fontSize: 14,
                            ),
                          ),
                          Icon(
                            _showMoreTools
                                ? Icons.expand_less
                                : Icons.expand_more,
                            color: _palette.textSecondary,
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_showMoreTools) ...[
                    const SizedBox(height: 8),
                    _buildToolButton(
                      icon: Icons.crop_square,
                      label: 'Rectangle',
                      tool: DrawingTool.rectangle,
                      isSelected:
                          annotationState.currentTool == DrawingTool.rectangle,
                      onTap: () =>
                          annotationNotifier.setTool(DrawingTool.rectangle),
                    ),
                    const SizedBox(height: 8),
                    _buildToolButton(
                      icon: Icons.square,
                      label: 'Filled Square',
                      tool: DrawingTool.filledSquare,
                      isSelected:
                          annotationState.currentTool ==
                          DrawingTool.filledSquare,
                      onTap: () =>
                          annotationNotifier.setTool(DrawingTool.filledSquare),
                    ),
                    const SizedBox(height: 8),
                    _buildToolButton(
                      icon: Icons.circle_outlined,
                      label: 'Circle',
                      tool: DrawingTool.circle,
                      isSelected:
                          annotationState.currentTool == DrawingTool.circle,
                      onTap: () =>
                          annotationNotifier.setTool(DrawingTool.circle),
                    ),
                    const SizedBox(height: 8),
                    _buildToolButton(
                      icon: Icons.circle,
                      label: 'Filled Circle',
                      tool: DrawingTool.filledCircle,
                      isSelected:
                          annotationState.currentTool ==
                          DrawingTool.filledCircle,
                      onTap: () =>
                          annotationNotifier.setTool(DrawingTool.filledCircle),
                    ),
                    const SizedBox(height: 8),
                    _buildToolButton(
                      icon: Icons.horizontal_rule,
                      label: 'Line',
                      tool: DrawingTool.line,
                      isSelected:
                          annotationState.currentTool == DrawingTool.line,
                      onTap: () => annotationNotifier.setTool(DrawingTool.line),
                    ),
                    const SizedBox(height: 8),
                    _buildToolButton(
                      icon: Icons.arrow_forward,
                      label: 'Arrow',
                      tool: DrawingTool.arrow,
                      isSelected:
                          annotationState.currentTool == DrawingTool.arrow,
                      onTap: () =>
                          annotationNotifier.setTool(DrawingTool.arrow),
                    ),
                    const SizedBox(height: 8),
                    _buildToolButton(
                      icon: Icons.text_fields,
                      label: 'Text',
                      tool: DrawingTool.text,
                      isSelected:
                          annotationState.currentTool == DrawingTool.text,
                      onTap: () => annotationNotifier.setTool(DrawingTool.text),
                    ),
                  ],
                ],
              ),
            ),

            Divider(height: 1, color: _palette.border),

            // Color picker
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Color',
                    style: TextStyle(
                      color: _palette.textSecondary,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ..._palette.annotationSwatches.map(
                        (color) => _buildColorButton(
                          color,
                          annotationState,
                          annotationNotifier,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            Divider(height: 1, color: _palette.border),

            // Adaptive sizing control
            Padding(
              padding: const EdgeInsets.all(16),
              child: AnnotationSizeControl(
                label: showTextSizeControl ? 'Text Size' : 'Stroke Width',
                value: showTextSizeControl ? activeFontSize : activeStrokeWidth,
                min: showTextSizeControl ? 12.0 : 1.0,
                max: showTextSizeControl ? 100.0 : 10.0,
                divisions: showTextSizeControl ? 44 : 18,
                isTextSize: showTextSizeControl,
                onChanged: showTextSizeControl
                    ? annotationNotifier.setFontSize
                    : annotationNotifier.setStrokeWidth,
              ),
            ),

            Divider(height: 1, color: _palette.border),

            // Actions
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Actions',
                    style: TextStyle(
                      color: _palette.textSecondary,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: annotationNotifier.canUndo
                        ? () => annotationNotifier.undo()
                        : null,
                    icon: const Icon(Icons.undo),
                    label: Text('Undo'),
                    style: ElevatedButton.styleFrom(
                      alignment: Alignment.centerLeft,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: annotationNotifier.canRedo
                        ? () => annotationNotifier.redo()
                        : null,
                    icon: const Icon(Icons.redo),
                    label: Text('Redo'),
                    style: ElevatedButton.styleFrom(
                      alignment: Alignment.centerLeft,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: annotationNotifier.canDuplicateSelectedStroke
                        ? annotationNotifier.duplicateSelectedStroke
                        : null,
                    icon: const Icon(Icons.control_point_duplicate),
                    label: Text('Duplicate Selected'),
                    style: ElevatedButton.styleFrom(
                      alignment: Alignment.centerLeft,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: annotationState.allStrokes.isNotEmpty
                        ? () => _showClearConfirmation(
                            context,
                            annotationNotifier,
                          )
                        : null,
                    icon: const Icon(Icons.clear_all),
                    label: Text('Clear All'),
                    style: ElevatedButton.styleFrom(
                      alignment: Alignment.centerLeft,
                    ),
                  ),
                ],
              ),
            ),

            Divider(height: 1, color: _palette.border),

            // Status
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Strokes: ${annotationState.allStrokes.length}',
                    style: TextStyle(color: _palette.textMuted, fontSize: 12),
                  ),
                  Text(
                    'Keyframes: ${keyframeTimesMs.length}',
                    style: TextStyle(color: _palette.textMuted, fontSize: 12),
                  ),
                  if (activeKeyframeMs != null)
                    Text(
                      'Active frame: ${((activeKeyframeMs / 1000.0) * fps).round()}',
                      style: TextStyle(
                        color: _palette.accentBright,
                        fontSize: 12,
                      ),
                    ),
                  Text(
                    'Draw target: ${((drawingTargetKeyframeMs / 1000.0) * fps).round()}',
                    style: TextStyle(
                      color: keyframeMode == KeyframeCreationMode.manual
                          ? _palette.loopB
                          : _palette.textMuted,
                      fontSize: 12,
                    ),
                  ),
                  if (annotationState.hasUnsavedChanges)
                    Text(
                      'Unsaved changes',
                      style: TextStyle(
                        color: _palette.warning,
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKeyframeModeButton({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? _palette.panelElevated : _palette.panel,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? _palette.accentBright : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _palette.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildToolButton({
    required IconData icon,
    required String label,
    required DrawingTool tool,
    required bool isSelected,
    required VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? _palette.accentSoft : _palette.panelElevated,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? _palette.accent : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: onTap != null
                  ? _palette.textPrimary
                  : _palette.textDisabled,
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                color: onTap != null
                    ? _palette.textPrimary
                    : _palette.textDisabled,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildColorButton(
    Color color,
    AnnotationState state,
    AnnotationNotifier notifier,
  ) {
    final isSelected = state.currentColor == color;
    final isDarkSwatch = color.computeLuminance() < 0.08;
    final isLightSwatch = color.computeLuminance() > 0.88;
    final borderColor = isSelected
        ? (isLightSwatch ? _palette.background : _palette.textPrimary)
        : (isDarkSwatch ? _palette.border : Colors.transparent);
    final borderWidth = isSelected ? 3.0 : (isDarkSwatch ? 1.5 : 0.0);

    return InkWell(
      onTap: () => notifier.setColor(color),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: borderColor, width: borderWidth),
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
  }

  void _showClearConfirmation(
    BuildContext context,
    AnnotationNotifier notifier,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Clear All Annotations'),
        content: Text(
          'Are you sure you want to clear all annotations? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              notifier.clearAll();
              Navigator.of(context).pop();
            },
            child: Text('Clear All', style: TextStyle(color: _palette.error)),
          ),
        ],
      ),
    );
  }
}
