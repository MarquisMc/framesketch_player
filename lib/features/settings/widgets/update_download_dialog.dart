import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/services/app_update_installer_service.dart';
import '../../../core/services/github_release_update_service.dart';

class UpdateDownloadDialog extends StatefulWidget {
  const UpdateDownloadDialog({
    super.key,
    required this.asset,
    required this.installerService,
  });

  final GitHubReleaseAsset asset;
  final AppUpdateInstallerService installerService;

  @override
  State<UpdateDownloadDialog> createState() => _UpdateDownloadDialogState();
}

class _UpdateDownloadDialogState extends State<UpdateDownloadDialog> {
  int _receivedBytes = 0;
  int _totalBytes = 0;
  bool _isInstalling = false;
  String? _error;

  double? get _progress {
    if (_totalBytes <= 0) return null;
    return (_receivedBytes / _totalBytes).clamp(0, 1);
  }

  @override
  void initState() {
    super.initState();
    unawaited(_downloadAndInstall());
  }

  Future<void> _downloadAndInstall() async {
    setState(() {
      _receivedBytes = 0;
      _totalBytes = widget.asset.size;
      _isInstalling = false;
      _error = null;
    });

    try {
      final installer = await widget.installerService.downloadInstaller(
        widget.asset,
        onProgress: ({required receivedBytes, required totalBytes}) {
          if (!mounted) return;
          setState(() {
            _receivedBytes = receivedBytes;
            _totalBytes = totalBytes;
          });
        },
      );
      if (!mounted) return;

      setState(() => _isInstalling = true);
      await widget.installerService.installAndRestart(installer);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isInstalling = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final error = _error;
    return PopScope(
      canPop: error != null,
      child: AlertDialog(
        title: Text(_isInstalling ? 'Installing Update' : 'Downloading Update'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (error != null) ...[
                const Text('The update could not be installed.'),
                const SizedBox(height: 8),
                Text(error),
              ] else if (_isInstalling) ...[
                const LinearProgressIndicator(),
                const SizedBox(height: 16),
                const Text(
                  'Installing the update now. FrameSketch will close and '
                  'restart automatically.',
                ),
              ] else ...[
                LinearProgressIndicator(value: _progress),
                const SizedBox(height: 16),
                Text(_progressLabel),
                const SizedBox(height: 8),
                const Text(
                  'Keep FrameSketch open. It will restart automatically once '
                  'the update is installed.',
                ),
              ],
            ],
          ),
        ),
        actions: error == null
            ? const []
            : [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
                FilledButton(
                  onPressed: _downloadAndInstall,
                  child: const Text('Retry'),
                ),
              ],
      ),
    );
  }

  String get _progressLabel {
    if (_totalBytes <= 0) {
      return 'Starting download...';
    }
    final percentage = (_progress! * 100).round();
    return '$percentage%  (${_formatBytes(_receivedBytes)} of '
        '${_formatBytes(_totalBytes)})';
  }

  String _formatBytes(int bytes) {
    const bytesPerMegabyte = 1024 * 1024;
    if (bytes >= bytesPerMegabyte) {
      return '${(bytes / bytesPerMegabyte).toStringAsFixed(1)} MB';
    }
    return '${(bytes / 1024).toStringAsFixed(0)} KB';
  }
}
