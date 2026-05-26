import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/annotation_data.dart';
import '../../../core/models/project_library_entry.dart';
import '../../../core/services/annotation_storage_service.dart';
import '../../../core/services/youtube_video_source_service.dart';
import '../../../core/theme/app_palette.dart';
import '../../annotations/providers/annotation_provider.dart';
import '../providers/player_provider.dart';

typedef LoadingOverlayRunner =
    Future<T> Function<T>({
      required String message,
      required Future<T> Function() action,
      String? cancelLabel,
      VoidCallback? onCancel,
    });

class SourceOpenActions {
  const SourceOpenActions({
    required this.ref,
    required this.navigatorKey,
    required this.scaffoldMessengerKey,
    required this.focusNode,
    required this.isMounted,
    required this.activePalette,
    required this.runWithLoadingOverlay,
    required this.registerCurrentProject,
    required this.showErrorDialog,
  });

  final WidgetRef ref;
  final GlobalKey<NavigatorState> navigatorKey;
  final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey;
  final FocusNode focusNode;
  final bool Function() isMounted;
  final AppPalette Function() activePalette;
  final LoadingOverlayRunner runWithLoadingOverlay;
  final Future<void> Function({String? projectTitle}) registerCurrentProject;
  final void Function(String message) showErrorDialog;

  Future<void> openProject(ProjectLibraryEntry project) async {
    if (project.isYouTubeProject) {
      final youtubeUrl = project.youtubeUrl;
      if (youtubeUrl == null || youtubeUrl.trim().isEmpty) {
        showErrorDialog('This YouTube project is missing its source URL.');
        return;
      }
      await loadYouTubeUrl(youtubeUrl);
      return;
    }

    final sourcePath = project.sourcePath;
    if (sourcePath.trim().isEmpty || !await File(sourcePath).exists()) {
      showErrorDialog(
        'The video file for this project could not be found:\n$sourcePath',
      );
      return;
    }

    await loadInitialVideo(sourcePath);
  }

  Future<void> openRecentFromPalette() async {
    final recent = await AnnotationStorageService().getRecentFiles();
    if (!isMounted()) return;
    if (recent.isEmpty) {
      scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(
          content: const Text('No recent files'),
          backgroundColor: activePalette().warning,
        ),
      );
      return;
    }

    final dialogHostContext = navigatorKey.currentContext;
    if (dialogHostContext == null) return;

    final chosen = await showDialog<String>(
      // ignore: use_build_context_synchronously
      context: dialogHostContext,
      builder: (dialogContext) {
        final palette = AppPalette.of(dialogContext);
        return Dialog(
          child: SizedBox(
            width: 560,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Open Recent',
                      style: TextStyle(
                        color: palette.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                Divider(height: 1, color: palette.border),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: recent.length,
                    itemBuilder: (_, i) {
                      final path = recent[i];
                      final name = path.replaceAll('\\', '/').split('/').last;
                      return ListTile(
                        leading: Icon(
                          Icons.movie_outlined,
                          size: 18,
                          color: palette.textSecondary,
                        ),
                        title: Text(name),
                        subtitle: Text(
                          path,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () => Navigator.of(dialogContext).pop(path),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (chosen != null) {
      await loadInitialVideo(chosen);
    }
  }

  Future<void> loadInitialVideo(String filePath) async {
    if (isAnnotationJsonPath(filePath)) {
      await openAnnotationJsonPath(filePath);
      return;
    }

    final uri = Uri.tryParse(filePath);
    if (uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        looksLikeYouTubeUrl(filePath)) {
      await loadYouTubeUrl(filePath);
      return;
    }

    try {
      await runWithLoadingOverlay(
        message: 'Loading video...',
        action: () async {
          final playerNotifier = ref.read(playerProvider.notifier);
          await playerNotifier.loadVideo(filePath);

          final playerState = ref.read(playerProvider);
          if (playerState.metadata == null) {
            if (isMounted()) {
              showErrorDialog(
                'Failed to load video. The video file may be corrupted or in an unsupported format.',
              );
            }
            return;
          }

          final annotationNotifier = ref.read(annotationProvider.notifier);
          await annotationNotifier.initializeForVideo(
            filePath,
            playerState.metadata!.fps,
          );

          final storageService = AnnotationStorageService();
          await storageService.addToRecentFiles(filePath);
          await registerCurrentProject();

          focusNode.requestFocus();
        },
      );
    } catch (e) {
      if (isMounted()) {
        showErrorDialog('Error opening file: $e');
      }
    }
  }

  Future<void> openDroppedFiles(Iterable<String> filePaths) async {
    for (final filePath in filePaths) {
      if (isSupportedVideoPath(filePath)) {
        await loadInitialVideo(filePath);
        return;
      }
    }

    if (isMounted()) {
      showErrorDialog(
        'No supported video file was dropped. Try an MP4, MOV, MKV, AVI, '
        'WebM, WMV, M4V, MPEG, MPG, TS, MTS, or M2TS file.',
      );
    }
  }

  Future<void> openFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.video,
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) return;
      final filePath = result.files.first.path;
      if (filePath == null) return;

      await runWithLoadingOverlay(
        message: 'Opening file...',
        action: () async {
          final playerNotifier = ref.read(playerProvider.notifier);
          await playerNotifier.loadVideo(filePath);

          final playerState = ref.read(playerProvider);
          if (playerState.metadata == null) {
            if (isMounted()) {
              showErrorDialog(
                'Failed to load video. The video file may be corrupted or in an unsupported format.',
              );
            }
            return;
          }

          final annotationNotifier = ref.read(annotationProvider.notifier);
          await annotationNotifier.initializeForVideo(
            filePath,
            playerState.metadata!.fps,
          );

          final storageService = AnnotationStorageService();
          await storageService.addToRecentFiles(filePath);
          await registerCurrentProject();

          focusNode.requestFocus();
        },
      );
    } catch (e) {
      if (isMounted()) {
        showErrorDialog('Error opening file: $e');
      }
    }
  }

  Future<void> openYouTubeUrl() async {
    final dialogHostContext = navigatorKey.currentContext;
    if (dialogHostContext == null || !isMounted()) {
      return;
    }

    String enteredUrl = '';
    final url = await showDialog<String>(
      context: dialogHostContext,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Open YouTube URL'),
          content: TextField(
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Enter YouTube Link...',
            ),
            onChanged: (value) => enteredUrl = value,
            onSubmitted: (value) => Navigator.of(dialogContext).pop(value),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(enteredUrl),
              child: const Text('Open'),
            ),
          ],
        );
      },
    );

    if (url == null || url.trim().isEmpty) {
      focusNode.requestFocus();
      return;
    }

    await loadYouTubeUrl(url);
  }

  Future<void> loadYouTubeUrl(String url) async {
    try {
      if (!looksLikeYouTubeUrl(url)) {
        showErrorDialog('Please enter a valid YouTube URL.');
        return;
      }

      await runWithLoadingOverlay(
        message: 'Loading YouTube video...',
        action: () async {
          final youtubeService = YouTubeVideoSourceService();
          final resolved = await youtubeService.resolve(url);

          final playerNotifier = ref.read(playerProvider.notifier);
          await playerNotifier.loadNetworkVideo(
            mediaUrl: resolved.streamUri.toString(),
            sourceLabel: resolved.canonicalUrl,
            displayLabel: resolved.title,
            externalAudioUrl: resolved.externalAudioUri?.toString(),
          );

          final playerState = ref.read(playerProvider);
          if (playerState.metadata == null) {
            if (isMounted()) {
              showErrorDialog('Failed to load YouTube video stream.');
            }
            return;
          }

          final annotationNotifier = ref.read(annotationProvider.notifier);
          await annotationNotifier.initializeForYouTubeVideo(
            youtubeVideoId: resolved.videoId,
            youtubeUrl: resolved.canonicalUrl,
            fps: playerState.metadata!.fps,
          );
          await registerCurrentProject(projectTitle: resolved.title);

          if (isMounted()) {
            scaffoldMessengerKey.currentState?.showSnackBar(
              SnackBar(
                content: Text(
                  'Loaded YouTube video: ${resolved.title} (${_qualitySummary(resolved, playerState)})',
                ),
                backgroundColor: activePalette().success,
              ),
            );
          }

          focusNode.requestFocus();
        },
      );
    } catch (e) {
      if (isMounted()) {
        if (e is YouTubeSourceLoadException) {
          showErrorDialog(e.userMessage);
        } else {
          showErrorDialog('Error loading YouTube URL: $e');
        }
      }
    }
  }

  Future<void> openAnnotationJson() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['framesketch', 'json'],
        dialogTitle: 'Select Annotation File',
      );

      if (result == null || result.files.isEmpty) return;
      final filePath = result.files.first.path;
      if (filePath == null) return;

      await openAnnotationJsonPath(filePath);
    } catch (e) {
      if (isMounted()) {
        if (e is YouTubeSourceLoadException) {
          showErrorDialog(
            'The annotation file was loaded, but the linked YouTube video could not be opened.\n\n${e.userMessage}',
          );
        } else {
          showErrorDialog('Error opening annotation file: $e');
        }
      }
    }
  }

  Future<void> openAnnotationJsonPath(String annotationPath) async {
    try {
      await runWithLoadingOverlay(
        message: 'Loading annotations...',
        action: () async {
          final storageService = AnnotationStorageService();
          final data = await storageService.loadAnnotationsFromFile(
            annotationPath,
          );
          if (data == null) {
            showErrorDialog('Unable to read annotation file.');
            return;
          }

          await loadSourceForAnnotationData(data);
          await registerCurrentProject();

          if (isMounted()) {
            scaffoldMessengerKey.currentState?.showSnackBar(
              SnackBar(
                content: Text(
                  'Loaded annotations from ${File(annotationPath).path}',
                ),
                backgroundColor: activePalette().success,
              ),
            );
          }

          focusNode.requestFocus();
        },
      );
    } catch (e) {
      if (isMounted()) {
        showErrorDialog('Error opening annotation file: $e');
      }
    }
  }

  Future<void> loadSourceForAnnotationData(AnnotationData data) async {
    final playerNotifier = ref.read(playerProvider.notifier);
    final annotationNotifier = ref.read(annotationProvider.notifier);

    if (data.youtubeUrl != null && data.youtubeUrl!.trim().isNotEmpty) {
      final youtubeService = YouTubeVideoSourceService();
      final storageService = AnnotationStorageService();
      final resolved = await youtubeService.resolve(data.youtubeUrl!);
      await playerNotifier.loadNetworkVideo(
        mediaUrl: resolved.streamUri.toString(),
        sourceLabel: resolved.canonicalUrl,
        displayLabel: resolved.title,
        externalAudioUrl: resolved.externalAudioUri?.toString(),
      );
      if (ref.read(playerProvider).metadata == null) {
        throw StateError('Failed to load YouTube source from annotation JSON');
      }
      annotationNotifier.initializeFromAnnotationData(
        data.copyWith(
          videoPath: storageService.buildYouTubeAnnotationKey(resolved.videoId),
          youtubeUrl: resolved.canonicalUrl,
        ),
      );
      return;
    }

    final localPath = data.videoPath;
    if (localPath.isEmpty || !await File(localPath).exists()) {
      throw StateError(
        'Annotation JSON references a local video that was not found:\n$localPath',
      );
    }

    await playerNotifier.loadVideo(localPath);
    if (ref.read(playerProvider).metadata == null) {
      throw StateError('Failed to load local video from annotation JSON');
    }
    annotationNotifier.initializeFromAnnotationData(data);
  }

  String _qualitySummary(
    YouTubeResolvedSource resolved,
    PlayerState playerState,
  ) {
    final qualityParts = <String>[];
    final selectedLabel = resolved.selectedQualityLabel?.trim();
    final selectedWidth = resolved.selectedWidth;
    final selectedHeight = resolved.selectedHeight;

    if (selectedLabel != null && selectedLabel.isNotEmpty) {
      qualityParts.add(selectedLabel);
    }

    if (selectedWidth != null &&
        selectedWidth > 0 &&
        selectedHeight != null &&
        selectedHeight > 0) {
      qualityParts.add('${selectedWidth}x$selectedHeight');
    }

    if (resolved.usesHls) {
      qualityParts.add('HLS');
    }
    if (resolved.externalAudioUri != null) {
      qualityParts.add('split A/V');
    }

    if (qualityParts.isEmpty && playerState.metadata != null) {
      qualityParts.add(
        '${playerState.metadata!.width}x${playerState.metadata!.height}',
      );
    }

    return qualityParts.join(' | ');
  }
}

bool looksLikeYouTubeUrl(String value) {
  final uri = Uri.tryParse(value.trim());
  if (uri == null) return false;
  final host = uri.host.toLowerCase();
  return host.contains('youtube.com') || host.contains('youtu.be');
}

bool isAnnotationJsonPath(String value) {
  final lower = value.toLowerCase();
  return lower.endsWith('.framesketch') ||
      lower.endsWith('.annotations.json') ||
      lower.endsWith('.json');
}

bool isSupportedVideoPath(String value) {
  final lower = value.toLowerCase();
  return const <String>[
    '.mp4',
    '.mov',
    '.mkv',
    '.avi',
    '.webm',
    '.wmv',
    '.m4v',
    '.mpeg',
    '.mpg',
    '.ts',
    '.mts',
    '.m2ts',
  ].any(lower.endsWith);
}
