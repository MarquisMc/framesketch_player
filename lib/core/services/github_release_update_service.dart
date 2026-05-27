import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

typedef InstalledVersionReader = Future<String> Function();

class GitHubReleaseUpdateService {
  GitHubReleaseUpdateService({
    http.Client? client,
    InstalledVersionReader? installedVersionReader,
    this.owner = 'MarquisMc',
    this.repository = 'framesketch_player',
  }) : _client = client,
       _installedVersionReader =
           installedVersionReader ?? _readInstalledVersion;

  final http.Client? _client;
  final InstalledVersionReader _installedVersionReader;
  final String owner;
  final String repository;

  Future<UpdateCheckResult> checkForUpdate() async {
    final installedVersion = await _installedVersionReader();
    final client = _client ?? http.Client();

    try {
      final response = await client.get(
        Uri.https(
          'api.github.com',
          '/repos/$owner/$repository/releases/latest',
        ),
        headers: const {
          'Accept': 'application/vnd.github+json',
          'X-GitHub-Api-Version': '2022-11-28',
        },
      );

      if (response.statusCode == 404) {
        return UpdateCheckResult(
          installedVersion: installedVersion,
          latestRelease: null,
        );
      }

      if (response.statusCode != 200) {
        throw UpdateCheckException(
          'GitHub returned status ${response.statusCode} while checking releases.',
        );
      }

      final body = jsonDecode(response.body);
      if (body is! Map<String, dynamic>) {
        throw const UpdateCheckException(
          'GitHub returned an unexpected release response.',
        );
      }

      final tagName = body['tag_name'];
      final releaseUrl = body['html_url'];
      if (tagName is! String || releaseUrl is! String) {
        throw const UpdateCheckException(
          'The latest GitHub release is missing its tag or URL.',
        );
      }

      return UpdateCheckResult(
        installedVersion: installedVersion,
        latestRelease: GitHubRelease(
          tagName: tagName,
          pageUrl: Uri.parse(releaseUrl),
          name: body['name'] is String ? body['name'] as String : null,
          assets: _parseAssets(body['assets']),
        ),
      );
    } finally {
      if (_client == null) {
        client.close();
      }
    }
  }

  static Future<String> _readInstalledVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    return packageInfo.version;
  }

  static List<GitHubReleaseAsset> _parseAssets(Object? assets) {
    if (assets is! List<dynamic>) return const [];

    return assets
        .whereType<Map<String, dynamic>>()
        .map((asset) {
          final name = asset['name'];
          final downloadUrl = asset['browser_download_url'];
          final size = asset['size'];
          if (name is! String || downloadUrl is! String || size is! int) {
            return null;
          }
          return GitHubReleaseAsset(
            name: name,
            downloadUrl: Uri.parse(downloadUrl),
            size: size,
          );
        })
        .whereType<GitHubReleaseAsset>()
        .toList(growable: false);
  }
}

class UpdateCheckResult {
  const UpdateCheckResult({
    required this.installedVersion,
    required this.latestRelease,
  });

  final String installedVersion;
  final GitHubRelease? latestRelease;

  bool get hasUpdate =>
      latestRelease != null &&
      compareAppVersions(latestRelease!.tagName, installedVersion) > 0;
}

class GitHubRelease {
  const GitHubRelease({
    required this.tagName,
    required this.pageUrl,
    this.name,
    this.assets = const [],
  });

  final String tagName;
  final Uri pageUrl;
  final String? name;
  final List<GitHubReleaseAsset> assets;

  String get displayVersion => tagName.replaceFirst(RegExp(r'^[vV]'), '');

  GitHubReleaseAsset? get windowsInstallerAsset {
    for (final asset in assets) {
      final lowerName = asset.name.toLowerCase();
      if (lowerName.endsWith('.exe') &&
          lowerName.contains('setup') &&
          lowerName.contains('windows')) {
        return asset;
      }
    }
    return null;
  }
}

class GitHubReleaseAsset {
  const GitHubReleaseAsset({
    required this.name,
    required this.downloadUrl,
    required this.size,
  });

  final String name;
  final Uri downloadUrl;
  final int size;
}

class UpdateCheckException implements Exception {
  const UpdateCheckException(this.message);

  final String message;

  @override
  String toString() => message;
}

int compareAppVersions(String first, String second) {
  final a = _ParsedVersion.parse(first);
  final b = _ParsedVersion.parse(second);

  for (var i = 0; i < 3; i++) {
    final comparison = a.parts[i].compareTo(b.parts[i]);
    if (comparison != 0) return comparison;
  }

  if (a.prerelease == null && b.prerelease != null) return 1;
  if (a.prerelease != null && b.prerelease == null) return -1;
  return (a.prerelease ?? '').compareTo(b.prerelease ?? '');
}

class _ParsedVersion {
  const _ParsedVersion(this.parts, this.prerelease);

  final List<int> parts;
  final String? prerelease;

  factory _ParsedVersion.parse(String input) {
    final normalized = input.trim().replaceFirst(RegExp(r'^[vV]'), '');
    final withoutBuild = normalized.split('+').first;
    final prereleaseIndex = withoutBuild.indexOf('-');
    final version = prereleaseIndex < 0
        ? withoutBuild
        : withoutBuild.substring(0, prereleaseIndex);
    final rawParts = version.split('.');
    final parts = List<int>.generate(
      3,
      (index) =>
          index < rawParts.length ? int.tryParse(rawParts[index]) ?? 0 : 0,
    );
    final prerelease = prereleaseIndex < 0
        ? null
        : withoutBuild.substring(prereleaseIndex + 1);
    return _ParsedVersion(parts, prerelease);
  }
}
