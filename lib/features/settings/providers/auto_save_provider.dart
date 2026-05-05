import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AutoSaveNotifier extends StateNotifier<bool> {
  static const String _storageKey = 'auto_save_enabled';

  AutoSaveNotifier() : super(true) {
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final storedValue = prefs.getBool(_storageKey);
      if (storedValue != null) {
        state = storedValue;
      }
    } catch (e) {
      debugPrint('Error loading auto save preference: $e');
    }
  }

  Future<void> setEnabled(bool enabled) async {
    state = enabled;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_storageKey, enabled);
    } catch (e) {
      debugPrint('Error saving auto save preference: $e');
    }
  }
}

final autoSaveProvider = StateNotifierProvider<AutoSaveNotifier, bool>((ref) {
  return AutoSaveNotifier();
});
