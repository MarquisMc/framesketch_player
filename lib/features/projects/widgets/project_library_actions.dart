import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/project_library_entry.dart';
import '../../../core/theme/app_palette.dart';
import '../providers/project_library_provider.dart';
import 'project_browser.dart';

typedef LoadingOverlayRunner =
    Future<T> Function<T>({
      required String message,
      required Future<T> Function() action,
      String? cancelLabel,
      VoidCallback? onCancel,
    });

class ProjectLibraryActions {
  const ProjectLibraryActions({
    required this.ref,
    required this.navigatorKey,
    required this.scaffoldMessengerKey,
    required this.focusNode,
    required this.isMounted,
    required this.activePalette,
    required this.runWithLoadingOverlay,
    required this.openProject,
    required this.showErrorDialog,
  });

  final WidgetRef ref;
  final GlobalKey<NavigatorState> navigatorKey;
  final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey;
  final FocusNode focusNode;
  final bool Function() isMounted;
  final AppPalette Function() activePalette;
  final LoadingOverlayRunner runWithLoadingOverlay;
  final Future<void> Function(ProjectLibraryEntry project) openProject;
  final void Function(String message) showErrorDialog;

  Future<void> openProjectsDialog() async {
    final dialogHostContext = navigatorKey.currentContext;
    if (dialogHostContext == null || !isMounted()) {
      return;
    }

    final selectedProject = await showDialog<ProjectLibraryEntry>(
      context: dialogHostContext,
      builder: (dialogContext) {
        return Dialog(
          insetPadding: const EdgeInsets.all(24),
          child: SizedBox(
            width: 1040,
            height: 720,
            child: Consumer(
              builder: (context, ref, _) {
                final projectLibraryState = ref.watch(projectLibraryProvider);
                return ProjectBrowser(
                  projects: projectLibraryState.projects,
                  isLoading: projectLibraryState.isLoading,
                  onOpenProject: (project) {
                    Navigator.of(dialogContext).pop(project);
                  },
                  onRenameProject: renameProjectFromBrowser,
                  onRevertProjectName: revertProjectNameFromBrowser,
                  onDeleteProject: deleteProjectFromBrowser,
                  onPinProject: pinProjectFromBrowser,
                  onDuplicateProject: duplicateProjectFromBrowser,
                  onRefresh: loadProjects,
                );
              },
            ),
          ),
        );
      },
    );

    if (selectedProject != null) {
      await openProject(selectedProject);
    }

    focusNode.requestFocus();
  }

  Future<void> renameProjectFromBrowser(ProjectLibraryEntry project) async {
    final dialogHostContext = navigatorKey.currentContext;
    if (dialogHostContext == null || !isMounted()) {
      return;
    }

    var pendingTitle = project.title;
    final renamedTitle = await showDialog<String>(
      context: dialogHostContext,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Rename Project'),
          content: TextFormField(
            initialValue: project.title,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Project name'),
            onChanged: (value) => pendingTitle = value,
            onFieldSubmitted: (value) => Navigator.of(dialogContext).pop(value),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(pendingTitle),
              child: const Text('Rename'),
            ),
          ],
        );
      },
    );

    if (renamedTitle == null) {
      return;
    }

    final trimmedTitle = renamedTitle.trim();
    if (trimmedTitle.isEmpty || trimmedTitle == project.title) {
      return;
    }

    try {
      await runWithLoadingOverlay(
        message: 'Renaming project...',
        action: () async {
          await ref
              .read(projectLibraryProvider.notifier)
              .renameProject(project: project, newTitle: trimmedTitle);
        },
      );

      if (!isMounted()) return;
      scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text('Renamed project to $trimmedTitle'),
          backgroundColor: activePalette().success,
        ),
      );
    } catch (e) {
      if (isMounted()) {
        showErrorDialog('Error renaming project: $e');
      }
    } finally {
      focusNode.requestFocus();
    }
  }

  Future<void> deleteProjectFromBrowser(ProjectLibraryEntry project) async {
    final dialogHostContext = navigatorKey.currentContext;
    if (dialogHostContext == null || !isMounted()) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: dialogHostContext,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Project'),
          content: Text(
            project.isYouTubeProject
                ? 'Delete "${project.title}" from the library and remove its saved annotation data?'
                : 'Delete "${project.title}" from the library and permanently remove its video file and annotation file from this machine?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    try {
      await runWithLoadingOverlay(
        message: 'Deleting project...',
        action: () async {
          await ref
              .read(projectLibraryProvider.notifier)
              .deleteProject(project);
        },
      );

      if (!isMounted()) return;
      scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text('Deleted project ${project.title}'),
          backgroundColor: activePalette().success,
        ),
      );
    } catch (e) {
      if (isMounted()) {
        showErrorDialog('Error deleting project: $e');
      }
    } finally {
      focusNode.requestFocus();
    }
  }

  Future<void> revertProjectNameFromBrowser(ProjectLibraryEntry project) async {
    if (!project.canRevertToOriginalName) {
      return;
    }

    final dialogHostContext = navigatorKey.currentContext;
    if (dialogHostContext == null || !isMounted()) {
      return;
    }

    final originalTitle = project.originalTitle ?? project.title;
    final confirmed = await showDialog<bool>(
      context: dialogHostContext,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Revert Project Name'),
          content: Text(
            'Rename "${project.title}" back to "$originalTitle" and restore the original filename on disk?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Revert'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    try {
      await runWithLoadingOverlay(
        message: 'Reverting project name...',
        action: () async {
          await ref
              .read(projectLibraryProvider.notifier)
              .revertProjectToOriginalName(project);
        },
      );

      if (!isMounted()) return;
      scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text('Reverted project name to $originalTitle'),
          backgroundColor: activePalette().success,
        ),
      );
    } catch (e) {
      if (isMounted()) {
        showErrorDialog('Error reverting project name: $e');
      }
    } finally {
      focusNode.requestFocus();
    }
  }

  Future<void> pinProjectFromBrowser(ProjectLibraryEntry project) async {
    try {
      await runWithLoadingOverlay(
        message: 'Updating pin...',
        action: () async {
          await ref.read(projectLibraryProvider.notifier).togglePin(project);
        },
      );
    } catch (e) {
      if (isMounted()) {
        showErrorDialog('Error updating pin: $e');
      }
    } finally {
      focusNode.requestFocus();
    }
  }

  Future<void> duplicateProjectFromBrowser(ProjectLibraryEntry project) async {
    try {
      await runWithLoadingOverlay(
        message: 'Duplicating project...',
        action: () async {
          await ref
              .read(projectLibraryProvider.notifier)
              .duplicateProject(project);
        },
      );

      if (!isMounted()) return;
      scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text('Duplicated "${project.title}" as a new revision'),
          backgroundColor: activePalette().success,
        ),
      );
    } catch (e) {
      if (isMounted()) {
        showErrorDialog('Error duplicating project: $e');
      }
    } finally {
      focusNode.requestFocus();
    }
  }

  Future<void> loadProjects() {
    return ref.read(projectLibraryProvider.notifier).loadProjects();
  }
}
