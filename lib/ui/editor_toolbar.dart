import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:io' show Platform;
import '../core/theme/app_palette.dart';
import '../core/theme/theme_provider.dart';
import '../features/crop/widgets/crop_controls.dart';
import '../features/player/providers/player_provider.dart';

/// Top editor toolbar — branding, file menu, view toggles.
class EditorToolbar extends ConsumerWidget {
  final bool isDesktop;
  final bool isInspectorVisible;
  final bool isToolsPanelVisible;
  final bool isToolsStripVisible;
  final VoidCallback onToggleInspector;
  final VoidCallback onToggleToolsPanel;
  final VoidCallback onToggleToolsStrip;
  final VoidCallback onOpenFile;
  final VoidCallback onOpenYouTube;
  final VoidCallback onOpenAnnotation;
  final VoidCallback onOpenProjects;
  final VoidCallback onSaveAnnotations;
  final VoidCallback onSaveAnnotationsAs;
  final VoidCallback onOpenSettings;
  final VoidCallback onOpenThemeManager;
  final VoidCallback onCheckForUpdates;
  final bool isUpdateAvailable;
  final bool isCheckingForUpdates;
  final ValueChanged<String> onRenameCurrentVideo;
  final VoidCallback onOpenCommandPalette;
  final String commandPaletteShortcutLabel;

  final VoidCallback? onToggleCropExportPanel;
  final bool isCropExportPanelOpen;

  /// Called with the action string 'register' | 'unregister' | 'check'
  final void Function(String, BuildContext)? onMenuAction;

  const EditorToolbar({
    super.key,
    required this.isDesktop,
    required this.isInspectorVisible,
    required this.isToolsPanelVisible,
    required this.isToolsStripVisible,
    required this.onToggleInspector,
    required this.onToggleToolsPanel,
    required this.onToggleToolsStrip,
    required this.onOpenFile,
    required this.onOpenYouTube,
    required this.onOpenAnnotation,
    required this.onOpenProjects,
    required this.onSaveAnnotations,
    required this.onSaveAnnotationsAs,
    required this.onOpenSettings,
    required this.onOpenThemeManager,
    required this.onCheckForUpdates,
    required this.isUpdateAvailable,
    required this.isCheckingForUpdates,
    required this.onRenameCurrentVideo,
    required this.onOpenCommandPalette,
    required this.commandPaletteShortcutLabel,
    this.onToggleCropExportPanel,
    this.isCropExportPanelOpen = false,
    this.onMenuAction,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = AppPalette.of(context);
    final themeState = ref.watch(themeControllerProvider);
    final themeController = ref.read(themeControllerProvider.notifier);
    final hasVideoLoaded = ref.watch(
      playerProvider.select((s) => s.hasLoadedSource),
    );
    final sourceLabel = ref.watch(
      playerProvider.select(
        (s) => (s.currentDisplayLabel?.trim().isNotEmpty ?? false)
            ? s.currentDisplayLabel
            : s.currentSourceLabel,
      ),
    );

    return Container(
      height: 44,
      color: palette.panel,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Row(
        children: [
          // ── Branding ──────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SvgPicture.asset(
                  'assets/Images/frame-sketch-icon-light.svg',
                  width: 30,
                  height: 30,
                  colorFilter: ColorFilter.mode(
                    palette.accent,
                    BlendMode.srcIn,
                  ),
                ),
                if (isDesktop) ...[
                  const SizedBox(width: 6),
                  Text(
                    'FrameSketch',
                    style: TextStyle(
                      color: palette.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ],
            ),
          ),

          _Sep(),

          // ── File dropdown menu ─────────────────────────────────────
          _FileMenuButton(
            hasVideoLoaded: hasVideoLoaded,
            onOpenFile: onOpenFile,
            onOpenYouTube: onOpenYouTube,
            onOpenAnnotation: onOpenAnnotation,
            onOpenProjects: onOpenProjects,
            onSaveAnnotations: onSaveAnnotations,
            onSaveAnnotationsAs: onSaveAnnotationsAs,
          ),

          _Sep(),

          // ── Tools dropdown-style toggle ────────────────────────────
          _ToolsStripToggle(
            isToolsStripVisible: isToolsStripVisible,
            onToggleToolsStrip: onToggleToolsStrip,
            palette: palette,
          ),
          if (isDesktop)
            _Btn(
              icon: isToolsPanelVisible
                  ? Icons.view_sidebar
                  : Icons.view_sidebar_outlined,
              tooltip: isToolsPanelVisible
                  ? 'Hide Tools Panel'
                  : 'Show Tools Panel',
              onPressed: onToggleToolsPanel,
            ),

          _Sep(),

          // ── Source label (fills available space) ──────────────────
          Expanded(
            child: hasVideoLoaded && sourceLabel != null && isDesktop
                ? Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: _EditableSourceLabel(
                      label: _shortenLabel(sourceLabel),
                      onRename: onRenameCurrentVideo,
                    ),
                  )
                : const SizedBox.shrink(),
          ),

          // ── Right: crop, command palette, view toggles ────────────
          if (onToggleCropExportPanel != null) ...[
            _Sep(),

            // Crop & export panel toggle
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: CropModeToggleButton(
                onTogglePanel: onToggleCropExportPanel,
                isPanelOpen: isCropExportPanelOpen,
              ),
            ),

            _Sep(),
          ],

          _Btn(
            icon: themeState.mode == ThemeMode.dark
                ? Icons.light_mode_outlined
                : Icons.dark_mode_outlined,
            tooltip: themeState.mode == ThemeMode.dark
                ? 'Switch to Light Mode'
                : 'Switch to Dark Mode',
            onPressed: themeController.toggleThemeMode,
          ),
          _Btn(
            icon: Icons.palette_outlined,
            tooltip: 'Theme Manager',
            onPressed: onOpenThemeManager,
          ),
          _Btn(
            icon: Icons.search,
            tooltip: _commandPaletteTooltip(commandPaletteShortcutLabel),
            onPressed: onOpenCommandPalette,
          ),
          _Btn(
            icon: Icons.keyboard_outlined,
            tooltip: 'Keyboard Shortcuts',
            onPressed: onOpenSettings,
          ),
          _UpdateCheckButton(
            isChecking: isCheckingForUpdates,
            isUpdateAvailable: isUpdateAvailable,
            onPressed: onCheckForUpdates,
          ),
          if (isDesktop)
            _Btn(
              icon: isInspectorVisible
                  ? Icons.visibility
                  : Icons.visibility_off,
              tooltip: isInspectorVisible ? 'Hide Inspector' : 'Show Inspector',
              onPressed: onToggleInspector,
            ),

          // Windows-only file associations menu
          if (Platform.isWindows && onMenuAction != null)
            Builder(
              builder: (ctx) => PopupMenuButton<String>(
                icon: Icon(
                  Icons.more_vert,
                  size: 18,
                  color: palette.textSecondary,
                ),
                tooltip: 'More Options',
                padding: EdgeInsets.zero,
                iconSize: 18,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 36),
                onSelected: (value) => onMenuAction!(value, ctx),
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'register',
                    child: Row(
                      children: [
                        Icon(Icons.check_circle_outline, size: 16),
                        SizedBox(width: 8),
                        Text('Register File Associations'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'unregister',
                    child: Row(
                      children: [
                        Icon(Icons.cancel_outlined, size: 16),
                        SizedBox(width: 8),
                        Text('Remove File Associations'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'check',
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, size: 16),
                        SizedBox(width: 8),
                        Text('Check Registration Status'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  static String _shortenLabel(String label) {
    final segments = label.replaceAll('\\', '/').split('/');
    if (segments.length > 1) return segments.last;
    return label;
  }

  static String _commandPaletteTooltip(String shortcut) {
    return 'Command Palette ($shortcut)';
  }
}

// ─── File dropdown button ─────────────────────────────────────────────────────

class _ToolsStripToggle extends StatelessWidget {
  final bool isToolsStripVisible;
  final VoidCallback onToggleToolsStrip;
  final AppPalette palette;

  const _ToolsStripToggle({
    required this.isToolsStripVisible,
    required this.onToggleToolsStrip,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: isToolsStripVisible ? 'Hide Tools Strip' : 'Show Tools Strip',
      waitDuration: const Duration(milliseconds: 600),
      child: InkWell(
        onTap: onToggleToolsStrip,
        borderRadius: BorderRadius.circular(6),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
          constraints: const BoxConstraints(minHeight: 32),
          decoration: BoxDecoration(
            color: isToolsStripVisible
                ? palette.accentSoft
                : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.brush_outlined,
                size: 15,
                color: isToolsStripVisible
                    ? palette.accentBright
                    : palette.textSecondary,
              ),
              const SizedBox(width: 5),
              Text(
                'Tools',
                style: TextStyle(
                  color: isToolsStripVisible
                      ? palette.accentBright
                      : palette.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 3),
              AnimatedRotation(
                turns: isToolsStripVisible ? 0.5 : 0.0,
                duration: const Duration(milliseconds: 150),
                child: Icon(
                  Icons.expand_more,
                  size: 14,
                  color: isToolsStripVisible
                      ? palette.accentBright
                      : palette.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FileMenuButton extends StatefulWidget {
  final bool hasVideoLoaded;
  final VoidCallback onOpenFile;
  final VoidCallback onOpenYouTube;
  final VoidCallback onOpenAnnotation;
  final VoidCallback onOpenProjects;
  final VoidCallback onSaveAnnotations;
  final VoidCallback onSaveAnnotationsAs;

  const _FileMenuButton({
    required this.hasVideoLoaded,
    required this.onOpenFile,
    required this.onOpenYouTube,
    required this.onOpenAnnotation,
    required this.onOpenProjects,
    required this.onSaveAnnotations,
    required this.onSaveAnnotationsAs,
  });

  @override
  State<_FileMenuButton> createState() => _FileMenuButtonState();
}

class _FileMenuButtonState extends State<_FileMenuButton> {
  bool _isOpen = false;

  void _openMenu(BuildContext context) async {
    final palette = AppPalette.of(context);
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;

    final offset = box.localToGlobal(Offset.zero);
    final menuTop = offset.dy + box.size.height + 2;
    final menuLeft = offset.dx;

    setState(() => _isOpen = true);

    await showMenu<_FileAction>(
      context: context,
      position: RelativeRect.fromLTRB(
        menuLeft,
        menuTop,
        menuLeft + 200,
        menuTop,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      elevation: 8,
      items: [
        // ── Open section ──────────────────────────────
        _menuHeader('Open', palette),
        _menuItem(
          action: _FileAction.openVideo,
          icon: Icons.folder_open_outlined,
          label: 'Open Video',
          shortcut: 'Ctrl+O',
          palette: palette,
        ),
        _menuItem(
          action: _FileAction.openYouTube,
          icon: Icons.smart_display_outlined,
          label: 'Open YouTube URL',
          palette: palette,
        ),
        _menuItem(
          action: _FileAction.openAnnotation,
          icon: Icons.data_object_outlined,
          label: 'Open Annotation File',
          palette: palette,
        ),
        // ── Projects section ──────────────────────────
        _menuDivider(),
        _menuHeader('Projects', palette),
        _menuItem(
          action: _FileAction.browseProjects,
          icon: Icons.grid_view_outlined,
          label: 'Browse Projects',
          palette: palette,
        ),
        // ── Save section ──────────────────────────────
        _menuDivider(),
        _menuHeader('Save', palette),
        _menuItem(
          action: _FileAction.saveAnnotations,
          icon: Icons.save_outlined,
          label: 'Save',
          shortcut: 'Ctrl+S',
          enabled: widget.hasVideoLoaded,
          palette: palette,
        ),
        _menuItem(
          action: _FileAction.saveAnnotationsAs,
          icon: Icons.save_as_outlined,
          label: 'Save As\u2026',
          enabled: widget.hasVideoLoaded,
          palette: palette,
        ),
      ],
    ).then((action) {
      if (!mounted) return;
      setState(() => _isOpen = false);
      if (action == null) return;
      switch (action) {
        case _FileAction.openVideo:
          widget.onOpenFile();
        case _FileAction.openYouTube:
          widget.onOpenYouTube();
        case _FileAction.openAnnotation:
          widget.onOpenAnnotation();
        case _FileAction.browseProjects:
          widget.onOpenProjects();
        case _FileAction.saveAnnotations:
          widget.onSaveAnnotations();
        case _FileAction.saveAnnotationsAs:
          widget.onSaveAnnotationsAs();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final isActive = _isOpen;

    return Tooltip(
      message: 'File',
      waitDuration: const Duration(milliseconds: 600),
      child: InkWell(
        onTap: () => _openMenu(context),
        borderRadius: BorderRadius.circular(6),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
          constraints: const BoxConstraints(minHeight: 32),
          decoration: BoxDecoration(
            color: isActive ? palette.accentSoft : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.folder_outlined,
                size: 15,
                color: isActive ? palette.accentBright : palette.textSecondary,
              ),
              const SizedBox(width: 5),
              Text(
                'File',
                style: TextStyle(
                  color: isActive
                      ? palette.accentBright
                      : palette.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 3),
              AnimatedRotation(
                turns: isActive ? 0.5 : 0.0,
                duration: const Duration(milliseconds: 150),
                child: Icon(
                  Icons.expand_more,
                  size: 14,
                  color: isActive ? palette.accentBright : palette.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Menu item helpers ────────────────────────────────────────────────────────

enum _FileAction {
  openVideo,
  openYouTube,
  openAnnotation,
  browseProjects,
  saveAnnotations,
  saveAnnotationsAs,
}

PopupMenuEntry<_FileAction> _menuHeader(String title, AppPalette palette) {
  return PopupMenuItem<_FileAction>(
    enabled: false,
    height: 28,
    padding: const EdgeInsets.fromLTRB(14, 6, 14, 2),
    child: Text(
      title.toUpperCase(),
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
        color: palette.textMuted,
      ),
    ),
  );
}

PopupMenuEntry<_FileAction> _menuDivider() {
  return const PopupMenuDivider(height: 1);
}

PopupMenuEntry<_FileAction> _menuItem({
  required _FileAction action,
  required IconData icon,
  required String label,
  required AppPalette palette,
  String? shortcut,
  bool enabled = true,
}) {
  final labelColor = enabled ? palette.textPrimary : palette.textDisabled;
  final iconColor = enabled ? palette.textSecondary : palette.textDisabled;

  return PopupMenuItem<_FileAction>(
    value: action,
    enabled: enabled,
    height: 36,
    padding: const EdgeInsets.symmetric(horizontal: 14),
    child: Row(
      children: [
        Icon(icon, size: 16, color: iconColor),
        const SizedBox(width: 10),
        Expanded(
          child: Text(label, style: TextStyle(fontSize: 13, color: labelColor)),
        ),
        if (shortcut != null)
          Text(
            shortcut,
            style: TextStyle(
              fontSize: 11,
              color: palette.textMuted,
              fontFamily: 'monospace',
            ),
          ),
      ],
    ),
  );
}

// ─── Shared toolbar helpers ───────────────────────────────────────────────────

class _Sep extends StatelessWidget {
  const _Sep();

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Container(
      width: 1,
      height: 24,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      color: palette.border,
    );
  }
}

class _EditableSourceLabel extends StatefulWidget {
  final String label;
  final ValueChanged<String> onRename;

  const _EditableSourceLabel({required this.label, required this.onRename});

  @override
  State<_EditableSourceLabel> createState() => _EditableSourceLabelState();
}

class _EditableSourceLabelState extends State<_EditableSourceLabel> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.label);
    _focusNode = FocusNode();
    _focusNode.addListener(_handleFocusChanged);
  }

  @override
  void didUpdateWidget(covariant _EditableSourceLabel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isEditing && oldWidget.label != widget.label) {
      _controller.text = widget.label;
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    if (_isEditing) {
      return SizedBox(
        height: 28,
        child: TextField(
          controller: _controller,
          focusNode: _focusNode,
          style: TextStyle(color: palette.textPrimary, fontSize: 11),
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 6,
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
          ),
          onSubmitted: _submit,
        ),
      );
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onDoubleTap: _startEditing,
      child: Tooltip(
        message: 'Double-click to rename video',
        child: Text(
          widget.label,
          style: TextStyle(color: palette.textMuted, fontSize: 11),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  void _startEditing() {
    setState(() {
      _isEditing = true;
      _controller.text = widget.label;
      _controller.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _controller.text.length,
      );
    });
    _focusNode.requestFocus();
  }

  void _submit(String value) {
    final trimmed = value.trim();
    setState(() => _isEditing = false);
    if (trimmed.isNotEmpty && trimmed != widget.label) {
      widget.onRename(trimmed);
    } else {
      _controller.text = widget.label;
    }
  }

  void _cancelEditing() {
    if (!_isEditing) return;
    setState(() {
      _isEditing = false;
      _controller.text = widget.label;
    });
  }

  void _handleFocusChanged() {
    if (!_focusNode.hasFocus) {
      _cancelEditing();
    }
  }
}

class _UpdateCheckButton extends StatefulWidget {
  final bool isChecking;
  final bool isUpdateAvailable;
  final VoidCallback onPressed;

  const _UpdateCheckButton({
    required this.isChecking,
    required this.isUpdateAvailable,
    required this.onPressed,
  });

  @override
  State<_UpdateCheckButton> createState() => _UpdateCheckButtonState();
}

class _UpdateCheckButtonState extends State<_UpdateCheckButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    );
    if (widget.isChecking) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant _UpdateCheckButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isChecking && !oldWidget.isChecking) {
      _controller.repeat();
    } else if (!widget.isChecking && oldWidget.isChecking) {
      _controller.stop();
      _controller.reset();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final color = widget.isUpdateAvailable ? palette.warning : null;

    return _Btn(
      icon: widget.isChecking ? Icons.refresh : Icons.new_releases_outlined,
      tooltip: widget.isChecking
          ? 'Checking for updates'
          : widget.isUpdateAvailable
          ? 'Update Available'
          : 'Check for Updates',
      onPressed: widget.isChecking ? null : widget.onPressed,
      color: color,
      turns: widget.isChecking ? _controller : null,
    );
  }
}

class _Btn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final Color? color;
  final Animation<double>? turns;

  const _Btn({
    required this.icon,
    required this.tooltip,
    this.onPressed,
    this.color,
    this.turns,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final foregroundColor =
        color ??
        (onPressed != null ? palette.textSecondary : palette.textDisabled);

    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 500),
      child: IconButton(
        icon: turns == null
            ? Icon(icon, size: 18, color: foregroundColor)
            : RotationTransition(
                turns: turns!,
                child: Icon(icon, size: 18, color: foregroundColor),
              ),
        onPressed: onPressed,
        iconSize: 18,
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        constraints: const BoxConstraints(minWidth: 32, minHeight: 36),
      ),
    );
  }
}
