import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:framesketch_player/core/services/github_release_update_service.dart';

void main() {
  group('compareAppVersions', () {
    test('accepts GitHub tags prefixed with v', () {
      expect(compareAppVersions('v1.2.0', '1.1.9'), greaterThan(0));
    });

    test('does not consider build metadata a newer app version', () {
      expect(compareAppVersions('1.0.0+4', '1.0.0+1'), equals(0));
    });

    test('considers a stable release newer than its prerelease', () {
      expect(compareAppVersions('v2.0.0', '2.0.0-beta.1'), greaterThan(0));
    });
  });

  test('UpdateCheckResult identifies an available newer release', () {
    final result = UpdateCheckResult(
      installedVersion: '1.0.0',
      latestRelease: GitHubRelease(
        tagName: 'v1.1.0',
        pageUrl: Uri.parse('https://github.com/example/releases/tag/v1.1.0'),
      ),
    );

    expect(result.hasUpdate, isTrue);
  });

  test('returns the latest GitHub release when one is published', () async {
    final service = GitHubReleaseUpdateService(
      installedVersionReader: () async => '1.0.0',
      client: MockClient(
        (_) async => http.Response(
          '{"tag_name":"v1.2.0","html_url":"https://github.com/'
          'MarquisMc/framesketch_player/releases/tag/v1.2.0",'
          '"assets":[{"name":"FrameSketch-Setup-v1.2.0-windows-x64.exe",'
          '"browser_download_url":"https://github.com/example/setup.exe",'
          '"size":2048}]}',
          200,
        ),
      ),
    );

    final result = await service.checkForUpdate();

    expect(result.hasUpdate, isTrue);
    expect(result.latestRelease?.displayVersion, '1.2.0');
    expect(
      result.latestRelease?.windowsInstallerAsset?.name,
      'FrameSketch-Setup-v1.2.0-windows-x64.exe',
    );
  });

  test(
    'handles repositories that do not have a published release yet',
    () async {
      final service = GitHubReleaseUpdateService(
        installedVersionReader: () async => '1.0.0',
        client: MockClient((_) async => http.Response('', 404)),
      );

      final result = await service.checkForUpdate();

      expect(result.hasUpdate, isFalse);
      expect(result.latestRelease, isNull);
    },
  );
}
