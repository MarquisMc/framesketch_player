import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/file_association_service.dart';
import '../../../core/theme/app_palette.dart';
import '../providers/auto_save_provider.dart';
import '../providers/keyboard_shortcuts_provider.dart';
import 'settings_dialog.dart';
import 'theme_dialog.dart';

class SettingsActions {
  const SettingsActions({
    required this.ref,
    required this.navigatorKey,
    required this.scaffoldMessengerKey,
    required this.focusNode,
    required this.isMounted,
    required this.activePalette,
    required this.onAutoSaveChanged,
    required this.showInfoDialog,
    required this.showErrorDialog,
  });

  final WidgetRef ref;
  final GlobalKey<NavigatorState> navigatorKey;
  final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey;
  final FocusNode focusNode;
  final bool Function() isMounted;
  final AppPalette Function() activePalette;
  final Future<void> Function(bool enabled) onAutoSaveChanged;
  final void Function(String title, String message) showInfoDialog;
  final void Function(String message) showErrorDialog;

  void openSettings(BuildContext context) {
    try {
      showDialog(
        context: context,
        builder: (dialogContext) {
          return SettingsDialog(
            shortcuts: ref.read(keyboardShortcutsProvider),
            autoSaveEnabled: ref.read(autoSaveProvider),
            onSave: (shortcuts, autoSaveEnabled) {
              unawaited(
                ref
                    .read(keyboardShortcutsProvider.notifier)
                    .setShortcuts(shortcuts),
              );
              unawaited(onAutoSaveChanged(autoSaveEnabled));
              focusNode.requestFocus();
            },
          );
        },
      );
    } catch (e) {
      showErrorDialog('Error opening settings: $e');
    }
  }

  void openThemeManager(BuildContext context) {
    try {
      showDialog(context: context, builder: (_) => const ThemeManagerDialog());
    } catch (e) {
      showErrorDialog('Error opening theme manager: $e');
    }
  }

  Future<void> handleMenuAction(String action) async {
    final service = FileAssociationService();

    switch (action) {
      case 'register':
        await _registerFileAssociations(service);
        break;
      case 'unregister':
        await _unregisterFileAssociations(service);
        break;
      case 'check':
        await _checkFileAssociationStatus(service);
        break;
    }
  }

  Future<void> _registerFileAssociations(FileAssociationService service) async {
    try {
      final success = await service.registerFileAssociations();
      if (!isMounted()) return;
      if (success) {
        showInfoDialog(
          'File Associations Registered',
          'FrameSketch Player has been registered for video files and .framesketch files.\n\n'
              'To set it as default for video files:\n'
              '1. Right-click any video file\n'
              '2. Select "Open with" -> "Choose another app"\n'
              '3. Select "FrameSketch Player"\n'
              '4. Check "Always use this app"\n\n'
              '.framesketch files should now open directly with FrameSketch Player.',
        );
      } else {
        showErrorDialog(
          'Failed to register file associations. Please try running as administrator.',
        );
      }
    } catch (e) {
      if (isMounted()) {
        showErrorDialog('Error registering file associations: $e');
      }
    }
  }

  Future<void> _unregisterFileAssociations(
    FileAssociationService service,
  ) async {
    try {
      final success = await service.unregisterFileAssociations();
      if (!isMounted()) return;
      if (success) {
        scaffoldMessengerKey.currentState?.showSnackBar(
          SnackBar(
            content: const Text(
              'Video and annotation file associations removed successfully',
            ),
            backgroundColor: activePalette().success,
          ),
        );
      } else {
        showErrorDialog('Failed to remove file associations.');
      }
    } catch (e) {
      if (isMounted()) {
        showErrorDialog('Error removing file associations: $e');
      }
    }
  }

  Future<void> _checkFileAssociationStatus(
    FileAssociationService service,
  ) async {
    try {
      final isRegistered = await service.isRegistered();
      if (!isMounted()) return;
      showInfoDialog(
        'Registration Status',
        isRegistered
            ? 'FrameSketch Player is currently registered for video files and .framesketch files.'
            : 'FrameSketch Player is not registered.\n\nUse "Register Video + Annotation Files" to register it.',
      );
    } catch (e) {
      if (isMounted()) {
        showErrorDialog('Error checking registration status: $e');
      }
    }
  }
}
