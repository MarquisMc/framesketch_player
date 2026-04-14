import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/models/project_library_entry.dart';
import '../../../core/theme/app_palette.dart';

enum ProjectSortOrder { lastOpened, lastEdited, title, sourceType }

class ProjectBrowser extends StatefulWidget {
  final List<ProjectLibraryEntry> projects;
  final bool isLoading;
  final bool autofocusSearch;
  final ValueChanged<ProjectLibraryEntry> onOpenProject;
  final Future<void> Function(ProjectLibraryEntry)? onRenameProject;
  final Future<void> Function(ProjectLibraryEntry)? onRevertProjectName;
  final Future<void> Function(ProjectLibraryEntry)? onDeleteProject;
  final Future<void> Function(ProjectLibraryEntry)? onPinProject;
  final Future<void> Function(ProjectLibraryEntry)? onDuplicateProject;
  final VoidCallback? onOpenFile;
  final VoidCallback? onOpenYouTube;
  final VoidCallback? onRefresh;

  const ProjectBrowser({
    super.key,
    required this.projects,
    required this.isLoading,
    this.autofocusSearch = true,
    required this.onOpenProject,
    this.onRenameProject,
    this.onRevertProjectName,
    this.onDeleteProject,
    this.onPinProject,
    this.onDuplicateProject,
    this.onOpenFile,
    this.onOpenYouTube,
    this.onRefresh,
  });

  @override
  State<ProjectBrowser> createState() => _ProjectBrowserState();
}

class _ProjectBrowserState extends State<ProjectBrowser> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _query = '';
  ProjectSortOrder _sortOrder = ProjectSortOrder.lastOpened;

  @override
  void initState() {
    super.initState();
    if (widget.autofocusSearch) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _searchFocusNode.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  List<ProjectLibraryEntry> get _sorted {
    final q = _query.trim().toLowerCase();
    var list = q.isEmpty
        ? List<ProjectLibraryEntry>.from(widget.projects)
        : widget.projects
              .where(
                (p) =>
                    p.title.toLowerCase().contains(q) ||
                    p.sourceLabel.toLowerCase().contains(q),
              )
              .toList();

    list.sort((a, b) {
      // Pinned entries always float to the top within any sort.
      if (a.isPinned != b.isPinned) {
        return a.isPinned ? -1 : 1;
      }
      switch (_sortOrder) {
        case ProjectSortOrder.lastOpened:
          return b.lastOpenedAt.compareTo(a.lastOpenedAt);
        case ProjectSortOrder.lastEdited:
          return b.updatedAt.compareTo(a.updatedAt);
        case ProjectSortOrder.title:
          return a.title.toLowerCase().compareTo(b.title.toLowerCase());
        case ProjectSortOrder.sourceType:
          final aType = a.isYouTubeProject ? 1 : 0;
          final bType = b.isYouTubeProject ? 1 : 0;
          if (aType != bType) return aType.compareTo(bType);
          return b.lastOpenedAt.compareTo(a.lastOpenedAt);
      }
    });

    return list;
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final sorted = _sorted;

    return Container(
      color: palette.background,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
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
                      const SizedBox(height: 4),
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
                if (widget.onOpenFile != null)
                  OutlinedButton.icon(
                    onPressed: widget.onOpenFile,
                    icon: const Icon(Icons.folder_open_outlined, size: 16),
                    label: const Text('Open Video'),
                  ),
                if (widget.onOpenFile != null && widget.onOpenYouTube != null)
                  const SizedBox(width: 8),
                if (widget.onOpenYouTube != null)
                  OutlinedButton.icon(
                    onPressed: widget.onOpenYouTube,
                    icon: const Icon(Icons.smart_display_outlined, size: 16),
                    label: const Text('YouTube'),
                  ),
                if (widget.onRefresh != null) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Refresh projects',
                    onPressed: widget.onRefresh,
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ],
            ),

            const SizedBox(height: 16),

            // ── Search + Sort bar ────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 36,
                    child: TextField(
                      controller: _searchController,
                      focusNode: _searchFocusNode,
                      onChanged: (v) => setState(() => _query = v),
                      style: TextStyle(
                        color: palette.textPrimary,
                        fontSize: 13,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Search projects\u2026',
                        hintStyle: TextStyle(
                          color: palette.textMuted,
                          fontSize: 13,
                        ),
                        prefixIcon: Icon(
                          Icons.search,
                          size: 18,
                          color: palette.textMuted,
                        ),
                        suffixIcon: _query.isNotEmpty
                            ? IconButton(
                                icon: Icon(
                                  Icons.close,
                                  size: 16,
                                  color: palette.textMuted,
                                ),
                                visualDensity: VisualDensity.compact,
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _query = '');
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: palette.panelElevated,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 8),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: palette.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: palette.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: palette.accent,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                _SortDropdown(
                  value: _sortOrder,
                  onChanged: (v) => setState(() => _sortOrder = v),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // ── Grid ─────────────────────────────────────────────────
            Expanded(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: palette.panel,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: palette.border),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: widget.isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : sorted.isEmpty && _query.isEmpty
                      ? _EmptyProjects(
                          onOpenFile: widget.onOpenFile,
                          onOpenYouTube: widget.onOpenYouTube,
                        )
                      : sorted.isEmpty
                      ? _EmptySearch(query: _query)
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
                                    childAspectRatio: 1.2,
                                  ),
                              itemCount: sorted.length,
                              itemBuilder: (context, index) {
                                final project = sorted[index];
                                return _ProjectCard(
                                  project: project,
                                  onTap: () => widget.onOpenProject(project),
                                  onPin: widget.onPinProject == null
                                      ? null
                                      : () => widget.onPinProject!(project),
                                  onRename: widget.onRenameProject == null
                                      ? null
                                      : () => widget.onRenameProject!(project),
                                  onRevertName:
                                      widget.onRevertProjectName == null ||
                                          !project.canRevertToOriginalName
                                      ? null
                                      : () => widget.onRevertProjectName!(
                                          project,
                                        ),
                                  onDuplicate: widget.onDuplicateProject == null
                                      ? null
                                      : () =>
                                            widget.onDuplicateProject!(project),
                                  onDelete: widget.onDeleteProject == null
                                      ? null
                                      : () => widget.onDeleteProject!(project),
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

// ─── Sort dropdown ────────────────────────────────────────────────────────────

class _SortDropdown extends StatelessWidget {
  final ProjectSortOrder value;
  final ValueChanged<ProjectSortOrder> onChanged;

  const _SortDropdown({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);

    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: palette.panelElevated,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: palette.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<ProjectSortOrder>(
          value: value,
          isDense: true,
          icon: Icon(Icons.unfold_more, size: 16, color: palette.textMuted),
          style: TextStyle(color: palette.textPrimary, fontSize: 13),
          dropdownColor: palette.panelElevated,
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
          items: const [
            DropdownMenuItem(
              value: ProjectSortOrder.lastOpened,
              child: Text('Last Opened'),
            ),
            DropdownMenuItem(
              value: ProjectSortOrder.lastEdited,
              child: Text('Last Edited'),
            ),
            DropdownMenuItem(
              value: ProjectSortOrder.title,
              child: Text('Title'),
            ),
            DropdownMenuItem(
              value: ProjectSortOrder.sourceType,
              child: Text('Source Type'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Empty states ─────────────────────────────────────────────────────────────

class _EmptySearch extends StatelessWidget {
  final String query;
  const _EmptySearch({required this.query});

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search_off, size: 48, color: palette.textMuted),
          const SizedBox(height: 12),
          Text(
            'No projects match \u201c$query\u201d',
            style: TextStyle(
              color: palette.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Try a different search term.',
            style: TextStyle(color: palette.textSecondary, fontSize: 13),
          ),
        ],
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

// ─── Project card ─────────────────────────────────────────────────────────────

class _ProjectCard extends StatefulWidget {
  final ProjectLibraryEntry project;
  final VoidCallback onTap;
  final Future<void> Function()? onPin;
  final Future<void> Function()? onRename;
  final Future<void> Function()? onRevertName;
  final Future<void> Function()? onDuplicate;
  final Future<void> Function()? onDelete;

  const _ProjectCard({
    required this.project,
    required this.onTap,
    this.onPin,
    this.onRename,
    this.onRevertName,
    this.onDuplicate,
    this.onDelete,
  });

  @override
  State<_ProjectCard> createState() => _ProjectCardState();
}

class _ProjectCardState extends State<_ProjectCard> {
  bool _hovered = false;

  bool get _isRecent {
    final age = DateTime.now().difference(widget.project.lastOpenedAt);
    return age.inDays <= 7;
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final project = widget.project;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Material(
        color: palette.panelElevated,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: widget.onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Thumbnail ──────────────────────────────────
              Expanded(
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(14),
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _ProjectThumbnail(project: project),

                      // Source-type badge (bottom-left)
                      Positioned(
                        left: 10,
                        bottom: 10,
                        child: _Badge(
                          label: project.isYouTubeProject ? 'YouTube' : 'Local',
                          icon: project.isYouTubeProject
                              ? Icons.smart_display_outlined
                              : Icons.folder_outlined,
                        ),
                      ),

                      // Recent badge (bottom-right)
                      if (_isRecent)
                        Positioned(
                          right: 10,
                          bottom: 10,
                          child: _Badge(
                            label: 'Recent',
                            icon: Icons.schedule,
                            accent: true,
                          ),
                        ),

                      // Pin button (top-right, shown on hover or if pinned)
                      if (widget.onPin != null &&
                          (_hovered || project.isPinned))
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Tooltip(
                            message: project.isPinned
                                ? 'Unpin project'
                                : 'Pin project',
                            child: IconButton(
                              onPressed: widget.onPin,
                              iconSize: 14,
                              tooltip: project.isPinned
                                  ? 'Unpin project'
                                  : 'Pin project',
                              style: IconButton.styleFrom(
                                backgroundColor: project.isPinned
                                    ? palette.accent.withValues(alpha: 0.9)
                                    : Colors.black.withValues(alpha: 0.45),
                                minimumSize: const Size(28, 28),
                                maximumSize: const Size(28, 28),
                                padding: EdgeInsets.zero,
                                shape: const CircleBorder(),
                              ),
                              icon: Icon(
                                project.isPinned
                                    ? Icons.push_pin
                                    : Icons.push_pin_outlined,
                                size: 14,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // ── Info row ───────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              if (project.isPinned) ...[
                                Icon(
                                  Icons.push_pin,
                                  size: 12,
                                  color: palette.accent,
                                ),
                                const SizedBox(width: 4),
                              ],
                              Expanded(
                                child: Text(
                                  project.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: palette.textPrimary,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _formatTimestamp(project.lastOpenedAt),
                            style: TextStyle(
                              color: palette.textMuted,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Context menu
                    if (widget.onPin != null ||
                        widget.onRename != null ||
                        widget.onRevertName != null ||
                        widget.onDuplicate != null ||
                        widget.onDelete != null)
                      PopupMenuButton<_CardAction>(
                        tooltip: 'Project actions',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 28,
                        ),
                        onSelected: (action) async {
                          switch (action) {
                            case _CardAction.pin:
                              await widget.onPin?.call();
                            case _CardAction.rename:
                              await widget.onRename?.call();
                            case _CardAction.revertName:
                              await widget.onRevertName?.call();
                            case _CardAction.duplicate:
                              await widget.onDuplicate?.call();
                            case _CardAction.delete:
                              await widget.onDelete?.call();
                          }
                        },
                        itemBuilder: (_) => [
                          if (widget.onPin != null)
                            PopupMenuItem(
                              value: _CardAction.pin,
                              height: 36,
                              child: Row(
                                children: [
                                  Icon(
                                    project.isPinned
                                        ? Icons.push_pin_outlined
                                        : Icons.push_pin,
                                    size: 15,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(project.isPinned ? 'Unpin' : 'Pin'),
                                ],
                              ),
                            ),
                          if (widget.onRename != null)
                            const PopupMenuItem(
                              value: _CardAction.rename,
                              height: 36,
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.drive_file_rename_outline,
                                    size: 15,
                                  ),
                                  SizedBox(width: 8),
                                  Text('Rename'),
                                ],
                              ),
                            ),
                          if (widget.onRevertName != null)
                            const PopupMenuItem(
                              value: _CardAction.revertName,
                              height: 36,
                              child: Row(
                                children: [
                                  Icon(Icons.undo, size: 15),
                                  SizedBox(width: 8),
                                  Text('Revert Name'),
                                ],
                              ),
                            ),
                          if (widget.onDuplicate != null) ...[
                            if (widget.onPin != null || widget.onRename != null)
                              const PopupMenuDivider(),
                            const PopupMenuItem(
                              value: _CardAction.duplicate,
                              height: 36,
                              child: Row(
                                children: [
                                  Icon(Icons.copy_outlined, size: 15),
                                  SizedBox(width: 8),
                                  Text('Duplicate as Revision'),
                                ],
                              ),
                            ),
                          ],
                          if (widget.onDelete != null) ...[
                            const PopupMenuDivider(),
                            const PopupMenuItem(
                              value: _CardAction.delete,
                              height: 36,
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.delete_outline,
                                    size: 15,
                                    color: Color(0xFFE53935),
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Delete',
                                    style: TextStyle(color: Color(0xFFE53935)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(4, 0, 6, 0),
                          child: Icon(
                            Icons.more_horiz,
                            size: 18,
                            color: palette.textMuted,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime value) {
    final now = DateTime.now();
    final local = value.toLocal();
    final diff = now.difference(local);

    if (diff.isNegative) return 'Just now';
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat.yMd().format(local);
  }
}

enum _CardAction { pin, rename, revertName, duplicate, delete }

// ─── Badge widget ─────────────────────────────────────────────────────────────

class _Badge extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool accent;

  const _Badge({required this.label, required this.icon, this.accent = false});

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final bg = accent
        ? palette.accent.withValues(alpha: 0.85)
        : Colors.black.withValues(alpha: 0.55);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Thumbnail ────────────────────────────────────────────────────────────────

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

    return ColoredBox(
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
                if (loadingProgress == null) return child;
                return _fallback(palette);
              },
              errorBuilder: (_, _, _) => _fallback(palette),
            );
          }

          return _fallback(palette);
        },
      ),
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
