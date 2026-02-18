import 'dart:async';
import 'dart:io';
import 'package:path/path.dart' as path;

class FFmpegProvisioningProgress {
  final String message;
  final double? progress;

  const FFmpegProvisioningProgress({required this.message, this.progress});
}

typedef FFmpegProvisioningProgressCallback =
    void Function(FFmpegProvisioningProgress progress);

/// Resolves FFmpeg/FFprobe binaries without requiring a manual user install.
///
/// On Windows, if binaries are missing from bundled locations, this service
/// auto-downloads an FFmpeg bundle (includes ffprobe) into app-local storage.
class FFmpegBinariesService {
  static const String _windowsDownloadUrl =
      'https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip';

  static Future<void>? _provisioningTask;
  static final List<FFmpegProvisioningProgressCallback> _progressListeners = [];
  static FFmpegProvisioningProgress? _latestProgress;

  Future<String?> findFFmpegPath({
    FFmpegProvisioningProgressCallback? onProgress,
  }) => _findBinaryPath('ffmpeg', onProgress: onProgress);

  Future<String?> findFFprobePath({
    FFmpegProvisioningProgressCallback? onProgress,
  }) => _findBinaryPath('ffprobe', onProgress: onProgress);

  Future<String?> _findBinaryPath(
    String binaryBaseName, {
    FFmpegProvisioningProgressCallback? onProgress,
  }) async {
    final binaryName = Platform.isWindows
        ? '$binaryBaseName.exe'
        : binaryBaseName;

    final bundledPath = await _findInBundledLocations(binaryName);
    if (bundledPath != null) return bundledPath;

    final managedPath = await _findInManagedLocations(binaryName);
    if (managedPath != null) return managedPath;

    if (Platform.isWindows) {
      await _ensureWindowsProvisioned(onProgress: onProgress);
      return _findInManagedLocations(binaryName);
    }

    return null;
  }

  Future<String?> _findInBundledLocations(String binaryName) async {
    final exePath = Platform.resolvedExecutable;
    final exeDir = path.dirname(exePath);

    if (Platform.isWindows) {
      final candidates = <String>[
        path.join(exeDir, binaryName),
        path.join(
          exeDir,
          'data',
          'flutter_assets',
          'packages',
          'media_kit_libs_windows_video',
          binaryName,
        ),
      ];
      return _firstExistingFile(candidates);
    }

    if (Platform.isMacOS) {
      final appContentsDir = path.normalize(path.join(exeDir, '..'));
      final candidates = <String>[
        path.join(exeDir, binaryName),
        path.join(
          appContentsDir,
          'Frameworks',
          'App.framework',
          'Resources',
          'flutter_assets',
          'packages',
          'media_kit_libs_macos_video',
          binaryName,
        ),
        path.join(
          appContentsDir,
          'Resources',
          'flutter_assets',
          'packages',
          'media_kit_libs_macos_video',
          binaryName,
        ),
      ];
      return _firstExistingFile(candidates);
    }

    if (Platform.isLinux) {
      final candidates = <String>[
        path.join(exeDir, binaryName),
        path.join(
          exeDir,
          'data',
          'flutter_assets',
          'packages',
          'media_kit_libs_linux',
          binaryName,
        ),
      ];
      return _firstExistingFile(candidates);
    }

    return null;
  }

  Future<String?> _findInManagedLocations(String binaryName) async {
    final rootDir = _managedRootDir();
    if (!await rootDir.exists()) return null;

    final directPath = path.join(rootDir.path, binaryName);
    if (await File(directPath).exists()) return directPath;

    try {
      await for (final entity in rootDir.list(
        recursive: true,
        followLinks: false,
      )) {
        if (entity is! File) continue;
        if (path.basename(entity.path).toLowerCase() ==
            binaryName.toLowerCase()) {
          return entity.path;
        }
      }
    } catch (_) {}

    return null;
  }

  Future<void> _ensureWindowsProvisioned({
    FFmpegProvisioningProgressCallback? onProgress,
  }) async {
    if (onProgress != null) {
      _progressListeners.add(onProgress);
      final latest = _latestProgress;
      if (latest != null) {
        onProgress(latest);
      }
    }

    final task = _provisioningTask ??= _provisionWindowsBinaries();
    try {
      await task;
    } finally {
      if (identical(_provisioningTask, task)) {
        _provisioningTask = null;
      }
      if (onProgress != null) {
        _progressListeners.remove(onProgress);
      }
      if (_provisioningTask == null && _progressListeners.isEmpty) {
        _latestProgress = null;
      }
    }
  }

  Future<void> _provisionWindowsBinaries() async {
    _emitProgress(
      const FFmpegProvisioningProgress(
        message: 'Checking FFmpeg tools...',
        progress: 0.0,
      ),
    );

    final rootDir = _managedRootDir();
    final ffmpegPath = path.join(rootDir.path, 'ffmpeg.exe');
    final ffprobePath = path.join(rootDir.path, 'ffprobe.exe');
    if (await File(ffmpegPath).exists() && await File(ffprobePath).exists()) {
      _emitProgress(
        const FFmpegProvisioningProgress(
          message: 'FFmpeg tools ready.',
          progress: 1.0,
        ),
      );
      return;
    }

    await rootDir.create(recursive: true);

    final tempZipPath = path.join(
      Directory.systemTemp.path,
      'framesketch_ffmpeg_bundle.zip',
    );
    final zipFile = File(tempZipPath);

    try {
      _emitProgress(
        const FFmpegProvisioningProgress(
          message: 'Downloading FFmpeg tools...',
          progress: 0.05,
        ),
      );
      await _downloadFile(
        _windowsDownloadUrl,
        zipFile,
        onProgress: (receivedBytes, totalBytes) {
          if (totalBytes == null || totalBytes <= 0) {
            _emitProgress(
              const FFmpegProvisioningProgress(
                message: 'Downloading FFmpeg tools...',
                progress: null,
              ),
            );
            return;
          }
          final ratio = receivedBytes / totalBytes;
          final mapped = 0.05 + (ratio * 0.8);
          _emitProgress(
            FFmpegProvisioningProgress(
              message: 'Downloading FFmpeg tools...',
              progress: mapped.clamp(0.05, 0.85),
            ),
          );
        },
      );

      final extractionDir = path.join(rootDir.path, 'bundle');
      await Directory(extractionDir).create(recursive: true);
      _emitProgress(
        const FFmpegProvisioningProgress(
          message: 'Extracting FFmpeg tools...',
          progress: 0.9,
        ),
      );

      final expandResult = await Process.run('powershell', [
        '-NoProfile',
        '-Command',
        'Expand-Archive -LiteralPath "${zipFile.path}" -DestinationPath "$extractionDir" -Force',
      ]);

      if (expandResult.exitCode != 0) {
        throw Exception(
          'Failed to extract FFmpeg archive: ${expandResult.stderr}',
        );
      }

      _emitProgress(
        const FFmpegProvisioningProgress(
          message: 'FFmpeg tools ready.',
          progress: 1.0,
        ),
      );
    } finally {
      try {
        if (await zipFile.exists()) await zipFile.delete();
      } catch (_) {}
    }
  }

  Future<void> _downloadFile(
    String url,
    File outputFile, {
    void Function(int receivedBytes, int? totalBytes)? onProgress,
  }) async {
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 30);

    try {
      final request = await client.getUrl(Uri.parse(url));
      final response = await request.close();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException(
          'Failed to download FFmpeg bundle (HTTP ${response.statusCode})',
        );
      }

      final sink = outputFile.openWrite();
      try {
        int receivedBytes = 0;
        final totalBytes = response.contentLength > 0
            ? response.contentLength
            : null;
        int? lastPercent;

        await for (final chunk in response) {
          sink.add(chunk);
          receivedBytes += chunk.length;
          if (onProgress == null) continue;

          if (totalBytes == null) {
            onProgress(receivedBytes, null);
            continue;
          }

          final percent = ((receivedBytes / totalBytes) * 100).floor();
          if (percent != lastPercent) {
            lastPercent = percent;
            onProgress(receivedBytes, totalBytes);
          }
        }
      } finally {
        await sink.close();
      }
    } finally {
      client.close(force: true);
    }
  }

  Directory _managedRootDir() {
    if (Platform.isWindows) {
      final appData = Platform.environment['LOCALAPPDATA'];
      if (appData != null && appData.trim().isNotEmpty) {
        return Directory(path.join(appData, 'framesketch_player', 'ffmpeg'));
      }
    }

    final home = Platform.environment['HOME'] ?? Directory.current.path;
    return Directory(path.join(home, '.framesketch_player', 'ffmpeg'));
  }

  Future<String?> _firstExistingFile(List<String> candidates) async {
    for (final candidate in candidates) {
      if (await File(candidate).exists()) {
        return candidate;
      }
    }
    return null;
  }

  void _emitProgress(FFmpegProvisioningProgress progress) {
    _latestProgress = progress;
    for (final listener in List<FFmpegProvisioningProgressCallback>.from(
      _progressListeners,
    )) {
      try {
        listener(progress);
      } catch (_) {}
    }
  }
}
