import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/models/keyboard_shortcuts.dart';

/// Manages keyboard shortcuts preferences
class KeyboardShortcutsNotifier extends StateNotifier<KeyboardShortcuts> {
  static const String _storageKey = 'keyboard_shortcuts';

  KeyboardShortcutsNotifier() : super(defaultKeyboardShortcuts) {
    unawaited(_loadShortcuts());
  }

  /// Load shortcuts from storage
  Future<void> _loadShortcuts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_storageKey);
      if (json != null) {
        final shortcuts = KeyboardShortcuts.fromJson(
          jsonDecode(json) as Map<String, dynamic>,
        );
        state = shortcuts;
      }
    } catch (e) {
      debugPrint('Error loading keyboard shortcuts: $e');
      state = defaultKeyboardShortcuts;
    }
  }

  /// Save shortcuts to storage
  Future<void> _saveShortcuts(KeyboardShortcuts shortcuts) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storageKey, jsonEncode(shortcuts.toJson()));
    } catch (e) {
      debugPrint('Error saving keyboard shortcuts: $e');
    }
  }

  /// Replace all shortcuts at once.
  Future<void> setShortcuts(KeyboardShortcuts shortcuts) async {
    state = shortcuts;
    await _saveShortcuts(shortcuts);
  }

  /// Update next frame shortcut
  Future<void> updateNextFrame(KeyboardShortcut shortcut) async {
    final updated = state.copyWith(nextFrame: shortcut);
    state = updated;
    await _saveShortcuts(updated);
  }

  /// Update previous frame shortcut
  Future<void> updatePreviousFrame(KeyboardShortcut shortcut) async {
    final updated = state.copyWith(previousFrame: shortcut);
    state = updated;
    await _saveShortcuts(updated);
  }

  /// Update play/pause shortcut
  Future<void> updatePlayPause(KeyboardShortcut shortcut) async {
    final updated = state.copyWith(playPause: shortcut);
    state = updated;
    await _saveShortcuts(updated);
  }

  /// Update jump forward shortcut
  Future<void> updateJumpForward(KeyboardShortcut shortcut) async {
    final updated = state.copyWith(jumpForward: shortcut);
    state = updated;
    await _saveShortcuts(updated);
  }

  /// Update jump backward shortcut
  Future<void> updateJumpBackward(KeyboardShortcut shortcut) async {
    final updated = state.copyWith(jumpBackward: shortcut);
    state = updated;
    await _saveShortcuts(updated);
  }

  /// Reset all shortcuts to defaults
  Future<void> resetToDefaults() async {
    await setShortcuts(defaultKeyboardShortcuts);
  }
}

/// Keyboard shortcuts provider
final keyboardShortcutsProvider =
    StateNotifierProvider<KeyboardShortcutsNotifier, KeyboardShortcuts>((ref) {
      return KeyboardShortcutsNotifier();
    });
