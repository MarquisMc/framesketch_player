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

  Future<ProjectLibraryEntry> togglePin(ProjectLibraryEntry project) async {
    final now = DateTime.now();
    final updated = project.copyWith(
      isPinned: !project.isPinned,
      pinnedAt: project.isPinned ? null : now,
      clearPinnedAt: project.isPinned,
      updatedAt: now,
    );
    await _replaceProject(updated);
    return updated;
  }

  Future<ProjectLibraryEntry> duplicateProject(
    ProjectLibraryEntry project,
  ) async {
    final now = DateTime.now();
    final newTitle = '${project.title} (copy)';
    if (project.isLocalFileProject) {
      return _duplicateLocalProject(
        project: project,
        duplicateTitle: newTitle,
        now: now,
      );
    }

    final newAnnotationKey = 'yt:copy_${now.millisecondsSinceEpoch}';
    final newId = _annotationStorageService.generateVideoId(newAnnotationKey);

    final existingAnnotationData = await _annotationStorageService
        .loadAnnotations(project.sourcePath);
    if (existingAnnotationData != null) {
      final duplicateAnnotationPath = await _annotationStorageService
          .getAnnotationPath(newAnnotationKey);
      final duplicateAnnotationData = existingAnnotationData.copyWith(
        videoId: newId,
        videoPath: newAnnotationKey,
        updatedAt: now,
      );
      await _annotationStorageService.saveAnnotationsToFile(
        duplicateAnnotationData,
        duplicateAnnotationPath,
      );
    }

    final duplicate = ProjectLibraryEntry(
      id: newId,
      title: newTitle,
      sourcePath: newAnnotationKey,
      sourceLabel: project.sourceLabel,
      originalTitle: newTitle,
      originalSourcePath: project.originalSourcePath,
      originalSourceLabel: project.originalSourceLabel,
      youtubeUrl: project.youtubeUrl,
      thumbnailPath: project.thumbnailPath,
      thumbnailUrl: project.thumbnailUrl,
      lastOpenedAt: now,
      updatedAt: now,
    );

    final prefs = await SharedPreferences.getInstance();
    final existingProjects = await getProjects();
    existingProjects.add(duplicate);
    existingProjects.sort((a, b) => b.lastOpenedAt.compareTo(a.lastOpenedAt));
    await _saveProjects(prefs, existingProjects);
    return duplicate;
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
    final int clampedMs = targetMs.clamp(300, 3000);
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

        final segments = uri.pathSegments.where(
          (segment) => segment.isNotEmpty,
        );
        final normalizedPath = uri.path.toLowerCase();
        if ((normalizedPath.startsWith('/embed') ||
                normalizedPath.contains('embed')) &&
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

  Future<ProjectLibraryEntry> _duplicateLocalProject({
    required ProjectLibraryEntry project,
    required String duplicateTitle,
    required DateTime now,
  }) async {
    final sourceFile = File(project.sourcePath);
    if (!await sourceFile.exists()) {
      throw FileSystemException(
        'The project video file could not be found.',
        project.sourcePath,
      );
    }

    final duplicatePath = await _nextAvailableDuplicateVideoPath(
      sourcePath: project.sourcePath,
      desiredTitle: duplicateTitle,
    );
    await sourceFile.copy(duplicatePath);

    final duplicateId = _annotationStorageService.generateVideoId(
      duplicatePath,
    );
    final existingAnnotationData = await _annotationStorageService
        .loadAnnotations(project.sourcePath);
    if (existingAnnotationData != null) {
      final duplicateAnnotationPath = await _annotationStorageService
          .getAnnotationPath(duplicatePath);
      final duplicateAnnotationData = existingAnnotationData.copyWith(
        videoId: duplicateId,
        videoPath: duplicatePath,
        updatedAt: now,
      );
      final saved = await _annotationStorageService.saveAnnotationsToFile(
        duplicateAnnotationData,
        duplicateAnnotationPath,
      );
      if (!saved) {
        final copiedFile = File(duplicatePath);
        if (await copiedFile.exists()) {
          await copiedFile.delete();
        }
        throw FileSystemException(
          'Failed to duplicate the project annotation file.',
          duplicateAnnotationPath,
        );
      }
    }

    final duplicateThumbnailPath = await _duplicateThumbnailForProject(
      projectId: duplicateId,
      sourceThumbnailPath: project.thumbnailPath,
    );

    final duplicate = ProjectLibraryEntry(
      id: duplicateId,
      title: path.basenameWithoutExtension(duplicatePath),
      sourcePath: duplicatePath,
      sourceLabel: duplicatePath,
      originalTitle: path.basenameWithoutExtension(duplicatePath),
      originalSourcePath: duplicatePath,
      originalSourceLabel: duplicatePath,
      youtubeUrl: project.youtubeUrl,
      thumbnailPath: duplicateThumbnailPath,
      thumbnailUrl: project.thumbnailUrl,
      lastOpenedAt: now,
      updatedAt: now,
    );

    final prefs = await SharedPreferences.getInstance();
    final existingProjects = await getProjects();
    existingProjects.add(duplicate);
    existingProjects.sort((a, b) => b.lastOpenedAt.compareTo(a.lastOpenedAt));
    try {
      await _saveProjects(prefs, existingProjects);
    } catch (e) {
      // Roll back orphaned files if persistence fails.
      try {
        final copiedFile = File(duplicatePath);
        if (await copiedFile.exists()) {
          await copiedFile.delete();
        }
      } catch (cleanupError) {
        stderr.writeln(
          'Failed to roll back duplicate video file: $cleanupError',
        );
      }
      try {
        final duplicateAnnotationPath = await _annotationStorageService
            .getAnnotationPath(duplicatePath);
        final annotationFile = File(duplicateAnnotationPath);
        if (await annotationFile.exists()) {
          await annotationFile.delete();
        }
      } catch (cleanupError) {
        stderr.writeln(
          'Failed to roll back duplicate annotation file: $cleanupError',
        );
      }
      try {
        await _deleteThumbnailIfPresent(duplicateThumbnailPath);
      } catch (cleanupError) {
        stderr.writeln(
          'Failed to roll back duplicate thumbnail: $cleanupError',
        );
      }
      rethrow;
    }
    return duplicate;
  }

  Future<String> _nextAvailableDuplicateVideoPath({
    required String sourcePath,
    required String desiredTitle,
  }) async {
    final directory = path.dirname(sourcePath);
    final extension = path.extension(sourcePath);
    final sanitizedTitle = _validateFileName(desiredTitle.trim());
    var candidatePath = path.join(directory, '$sanitizedTitle$extension');
    var duplicateIndex = 2;

    while (await File(candidatePath).exists()) {
      candidatePath = path.join(
        directory,
        '$sanitizedTitle $duplicateIndex$extension',
      );
      duplicateIndex += 1;
    }

    return candidatePath;
  }

  Future<String?> _duplicateThumbnailForProject({
    required String projectId,
    required String? sourceThumbnailPath,
  }) async {
    if (sourceThumbnailPath == null || sourceThumbnailPath.isEmpty) {
      return null;
    }

    final sourceFile = File(sourceThumbnailPath);
    if (!await sourceFile.exists()) {
      return null;
    }

    final extension = path.extension(sourceThumbnailPath);
    final thumbnailDir = await _thumbnailDirectory();
    final destinationPath = path.join(
      thumbnailDir.path,
      '$projectId$extension',
    );
    await sourceFile.copy(destinationPath);
    return destinationPath;
  }
}
