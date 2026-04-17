import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/app_palette.dart';
import '../features/player/providers/player_provider.dart';
import '../features/player/widgets/video_viewport.dart';
import '../features/player/widgets/playback_controls.dart';
import '../features/timeline/widgets/timeline_scrubber.dart';
import '../features/annotations/widgets/drawing_tools_panel.dart';
import '../features/annotations/widgets/annotation_keyframe_timeline.dart';
import '../features/annotations/providers/annotation_keyframe_timeline_provider.dart';
import '../features/crop/providers/crop_provider.dart';
import '../features/crop/widgets/crop_controls.dart';
import 'editor_toolbar.dart';
import 'horizontal_tools_strip.dart';
import 'inspector_panel.dart';

// Breakpoints
const double _kMobileBreakpoint = 600;
const double _kTabletBreakpoint = 1024;

/// Adaptive editor scaffold that switches between mobile/tablet/desktop layouts.
class EditorScaffold extends ConsumerWidget {
  final bool isFullscreen;
  final bool showInspector;
  final bool showToolsPanel;
  final bool showToolsStrip;
  final Widget projectBrowser;
  final VoidCallback onToggleFullscreen;
  final VoidCallback onToggleInspector;
  final VoidCallback onToggleToolsPanel;
  final VoidCallback onToggleToolsStrip;
  final VoidCallback onOpenFile;
  final VoidCallback onOpenYouTube;
  final VoidCallback onOpenAnnotation;
  final VoidCallback onOpenProjects;
  final VoidCallback onSaveAnnotations;
  final VoidCallback onSaveAnnotationsAs;
  final VoidCallback onExportVideo;
  final VoidCallback onOpenSettings;
  final VoidCallback onOpenThemeManager;
  final VoidCallback onOpenCommandPalette;
  final String commandPaletteShortcutLabel;
  final bool isExporting;
  final bool showExportHourglassBottom;
  final void Function(String, BuildContext)? onMenuAction;

  const EditorScaffold({
    super.key,
    required this.isFullscreen,
    required this.showInspector,
    required this.showToolsPanel,
    required this.showToolsStrip,
    required this.projectBrowser,
    required this.onToggleFullscreen,
    required this.onToggleInspector,
    required this.onToggleToolsPanel,
    required this.onToggleToolsStrip,
    required this.onOpenFile,
    required this.onOpenYouTube,
    required this.onOpenAnnotation,
    required this.onOpenProjects,
    required this.onSaveAnnotations,
    required this.onSaveAnnotationsAs,
    required this.onExportVideo,
    required this.onOpenSettings,
    required this.onOpenThemeManager,
    required this.onOpenCommandPalette,
    required this.commandPaletteShortcutLabel,
    required this.isExporting,
    required this.showExportHourglassBottom,
    this.onMenuAction,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (isFullscreen) {
      return _buildFullscreen(context, ref);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        if (width >= _kTabletBreakpoint) {
          return _buildDesktopLayout(context, ref);
        } else if (width >= _kMobileBreakpoint) {
          return _buildTabletLayout(context, ref);
        } else {
          return _buildMobileLayout(context, ref);
        }
      },
    );
  }

  // ─── Fullscreen ───────────────────────────────────────────────────────────

  Widget _buildFullscreen(BuildContext context, WidgetRef ref) {
    final palette = AppPalette.of(context);

    return ColoredBox(
      color: Colors.black,
      child: SafeArea(
        child: Column(
          children: [
            const Expanded(child: VideoViewport(showOverlays: true)),
            Divider(height: 1, thickness: 1, color: palette.border),
            const TimelineScrubber(showAnnotationTimelineToggle: false),
            Divider(height: 1, thickness: 1, color: palette.border),
            PlaybackControls(
              isFullscreen: true,
              onToggleFullscreen: onToggleFullscreen,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProjectBrowserLayout(
    BuildContext context, {
    required bool isDesktop,
  }) {
    final palette = AppPalette.of(context);

    return Column(
      children: [
        EditorToolbar(
          isDesktop: isDesktop,
          isInspectorVisible: showInspector,
          isToolsPanelVisible: showToolsPanel,
          isToolsStripVisible: showToolsStrip,
          onToggleToolsPanel: onToggleToolsPanel,
          onToggleToolsStrip: onToggleToolsStrip,
          isExporting: isExporting,
          showExportHourglassBottom: showExportHourglassBottom,
          onToggleInspector: onToggleInspector,
          onOpenFile: onOpenFile,
          onOpenYouTube: onOpenYouTube,
          onOpenAnnotation: onOpenAnnotation,
          onOpenProjects: onOpenProjects,
          onSaveAnnotations: onSaveAnnotations,
          onSaveAnnotationsAs: onSaveAnnotationsAs,
          onExportVideo: onExportVideo,
          onOpenSettings: onOpenSettings,
          onOpenThemeManager: onOpenThemeManager,
          onOpenCommandPalette: onOpenCommandPalette,
          commandPaletteShortcutLabel: commandPaletteShortcutLabel,
          onMenuAction: onMenuAction,
        ),
        Divider(height: 1, thickness: 1, color: palette.border),
        Expanded(child: projectBrowser),
      ],
    );
  }

  // ─── Desktop (>1024) ──────────────────────────────────────────────────────

  Widget _buildDesktopLayout(BuildContext context, WidgetRef ref) {
    final palette = AppPalette.of(context);
    final isCropModeActive = ref.watch(
      cropProvider.select((s) => s.isCropModeActive),
    );
    final hasLoadedSource = ref.watch(
      playerProvider.select((state) => state.hasLoadedSource),
    );

    if (!hasLoadedSource) {
      return _buildProjectBrowserLayout(context, isDesktop: true);
    }

    return Column(
      children: [
        // 1) Top toolbar
        EditorToolbar(
          isDesktop: true,
          isInspectorVisible: showInspector,
          isToolsPanelVisible: showToolsPanel,
          isToolsStripVisible: showToolsStrip,
          onToggleToolsPanel: onToggleToolsPanel,
          onToggleToolsStrip: onToggleToolsStrip,
          isExporting: isExporting,
          showExportHourglassBottom: showExportHourglassBottom,
          onToggleInspector: onToggleInspector,
          onOpenFile: onOpenFile,
          onOpenYouTube: onOpenYouTube,
          onOpenAnnotation: onOpenAnnotation,
          onOpenProjects: onOpenProjects,
          onSaveAnnotations: onSaveAnnotations,
          onSaveAnnotationsAs: onSaveAnnotationsAs,
          onExportVideo: onExportVideo,
          onOpenSettings: onOpenSettings,
          onOpenThemeManager: onOpenThemeManager,
          onOpenCommandPalette: onOpenCommandPalette,
          commandPaletteShortcutLabel: commandPaletteShortcutLabel,
          onMenuAction: onMenuAction,
        ),
        Divider(height: 1, thickness: 1, color: palette.border),

        if (showToolsStrip && !isCropModeActive) ...[
          const HorizontalToolsStrip(),
          Divider(height: 1, thickness: 1, color: palette.border),
        ],

        // 2) Main content row: left tools | canvas | right inspector
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Left: drawing tools panel (fixed width, scrollable internally)
              if (showToolsPanel && !isCropModeActive) ...[
                const SizedBox(width: 240, child: DrawingToolsPanel()),
                VerticalDivider(width: 1, thickness: 1, color: palette.border),
              ],

              // Center: canvas
              const Expanded(child: VideoViewport(showOverlays: true)),

              if (showInspector && !isCropModeActive) ...[
                VerticalDivider(width: 1, thickness: 1, color: palette.border),

                // Right: inspector panel
                const SizedBox(width: 220, child: InspectorPanel()),
              ],
            ],
          ),
        ),

        Divider(height: 1, thickness: 1, color: palette.border),
        _buildBottomControls(context, ref),
      ],
    );
  }

  // ─── Tablet (600–1024) ────────────────────────────────────────────────────

  Widget _buildTabletLayout(BuildContext context, WidgetRef ref) {
    final palette = AppPalette.of(context);
    final isCropModeActive = ref.watch(
      cropProvider.select((s) => s.isCropModeActive),
    );
    final hasLoadedSource = ref.watch(
      playerProvider.select((state) => state.hasLoadedSource),
    );

    if (!hasLoadedSource) {
      return _buildProjectBrowserLayout(context, isDesktop: false);
    }

    return Column(
      children: [
        EditorToolbar(
          isDesktop: false,
          isInspectorVisible: showInspector,
          isToolsPanelVisible: showToolsPanel,
          isToolsStripVisible: showToolsStrip,
          onToggleToolsPanel: onToggleToolsPanel,
          onToggleToolsStrip: onToggleToolsStrip,
          isExporting: isExporting,
          showExportHourglassBottom: showExportHourglassBottom,
          onToggleInspector: onToggleInspector,
          onOpenFile: onOpenFile,
          onOpenYouTube: onOpenYouTube,
          onOpenAnnotation: onOpenAnnotation,
          onOpenProjects: onOpenProjects,
          onSaveAnnotations: onSaveAnnotations,
          onSaveAnnotationsAs: onSaveAnnotationsAs,
          onExportVideo: onExportVideo,
          onOpenSettings: onOpenSettings,
          onOpenThemeManager: onOpenThemeManager,
          onOpenCommandPalette: onOpenCommandPalette,
          commandPaletteShortcutLabel: commandPaletteShortcutLabel,
          onMenuAction: onMenuAction,
        ),
        Divider(height: 1, thickness: 1, color: palette.border),

        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Compact tools column (icon-only, narrower)
              if (!isCropModeActive) ...[
                const _CompactToolsStrip(),
                VerticalDivider(width: 1, thickness: 1, color: palette.border),
              ],

              // Canvas
              const Expanded(child: VideoViewport(showOverlays: true)),
            ],
          ),
        ),

        Divider(height: 1, thickness: 1, color: palette.border),
        _buildBottomControls(context, ref),
      ],
    );
  }

  // ─── Mobile (<600) ────────────────────────────────────────────────────────

  Widget _buildMobileLayout(BuildContext context, WidgetRef ref) {
    final palette = AppPalette.of(context);
    final hasLoadedSource = ref.watch(
      playerProvider.select((state) => state.hasLoadedSource),
    );

    if (!hasLoadedSource) {
      return _buildProjectBrowserLayout(context, isDesktop: false);
    }

    return Column(
      children: [
        // Compact top bar (no labels, just icons + menu)
        EditorToolbar(
          isDesktop: false,
          isInspectorVisible: showInspector,
          isToolsPanelVisible: showToolsPanel,
          isToolsStripVisible: showToolsStrip,
          onToggleToolsPanel: onToggleToolsPanel,
          onToggleToolsStrip: onToggleToolsStrip,
          isExporting: isExporting,
          showExportHourglassBottom: showExportHourglassBottom,
          onToggleInspector: onToggleInspector,
          onOpenFile: onOpenFile,
          onOpenYouTube: onOpenYouTube,
          onOpenAnnotation: onOpenAnnotation,
          onOpenProjects: onOpenProjects,
          onSaveAnnotations: onSaveAnnotations,
          onSaveAnnotationsAs: onSaveAnnotationsAs,
          onExportVideo: onExportVideo,
          onOpenSettings: onOpenSettings,
          onOpenThemeManager: onOpenThemeManager,
          onOpenCommandPalette: onOpenCommandPalette,
          commandPaletteShortcutLabel: commandPaletteShortcutLabel,
          onMenuAction: onMenuAction,
        ),
        Divider(height: 1, thickness: 1, color: palette.border),

        // Canvas (most of the screen)
        const Expanded(child: VideoViewport(showOverlays: true)),

        Divider(height: 1, thickness: 1, color: palette.border),
        _buildBottomControls(context, ref),
      ],
    );
  }

  Widget _buildBottomControls(BuildContext context, WidgetRef ref) {
    final palette = AppPalette.of(context);
    final showAnnotationTimeline = ref.watch(
      annotationKeyframeTimelineVisibleProvider,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const CropControlsPanel(),
        if (showAnnotationTimeline) const AnnotationKeyframeTimeline(),
        TimelineScrubber(showAnnotationTimelineToggle: true),
        Divider(height: 1, thickness: 1, color: palette.border),
        PlaybackControls(
          isFullscreen: false,
          onToggleFullscreen: onToggleFullscreen,
        ),
      ],
    );
  }
}

/// Thin icon-only tools strip for tablet layout.
class _CompactToolsStrip extends StatelessWidget {
  const _CompactToolsStrip();

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    // We just show the DrawingToolsPanel in a narrower form.
    // Use a constrained box + clip so we only show the icon portion.
    return SizedBox(
      width: 56,
      child: ClipRect(
        child: ColoredBox(
          color: palette.panel,
          child: const DrawingToolsPanel(),
        ),
      ),
    );
  }
}
