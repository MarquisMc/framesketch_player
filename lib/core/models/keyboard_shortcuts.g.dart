// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'keyboard_shortcuts.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$KeyboardShortcutImpl _$$KeyboardShortcutImplFromJson(
  Map<String, dynamic> json,
) => _$KeyboardShortcutImpl(
  key: const LogicalKeyboardKeyConverter().fromJson(json['key'] as String),
  ctrlPressed: json['ctrlPressed'] as bool? ?? false,
  shiftPressed: json['shiftPressed'] as bool? ?? false,
  altPressed: json['altPressed'] as bool? ?? false,
);

Map<String, dynamic> _$$KeyboardShortcutImplToJson(
  _$KeyboardShortcutImpl instance,
) => <String, dynamic>{
  'key': const LogicalKeyboardKeyConverter().toJson(instance.key),
  'ctrlPressed': instance.ctrlPressed,
  'shiftPressed': instance.shiftPressed,
  'altPressed': instance.altPressed,
};

_$KeyboardShortcutsImpl _$$KeyboardShortcutsImplFromJson(
  Map<String, dynamic> json,
) => _$KeyboardShortcutsImpl(
  nextFrame: KeyboardShortcut.fromJson(
    json['nextFrame'] as Map<String, dynamic>,
  ),
  previousFrame: KeyboardShortcut.fromJson(
    json['previousFrame'] as Map<String, dynamic>,
  ),
  playPause: KeyboardShortcut.fromJson(
    json['playPause'] as Map<String, dynamic>,
  ),
  jumpForward: KeyboardShortcut.fromJson(
    json['jumpForward'] as Map<String, dynamic>,
  ),
  jumpBackward: KeyboardShortcut.fromJson(
    json['jumpBackward'] as Map<String, dynamic>,
  ),
  openFile: KeyboardShortcut.fromJson(json['openFile'] as Map<String, dynamic>),
  saveAnnotations: KeyboardShortcut.fromJson(
    json['saveAnnotations'] as Map<String, dynamic>,
  ),
  undo: KeyboardShortcut.fromJson(json['undo'] as Map<String, dynamic>),
  redo: KeyboardShortcut.fromJson(json['redo'] as Map<String, dynamic>),
  selectSelectionTool: KeyboardShortcut.fromJson(
    json['selectSelectionTool'] as Map<String, dynamic>,
  ),
  selectPenTool: KeyboardShortcut.fromJson(
    json['selectPenTool'] as Map<String, dynamic>,
  ),
  selectEraserTool: KeyboardShortcut.fromJson(
    json['selectEraserTool'] as Map<String, dynamic>,
  ),
  selectRectangleTool: KeyboardShortcut.fromJson(
    json['selectRectangleTool'] as Map<String, dynamic>,
  ),
  selectCircleTool: KeyboardShortcut.fromJson(
    json['selectCircleTool'] as Map<String, dynamic>,
  ),
  selectLineTool: KeyboardShortcut.fromJson(
    json['selectLineTool'] as Map<String, dynamic>,
  ),
  selectArrowTool: KeyboardShortcut.fromJson(
    json['selectArrowTool'] as Map<String, dynamic>,
  ),
  selectTextTool: KeyboardShortcut.fromJson(
    json['selectTextTool'] as Map<String, dynamic>,
  ),
  toggleFullLoop: KeyboardShortcut.fromJson(
    json['toggleFullLoop'] as Map<String, dynamic>,
  ),
  setLoopStart: KeyboardShortcut.fromJson(
    json['setLoopStart'] as Map<String, dynamic>,
  ),
  setLoopEnd: KeyboardShortcut.fromJson(
    json['setLoopEnd'] as Map<String, dynamic>,
  ),
  toggleSectionLoop: KeyboardShortcut.fromJson(
    json['toggleSectionLoop'] as Map<String, dynamic>,
  ),
  toggleCropMode: KeyboardShortcut.fromJson(
    json['toggleCropMode'] as Map<String, dynamic>,
  ),
  generalShortcutsEnabled: json['generalShortcutsEnabled'] as bool? ?? true,
  annotationToolsShortcutsEnabled:
      json['annotationToolsShortcutsEnabled'] as bool? ?? true,
  loopControlsShortcutsEnabled:
      json['loopControlsShortcutsEnabled'] as bool? ?? true,
  cropControlsShortcutsEnabled:
      json['cropControlsShortcutsEnabled'] as bool? ?? true,
);

Map<String, dynamic> _$$KeyboardShortcutsImplToJson(
  _$KeyboardShortcutsImpl instance,
) => <String, dynamic>{
  'nextFrame': instance.nextFrame,
  'previousFrame': instance.previousFrame,
  'playPause': instance.playPause,
  'jumpForward': instance.jumpForward,
  'jumpBackward': instance.jumpBackward,
  'openFile': instance.openFile,
  'saveAnnotations': instance.saveAnnotations,
  'undo': instance.undo,
  'redo': instance.redo,
  'selectSelectionTool': instance.selectSelectionTool,
  'selectPenTool': instance.selectPenTool,
  'selectEraserTool': instance.selectEraserTool,
  'selectRectangleTool': instance.selectRectangleTool,
  'selectCircleTool': instance.selectCircleTool,
  'selectLineTool': instance.selectLineTool,
  'selectArrowTool': instance.selectArrowTool,
  'selectTextTool': instance.selectTextTool,
  'toggleFullLoop': instance.toggleFullLoop,
  'setLoopStart': instance.setLoopStart,
  'setLoopEnd': instance.setLoopEnd,
  'toggleSectionLoop': instance.toggleSectionLoop,
  'toggleCropMode': instance.toggleCropMode,
  'generalShortcutsEnabled': instance.generalShortcutsEnabled,
  'annotationToolsShortcutsEnabled': instance.annotationToolsShortcutsEnabled,
  'loopControlsShortcutsEnabled': instance.loopControlsShortcutsEnabled,
  'cropControlsShortcutsEnabled': instance.cropControlsShortcutsEnabled,
};
