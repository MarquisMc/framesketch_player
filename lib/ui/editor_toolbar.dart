import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io' show Platform;
import '../core/theme/app_palette.dart';
import '../core/theme/theme_provider.dart';
import '../features/crop/widgets/crop_controls.dart';
import '../features/player/providers/player_provider.dart';

/// Top editor toolbar — branding, file actions, view toggles.
class EditorToolbar extends ConsumerWidget {
  final bool isDesktop;
  final bool isInspectorVisible;
  final bool isExporting;
  final bool showExportHourglassBottom;
  final VoidCallback onToggleInspector;
  final VoidCallback onOpenFile;
  final VoidCallback onOpenYouTube;
  final VoidCallback onOpenAnnotation;
  final VoidCallback onSaveAnnotations;
  final VoidCallback onSaveAnnotationsAs;
  final VoidCallback onExportVideo;
  final VoidCallback onOpenSettings;
  final VoidCallback onOpenThemeManager;

  /// Called with the action string 'register' | 'unregister' | 'check'
  final void Function(String, BuildContext)? onMenuAction;

  const EditorToolbar({
    super.key,
    required this.isDesktop,
    required this.isInspectorVisible,
    required this.isExporting,
    required this.showExportHourglassBottom,
    required this.onToggleInspector,
    required this.onOpenFile,
    required this.onOpenYouTube,
    required this.onOpenAnnotation,
    required this.onSaveAnnotations,
    required this.onSaveAnnotationsAs,
    required this.onExportVideo,
    required this.onOpenSettings,
    required this.onOpenThemeManager,
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
    final hasLocalVideoLoaded = ref.watch(
      playerProvider.select((s) => s.isLocalFileSource),
    );
    final sourceLabel = ref.watch(
      playerProvider.select((s) => s.currentSourceLabel),
    );

    return Container(
      height: 44,
      color: palette.panel,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Row(
        children: [
          // ── Branding ──────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.movie_filter_outlined,
                  size: 18,
                  color: palette.accent,
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

          // ── File group ────────────────────────────────────────────
          _Btn(
            icon: Icons.folder_open_outlined,
            tooltip: 'Open Video (Ctrl+O)',
            label: isDesktop ? 'Open' : null,
            onPressed: onOpenFile,
          ),
          _Btn(
            icon: Icons.smart_display_outlined,
            tooltip: 'Open YouTube URL',
            label: isDesktop ? 'YouTube' : null,
            onPressed: onOpenYouTube,
          ),
          _Btn(
            icon: Icons.data_object_outlined,
            tooltip: 'Open Annotation File',
            onPressed: onOpenAnnotation,
          ),

          _Sep(),

          // ── Save / Export ─────────────────────────────────────────
          _Btn(
            icon: Icons.save_outlined,
            tooltip: 'Save Annotations (Ctrl+S)',
            onPressed: onSaveAnnotations,
          ),
          _Btn(
            icon: Icons.save_as_outlined,
            tooltip: 'Save Annotations As…',
            onPressed: onSaveAnnotationsAs,
          ),
          _Btn(
            icon: isExporting
                ? (showExportHourglassBottom
                      ? Icons.hourglass_bottom
                      : Icons.hourglass_top)
                : Icons.file_download_outlined,
            tooltip: isExporting ? 'Exporting…' : 'Export Video',
            onPressed: hasVideoLoaded && !isExporting && hasLocalVideoLoaded
                ? onExportVideo
                : null,
          ),

          _Sep(),

          // ── Crop toggle ───────────────────────────────────────────
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 2),
            child: CropModeToggleButton(),
          ),

          _Sep(),

          // ── Source label (fills available space) ──────────────────
          Expanded(
            child: hasVideoLoaded && sourceLabel != null && isDesktop
                ? Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      _shortenLabel(sourceLabel),
                      style: TextStyle(color: palette.textMuted, fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  )
                : const SizedBox.shrink(),
          ),

          // ── Right: view toggles ───────────────────────────────────
          _Sep(),

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
            icon: Icons.keyboard_outlined,
            tooltip: 'Keyboard Shortcuts',
            onPressed: onOpenSettings,
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
}

// ─── Private helpers ──────────────────────────────────────────────────────────

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

class _Btn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final String? label;
  final VoidCallback? onPressed;

  const _Btn({
    required this.icon,
    required this.tooltip,
    this.label,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final color = onPressed != null
        ? palette.textSecondary
        : palette.textDisabled;

    final Widget inner = label != null
        ? TextButton.icon(
            onPressed: onPressed,
            icon: Icon(icon, size: 16, color: color),
            label: Text(label!, style: TextStyle(color: color, fontSize: 12)),
            style: TextButton.styleFrom(
              minimumSize: const Size(0, 36),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          )
        : IconButton(
            icon: Icon(icon, size: 18, color: color),
            onPressed: onPressed,
            iconSize: 18,
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            constraints: const BoxConstraints(minWidth: 32, minHeight: 36),
          );

    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 500),
      child: inner,
    );
  }
}
