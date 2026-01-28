import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/stroke.dart';
import '../providers/annotation_provider.dart';

/// Drawing tools panel
class DrawingToolsPanel extends ConsumerStatefulWidget {
  const DrawingToolsPanel({super.key});

  @override
  ConsumerState<DrawingToolsPanel> createState() => _DrawingToolsPanelState();
}

class _DrawingToolsPanelState extends ConsumerState<DrawingToolsPanel> {
  bool _showMoreTools = false;

  @override
  Widget build(BuildContext context) {
    final annotationState = ref.watch(annotationProvider);
    final annotationNotifier = ref.read(annotationProvider.notifier);

    return Container(
      width: 250,
      color: Colors.grey[850],
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            child: const Text(
              'Annotation Tools',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          const Divider(height: 1, color: Colors.white24),

          // Tool selection
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Tool',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                _buildToolButton(
                  icon: Icons.near_me,
                  label: 'Select',
                  tool: DrawingTool.select,
                  isSelected: annotationState.currentTool == DrawingTool.select,
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
                  isSelected: annotationState.currentTool == DrawingTool.eraser,
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
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey[800],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'More Tools',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                        ),
                        Icon(
                          _showMoreTools ? Icons.expand_less : Icons.expand_more,
                          color: Colors.white,
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
                    isSelected: annotationState.currentTool == DrawingTool.rectangle,
                    onTap: () => annotationNotifier.setTool(DrawingTool.rectangle),
                  ),
                  const SizedBox(height: 8),
                  _buildToolButton(
                    icon: Icons.circle_outlined,
                    label: 'Circle',
                    tool: DrawingTool.circle,
                    isSelected: annotationState.currentTool == DrawingTool.circle,
                    onTap: () => annotationNotifier.setTool(DrawingTool.circle),
                  ),
                  const SizedBox(height: 8),
                  _buildToolButton(
                    icon: Icons.horizontal_rule,
                    label: 'Line',
                    tool: DrawingTool.line,
                    isSelected: annotationState.currentTool == DrawingTool.line,
                    onTap: () => annotationNotifier.setTool(DrawingTool.line),
                  ),
                  const SizedBox(height: 8),
                  _buildToolButton(
                    icon: Icons.arrow_forward,
                    label: 'Arrow',
                    tool: DrawingTool.arrow,
                    isSelected: annotationState.currentTool == DrawingTool.arrow,
                    onTap: () => annotationNotifier.setTool(DrawingTool.arrow),
                  ),
                ],
              ],
            ),
          ),

          const Divider(height: 1, color: Colors.white24),

          // Color picker
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Color',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildColorButton(Colors.red, annotationState, annotationNotifier),
                    _buildColorButton(Colors.green, annotationState, annotationNotifier),
                    _buildColorButton(Colors.blue, annotationState, annotationNotifier),
                    _buildColorButton(Colors.yellow, annotationState, annotationNotifier),
                    _buildColorButton(Colors.orange, annotationState, annotationNotifier),
                    _buildColorButton(Colors.purple, annotationState, annotationNotifier),
                    _buildColorButton(Colors.white, annotationState, annotationNotifier),
                    _buildColorButton(Colors.black, annotationState, annotationNotifier),
                  ],
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: Colors.white24),

          // Stroke width
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Stroke Width',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Slider(
                        value: annotationState.currentStrokeWidth,
                        min: 1.0,
                        max: 10.0,
                        divisions: 18,
                        label: annotationState.currentStrokeWidth.toStringAsFixed(1),
                        onChanged: (value) {
                          annotationNotifier.setStrokeWidth(value);
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      annotationState.currentStrokeWidth.toStringAsFixed(1),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: Colors.white24),

          // Actions
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Actions',
                  style: TextStyle(
                    color: Colors.white70,
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
                  label: const Text('Undo'),
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
                  label: const Text('Redo'),
                  style: ElevatedButton.styleFrom(
                    alignment: Alignment.centerLeft,
                  ),
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: annotationState.allStrokes.isNotEmpty
                      ? () => _showClearConfirmation(context, annotationNotifier)
                      : null,
                  icon: const Icon(Icons.clear_all),
                  label: const Text('Clear All'),
                  style: ElevatedButton.styleFrom(
                    alignment: Alignment.centerLeft,
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: Colors.white24),

          // Status
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Strokes: ${annotationState.allStrokes.length}',
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                  ),
                ),
                if (annotationState.hasUnsavedChanges)
                  const Text(
                    'Unsaved changes',
                    style: TextStyle(
                      color: Colors.orange,
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
          color: isSelected ? Colors.red[700] : Colors.grey[800],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? Colors.red[400]! : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: onTap != null ? Colors.white : Colors.white38,
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                color: onTap != null ? Colors.white : Colors.white38,
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

    return InkWell(
      onTap: () => notifier.setColor(color),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? Colors.white : Colors.transparent,
            width: 3,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
      ),
    );
  }

  void _showClearConfirmation(BuildContext context, AnnotationNotifier notifier) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Annotations'),
        content: const Text(
          'Are you sure you want to clear all annotations? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              notifier.clearAll();
              Navigator.of(context).pop();
            },
            child: const Text(
              'Clear All',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
}
