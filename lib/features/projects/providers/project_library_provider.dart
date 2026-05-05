import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/annotation_data.dart';
import '../../../core/models/project_library_entry.dart';
import '../../../core/services/project_library_service.dart';

class ProjectLibraryState {
  final List<ProjectLibraryEntry> projects;
  final bool isLoading;
  final Object? error;

  const ProjectLibraryState({
    this.projects = const [],
    this.isLoading = false,
    this.error,
  });

  ProjectLibraryState copyWith({
    List<ProjectLibraryEntry>? projects,
    bool? isLoading,
    Object? error,
    bool clearError = false,
  }) {
    return ProjectLibraryState(
      projects: projects ?? this.projects,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class ProjectLibraryNotifier extends StateNotifier<ProjectLibraryState> {
  ProjectLibraryNotifier({ProjectLibraryService? service})
    : _service = service ?? ProjectLibraryService(),
      super(const ProjectLibraryState()) {
    unawaited(loadProjects());
  }

  final ProjectLibraryService _service;

  Future<void> loadProjects() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final projects = await _service.getProjects();
      state = state.copyWith(
        projects: projects,
        isLoading: false,
        clearError: true,
      );
    } catch (e) {
      debugPrint('Error loading projects: $e');
      state = state.copyWith(isLoading: false, error: e);
    }
  }

  Future<void> upsertProject({
    required AnnotationData annotationData,
    required String sourceLabel,
    String? projectTitle,
    Duration? duration,
  }) async {
    await _service.upsertProject(
      annotationData: annotationData,
      sourceLabel: sourceLabel,
      projectTitle: projectTitle,
      duration: duration,
    );
    await loadProjects();
  }

  Future<void> renameProject({
    required ProjectLibraryEntry project,
    required String newTitle,
  }) async {
    await _service.renameProject(project: project, newTitle: newTitle);
    await loadProjects();
  }

  Future<void> deleteProject(ProjectLibraryEntry project) async {
    await _service.deleteProject(project);
    await loadProjects();
  }

  Future<void> revertProjectToOriginalName(ProjectLibraryEntry project) async {
    await _service.revertProjectToOriginalName(project);
    await loadProjects();
  }

  Future<void> togglePin(ProjectLibraryEntry project) async {
    await _service.togglePin(project);
    await loadProjects();
  }

  Future<void> duplicateProject(ProjectLibraryEntry project) async {
    await _service.duplicateProject(project);
    await loadProjects();
  }
}

final projectLibraryProvider =
    StateNotifierProvider<ProjectLibraryNotifier, ProjectLibraryState>((ref) {
      return ProjectLibraryNotifier();
    });
