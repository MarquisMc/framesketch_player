import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/models/project_library_entry.dart';
import '../../../core/theme/app_palette.dart';

class ProjectBrowser extends StatelessWidget {
  final List<ProjectLibraryEntry> projects;
  final bool isLoading;
  final ValueChanged<ProjectLibraryEntry> onOpenProject;
  final Future<void> Function(ProjectLibraryEntry)? onRenameProject;
  final Future<void> Function(ProjectLibraryEntry)? onRevertProjectName;
  final Future<void> Function(ProjectLibraryEntry)? onDeleteProject;
  final VoidCallback? onOpenFile;
  final VoidCallback? onOpenYouTube;
  final VoidCallback? onRefresh;

  const ProjectBrowser({
    super.key,
    required this.projects,
    required this.isLoading,
    required this.onOpenProject,
    this.onRenameProject,
    this.onRevertProjectName,
    this.onDeleteProject,
    this.onOpenFile,
    this.onOpenYouTube,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);

    return Container(
      color: palette.background,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Projects',
                        style: TextStyle(
                          color: palette.textPrimary,
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Open a saved review session without going back through the file manager.',
                        style: TextStyle(
                          color: palette.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                if (onOpenFile != null)
                  OutlinedButton.icon(
                    onPressed: onOpenFile,
                    icon: const Icon(Icons.folder_open_outlined, size: 16),
                    label: const Text('Open Video'),
                  ),
                if (onOpenFile != null && onOpenYouTube != null)
                  const SizedBox(width: 8),
                if (onOpenYouTube != null)
                  OutlinedButton.icon(
                    onPressed: onOpenYouTube,
                    icon: const Icon(Icons.smart_display_outlined, size: 16),
                    label: const Text('YouTube'),
                  ),
                if (onRefresh != null) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Refresh projects',
                    onPressed: onRefresh,
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: palette.panel,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: palette.border),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : projects.isEmpty
                      ? _EmptyProjects(
                          onOpenFile: onOpenFile,
                          onOpenYouTube: onOpenYouTube,
                        )
                      : LayoutBuilder(
                          builder: (context, constraints) {
                            final width = constraints.maxWidth;
                            final crossAxisCount = width >= 1200
                                ? 4
                                : width >= 900
                                ? 3
                                : width >= 560
                                ? 2
                                : 1;

                            return GridView.builder(
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: crossAxisCount,
                                    mainAxisSpacing: 14,
                                    crossAxisSpacing: 14,
                                    childAspectRatio: 1.25,
                                  ),
                              itemCount: projects.length,
                              itemBuilder: (context, index) {
                                final project = projects[index];
                                return _ProjectCard(
                                  project: project,
                                  onTap: () => onOpenProject(project),
                                  onRename: onRenameProject == null
                                      ? null
                                      : () => onRenameProject!(project),
                                  onRevertName:
                                      onRevertProjectName == null ||
                                          !project.canRevertToOriginalName
                                      ? null
                                      : () => onRevertProjectName!(project),
                                  onDelete: onDeleteProject == null
                                      ? null
                                      : () => onDeleteProject!(project),
                                );
                              },
                            );
                          },
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyProjects extends StatelessWidget {
  final VoidCallback? onOpenFile;
  final VoidCallback? onOpenYouTube;

  const _EmptyProjects({this.onOpenFile, this.onOpenYouTube});

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.video_library_outlined,
              size: 64,
              color: palette.textMuted,
            ),
            const SizedBox(height: 16),
            Text(
              'No projects yet',
              style: TextStyle(
                color: palette.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Open a local video or a YouTube clip and it will show up here with its video thumbnail.',
              textAlign: TextAlign.center,
              style: TextStyle(color: palette.textSecondary, fontSize: 13),
            ),
            if (onOpenFile != null || onOpenYouTube != null) ...[
              const SizedBox(height: 18),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: [
                  if (onOpenFile != null)
                    FilledButton.icon(
                      onPressed: onOpenFile,
                      icon: const Icon(Icons.folder_open_outlined, size: 16),
                      label: const Text('Open Video'),
                    ),
                  if (onOpenYouTube != null)
                    OutlinedButton.icon(
                      onPressed: onOpenYouTube,
                      icon: const Icon(Icons.smart_display_outlined, size: 16),
                      label: const Text('Open YouTube'),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ProjectCard extends StatelessWidget {
  final ProjectLibraryEntry project;
  final VoidCallback onTap;
  final Future<void> Function()? onRename;
  final Future<void> Function()? onRevertName;
  final Future<void> Function()? onDelete;

  const _ProjectCard({
    required this.project,
    required this.onTap,
    this.onRename,
    this.onRevertName,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);

    return Material(
      color: palette.panelElevated,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(14),
                ),
                child: _ProjectThumbnail(project: project),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    project.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: palette.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    project.isYouTubeProject
                        ? (project.youtubeUrl ?? project.sourceLabel)
                        : project.sourcePath,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: palette.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Last opened ${_formatTimestamp(project.lastOpenedAt)}',
                    style: TextStyle(color: palette.textMuted, fontSize: 11),
                  ),
                ],
              ),
            ),
            if (onRename != null || onRevertName != null || onDelete != null)
              Align(
                alignment: Alignment.centerRight,
                child: PopupMenuButton<_ProjectCardAction>(
                  tooltip: 'Project actions',
                  onSelected: (action) async {
                    switch (action) {
                      case _ProjectCardAction.rename:
                        await onRename?.call();
                        break;
                      case _ProjectCardAction.revertName:
                        await onRevertName?.call();
                        break;
                      case _ProjectCardAction.delete:
                        await onDelete?.call();
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    if (onRename != null)
                      const PopupMenuItem<_ProjectCardAction>(
                        value: _ProjectCardAction.rename,
                        child: Row(
                          children: [
                            Icon(Icons.drive_file_rename_outline, size: 16),
                            SizedBox(width: 8),
                            Text('Rename'),
                          ],
                        ),
                      ),
                    if (onRevertName != null)
                      const PopupMenuItem<_ProjectCardAction>(
                        value: _ProjectCardAction.revertName,
                        child: Row(
                          children: [
                            Icon(Icons.undo, size: 16),
                            SizedBox(width: 8),
                            Text('Revert Name'),
                          ],
                        ),
                      ),
                    if (onDelete != null)
                      const PopupMenuItem<_ProjectCardAction>(
                        value: _ProjectCardAction.delete,
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline, size: 16),
                            SizedBox(width: 8),
                            Text('Delete'),
                          ],
                        ),
                      ),
                  ],
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(0, 0, 8, 8),
                    child: Icon(
                      Icons.more_horiz,
                      size: 18,
                      color: palette.textMuted,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime value) {
    final local = value.toLocal();
    return DateFormat.yMd().add_Hm().format(local);
  }
}

enum _ProjectCardAction { rename, revertName, delete }

class _ProjectThumbnail extends StatefulWidget {
  final ProjectLibraryEntry project;

  const _ProjectThumbnail({required this.project});

  @override
  State<_ProjectThumbnail> createState() => _ProjectThumbnailState();
}

class _ProjectThumbnailState extends State<_ProjectThumbnail> {
  late Future<bool> _hasThumbnailFuture;

  @override
  void initState() {
    super.initState();
    _hasThumbnailFuture = _thumbnailFileExists(widget.project.thumbnailPath);
  }

  @override
  void didUpdateWidget(covariant _ProjectThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.project.thumbnailPath != widget.project.thumbnailPath) {
      _hasThumbnailFuture = _thumbnailFileExists(widget.project.thumbnailPath);
    }
  }

  Future<bool> _thumbnailFileExists(String? thumbnailPath) {
    if (thumbnailPath == null || thumbnailPath.isEmpty) {
      return Future<bool>.value(false);
    }
    return File(thumbnailPath).exists();
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final thumbnailPath = widget.project.thumbnailPath;
    final thumbnailUrl = widget.project.thumbnailUrl;

    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(
          color: palette.background,
          child: FutureBuilder<bool>(
            future: _hasThumbnailFuture,
            builder: (context, snapshot) {
              final hasThumbnail = snapshot.data ?? false;

              if (hasThumbnail &&
                  thumbnailPath != null &&
                  thumbnailPath.isNotEmpty) {
                return Image.file(
                  File(thumbnailPath),
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => _fallback(palette),
                );
              }

              if (thumbnailUrl != null && thumbnailUrl.isNotEmpty) {
                return Image.network(
                  thumbnailUrl,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) {
                      return child;
                    }
                    return _fallback(palette);
                  },
                  errorBuilder: (_, _, _) => _fallback(palette),
                );
              }

              return _fallback(palette);
            },
          ),
        ),
        Positioned(
          left: 10,
          top: 10,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              widget.project.isYouTubeProject ? 'YouTube' : 'Local',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _fallback(AppPalette palette) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [palette.panelElevated, palette.background],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.movie_creation_outlined,
          color: palette.textMuted,
          size: 42,
        ),
      ),
    );
  }
}
