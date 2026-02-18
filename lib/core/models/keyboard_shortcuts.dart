import 'package:flutter/services.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'keyboard_shortcuts.freezed.dart';
part 'keyboard_shortcuts.g.dart';

/// Custom converter for LogicalKeyboardKey
class LogicalKeyboardKeyConverter
    implements JsonConverter<LogicalKeyboardKey, String> {
  const LogicalKeyboardKeyConverter();

  @override
  LogicalKeyboardKey fromJson(String json) {
    // Parse the key from its debugName representation
    return LogicalKeyboardKey(int.parse(json));
  }

  @override
  String toJson(LogicalKeyboardKey key) {
    return key.keyId.toString();
  }
}

/// Represents a keyboard shortcut binding
@freezed
class KeyboardShortcut with _$KeyboardShortcut {
  const factory KeyboardShortcut({
    @LogicalKeyboardKeyConverter() required LogicalKeyboardKey key,
    @Default(false) bool ctrlPressed,
    @Default(false) bool shiftPressed,
    @Default(false) bool altPressed,
  }) = _KeyboardShortcut;

  factory KeyboardShortcut.fromJson(Map<String, dynamic> json) =>
      _$KeyboardShortcutFromJson(json);
}

/// All configurable keyboard shortcuts
@freezed
class KeyboardShortcuts with _$KeyboardShortcuts {
  const factory KeyboardShortcuts({
    required KeyboardShortcut nextFrame,
    required KeyboardShortcut previousFrame,
    required KeyboardShortcut playPause,
    required KeyboardShortcut jumpForward,
    required KeyboardShortcut jumpBackward,
    @Default(KeyboardShortcut(key: LogicalKeyboardKey.f11))
    KeyboardShortcut toggleFullscreen,
    required KeyboardShortcut openFile,
    required KeyboardShortcut saveAnnotations,
    required KeyboardShortcut undo,
    required KeyboardShortcut redo,
    // Annotation tools
    required KeyboardShortcut selectSelectionTool,
    required KeyboardShortcut selectPenTool,
    required KeyboardShortcut selectEraserTool,
    required KeyboardShortcut selectRectangleTool,
    required KeyboardShortcut selectCircleTool,
    required KeyboardShortcut selectLineTool,
    required KeyboardShortcut selectArrowTool,
    required KeyboardShortcut selectTextTool,
    required KeyboardShortcut toggleKeyframeMode,
    // Loop shortcuts
    required KeyboardShortcut toggleFullLoop,
    required KeyboardShortcut setLoopStart,
    required KeyboardShortcut setLoopEnd,
    required KeyboardShortcut toggleSectionLoop,
    // Crop shortcuts
    required KeyboardShortcut toggleCropMode,
    // Group enable/disable toggles
    @Default(true) bool generalShortcutsEnabled,
    @Default(true) bool annotationToolsShortcutsEnabled,
    @Default(true) bool loopControlsShortcutsEnabled,
    @Default(true) bool cropControlsShortcutsEnabled,
  }) = _KeyboardShortcuts;

  factory KeyboardShortcuts.fromJson(Map<String, dynamic> json) =>
      _$KeyboardShortcutsFromJson(json);
}

/// Default keyboard shortcuts
final defaultKeyboardShortcuts = KeyboardShortcuts(
  nextFrame: const KeyboardShortcut(key: LogicalKeyboardKey.period),
  previousFrame: const KeyboardShortcut(key: LogicalKeyboardKey.comma),
  playPause: const KeyboardShortcut(key: LogicalKeyboardKey.space),
  jumpForward: const KeyboardShortcut(
    key: LogicalKeyboardKey.arrowRight,
    shiftPressed: true,
  ),
  jumpBackward: const KeyboardShortcut(
    key: LogicalKeyboardKey.arrowLeft,
    shiftPressed: true,
  ),
  toggleFullscreen: const KeyboardShortcut(key: LogicalKeyboardKey.f11),
  openFile: const KeyboardShortcut(
    key: LogicalKeyboardKey.keyO,
    ctrlPressed: true,
  ),
  saveAnnotations: const KeyboardShortcut(
    key: LogicalKeyboardKey.keyS,
    ctrlPressed: true,
  ),
  undo: const KeyboardShortcut(key: LogicalKeyboardKey.keyZ, ctrlPressed: true),
  redo: const KeyboardShortcut(key: LogicalKeyboardKey.keyY, ctrlPressed: true),
  // Annotation tools
  selectSelectionTool: const KeyboardShortcut(key: LogicalKeyboardKey.keyV),
  selectPenTool: const KeyboardShortcut(key: LogicalKeyboardKey.keyP),
  selectEraserTool: const KeyboardShortcut(key: LogicalKeyboardKey.keyE),
  selectRectangleTool: const KeyboardShortcut(key: LogicalKeyboardKey.keyR),
  selectCircleTool: const KeyboardShortcut(
    key: LogicalKeyboardKey.keyO,
    shiftPressed: true,
  ),
  selectLineTool: const KeyboardShortcut(
    key: LogicalKeyboardKey.keyL,
    shiftPressed: true,
  ),
  selectArrowTool: const KeyboardShortcut(key: LogicalKeyboardKey.keyA),
  selectTextTool: const KeyboardShortcut(key: LogicalKeyboardKey.keyT),
  toggleKeyframeMode: const KeyboardShortcut(key: LogicalKeyboardKey.keyM),
  // Loop shortcuts
  toggleFullLoop: const KeyboardShortcut(key: LogicalKeyboardKey.keyL),
  setLoopStart: const KeyboardShortcut(key: LogicalKeyboardKey.keyI),
  setLoopEnd: const KeyboardShortcut(key: LogicalKeyboardKey.keyO),
  toggleSectionLoop: const KeyboardShortcut(
    key: LogicalKeyboardKey.bracketLeft,
  ),
  // Crop shortcuts
  toggleCropMode: const KeyboardShortcut(key: LogicalKeyboardKey.keyC),
  // Group toggles - all enabled by default
  generalShortcutsEnabled: true,
  annotationToolsShortcutsEnabled: true,
  loopControlsShortcutsEnabled: true,
  cropControlsShortcutsEnabled: true,
);
