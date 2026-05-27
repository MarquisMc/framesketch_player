import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:framesketch_player/core/services/app_update_installer_service.dart';
import 'package:framesketch_player/core/services/github_release_update_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  late Directory tempDirectory;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp(
      'framesketch_update_',
    );
  });

  tearDown(() async {
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  test('downloads a Windows installer and reports byte progress', () async {
    final progress = <int>[];
    final service = AppUpdateInstallerService(
      supportsAutomaticInstallation: true,
      temporaryDirectoryReader: () async => tempDirectory,
      client: MockClient((_) async => http.Response.bytes([1, 2, 3, 4], 200)),
    );
    final asset = GitHubReleaseAsset(
      name: 'FrameSketch-Setup-v1.2.0-windows-x64.exe',
      downloadUrl: Uri.parse('https://github.com/example/setup.exe'),
      size: 4,
    );

    final installer = await service.downloadInstaller(
      asset,
      onProgress: ({required receivedBytes, required totalBytes}) {
        progress.add(receivedBytes);
        expect(totalBytes, 4);
      },
    );

    expect(await installer.readAsBytes(), [1, 2, 3, 4]);
    expect(progress.last, 4);
  });

  test('starts the installer with automatic restart arguments', () async {
    String? launchedPath;
    String? restartApplicationPath;
    List<String>? launchedArguments;
    final installer = File(
      '${tempDirectory.path}${Platform.pathSeparator}setup.exe',
    );
    await installer.writeAsBytes([1]);
    final service = AppUpdateInstallerService(
      supportsAutomaticInstallation: true,
      installerLauncher: (path, applicationPath, arguments) async {
        launchedPath = path;
        restartApplicationPath = applicationPath;
        launchedArguments = arguments;
      },
    );

    await service.installAndRestart(
      installer,
      applicationPath: 'C:\\Apps\\FrameSketch\\framesketch_player.exe',
    );

    expect(launchedPath, installer.path);
    expect(
      restartApplicationPath,
      'C:\\Apps\\FrameSketch\\framesketch_player.exe',
    );
    expect(launchedArguments, contains('/CLOSEAPPLICATIONS'));
    expect(launchedArguments, contains('/NORESTARTAPPLICATIONS'));
    expect(launchedArguments, contains('/VERYSILENT'));
    expect(launchedArguments, contains('/FRAMESELFUPDATELAUNCHER'));
  });
}
