import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/services/app_update_installer_service.dart';
import '../../../core/services/github_release_update_service.dart';
import '../widgets/update_download_dialog.dart';

/// Checks GitHub for app updates and drives the update/install dialogs.
///
/// [isChecking] and [isUpdateAvailable] back the toolbar indicator; the host
/// widget rebuilds when [onStateChanged] fires.
class UpdateCheckFlow {
  UpdateCheckFlow({
    required this.navigatorKey,
    required this.focusNode,
    required this.isMounted,
    required this.onStateChanged,
    required this.showInfoDialog,
    required this.showErrorDialog,
    GitHubReleaseUpdateService? updateService,
    AppUpdateInstallerService? installerService,
  }) : _updateService = updateService ?? GitHubReleaseUpdateService(),
       _installerService = installerService ?? AppUpdateInstallerService();

  final GlobalKey<NavigatorState> navigatorKey;
  final FocusNode focusNode;
  final bool Function() isMounted;
  final VoidCallback onStateChanged;
  final void Function(String title, String message) showInfoDialog;
  final void Function(String message) showErrorDialog;
  final GitHubReleaseUpdateService _updateService;
  final AppUpdateInstallerService _installerService;

  bool _isChecking = false;
  bool _isUpdateAvailable = false;

  bool get isChecking => _isChecking;
  bool get isUpdateAvailable => _isUpdateAvailable;

  Future<void> checkForUpdates({bool notifyWhenCurrent = false}) async {
    if (_isChecking) return;
    _isChecking = true;
    onStateChanged();

    try {
      final result = await _updateService.checkForUpdate();
      if (!isMounted()) return;

      if (_isUpdateAvailable != result.hasUpdate) {
        _isUpdateAvailable = result.hasUpdate;
        onStateChanged();
      }

      if (result.hasUpdate) {
        await _showUpdateAvailableDialog(result);
      } else if (notifyWhenCurrent) {
        final message = result.latestRelease == null
            ? 'No published GitHub releases are available yet.\n\n'
                  'Installed version: ${result.installedVersion}'
            : 'You are running the latest release.\n\n'
                  'Installed version: ${result.installedVersion}';
        showInfoDialog('No Update Available', message);
      }
    } catch (e, stackTrace) {
      debugPrint('Update check failed: $e');
      debugPrint('$stackTrace');
      if (notifyWhenCurrent && isMounted()) {
        showErrorDialog('Unable to check for updates right now.');
      }
    } finally {
      _isChecking = false;
      if (isMounted()) {
        onStateChanged();
      }
    }
  }

  Future<void> _showUpdateAvailableDialog(UpdateCheckResult result) async {
    final context = navigatorKey.currentContext;
    final release = result.latestRelease;
    if (context == null || release == null || !isMounted()) return;
    final installerAsset = _installerService.supportsAutomaticInstallation
        ? release.windowsInstallerAsset
        : null;

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Update Available'),
        content: Text(
          'FrameSketch ${release.displayVersion} is available.\n\n'
          'Installed version: ${result.installedVersion}\n\n'
          '${installerAsset == null ? 'Open the release page to download it.' : 'Save your work before installing. The app will restart during the update.'}',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              focusNode.requestFocus();
            },
            child: const Text('Later'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              unawaited(_openReleasePage(release.pageUrl));
            },
            child: const Text('Open Release Page'),
          ),
          if (installerAsset != null)
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                unawaited(_downloadAndInstallUpdate(installerAsset));
              },
              child: const Text('Download and Install Update'),
            ),
        ],
      ),
    );
  }

  Future<void> _downloadAndInstallUpdate(GitHubReleaseAsset asset) async {
    final context = navigatorKey.currentContext;
    if (context == null || !isMounted()) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          UpdateDownloadDialog(asset: asset, installerService: _installerService),
    );
    focusNode.requestFocus();
  }

  Future<void> _openReleasePage(Uri pageUrl) async {
    try {
      final opened = await launchUrl(
        pageUrl,
        mode: LaunchMode.externalApplication,
      );
      if (!opened && isMounted()) {
        showErrorDialog('Unable to open the GitHub release page.');
      }
    } catch (e, stackTrace) {
      debugPrint('Opening release page failed: $e');
      debugPrint('$stackTrace');
      if (isMounted()) {
        showErrorDialog('Unable to open the GitHub release page.');
      }
    }
    focusNode.requestFocus();
  }
}
