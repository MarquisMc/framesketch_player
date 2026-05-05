import 'package:flutter/material.dart';

import '../../../core/models/video_metadata.dart';
import '../../../core/services/video_export_models.dart';

enum ExportMode { frame, frames, video, annotationFile }

enum FrameExportFormat { png, jpg }

enum AnnotationExportFormat { framesketch, json }

class ExportRequest {
  final ExportMode mode;
  final String suggestedBaseName;
  final int startFrame;
  final int endFrame;
  final int frameStep;
  final FrameExportFormat frameFormat;
  final AnnotationExportFormat annotationFormat;
  final VideoExportPreset videoPreset;
  final ({int x, int y, int width, int height})? cropPixels;

  const ExportRequest({
    required this.mode,
    required this.suggestedBaseName,
    required this.startFrame,
    required this.endFrame,
    this.frameStep = 1,
    this.frameFormat = FrameExportFormat.png,
    this.annotationFormat = AnnotationExportFormat.framesketch,
    this.videoPreset = VideoExportPreset.compatible,
    this.cropPixels,
  });

  String get frameExtension =>
      frameFormat == FrameExportFormat.jpg ? 'jpg' : 'png';

  String get annotationExtension =>
      annotationFormat == AnnotationExportFormat.json ? 'json' : 'framesketch';
}

class ExportOptionsDialog extends StatefulWidget {
  final int initialFrame;
  final VideoMetadata metadata;
  final String suggestedBaseName;
  final Duration? exportStart;
  final Duration? exportEnd;
  final bool isLocalSource;

  const ExportOptionsDialog({
    super.key,
    required this.initialFrame,
    required this.metadata,
    required this.suggestedBaseName,
    required this.exportStart,
    required this.exportEnd,
    required this.isLocalSource,
  });

  @override
  State<ExportOptionsDialog> createState() => _ExportOptionsDialogState();
}

class _ExportOptionsDialogState extends State<ExportOptionsDialog> {
  late ExportMode _mode;
  late FrameExportFormat _frameFormat;
  late AnnotationExportFormat _annotationFormat;
  late VideoExportPreset _videoPreset;
  late final TextEditingController _frameController;
  late final TextEditingController _startFrameController;
  late final TextEditingController _endFrameController;
  late final TextEditingController _stepController;
  String? _validationMessage;

  @override
  void initState() {
    super.initState();
    _mode = widget.isLocalSource ? ExportMode.video : ExportMode.frame;
    _frameFormat = FrameExportFormat.png;
    _annotationFormat = AnnotationExportFormat.framesketch;
    _videoPreset = VideoExportPreset.compatible;

    final startFrame = widget.exportStart == null
        ? 0
        : _frameFromDuration(widget.exportStart!);
    final endFrame = widget.exportEnd == null
        ? _maxFrame
        : (_frameFromDuration(widget.exportEnd!) - 1).clamp(0, _maxFrame);

    _frameController = TextEditingController(
      text: widget.initialFrame.toString(),
    );
    _startFrameController = TextEditingController(text: startFrame.toString());
    _endFrameController = TextEditingController(text: endFrame.toString());
    _stepController = TextEditingController(text: '1');
  }

  @override
  void dispose() {
    _frameController.dispose();
    _startFrameController.dispose();
    _endFrameController.dispose();
    _stepController.dispose();
    super.dispose();
  }

  int get _maxFrame => widget.metadata.frameCount > 0
      ? widget.metadata.frameCount - 1
      : widget.initialFrame;

  int _frameFromDuration(Duration duration) {
    final seconds = duration.inMicroseconds / 1000000.0;
    return (seconds * widget.metadata.fps).round().clamp(0, _maxFrame);
  }

  int? _parseFrame(TextEditingController controller) {
    return int.tryParse(controller.text.trim());
  }

  void _submit() {
    final frame = _parseFrame(_frameController);
    final startFrame = _parseFrame(_startFrameController);
    final endFrame = _parseFrame(_endFrameController);
    final step = _parseFrame(_stepController);

    String? validationMessage;
    if (_mode == ExportMode.frame) {
      if (frame == null || frame < 0 || frame > _maxFrame) {
        validationMessage = 'Enter a frame between 0 and $_maxFrame.';
      }
    } else if (_mode == ExportMode.frames) {
      if (startFrame == null || endFrame == null) {
        validationMessage = 'Enter a valid frame range.';
      } else if (startFrame < 0 ||
          endFrame > _maxFrame ||
          startFrame > endFrame) {
        validationMessage = 'Frame range must stay between 0 and $_maxFrame.';
      } else if (step == null || step <= 0) {
        validationMessage = 'Step must be 1 or greater.';
      }
    } else if (_mode == ExportMode.video) {
      if (startFrame == null || endFrame == null) {
        validationMessage = 'Enter a valid video frame range.';
      } else if (startFrame < 0 ||
          endFrame > _maxFrame ||
          startFrame > endFrame) {
        validationMessage = 'Video range must stay between 0 and $_maxFrame.';
      }
    }

    if (validationMessage != null) {
      setState(() {
        _validationMessage = validationMessage;
      });
      return;
    }

    final resolvedEndFrame = _mode == ExportMode.frame
        ? frame!
        : (_mode == ExportMode.annotationFile
              ? (endFrame ?? _maxFrame)
              : endFrame!);

    Navigator.of(context).pop(
      ExportRequest(
        mode: _mode,
        suggestedBaseName: widget.suggestedBaseName,
        startFrame: _mode == ExportMode.frame ? frame! : (startFrame ?? 0),
        endFrame: resolvedEndFrame,
        frameStep: step ?? 1,
        frameFormat: _frameFormat,
        annotationFormat: _annotationFormat,
        videoPreset: _videoPreset,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Export'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<ExportMode>(
                initialValue: _mode,
                decoration: const InputDecoration(labelText: 'Export Mode'),
                items: _modeItems,
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _mode = value;
                    _validationMessage = null;
                  });
                },
              ),
              const SizedBox(height: 14),
              if (_mode == ExportMode.frame) ...[
                _frameField(controller: _frameController, label: 'Frame'),
                const SizedBox(height: 12),
                DropdownButtonFormField<FrameExportFormat>(
                  initialValue: _frameFormat,
                  decoration: const InputDecoration(labelText: 'Image Format'),
                  items: const [
                    DropdownMenuItem(
                      value: FrameExportFormat.png,
                      child: Text('PNG'),
                    ),
                    DropdownMenuItem(
                      value: FrameExportFormat.jpg,
                      child: Text('JPG'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _frameFormat = value);
                  },
                ),
              ],
              if (_mode == ExportMode.frames) ...[
                _frameField(
                  controller: _startFrameController,
                  label: 'Start Frame',
                ),
                const SizedBox(height: 12),
                _frameField(
                  controller: _endFrameController,
                  label: 'End Frame',
                ),
                const SizedBox(height: 12),
                _frameField(
                  controller: _stepController,
                  label: 'Every N Frames',
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<FrameExportFormat>(
                  initialValue: _frameFormat,
                  decoration: const InputDecoration(labelText: 'Image Format'),
                  items: const [
                    DropdownMenuItem(
                      value: FrameExportFormat.png,
                      child: Text('PNG'),
                    ),
                    DropdownMenuItem(
                      value: FrameExportFormat.jpg,
                      child: Text('JPG'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _frameFormat = value);
                  },
                ),
              ],
              if (_mode == ExportMode.video) ...[
                _frameField(
                  controller: _startFrameController,
                  label: 'Start Frame',
                ),
                const SizedBox(height: 12),
                _frameField(
                  controller: _endFrameController,
                  label: 'End Frame',
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<VideoExportPreset>(
                  initialValue: _videoPreset,
                  decoration: const InputDecoration(
                    labelText: 'Speed / Quality',
                  ),
                  items: VideoExportPreset.values
                      .map(
                        (preset) => DropdownMenuItem(
                          value: preset,
                          child: Text(preset.displayName),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _videoPreset = value);
                  },
                ),
                const SizedBox(height: 8),
                Text(
                  _videoPreset.description,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              if (_mode == ExportMode.annotationFile) ...[
                DropdownButtonFormField<AnnotationExportFormat>(
                  initialValue: _annotationFormat,
                  decoration: const InputDecoration(labelText: 'File Format'),
                  items: const [
                    DropdownMenuItem(
                      value: AnnotationExportFormat.framesketch,
                      child: Text('.framesketch'),
                    ),
                    DropdownMenuItem(
                      value: AnnotationExportFormat.json,
                      child: Text('.json'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _annotationFormat = value);
                  },
                ),
                const SizedBox(height: 8),
                Text(
                  'Exports the current annotation project file for this local video.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              if (_validationMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  _validationMessage!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Continue')),
      ],
    );
  }

  Widget _frameField({
    required TextEditingController controller,
    required String label,
  }) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        helperText: '0 - $_maxFrame',
      ),
    );
  }

  List<DropdownMenuItem<ExportMode>> get _modeItems {
    return [
      const DropdownMenuItem(
        value: ExportMode.frame,
        child: Text('Single Frame'),
      ),
      const DropdownMenuItem(
        value: ExportMode.frames,
        child: Text('Multiple Frames'),
      ),
      if (widget.isLocalSource) ...const [
        DropdownMenuItem(
          value: ExportMode.video,
          child: Text('Annotated Video'),
        ),
        DropdownMenuItem(
          value: ExportMode.annotationFile,
          child: Text('Annotation File'),
        ),
      ],
    ];
  }
}
