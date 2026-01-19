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
    required KeyboardShortcut openFile,
    required KeyboardShortcut saveAnnotations,
    required KeyboardShortcut undo,
    required KeyboardShortcut redo,
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
  openFile: const KeyboardShortcut(
    key: LogicalKeyboardKey.keyO,
    ctrlPressed: true,
  ),
  saveAnnotations: const KeyboardShortcut(
    key: LogicalKeyboardKey.keyS,
    ctrlPressed: true,
  ),
  undo: const KeyboardShortcut(
    key: LogicalKeyboardKey.keyZ,
    ctrlPressed: true,
  ),
  redo: const KeyboardShortcut(
    key: LogicalKeyboardKey.keyY,
    ctrlPressed: true,
  ),
);
