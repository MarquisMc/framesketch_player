import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/annotation_data.dart';
import '../models/project_library_entry.dart';
import 'annotation_storage_service.dart';
import 'ffprobe_service.dart';

class ProjectLibraryService {
  static const String _projectsKey = 'project_library_entries';
  final FFprobeService _ffprobeService;
  final AnnotationStorageService _annotationStorageService;

  ProjectLibraryService({
    FFprobeService? ffprobeService,
    AnnotationStorageService? annotationStorageService,
  }) : _ffprobeService = ffprobeService ?? FFprobeService(),
       _annotationStorageService =
           annotationStorageService ?? AnnotationStorageService();

  Future<List<ProjectLibraryEntry>> getProjects() async {
    final prefs = await SharedPreferences.getInstance();
    final rawEntries = prefs.getStringList(_projectsKey) ?? const [];
    final projects = <ProjectLibraryEntry>[];

    for (final raw in rawEntries) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is! Map<String, dynamic>) {
          stderr.writeln(
            'Skipping malformed project library entry: expected JSON object.',
          );
          continue;
        }

        projects.add(ProjectLibraryEntry.fromJson(decoded));
      } catch (error) {
        stderr.writeln(
          'Skipping malformed project library entry: $error. Raw entry: $raw',
        );
      }
    }

    projects.sort((a, b) => b.lastOpenedAt.compareTo(a.lastOpenedAt));
    return projects;
  }

  Future<void> upsertProject({
    required AnnotationData annotationData,
    required String sourceLabel,
    String? projectTitle,
    Duration? duration,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final existingProjects = await getProjects();
    final now = DateTime.now();
    final existingIndex = existingProjects.indexWhere(
      (entry) => entry.id == annotationData.videoId,
    );
    final existing = existingIndex >= 0
        ? existingProjects[existingIndex]
        : null;

    final thumbnailPath = await _resolveThumbnailPath(
      annotationData: annotationData,
      duration: duration,
      existingThumbnailPath: existing?.thumbnailPath,
    );

    final entry = ProjectLibraryEntry(
      id: annotationData.videoId,
      title: _buildProjectTitle(
        annotationData: annotationData,
        sourceLabel: sourceLabel,
        explicitTitle: projectTitle,
      ),
      sourcePath: annotationData.videoPath,
      sourceLabel: sourceLabel,
      originalTitle:
          existing?.originalTitle ??
          _buildProjectTitle(
            annotationData: annotationData,
            sourceLabel: sourceLabel,
            explicitTitle: projectTitle,
          ),
      originalSourcePath:
          existing?.originalSourcePath ?? annotationData.videoPath,
      originalSourceLabel: existing?.originalSourceLabel ?? sourceLabel,
      youtubeUrl: annotationData.youtubeUrl,
      thumbnailPath: thumbnailPath,
      thumbnailUrl: _buildThumbnailUrl(annotationData),
      lastOpenedAt: now,
      updatedAt: now,
    );

    if (existingIndex >= 0) {
      existingProjects[existingIndex] = entry;
    } else {
      existingProjects.add(entry);
    }

    existingProjects.sort((a, b) => b.lastOpenedAt.compareTo(a.lastOpenedAt));
    await prefs.setStringList(
      _projectsKey,
      existingProjects.map((project) => jsonEncode(project.toJson())).toList(),
    );
  }

  Future<void> removeProject(String projectId) async {
    final prefs = await SharedPreferences.getInstance();
    final existingProjects = await getProjects();
    existingProjects.removeWhere((entry) => entry.id == projectId);
    await _saveProjects(prefs, existingProjects);
  }

  Future<ProjectLibraryEntry> renameProject({
    required ProjectLibraryEntry project,
    required String newTitle,
  }) async {
    final trimmedTitle = newTitle.trim();
    if (trimmedTitle.isEmpty) {
      throw ArgumentError('Project name cannot be empty.');
    }

    if (project.isYouTubeProject) {
      final renamedProject = project.copyWith(
        title: trimmedTitle,
        updatedAt: DateTime.now(),
      );
      await _replaceProject(renamedProject);
      return renamedProject;
    }

    final validatedTitle = _validateFileName(trimmedTitle);

    final extension = path.extension(project.sourcePath);
    final targetVideoPath = path.join(
      path.dirname(project.sourcePath),
      '$validatedTitle$extension',
    );

    return _renameLocalProject(
      project: project,
      newTitle: validatedTitle,
      targetVideoPath: targetVideoPath,
    );
  }

  String _validateFileName(String fileName) {
    const invalidChars = ['/', '\\', ':', '*', '?', '"', '<', '>', '|'];
    final offendingChars = <String>{};

    for (final char in fileName.split('')) {
      if (invalidChars.contains(char)) {
        offendingChars.add(char);
      }
    }

    final hasControlCharacters = fileName.runes.any((rune) => rune < 32);
    if (hasControlCharacters) {
      offendingChars.add('control characters (U+0000-U+001F)');
    }

    if (offendingChars.isNotEmpty) {
      final sortedOffenders = offendingChars.toList()..sort();
      throw ArgumentError(
        'Project name contains invalid filename characters: '
        '${sortedOffenders.join(', ')}.',
      );
    }

    return fileName;
  }

  Future<ProjectLibraryEntry> revertProjectToOriginalName(
    ProjectLibraryEntry project,
  ) async {
    if (!project.canRevertToOriginalName) {
      return project;
    }

    final originalTitle = project.originalTitle?.trim();
    final originalSourcePath = project.originalSourcePath?.trim();
    if (originalTitle == null ||
        originalTitle.isEmpty ||
        originalSourcePath == null ||
        originalSourcePath.isEmpty) {
      throw ArgumentError('Original project name is unavailable.');
    }

    return _renameLocalProject(
      project: project,
      newTitle: originalTitle,
      targetVideoPath: originalSourcePath,
    );
  }

  Future<ProjectLibraryEntry> _renameLocalProject({
    required ProjectLibraryEntry project,
    required String newTitle,
    required String targetVideoPath,
  }) async {
    final currentVideoFile = File(project.sourcePath);
    if (!await currentVideoFile.exists()) {
      throw FileSystemException(
        'The project video file could not be found.',
        project.sourcePath,
      );
    }

    final normalizedCurrentPath = path.normalize(project.sourcePath);
    final normalizedTargetPath = path.normalize(targetVideoPath);
    final pathChanged = normalizedCurrentPath != normalizedTargetPath;

    if (pathChanged && await File(targetVideoPath).exists()) {
      throw FileSystemException(
        'A file with that name already exists.',
        targetVideoPath,
      );
    }

    final oldAnnotationPath = await _annotationStorageService.getAnnotationPath(
      project.sourcePath,
    );
    final newAnnotationPath = await _annotationStorageService.getAnnotationPath(
      targetVideoPath,
    );
    final annotationPathChanged =
        path.normalize(oldAnnotationPath) != path.normalize(newAnnotationPath);
    final existingAnnotationData = await _annotationStorageService
        .loadAnnotations(project.sourcePath);

    File? renamedVideoFile;
    if (pathChanged) {
      renamedVideoFile = await currentVideoFile.rename(targetVideoPath);
    }

    try {
      if (existingAnnotationData != null) {
        final updatedAnnotationData = existingAnnotationData.copyWith(
          videoPath: targetVideoPath,
          updatedAt: DateTime.now(),
        );
        final saved = await _annotationStorageService.saveAnnotationsToFile(
          updatedAnnotationData,
          newAnnotationPath,
        );
        if (!saved) {
          throw FileSystemException(
            'Failed to update the project annotation file.',
            newAnnotationPath,
          );
        }
      }

      final renamedProject = project.copyWith(
        title: newTitle,
        sourcePath: targetVideoPath,
        sourceLabel: targetVideoPath,
        originalTitle: project.originalTitle ?? project.title,
        originalSourcePath: project.originalSourcePath ?? project.sourcePath,
        originalSourceLabel: project.originalSourceLabel ?? project.sourceLabel,
        updatedAt: DateTime.now(),
      );
      await _replaceProject(renamedProject);
      await _annotationStorageService.renameRecentFile(
        project.sourcePath,
        targetVideoPath,
      );

      if (existingAnnotationData != null && annotationPathChanged) {
        final oldAnnotationFile = File(oldAnnotationPath);
        if (await oldAnnotationFile.exists()) {
          await oldAnnotationFile.delete();
        }
      }

      return renamedProject;
    } catch (error) {
      if (existingAnnotationData != null && annotationPathChanged) {
        try {
          final newAnnotationFile = File(newAnnotationPath);
          if (await newAnnotationFile.exists()) {
            await newAnnotationFile.delete();
          }
        } catch (cleanupError) {
          stderr.writeln(
            'Failed to roll back annotation file rename: $cleanupError',
          );
        }
      }

      if (pathChanged && renamedVideoFile != null) {
        final revertedFile = File(targetVideoPath);
        if (await revertedFile.exists() && !await currentVideoFile.exists()) {
          await revertedFile.rename(project.sourcePath);
        }
      }
      rethrow;
    }
  }

  Future<void> deleteProject(ProjectLibraryEntry project) async {
    final failures = <String>[];

    Future<void> attempt(String step, Future<void> Function() action) async {
      try {
        await action();
      } catch (error) {
        failures.add('$step: $error');
        stderr.writeln('Failed to delete project during $step: $error');
      }
    }

    await attempt('delete annotations', () async {
      final deleted = await _annotationStorageService.deleteAnnotations(
        project.sourcePath,
      );
      if (!deleted) {
        throw StateError('Annotation storage service reported failure.');
      }
    });

    if (project.isLocalFileProject) {
      await attempt('delete video file', () async {
        final videoFile = File(project.sourcePath);
        if (await videoFile.exists()) {
          await videoFile.delete();
        }
      });

      await attempt('delete annotation file', () async {
        final annotationPath = await _annotationStorageService
            .getAnnotationPath(project.sourcePath);
        final annotationFile = File(annotationPath);
        if (await annotationFile.exists()) {
          await annotationFile.delete();
        }
      });
    }

    await attempt('delete thumbnail', () async {
      await _deleteThumbnailIfPresent(project.thumbnailPath);
    });

    await attempt('remove recent file', () async {
      await _annotationStorageService.removeRecentFile(project.sourcePath);
    });

    if (failures.isNotEmpty) {
      throw StateError(
        'Failed to fully delete project "${project.title}": ${failures.join('; ')}',
      );
    }

    await removeProject(project.id);
  }

  String _buildProjectTitle({
    required AnnotationData annotationData,
    required String sourceLabel,
    String? explicitTitle,
  }) {
    final trimmedExplicitTitle = explicitTitle?.trim();
    if (trimmedExplicitTitle != null && trimmedExplicitTitle.isNotEmpty) {
      return trimmedExplicitTitle;
    }

    if (annotationData.youtubeUrl != null &&
        annotationData.youtubeUrl!.trim().isNotEmpty) {
      final videoId = _extractYouTubeVideoId(annotationData);
      return videoId == null || videoId.isEmpty
          ? 'YouTube Project'
          : 'YouTube $videoId';
    }

    final normalized = sourceLabel.replaceAll('\\', '/');
    final fileName = normalized.split('/').last;
    final dotIndex = fileName.lastIndexOf('.');
    return dotIndex > 0 ? fileName.substring(0, dotIndex) : fileName;
  }

  Future<String?> _resolveThumbnailPath({
    required AnnotationData annotationData,
    required Duration? duration,
    required String? existingThumbnailPath,
  }) async {
    if (annotationData.youtubeUrl != null &&
        annotationData.youtubeUrl!.trim().isNotEmpty) {
      return null;
    }

    final videoPath = annotationData.videoPath;
    if (videoPath.trim().isEmpty || !await File(videoPath).exists()) {
      return existingThumbnailPath;
    }

    if (existingThumbnailPath != null &&
        existingThumbnailPath.isNotEmpty &&
        await File(existingThumbnailPath).exists()) {
      return existingThumbnailPath;
    }

    final thumbnailDir = await _thumbnailDirectory();
    final outputPath = path.join(
      thumbnailDir.path,
      '${annotationData.videoId}.jpg',
    );
    if (await File(outputPath).exists()) {
      return outputPath;
    }

    final outputFile = await _ffprobeService.extractFrameAt(
      videoPath,
      _thumbnailTimestamp(duration),
      outputPath,
    );

    if (outputFile == null || !await outputFile.exists()) {
      return existingThumbnailPath;
    }

    return outputFile.path;
  }

  Future<Directory> _thumbnailDirectory() async {
    final appSupportDir = await getApplicationSupportDirectory();
    final dir = Directory(path.join(appSupportDir.path, 'project_thumbnails'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Duration _thumbnailTimestamp(Duration? duration) {
    if (duration == null || duration <= Duration.zero) {
      return const Duration(milliseconds: 500);
    }

    final targetMs = (duration.inMilliseconds * 0.15).round();
    final int clampedMs = targetMs.clamp(300, 3000) as int;
    return Duration(milliseconds: clampedMs);
  }

  String? _buildThumbnailUrl(AnnotationData annotationData) {
    final videoId = _extractYouTubeVideoId(annotationData);
    if (videoId == null || videoId.isEmpty) {
      return null;
    }

    return 'https://img.youtube.com/vi/$videoId/hqdefault.jpg';
  }

  String? _extractYouTubeVideoId(AnnotationData annotationData) {
    final youtubeUrl = annotationData.youtubeUrl?.trim();
    if (youtubeUrl != null && youtubeUrl.isNotEmpty) {
      final uri = Uri.tryParse(youtubeUrl);
      if (uri != null) {
        final queryId = uri.queryParameters['v'];
        if (queryId != null && queryId.isNotEmpty) {
          return queryId;
        }

        final segments = uri.pathSegments.where((segment) => segment.isNotEmpty);
        final normalizedPath = uri.path.toLowerCase();
        if ((normalizedPath.startsWith('/embed') || normalizedPath.contains('embed')) &&
            segments.isNotEmpty) {
          return segments.last;
        }

        if (uri.host.toLowerCase().contains('youtu.be')) {
          if (segments.isNotEmpty) {
            return segments.last;
          }
        }
      }
    }

    if (annotationData.videoPath.startsWith('yt:')) {
      return annotationData.videoPath.substring(3);
    }

    return null;
  }

  Future<void> _replaceProject(ProjectLibraryEntry project) async {
    final prefs = await SharedPreferences.getInstance();
    final existingProjects = await getProjects();
    final existingIndex = existingProjects.indexWhere(
      (entry) => entry.id == project.id,
    );

    if (existingIndex >= 0) {
      existingProjects[existingIndex] = project;
    } else {
      existingProjects.add(project);
    }

    existingProjects.sort((a, b) => b.lastOpenedAt.compareTo(a.lastOpenedAt));
    await _saveProjects(prefs, existingProjects);
  }

  Future<void> _saveProjects(
    SharedPreferences prefs,
    List<ProjectLibraryEntry> projects,
  ) async {
    await prefs.setStringList(
      _projectsKey,
      projects.map((project) => jsonEncode(project.toJson())).toList(),
    );
  }

  Future<void> _deleteThumbnailIfPresent(String? thumbnailPath) async {
    if (thumbnailPath == null || thumbnailPath.isEmpty) {
      return;
    }

    final thumbnailFile = File(thumbnailPath);
    if (await thumbnailFile.exists()) {
      await thumbnailFile.delete();
    }
  }
}
