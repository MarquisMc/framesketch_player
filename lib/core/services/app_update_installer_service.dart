import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import 'github_release_update_service.dart';

typedef DownloadProgressCallback =
    void Function({required int receivedBytes, required int totalBytes});
typedef TemporaryDirectoryReader = Future<Directory> Function();
typedef InstallerLauncher =
    Future<void> Function(
      String installerPath,
      String applicationPath,
      List<String> arguments,
    );

class AppUpdateInstallerService {
  AppUpdateInstallerService({
    http.Client? client,
    bool? supportsAutomaticInstallation,
    TemporaryDirectoryReader? temporaryDirectoryReader,
    InstallerLauncher? installerLauncher,
  }) : _client = client,
       _supportsAutomaticInstallation =
           supportsAutomaticInstallation ?? Platform.isWindows,
       _temporaryDirectoryReader =
           temporaryDirectoryReader ?? getTemporaryDirectory,
       _installerLauncher = installerLauncher ?? _launchInstaller;

  final http.Client? _client;
  final bool _supportsAutomaticInstallation;
  final TemporaryDirectoryReader _temporaryDirectoryReader;
  final InstallerLauncher _installerLauncher;

  bool get supportsAutomaticInstallation => _supportsAutomaticInstallation;

  Future<File> downloadInstaller(
    GitHubReleaseAsset asset, {
    required DownloadProgressCallback onProgress,
  }) async {
    if (!supportsAutomaticInstallation) {
      throw const AppUpdateInstallerException(
        'Automatic update installation is currently supported on Windows only.',
      );
    }

    final client = _client ?? http.Client();
    final request = http.Request('GET', asset.downloadUrl);
    final tempDirectory = await _temporaryDirectoryReader();
    final outputFile = File(
      '${tempDirectory.path}${Platform.pathSeparator}${path.basename(asset.name)}',
    );
    final sink = outputFile.openWrite();

    try {
      final response = await client.send(request);
      if (response.statusCode != 200) {
        throw AppUpdateInstallerException(
          'GitHub returned status ${response.statusCode} while downloading the installer.',
        );
      }

      final totalBytes = response.contentLength ?? asset.size;
      var receivedBytes = 0;
      await for (final bytes in response.stream) {
        sink.add(bytes);
        receivedBytes += bytes.length;
        onProgress(receivedBytes: receivedBytes, totalBytes: totalBytes);
      }
      await sink.flush();
      await sink.close();
      return outputFile;
    } catch (_) {
      await sink.close();
      if (await outputFile.exists()) {
        await outputFile.delete();
      }
      rethrow;
    } finally {
      if (_client == null) {
        client.close();
      }
    }
  }

  Future<void> installAndRestart(
    File installer, {
    String? applicationPath,
  }) async {
    if (!supportsAutomaticInstallation) {
      throw const AppUpdateInstallerException(
        'Automatic update installation is currently supported on Windows only.',
      );
    }
    if (!await installer.exists()) {
      throw const AppUpdateInstallerException(
        'The downloaded update installer could not be found.',
      );
    }

    await _installerLauncher(
      installer.path,
      applicationPath ?? Platform.resolvedExecutable,
      const [
        '/VERYSILENT',
        '/SUPPRESSMSGBOXES',
        '/CLOSEAPPLICATIONS',
        '/NORESTARTAPPLICATIONS',
        '/NORESTART',
        '/FRAMESELFUPDATELAUNCHER',
      ],
    );
  }

  static Future<void> _launchInstaller(
    String installerPath,
    String applicationPath,
    List<String> arguments,
  ) async {
    final launcher = File(
      '${File(installerPath).parent.path}${Platform.pathSeparator}'
      'framesketch_update_launcher.cmd',
    );
    final installerCommand = _quoteForBatchFile(installerPath);
    final applicationCommand = _quoteForBatchFile(applicationPath);
    final setupArguments = arguments.join(' ');

    await launcher.writeAsString(
      '@echo off\r\n'
      'start "" /wait $installerCommand $setupArguments\r\n'
      'start "" $applicationCommand\r\n'
      'del "%~f0"\r\n',
      flush: true,
    );

    await Process.start('cmd.exe', [
      '/c',
      launcher.path,
    ], mode: ProcessStartMode.detached);
  }

  static String _quoteForBatchFile(String value) {
    return '"${value.replaceAll('"', '""')}"';
  }
}

class AppUpdateInstallerException implements Exception {
  const AppUpdateInstallerException(this.message);

  final String message;

  @override
  String toString() => message;
}
