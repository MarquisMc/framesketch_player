import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../annotations/providers/annotation_provider.dart';
import '../providers/auto_save_provider.dart';

/// Debounces and runs annotation auto-saves.
///
/// Owns the save/indicator timers; the host widget only mirrors the
/// indicator visibility reported through [onIndicatorVisibilityChanged].
class AutoSaveCoordinator {
  AutoSaveCoordinator({
    required this.ref,
    required this.isMounted,
    required this.onIndicatorVisibilityChanged,
    required this.showErrorDialog,
  });

  final WidgetRef ref;
  final bool Function() isMounted;
  final ValueChanged<bool> onIndicatorVisibilityChanged;
  final void Function(String message) showErrorDialog;

  Timer? _saveTimer;
  Timer? _indicatorTimer;
  bool _isAutoSaving = false;
  bool _isIndicatorVisible = false;

  bool get _isEnabled => ref.read(autoSaveProvider);

  void dispose() {
    _saveTimer?.cancel();
    _indicatorTimer?.cancel();
  }

  Future<void> setEnabled(bool enabled) async {
    await ref.read(autoSaveProvider.notifier).setEnabled(enabled);

    if (enabled) {
      handleUnsavedChanges(
        hasUnsavedChanges: ref.read(annotationProvider).hasUnsavedChanges,
      );
    } else {
      _saveTimer?.cancel();
    }
  }

  void handleUnsavedChanges({required bool hasUnsavedChanges}) {
    _saveTimer?.cancel();

    if (!_isEnabled || !hasUnsavedChanges) {
      _hideIndicator();
      return;
    }

    _showIndicatorNow();
    _saveTimer = Timer(
      const Duration(seconds: 2),
      () => unawaited(_performAutoSave()),
    );
  }

  Future<void> _performAutoSave() async {
    if (_isAutoSaving || !_isEnabled) {
      return;
    }

    final annotationState = ref.read(annotationProvider);
    if (!annotationState.hasUnsavedChanges ||
        annotationState.annotationData == null) {
      return;
    }

    _setAutoSaving(true);
    try {
      final success = await ref
          .read(annotationProvider.notifier)
          .saveAnnotations();
      if (!success && isMounted()) {
        showErrorDialog('Auto-save failed');
      }
    } catch (e, stackTrace) {
      debugPrint('Auto-save error: $e');
      debugPrint('$stackTrace');
      if (isMounted()) {
        showErrorDialog('Auto-save failed. Please try again.');
      }
    } finally {
      _setAutoSaving(false);
      final latestState = ref.read(annotationProvider);
      if (_isEnabled && latestState.hasUnsavedChanges) {
        handleUnsavedChanges(hasUnsavedChanges: true);
      }
    }
  }

  void _setAutoSaving(bool value) {
    _isAutoSaving = value;
    _indicatorTimer?.cancel();

    if (value) {
      _showIndicatorNow();
      return;
    }

    _indicatorTimer = Timer(const Duration(milliseconds: 1400), () {
      if (!isMounted()) return;
      _setIndicatorVisible(false);
    });
  }

  void _showIndicatorNow() {
    _indicatorTimer?.cancel();
    if (!isMounted()) return;
    _setIndicatorVisible(true);
  }

  void _hideIndicator() {
    _indicatorTimer?.cancel();
    if (!isMounted()) return;
    _setIndicatorVisible(false);
  }

  void _setIndicatorVisible(bool visible) {
    if (_isIndicatorVisible == visible) return;
    _isIndicatorVisible = visible;
    onIndicatorVisibilityChanged(visible);
  }
}
