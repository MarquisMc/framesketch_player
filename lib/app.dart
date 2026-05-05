import 'dart:async';
import 'dart:io' show Directory, File, Platform, Process, SystemEncoding;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'core/models/project_library_entry.dart';
import 'features/player/providers/player_provider.dart';
import 'features/annotations/providers/annotation_provider.dart';
import 'features/annotations/models/stroke.dart';
import 'core/services/annotation_overlay_renderer_service.dart';
import 'core/services/ffprobe_service.dart';
import 'core/models/annotation_data.dart';
import 'core/models/keyboard_shortcuts.dart';
import 'core/models/video_metadata.dart';
import 'features/projects/providers/project_library_provider.dart';
import 'features/projects/widgets/project_library_actions.dart';
import 'features/projects/widgets/project_browser.dart';
import 'features/settings/providers/auto_save_provider.dart';
import 'features/settings/providers/keyboard_shortcuts_provider.dart';
import 'features/settings/widgets/settings_actions.dart';
import 'features/loop/providers/loop_provider.dart';
import 'features/crop/providers/crop_provider.dart';
import 'features/player/widgets/source_open_actions.dart';
import 'core/services/video_export_models.dart';
import 'core/theme/app_palette.dart';
import 'core/theme/theme_provider.dart';
import 'ui/editor_scaffold.dart';
import 'ui/command_palette/command_palette.dart';
import 'ui/command_palette/editor_command_factory.dart';

/// Main application widget
class FrameSketchPlayerApp extends ConsumerStatefulWidget {
  final String? initialVideoPath;

  const FrameSketchPlayerApp({super.key, this.initialVideoPath});

  @override
  ConsumerState<FrameSketchPlayerApp> createState() =>
      _FrameSketchPlayerAppState();
}

class _FrameSketchPlayerAppState extends ConsumerState<FrameSketchPlayerApp> {
  final FocusNode _focusNode = FocusNode();
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();
  final FFprobeService _ffprobeService = FFprobeService();
  final AnnotationOverlayRendererService _overlayRenderer =
      AnnotationOverlayRendererService();
  late final ProviderSubscription<(bool, DateTime?)> _autoSaveSubscription;
  late final ProviderSubscription<({bool isEditingText, bool isInteracting})>
  _annotationFocusSubscription;
  Timer? _keyRepeatTimer;
  Timer? _exportIconTimer;
  Timer? _autoSaveTimer;
  LogicalKeyboardKey? _lastPressedKey;
  int _keyRepeatGeneration = 0;
  bool _isFullscreen = false;
  bool _showInspector = true;
  bool _showToolsPanel = true;
  bool _showToolsStrip = false;
  bool _showCommandPalette = false;
  bool _showCropExportPanel = false;
  bool _showExportHourglassBottom = false;
  int _loadingOverlayDepth = 0;
  String _loadingOverlayMessage = 'Loading...';
  String? _loadingOverlayCancelLabel;
  VoidCallback? _loadingOverlayCancelAction;
  bool _exportCancelRequested = false;
  Process? _activeFrameExportProcess;
  bool _isAutoSaving = false;
  AppPalette get _activePalette =>
      ref.read(themeControllerProvider).activePalette;
  KeyboardShortcuts get _shortcuts => ref.read(keyboardShortcutsProvider);
  bool get _autoSaveEnabled => ref.read(autoSaveProvider);

  @override
  void initState() {
    super.initState();
    _autoSaveSubscription = ref.listenManual<(bool, DateTime?)>(
      annotationProvider.select(
        (state) => (state.hasUnsavedChanges, state.annotationData?.updatedAt),
      ),
      (previous, next) {
        _handleAutoSaveStateChanged(hasUnsavedChanges: next.$1);
      },
    );
    _annotationFocusSubscription = ref
        .listenManual<({bool isEditingText, bool isInteracting})>(
          annotationProvider.select(
            (state) => (
              isEditingText: state.pendingTextStrokeId != null,
              isInteracting:
                  state.isDrawing ||
                  state.isBoxSelecting ||
                  state.isScaling ||
                  state.currentStroke != null,
            ),
          ),
          (previous, next) {
            if (next.isEditingText || next.isInteracting) {
              return;
            }
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted ||
                  ref.read(annotationProvider).pendingTextStrokeId != null) {
                return;
              }
              _focusNode.requestFocus();
            });
          },
        );
    // Request focus on startup
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
      // Auto-load video if provided via command-line
      if (widget.initialVideoPath != null) {
        _loadInitialVideo(widget.initialVideoPath!);
      }
    });
  }

  Future<void> _setAutoSaveEnabled(bool enabled) async {
    await ref.read(autoSaveProvider.notifier).setEnabled(enabled);

    if (enabled) {
      _handleAutoSaveStateChanged(
        hasUnsavedChanges: ref.read(annotationProvider).hasUnsavedChanges,
      );
    } else {
      _autoSaveTimer?.cancel();
    }
  }

  Future<void> _loadProjects() =>
      ref.read(projectLibraryProvider.notifier).loadProjects();

  void _handleAutoSaveStateChanged({required bool hasUnsavedChanges}) {
    _autoSaveTimer?.cancel();

    if (!_autoSaveEnabled || !hasUnsavedChanges) {
      return;
    }

    _autoSaveTimer = Timer(
      const Duration(seconds: 2),
      () => unawaited(_performAutoSave()),
    );
  }

  Future<void> _performAutoSave() async {
    if (_isAutoSaving || !_autoSaveEnabled) {
      return;
    }

    final annotationState = ref.read(annotationProvider);
    if (!annotationState.hasUnsavedChanges ||
        annotationState.annotationData == null) {
      return;
    }

    _isAutoSaving = true;
    try {
      final success = await ref
          .read(annotationProvider.notifier)
          .saveAnnotations();
      if (!success && mounted) {
        _showErrorDialog('Auto-save failed');
      }
    } catch (e, stackTrace) {
      debugPrint('Auto-save error: $e');
      debugPrint('$stackTrace');
      if (mounted) {
        _showErrorDialog('Auto-save failed. Please try again.');
      }
    } finally {
      _isAutoSaving = false;
      final latestState = ref.read(annotationProvider);
      if (_autoSaveEnabled && latestState.hasUnsavedChanges) {
        _handleAutoSaveStateChanged(hasUnsavedChanges: true);
      }
    }
  }

  Future<void> _registerCurrentProject({String? projectTitle}) async {
    final annotationData = ref.read(annotationProvider).annotationData;
    final playerState = ref.read(playerProvider);
    if (annotationData == null || playerState.currentSourceLabel == null) {
      return;
    }

    await ref
        .read(projectLibraryProvider.notifier)
        .upsertProject(
          annotationData: annotationData,
          sourceLabel: playerState.currentSourceLabel!,
          projectTitle: projectTitle,
          duration: playerState.duration,
        );
  }

  SourceOpenActions get _sourceOpenActions => SourceOpenActions(
    ref: ref,
    navigatorKey: _navigatorKey,
    scaffoldMessengerKey: _scaffoldMessengerKey,
    focusNode: _focusNode,
    isMounted: () => mounted,
    activePalette: () => _activePalette,
    runWithLoadingOverlay: _runWithLoadingOverlay,
    registerCurrentProject: _registerCurrentProject,
    showErrorDialog: _showErrorDialog,
  );

  SettingsActions get _settingsActions => SettingsActions(
    ref: ref,
    navigatorKey: _navigatorKey,
    scaffoldMessengerKey: _scaffoldMessengerKey,
    focusNode: _focusNode,
    isMounted: () => mounted,
    activePalette: () => _activePalette,
    onAutoSaveChanged: _setAutoSaveEnabled,
    showInfoDialog: _showInfoDialog,
    showErrorDialog: _showErrorDialog,
  );

  Future<void> _openProject(ProjectLibraryEntry project) {
    return _sourceOpenActions.openProject(project);
  }

  ProjectLibraryActions get _projectLibraryActions => ProjectLibraryActions(
    ref: ref,
    navigatorKey: _navigatorKey,
    scaffoldMessengerKey: _scaffoldMessengerKey,
    focusNode: _focusNode,
    isMounted: () => mounted,
    activePalette: () => _activePalette,
    runWithLoadingOverlay: _runWithLoadingOverlay,
    openProject: _openProject,
    showErrorDialog: _showErrorDialog,
  );

  Future<void> _openProjectsDialog() {
    return _projectLibraryActions.openProjectsDialog();
  }

  Future<void> _renameProjectFromBrowser(ProjectLibraryEntry project) {
    return _projectLibraryActions.renameProjectFromBrowser(project);
  }

  Future<void> _deleteProjectFromBrowser(ProjectLibraryEntry project) {
    return _projectLibraryActions.deleteProjectFromBrowser(project);
  }

  Future<void> _revertProjectNameFromBrowser(ProjectLibraryEntry project) {
    return _projectLibraryActions.revertProjectNameFromBrowser(project);
  }

  Future<void> _pinProjectFromBrowser(ProjectLibraryEntry project) {
    return _projectLibraryActions.pinProjectFromBrowser(project);
  }

  Future<void> _duplicateProjectFromBrowser(ProjectLibraryEntry project) {
    return _projectLibraryActions.duplicateProjectFromBrowser(project);
  }

  @override
  void dispose() {
    _exportCancelRequested = true;
    _activeFrameExportProcess?.kill();
    _activeFrameExportProcess = null;
    _autoSaveSubscription.close();
    _annotationFocusSubscription.close();
    _keyRepeatTimer?.cancel();
    _exportIconTimer?.cancel();
    _autoSaveTimer?.cancel();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeState = ref.watch(themeControllerProvider);
    final shortcuts = ref.watch(keyboardShortcutsProvider);
    ref.watch(autoSaveProvider);
    final projectLibraryState = ref.watch(projectLibraryProvider);
    final selectedTheme = themeState.selectedTheme;
    final isExporting = ref.watch(
      cropProvider.select(
        (state) => state.exportStatus == ExportStatus.exporting,
      ),
    );
    _syncExportIconAnimation(isExporting);

    return MaterialApp(
      navigatorKey: _navigatorKey,
      scaffoldMessengerKey: _scaffoldMessengerKey,
      title: 'FrameSketch Player',
      debugShowCheckedModeBanner: false,
      theme: AppPalette.themeData(
        Brightness.light,
        palette: selectedTheme.lightPalette,
      ),
      darkTheme: AppPalette.themeData(
        Brightness.dark,
        palette: selectedTheme.darkPalette,
      ),
      themeMode: themeState.mode,
      home: Focus(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: (node, event) => _handleKeyEvent(event),
        child: Builder(
          builder: (context) => Scaffold(
            body: Stack(
              children: [
                EditorScaffold(
                  isFullscreen: _isFullscreen,
                  showInspector: _showInspector,
                  showToolsPanel: _showToolsPanel,
                  showToolsStrip: _showToolsStrip,
                  projectBrowser: ProjectBrowser(
                    projects: projectLibraryState.projects,
                    isLoading: projectLibraryState.isLoading,
                    onOpenProject: (project) {
                      unawaited(_openProject(project));
                    },
                    onRenameProject: _renameProjectFromBrowser,
                    onRevertProjectName: _revertProjectNameFromBrowser,
                    onDeleteProject: _deleteProjectFromBrowser,
                    onPinProject: _pinProjectFromBrowser,
                    onDuplicateProject: _duplicateProjectFromBrowser,
                    onOpenFile: _openFile,
                    onOpenYouTube: _openYouTubeUrl,
                    onRefresh: _loadProjects,
                  ),
                  onToggleFullscreen: _toggleFullscreenMode,
                  onToggleInspector: _toggleInspectorVisibility,
                  onToggleToolsPanel: _toggleToolsPanelVisibility,
                  onToggleToolsStrip: _toggleToolsStrip,
                  onOpenFile: _openFile,
                  onOpenYouTube: _openYouTubeUrl,
                  onOpenAnnotation: _openAnnotationJson,
                  onOpenProjects: _openProjectsDialog,
                  onSaveAnnotations: _saveAnnotations,
                  onSaveAnnotationsAs: _saveAnnotationsAs,
                  onOpenSettings: () => _openSettings(context),
                  onOpenThemeManager: () => _openThemeManager(context),
                  onOpenCommandPalette: _openCommandPalette,
                  commandPaletteShortcutLabel: formatShortcutLabel(
                    shortcuts.openCommandPalette,
                  ),
                  onToggleCropExportPanel: _toggleCropExportPanel,
                  isCropExportPanelOpen: _showCropExportPanel,
                  onExportFrames: _exportFramesFromPanel,
                  onMenuAction: _handleMenuAction,
                ),
                if (_loadingOverlayDepth > 0)
                  _buildGlobalLoadingOverlay(context),
                if (_showCommandPalette)
                  CommandPalette(
                    commands: EditorCommandFactory(
                      ref: ref,
                      shortcuts: _shortcuts,
                      markerColor: _activePalette.accent,
                      isFullscreen: _isFullscreen,
                      onOpenFile: _openFile,
                      onOpenRecent: _openRecentFromPalette,
                      onSaveAnnotations: _saveAnnotations,
                      onExportVideoFromTopBar: _exportVideoFromTopBar,
                      onOpenThemeManager: () {
                        final ctx = _navigatorKey.currentContext;
                        if (ctx != null) _openThemeManager(ctx);
                      },
                      onToggleFullscreen: _toggleFullscreenMode,
                    ).build(),
                    onClose: _closeCommandPalette,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _syncExportIconAnimation(bool isExporting) {
    if (isExporting) {
      if (_exportIconTimer != null) return;
      _showExportHourglassBottom = false;
      _exportIconTimer = Timer.periodic(const Duration(seconds: 2), (_) {
        if (!mounted) return;
        setState(() {
          _showExportHourglassBottom = !_showExportHourglassBottom;
        });
      });
      return;
    }

    _exportIconTimer?.cancel();
    _exportIconTimer = null;
    _showExportHourglassBottom = false;
  }

  Future<T> _runWithLoadingOverlay<T>({
    required String message,
    required Future<T> Function() action,
    String? cancelLabel,
    VoidCallback? onCancel,
  }) async {
    if (mounted) {
      setState(() {
        _loadingOverlayDepth += 1;
        _loadingOverlayMessage = message;
        _loadingOverlayCancelLabel = cancelLabel;
        _loadingOverlayCancelAction = onCancel;
      });
    }

    try {
      return await action();
    } finally {
      if (mounted) {
        setState(() {
          if (_loadingOverlayDepth > 0) {
            _loadingOverlayDepth -= 1;
          }
          if (_loadingOverlayDepth == 0) {
            _loadingOverlayMessage = 'Loading...';
            _loadingOverlayCancelLabel = null;
            _loadingOverlayCancelAction = null;
          }
        });
      }
    }
  }

  Widget _buildGlobalLoadingOverlay(BuildContext context) {
    final palette = AppPalette.of(context);
    return Positioned.fill(
      child: IgnorePointer(
        ignoring: false,
        child: Container(
          color: palette.panelOverlay,
          alignment: Alignment.center,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
            decoration: BoxDecoration(
              color: palette.panelElevated,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: palette.border),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 34,
                  height: 34,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: palette.accentBright,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _loadingOverlayMessage,
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Please wait...',
                  style: TextStyle(color: palette.textSecondary, fontSize: 12),
                ),
                if (_loadingOverlayCancelAction != null) ...[
                  const SizedBox(height: 14),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.cancel_outlined, size: 16),
                    label: Text(_loadingOverlayCancelLabel ?? 'Cancel'),
                    onPressed: _loadingOverlayCancelAction,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  KeyEventResult _handleKeyEvent(KeyEvent event) {
    final playerNotifier = ref.read(playerProvider.notifier);
    final annotationNotifier = ref.read(annotationProvider.notifier);
    final loopNotifier = ref.read(loopProvider.notifier);
    final annotationState = ref.read(annotationProvider);

    // Only process app-wide shortcuts while keyboard focus is in the editor
    // shell. Editable text descendants keep their normal text behavior.
    if (!_focusNode.hasFocus || _isEditableTextFocused()) {
      _keyRepeatGeneration++;
      _keyRepeatTimer?.cancel();
      _keyRepeatTimer = null;
      _lastPressedKey = null;
      return KeyEventResult.ignored;
    }

    // When focus is inside editable text, let the field consume normal
    // character input instead of routing those keys through global shortcuts.
    if (annotationState.pendingTextStrokeId != null) {
      _keyRepeatGeneration++;
      _keyRepeatTimer?.cancel();
      _keyRepeatTimer = null;
      _lastPressedKey = null;
      return KeyEventResult.ignored;
    }

    // Check for modifiers
    final isCtrl = HardwareKeyboard.instance.isControlPressed;
    final isShift = HardwareKeyboard.instance.isShiftPressed;
    final isAlt = HardwareKeyboard.instance.isAltPressed;

    // Helper to check if shortcut matches
    bool matchesShortcut(KeyboardShortcut shortcut) {
      return event.logicalKey == shortcut.key &&
          isCtrl == shortcut.ctrlPressed &&
          isShift == shortcut.shiftPressed &&
          isAlt == shortcut.altPressed;
    }

    // Helper to start key repeat.
    // Repeats are chained after each action completes, so seeks never overlap.
    void startKeyRepeat(Future<void> Function() action, {Duration? interval}) {
      // Ignore OS key-repeat KeyDown events while this key is already active.
      if (_lastPressedKey == event.logicalKey) {
        return;
      }

      _keyRepeatTimer?.cancel();
      _lastPressedKey = event.logicalKey;
      final generation = ++_keyRepeatGeneration;
      final repeatInterval = interval ?? const Duration(milliseconds: 50);

      Future<void> runAndSchedule({required bool initial}) async {
        if (generation != _keyRepeatGeneration) return;
        await action();
        if (generation != _keyRepeatGeneration) return;

        _keyRepeatTimer = Timer(
          initial ? const Duration(milliseconds: 500) : repeatInterval,
          () => unawaited(runAndSchedule(initial: false)),
        );
      }

      // Execute immediately, then schedule repeat chain.
      unawaited(runAndSchedule(initial: true));
    }

    // Handle key up events - stop repeat
    if (event is KeyUpEvent) {
      if (_lastPressedKey == event.logicalKey) {
        _keyRepeatGeneration++;
        _keyRepeatTimer?.cancel();
        _keyRepeatTimer = null;
        _lastPressedKey = null;
      }
      return KeyEventResult.ignored;
    }

    // Only handle key down events for actions
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    if (matchesShortcut(_shortcuts.toggleFullscreen)) {
      _toggleFullscreenMode();
      return KeyEventResult.handled;
    }

    // General shortcuts
    if (_shortcuts.generalShortcutsEnabled) {
      if (matchesShortcut(_shortcuts.openCommandPalette)) {
        _openCommandPalette();
        return KeyEventResult.handled;
      }

      // Next frame (with repeat)
      if (matchesShortcut(_shortcuts.nextFrame)) {
        startKeyRepeat(() async => playerNotifier.stepForward());
        return KeyEventResult.handled;
      }

      // Previous frame (with repeat)
      if (matchesShortcut(_shortcuts.previousFrame)) {
        startKeyRepeat(() async => playerNotifier.stepBackward());
        return KeyEventResult.handled;
      }

      // Play/Pause (no repeat)
      if (matchesShortcut(_shortcuts.playPause)) {
        playerNotifier.togglePlayPause();
        return KeyEventResult.handled;
      }

      // Jump forward (with repeat, slower)
      if (matchesShortcut(_shortcuts.jumpForward)) {
        startKeyRepeat(
          () async => playerNotifier.jumpForward(const Duration(seconds: 1)),
          interval: const Duration(milliseconds: 100),
        );
        return KeyEventResult.handled;
      }

      // Jump backward (with repeat, slower)
      if (matchesShortcut(_shortcuts.jumpBackward)) {
        startKeyRepeat(
          () async => playerNotifier.jumpBackward(const Duration(seconds: 1)),
          interval: const Duration(milliseconds: 100),
        );
        return KeyEventResult.handled;
      }

      // Open file (no repeat)
      if (matchesShortcut(_shortcuts.openFile)) {
        _openFile();
        return KeyEventResult.handled;
      }

      // Save annotations (no repeat)
      if (matchesShortcut(_shortcuts.saveAnnotations)) {
        _saveAnnotations();
        return KeyEventResult.handled;
      }

      // Undo (no repeat)
      if (matchesShortcut(_shortcuts.undo)) {
        if (annotationNotifier.canUndo) {
          annotationNotifier.undo();
          return KeyEventResult.handled;
        }
      }

      // Redo (no repeat)
      if (matchesShortcut(_shortcuts.redo)) {
        if (annotationNotifier.canRedo) {
          annotationNotifier.redo();
          return KeyEventResult.handled;
        }
      }

      if (matchesShortcut(_shortcuts.nextMarker)) {
        unawaited(annotationNotifier.seekToNextMarker());
        return KeyEventResult.handled;
      }

      if (matchesShortcut(_shortcuts.previousMarker)) {
        unawaited(annotationNotifier.seekToPreviousMarker());
        return KeyEventResult.handled;
      }

      // Delete selected annotation (no repeat)
      if (event.logicalKey == LogicalKeyboardKey.delete) {
        if (annotationState.selectedStrokeId != null ||
            annotationState.selectedStrokeIds.isNotEmpty) {
          annotationNotifier.deleteSelectedStroke();
          return KeyEventResult.handled;
        }
      }
    }

    // Annotation tools shortcuts
    if (_shortcuts.annotationToolsShortcutsEnabled) {
      // Select selection tool (no repeat)
      if (matchesShortcut(_shortcuts.selectSelectionTool)) {
        annotationNotifier.setTool(DrawingTool.select);
        return KeyEventResult.handled;
      }

      // Select pen tool (no repeat)
      if (matchesShortcut(_shortcuts.selectPenTool)) {
        annotationNotifier.setTool(DrawingTool.pen);
        return KeyEventResult.handled;
      }

      // Select eraser tool (no repeat)
      if (matchesShortcut(_shortcuts.selectEraserTool)) {
        annotationNotifier.setTool(DrawingTool.eraser);
        return KeyEventResult.handled;
      }

      // Select rectangle tool (no repeat)
      if (matchesShortcut(_shortcuts.selectRectangleTool)) {
        annotationNotifier.setTool(DrawingTool.rectangle);
        return KeyEventResult.handled;
      }

      // Select circle tool (no repeat)
      if (matchesShortcut(_shortcuts.selectCircleTool)) {
        annotationNotifier.setTool(DrawingTool.circle);
        return KeyEventResult.handled;
      }

      // Select line tool (no repeat)
      if (matchesShortcut(_shortcuts.selectLineTool)) {
        annotationNotifier.setTool(DrawingTool.line);
        return KeyEventResult.handled;
      }

      // Select arrow tool (no repeat)
      if (matchesShortcut(_shortcuts.selectArrowTool)) {
        annotationNotifier.setTool(DrawingTool.arrow);
        return KeyEventResult.handled;
      }

      // Select text tool (no repeat)
      if (matchesShortcut(_shortcuts.selectTextTool)) {
        annotationNotifier.setTool(DrawingTool.text);
        return KeyEventResult.handled;
      }

      // Toggle keyframe creation mode (no repeat)
      if (matchesShortcut(_shortcuts.toggleKeyframeMode)) {
        annotationNotifier.setKeyframeCreationMode(
          annotationState.keyframeCreationMode == KeyframeCreationMode.manual
              ? KeyframeCreationMode.automatic
              : KeyframeCreationMode.manual,
        );
        return KeyEventResult.handled;
      }

      // Create manual keyframe at current frame (no repeat)
      if (matchesShortcut(_shortcuts.createManualKeyframe)) {
        annotationNotifier.createManualKeyframeAtCurrentFrame();
        return KeyEventResult.handled;
      }
    }

    // Loop controls shortcuts
    if (_shortcuts.loopControlsShortcutsEnabled) {
      // Toggle full video loop (no repeat)
      if (matchesShortcut(_shortcuts.toggleFullLoop)) {
        loopNotifier.toggleFullVideoLoop();
        return KeyEventResult.handled;
      }

      // Set loop start point (A) (no repeat)
      if (matchesShortcut(_shortcuts.setLoopStart)) {
        loopNotifier.setAPoint();
        return KeyEventResult.handled;
      }

      // Set loop end point (B) (no repeat)
      if (matchesShortcut(_shortcuts.setLoopEnd)) {
        loopNotifier.setBPoint();
        return KeyEventResult.handled;
      }

      // Toggle section loop (A-B) (no repeat)
      if (matchesShortcut(_shortcuts.toggleSectionLoop)) {
        loopNotifier.toggleSectionLoop();
        return KeyEventResult.handled;
      }
    }

    // Crop controls shortcuts
    if (_shortcuts.cropControlsShortcutsEnabled) {
      if (matchesShortcut(_shortcuts.toggleCropMode)) {
        _toggleCropExportPanel();
        return KeyEventResult.handled;
      }
    }

    // Escape key - close crop/export panel or exit fullscreen
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      if (_isFullscreen) {
        _setFullscreenMode(false);
        return KeyEventResult.handled;
      }
      if (_showCropExportPanel) {
        setState(() => _showCropExportPanel = false);
        ref.read(cropProvider.notifier).exitCropMode();
        return KeyEventResult.handled;
      }
    }

    return KeyEventResult.ignored;
  }

  bool _isEditableTextFocused() {
    final context = FocusManager.instance.primaryFocus?.context;
    if (context == null) {
      return false;
    }

    var hasEditableText = false;
    context.visitAncestorElements((element) {
      if (element.widget is EditableText) {
        hasEditableText = true;
        return false;
      }
      return true;
    });

    return hasEditableText || context.widget is EditableText;
  }

  void _openCommandPalette() {
    if (_showCommandPalette) return;
    setState(() => _showCommandPalette = true);
  }

  void _closeCommandPalette() {
    if (!_showCommandPalette) return;
    setState(() => _showCommandPalette = false);
    _focusNode.requestFocus();
  }

  void _toggleCropExportPanel() {
    setState(() => _showCropExportPanel = !_showCropExportPanel);
    if (!_showCropExportPanel) {
      ref.read(cropProvider.notifier).exitCropMode();
    }
    _focusNode.requestFocus();
  }

  void _toggleFullscreenMode() {
    _setFullscreenMode(!_isFullscreen);
  }

  void _toggleInspectorVisibility() {
    setState(() {
      _showInspector = !_showInspector;
    });
    _focusNode.requestFocus();
  }

  void _toggleToolsPanelVisibility() {
    setState(() {
      _showToolsPanel = !_showToolsPanel;
    });
    _focusNode.requestFocus();
  }

  void _toggleToolsStrip() {
    setState(() {
      _showToolsStrip = !_showToolsStrip;
    });
    _focusNode.requestFocus();
  }

  void _setFullscreenMode(bool enabled) {
    if (_isFullscreen == enabled) {
      return;
    }
    setState(() {
      _isFullscreen = enabled;
    });
    _focusNode.requestFocus();
  }

  Future<void> _openRecentFromPalette() {
    return _sourceOpenActions.openRecentFromPalette();
  }

  Future<void> _loadInitialVideo(String filePath) {
    return _sourceOpenActions.loadInitialVideo(filePath);
  }

  Future<void> _openFile() {
    return _sourceOpenActions.openFile();
  }

  Future<void> _openYouTubeUrl() {
    return _sourceOpenActions.openYouTubeUrl();
  }

  Future<void> _openAnnotationJson() {
    return _sourceOpenActions.openAnnotationJson();
  }

  Future<void> _saveAnnotations() async {
    try {
      final annotationNotifier = ref.read(annotationProvider.notifier);
      final success = await annotationNotifier.saveAnnotations();

      if (mounted) {
        if (success) {
          _scaffoldMessengerKey.currentState?.showSnackBar(
            SnackBar(
              content: Text('Annotations saved successfully'),
              backgroundColor: _activePalette.success,
            ),
          );
        } else {
          _showErrorDialog('Failed to save annotations');
        }
      }

      // Refocus
      _focusNode.requestFocus();
    } catch (e) {
      if (mounted) {
        _showErrorDialog('Error saving annotations: $e');
      }
    }
  }

  Future<void> _saveAnnotationsAs() async {
    try {
      final annotationState = ref.read(annotationProvider);
      final annotationData = annotationState.annotationData;
      if (annotationData == null) {
        _showErrorDialog('No annotations to save');
        return;
      }

      final playerState = ref.read(playerProvider);
      final suggestedBaseName = _buildSuggestedAnnotationFileBaseName(
        annotationData: annotationData,
        playerSourceLabel: playerState.currentSourceLabel,
      );

      final selectedPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Annotation File As',
        fileName: '$suggestedBaseName.framesketch',
        type: FileType.custom,
        allowedExtensions: ['framesketch', 'json'],
      );

      if (selectedPath == null) {
        _focusNode.requestFocus();
        return;
      }

      final outputPath = _normalizeAnnotationJsonOutputPath(selectedPath);
      final success = await ref
          .read(annotationProvider.notifier)
          .saveAnnotationsToFile(outputPath);

      if (!mounted) return;

      if (success) {
        _scaffoldMessengerKey.currentState?.showSnackBar(
          SnackBar(
            content: Text('Annotation file saved: $outputPath'),
            backgroundColor: _activePalette.success,
          ),
        );
      } else {
        _showErrorDialog('Failed to save annotation file');
      }

      _focusNode.requestFocus();
    } catch (e) {
      if (mounted) {
        _showErrorDialog('Error saving annotation file: $e');
      }
    }
  }

  String _normalizeAnnotationJsonOutputPath(String rawPath) {
    final lower = rawPath.toLowerCase();
    if (lower.endsWith('.framesketch') ||
        lower.endsWith('.annotations.json') ||
        lower.endsWith('.json')) {
      return rawPath;
    }
    return '$rawPath.framesketch';
  }

  String _buildSuggestedAnnotationFileBaseName({
    required AnnotationData annotationData,
    required String? playerSourceLabel,
  }) {
    final youtubeUrl = annotationData.youtubeUrl;
    if (youtubeUrl != null && youtubeUrl.trim().isNotEmpty) {
      final uri = Uri.tryParse(youtubeUrl);
      final shortSegments = uri?.pathSegments
          .where((s) => s.isNotEmpty)
          .toList();
      final videoId =
          uri?.queryParameters['v'] ??
          (uri?.host.toLowerCase().contains('youtu.be') == true
              ? ((shortSegments != null && shortSegments.isNotEmpty)
                    ? shortSegments.last
                    : null)
              : null);
      final label = videoId == null || videoId.isEmpty
          ? (playerSourceLabel ?? 'youtube_video')
          : 'youtube_$videoId';
      return _buildSafeOutputBaseName(label);
    }

    final videoPath = annotationData.videoPath;
    if (videoPath.isNotEmpty) {
      final fileName = File(videoPath).uri.pathSegments.isNotEmpty
          ? File(videoPath).uri.pathSegments.last
          : videoPath;
      final dot = fileName.lastIndexOf('.');
      final base = dot > 0 ? fileName.substring(0, dot) : fileName;
      return _buildSafeOutputBaseName(base);
    }

    return 'annotations';
  }

  Future<void> _exportVideoFromTopBar() async {
    try {
      final playerState = ref.read(playerProvider);
      final annotationData = ref.read(annotationProvider).annotationData;

      if (playerState.currentVideoPath == null) {
        _showErrorDialog('No video loaded');
        return;
      }
      if (annotationData == null || playerState.metadata == null) {
        _showErrorDialog('Open a video before exporting.');
        return;
      }

      final cropState = ref.read(cropProvider);
      if (cropState.exportStatus == ExportStatus.exporting) {
        return;
      }

      final dialogHostContext = _navigatorKey.currentContext;
      if (dialogHostContext == null || !mounted) {
        return;
      }

      final exportRequest = await showDialog<_ExportRequest>(
        context: dialogHostContext,
        builder: (dialogContext) => _ExportOptionsDialog(
          initialFrame: ref.read(playerProvider.notifier).currentFrame,
          metadata: playerState.metadata!,
          suggestedBaseName: _buildSuggestedAnnotationFileBaseName(
            annotationData: annotationData,
            playerSourceLabel: playerState.currentSourceLabel,
          ),
          exportStart: cropState.exportStart,
          exportEnd: cropState.exportEnd,
          isLocalSource: playerState.isLocalFileSource,
        ),
      );

      if (exportRequest == null) {
        _focusNode.requestFocus();
        return;
      }

      switch (exportRequest.mode) {
        case _ExportMode.frame:
          await _exportSingleFrame(exportRequest);
          break;
        case _ExportMode.frames:
          await _exportFrameRange(exportRequest);
          break;
        case _ExportMode.video:
          await _exportAnnotatedVideo(exportRequest);
          break;
        case _ExportMode.annotationFile:
          await _exportAnnotationFile(exportRequest, annotationData);
          break;
      }

      _focusNode.requestFocus();
    } catch (e) {
      if (e is _ExportCancelledException) {
        _exportCancelRequested = false;
        if (mounted) {
          _showExportCancelledSnackBar();
          _focusNode.requestFocus();
        }
        return;
      }
      if (mounted) {
        _showErrorDialog('Error exporting video: $e');
      }
    }
  }

  Future<void> _exportFramesFromPanel({
    required int startFrame,
    required int endFrame,
    required int step,
    required bool isPng,
  }) async {
    final playerState = ref.read(playerProvider);
    if (playerState.currentVideoPath == null || playerState.metadata == null) {
      _showErrorDialog('No local video loaded');
      return;
    }
    final annotationData = ref.read(annotationProvider).annotationData;
    if (annotationData == null) {
      _showErrorDialog('Open a video before exporting.');
      return;
    }
    final suggestedBase = _buildSuggestedAnnotationFileBaseName(
      annotationData: annotationData,
      playerSourceLabel: playerState.currentSourceLabel,
    );
    final cropState = ref.read(cropProvider);
    final meta = playerState.metadata!;
    final cropPixels = cropState.isCropModeActive
        ? cropState.cropRect.toPixels(meta.width, meta.height)
        : null;

    final request = _ExportRequest(
      mode: startFrame == endFrame ? _ExportMode.frame : _ExportMode.frames,
      suggestedBaseName: suggestedBase,
      startFrame: startFrame,
      endFrame: endFrame,
      frameStep: step,
      frameFormat: isPng ? _FrameExportFormat.png : _FrameExportFormat.jpg,
      cropPixels: cropPixels,
    );
    try {
      if (startFrame == endFrame) {
        await _exportSingleFrame(request);
      } else {
        await _exportFrameRange(request);
      }
    } catch (e) {
      if (e is _ExportCancelledException) {
        _exportCancelRequested = false;
        if (mounted) _showExportCancelledSnackBar();
        return;
      }
      if (mounted) _showErrorDialog('Error exporting frames: $e');
    } finally {
      _focusNode.requestFocus();
    }
  }

  Future<void> _exportSingleFrame(_ExportRequest request) async {
    final playerState = ref.read(playerProvider);
    final metadata = playerState.metadata;
    final videoPath = playerState.currentVideoPath;
    if (metadata == null || videoPath == null) {
      _showErrorDialog('No local video loaded');
      return;
    }

    final outputPath = await FilePicker.platform.saveFile(
      dialogTitle: 'Export Frame',
      fileName:
          '${request.suggestedBaseName}_frame_${request.startFrame.toString().padLeft(6, '0')}.${request.frameExtension}',
      type: FileType.custom,
      allowedExtensions: [request.frameExtension],
    );

    if (outputPath == null) {
      return;
    }

    final normalizedOutputPath = _ensureFileExtension(
      outputPath,
      request.frameExtension,
    );
    final timestamp = _durationForFrame(request.startFrame, metadata.fps);

    await _runWithLoadingOverlay(
      message: 'Exporting frame ${request.startFrame}...',
      cancelLabel: 'Cancel Export',
      onCancel: _requestExportCancel,
      action: () async {
        _exportCancelRequested = false;
        await _exportFrameImage(
          videoPath,
          timestamp: timestamp,
          outputPath: normalizedOutputPath,
          metadata: metadata,
          annotationData: ref.read(annotationProvider).annotationData,
          cropPixels: request.cropPixels,
        );
      },
    );

    if (!mounted) return;
    if (_exportCancelRequested) {
      _exportCancelRequested = false;
      _showExportCancelledSnackBar();
      return;
    }
    _scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Text('Frame exported: $normalizedOutputPath'),
        backgroundColor: _activePalette.success,
      ),
    );
  }

  Future<void> _exportFrameRange(_ExportRequest request) async {
    final playerState = ref.read(playerProvider);
    final metadata = playerState.metadata;
    final videoPath = playerState.currentVideoPath;
    if (metadata == null || videoPath == null) {
      _showErrorDialog('No local video loaded');
      return;
    }

    final selectedDirectory = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Choose Folder for Exported Frames',
    );
    if (selectedDirectory == null) {
      return;
    }

    final outputDirectory = Directory(selectedDirectory);
    final frameJobs = <_FrameExportJob>[];
    for (
      var frame = request.startFrame;
      frame <= request.endFrame;
      frame += request.frameStep
    ) {
      frameJobs.add(
        _FrameExportJob(
          frameNumber: frame,
          timestamp: _durationForFrame(frame, metadata.fps),
          outputPath:
              '${outputDirectory.path}${Platform.pathSeparator}'
              '${request.suggestedBaseName}_frame_${frame.toString().padLeft(6, '0')}.${request.frameExtension}',
        ),
      );
    }

    await _runWithLoadingOverlay(
      message: 'Exporting ${frameJobs.length} frames...',
      cancelLabel: 'Cancel Export',
      onCancel: _requestExportCancel,
      action: () async {
        _exportCancelRequested = false;
        final annotationData = ref.read(annotationProvider).annotationData;
        final ffmpegPath = await _findExportFfmpegPath();
        final plannedJobs = _planFrameExportJobs(frameJobs);

        if (annotationData == null ||
            plannedJobs.every((job) => job.visibleStrokes.isEmpty)) {
          await _exportUnannotatedFrameRange(
            ffmpegPath: ffmpegPath,
            videoPath: videoPath,
            jobs: plannedJobs,
            frameExtension: request.frameExtension,
            cropPixels: request.cropPixels,
          );
          return;
        }

        await _exportAnnotatedFrameRange(
          ffmpegPath: ffmpegPath,
          videoPath: videoPath,
          jobs: plannedJobs,
          metadata: metadata,
          annotationData: annotationData,
          cropPixels: request.cropPixels,
        );
      },
    );

    if (!mounted) return;
    if (_exportCancelRequested) {
      _exportCancelRequested = false;
      _showExportCancelledSnackBar();
      return;
    }
    _scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Text(
          'Exported ${frameJobs.length} frames to ${outputDirectory.path}',
        ),
        backgroundColor: _activePalette.success,
      ),
    );
  }

  Future<void> _exportAnnotatedVideo(_ExportRequest request) async {
    final playerState = ref.read(playerProvider);
    if (!playerState.isLocalFileSource) {
      _showErrorDialog('Video export is only available for local video files.');
      return;
    }

    final cropState = ref.read(cropProvider);
    final cropNotifier = ref.read(cropProvider.notifier);
    final annotationNotifier = ref.read(annotationProvider.notifier);
    final outputPath = await FilePicker.platform.saveFile(
      dialogTitle: 'Export Annotated Video',
      fileName: '${request.suggestedBaseName}_annotated.mp4',
      type: FileType.custom,
      allowedExtensions: const ['mp4'],
    );

    if (outputPath == null) {
      return;
    }

    final normalizedOutputPath = _ensureFileExtension(outputPath, 'mp4');
    final metadata = playerState.metadata;
    if (metadata == null) {
      _showErrorDialog('No local video loaded');
      return;
    }

    final previousStart = cropState.exportStart;
    final previousEnd = cropState.exportEnd;

    try {
      cropNotifier.setExportRange(
        start: _durationForFrame(request.startFrame, metadata.fps),
        end: _durationForFrame(request.endFrame + 1, metadata.fps),
      );

      await annotationNotifier.saveAnnotations();
      await _runWithLoadingOverlay(
        message: 'Exporting annotated video...',
        cancelLabel: 'Cancel Export',
        onCancel: () {
          cropNotifier.cancelExport();
          if (!mounted) return;
          setState(() {
            _loadingOverlayMessage = 'Cancelling export...';
          });
        },
        action: () => cropNotifier.exportCroppedVideo(
          normalizedOutputPath,
          annotationData: ref.read(annotationProvider).annotationData,
          preset: request.videoPreset,
        ),
      );
    } finally {
      cropNotifier.setExportRange(start: previousStart, end: previousEnd);
    }

    if (!mounted) return;

    final updatedCropState = ref.read(cropProvider);
    switch (updatedCropState.exportStatus) {
      case ExportStatus.success:
        _scaffoldMessengerKey.currentState?.showSnackBar(
          SnackBar(
            content: Text(
              'Export complete: ${updatedCropState.exportedFilePath ?? normalizedOutputPath}',
            ),
            backgroundColor: _activePalette.success,
          ),
        );
        break;
      case ExportStatus.cancelled:
        _scaffoldMessengerKey.currentState?.showSnackBar(
          SnackBar(
            content: const Text('Export cancelled'),
            backgroundColor: _activePalette.warning,
          ),
        );
        break;
      case ExportStatus.error:
        _showErrorDialog(updatedCropState.exportError ?? 'Export failed');
        break;
      case ExportStatus.idle:
      case ExportStatus.preparing:
      case ExportStatus.exporting:
        break;
    }
  }

  Future<void> _exportFrameImage(
    String videoPath, {
    required Duration timestamp,
    required String outputPath,
    required VideoMetadata metadata,
    required AnnotationData? annotationData,
    ({int x, int y, int width, int height})? cropPixels,
  }) async {
    _throwIfExportCancelled();
    final visibleStrokes = ref
        .read(annotationProvider.notifier)
        .getVisibleStrokes(timestamp);
    if (annotationData == null || visibleStrokes.isEmpty) {
      final exported = await _extractFrameAtCancellable(
        videoPath,
        timestamp: timestamp,
        outputPath: outputPath,
        cropPixels: cropPixels,
      );
      if (exported == null) {
        throw StateError('Failed to export frame.');
      }
      return;
    }

    final ffmpegPath = await _ffprobeService.findFFmpegPath();
    if (ffmpegPath == null) {
      throw StateError(
        'FFmpeg not found. Automatic provisioning failed. Check internet access and try again.',
      );
    }

    Directory? tempDir;
    try {
      tempDir = await Directory.systemTemp.createTemp(
        'framesketch_frame_export_',
      );
      final overlayPath =
          '${tempDir.path}${Platform.pathSeparator}frame_overlay.png';
      await _overlayRenderer.renderOverlayImage(
        outputPath: overlayPath,
        strokes: visibleStrokes,
        width: metadata.width,
        height: metadata.height,
        viewportWidth: annotationData.viewportWidth,
        viewportHeight: annotationData.viewportHeight,
      );

      final seconds = (timestamp.inMicroseconds / 1000000.0).toStringAsFixed(6);
      _throwIfExportCancelled();
      final filterComplex = cropPixels != null
          ? '[0:v][1:v]overlay=0:0[overlaid];[overlaid]crop=${cropPixels.width}:${cropPixels.height}:${cropPixels.x}:${cropPixels.y}'
          : '[0:v][1:v]overlay=0:0';
      final process = await Process.start(ffmpegPath, [
        '-hide_banner',
        '-ss',
        seconds,
        '-i',
        videoPath,
        '-i',
        overlayPath,
        '-filter_complex',
        filterComplex,
        '-frames:v',
        '1',
        '-q:v',
        '2',
        '-y',
        outputPath,
      ]);
      _activeFrameExportProcess = process;
      unawaited(process.stdout.drain<void>());
      unawaited(process.stderr.drain<void>());

      final result = await process.exitCode
          .timeout(
            const Duration(minutes: 2),
            onTimeout: () {
              process.kill();
              throw TimeoutException(
                'FFmpeg frame export exceeded 2 minute timeout',
              );
            },
          )
          .then((exitCode) => _ProcessResult(exitCode, '', ''));

      _throwIfExportCancelled();
      if (result.exitCode != 0) {
        throw StateError(
          'Failed to burn annotations into frame: ${result.stderr}',
        );
      }
    } finally {
      if (tempDir != null && await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
      _activeFrameExportProcess = null;
    }
  }

  Future<File?> _extractFrameAtCancellable(
    String videoPath, {
    required Duration timestamp,
    required String outputPath,
    String? ffmpegPath,
    ({int x, int y, int width, int height})? cropPixels,
  }) async {
    final resolvedFfmpegPath = ffmpegPath ?? await _findExportFfmpegPath();

    _throwIfExportCancelled();
    final seconds = (timestamp.inMicroseconds / 1000000.0).toStringAsFixed(6);
    final args = <String>[
      '-ss',
      seconds,
      '-i',
      videoPath,
      if (cropPixels != null) ...[
        '-vf',
        'crop=${cropPixels.width}:${cropPixels.height}:${cropPixels.x}:${cropPixels.y}',
      ],
      '-frames:v',
      '1',
      '-q:v',
      '2',
      '-y',
      outputPath,
    ];
    final process = await Process.start(resolvedFfmpegPath, args);
    _activeFrameExportProcess = process;

    final stderrBuffer = StringBuffer();
    unawaited(process.stdout.drain<void>());
    process.stderr
        .transform(const SystemEncoding().decoder)
        .listen(stderrBuffer.write);

    final exitCode = await process.exitCode.timeout(
      const Duration(minutes: 2),
      onTimeout: () {
        process.kill();
        throw TimeoutException('FFmpeg frame export exceeded 2 minute timeout');
      },
    );
    _activeFrameExportProcess = null;
    _throwIfExportCancelled();
    if (exitCode == 0) {
      return File(outputPath);
    }
    throw StateError('Failed to export frame: ${stderrBuffer.toString()}');
  }

  Future<String> _findExportFfmpegPath() async {
    final ffmpegPath = await _ffprobeService.findFFmpegPath();
    if (ffmpegPath == null) {
      throw StateError(
        'FFmpeg not found. Automatic provisioning failed. Check internet access and try again.',
      );
    }
    return ffmpegPath;
  }

  List<_PlannedFrameExportJob> _planFrameExportJobs(
    List<_FrameExportJob> jobs,
  ) {
    final annotationNotifier = ref.read(annotationProvider.notifier);
    return [
      for (final job in jobs)
        _PlannedFrameExportJob(
          frameNumber: job.frameNumber,
          timestamp: job.timestamp,
          outputPath: job.outputPath,
          activeKeyframeMs: annotationNotifier.getActiveKeyframeTimeMs(
            job.timestamp,
          ),
          visibleStrokes: annotationNotifier.getVisibleStrokes(job.timestamp),
        ),
    ];
  }

  Future<void> _exportUnannotatedFrameRange({
    required String ffmpegPath,
    required String videoPath,
    required List<_PlannedFrameExportJob> jobs,
    required String frameExtension,
    ({int x, int y, int width, int height})? cropPixels,
  }) async {
    if (jobs.isEmpty) return;

    Directory? tempDir;
    try {
      tempDir = await Directory.systemTemp.createTemp(
        'framesketch_frame_range_',
      );
      final tempPattern =
          '${tempDir.path}${Platform.pathSeparator}frame_%06d.$frameExtension';
      final selectFilter = _buildFrameSelectExpression(jobs);
      final vfFilter = cropPixels != null
          ? 'select=$selectFilter,crop=${cropPixels.width}:${cropPixels.height}:${cropPixels.x}:${cropPixels.y}'
          : 'select=$selectFilter';

      _throwIfExportCancelled();
      final process = await Process.start(ffmpegPath, [
        '-hide_banner',
        '-i',
        videoPath,
        '-vf',
        vfFilter,
        '-vsync',
        '0',
        '-q:v',
        '2',
        '-y',
        tempPattern,
      ]);
      _activeFrameExportProcess = process;

      final stderrBuffer = StringBuffer();
      unawaited(process.stdout.drain<void>());
      process.stderr
          .transform(const SystemEncoding().decoder)
          .listen(stderrBuffer.write);

      final exitCode = await process.exitCode.timeout(
        const Duration(minutes: 10),
        onTimeout: () {
          process.kill();
          throw TimeoutException(
            'FFmpeg frame range export exceeded 10 minute timeout',
          );
        },
      );
      _activeFrameExportProcess = null;
      _throwIfExportCancelled();

      if (exitCode != 0) {
        throw StateError(
          'Failed to export frame range: ${stderrBuffer.toString()}',
        );
      }

      for (var index = 0; index < jobs.length; index += 1) {
        _throwIfExportCancelled();
        final tempPath =
            '${tempDir.path}${Platform.pathSeparator}frame_${(index + 1).toString().padLeft(6, '0')}.$frameExtension';
        final tempFile = File(tempPath);
        if (!await tempFile.exists()) {
          throw StateError(
            'Frame range export produced fewer frames than expected.',
          );
        }
        final outputFile = File(jobs[index].outputPath);
        if (await outputFile.exists()) {
          await outputFile.delete();
        }
        await tempFile.rename(jobs[index].outputPath);
        _updateFrameRangeProgress(index + 1, jobs.length);
      }
    } finally {
      _activeFrameExportProcess = null;
      if (tempDir != null && await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    }
  }

  String _buildFrameSelectExpression(List<_PlannedFrameExportJob> jobs) {
    if (jobs.length == 1) {
      return 'eq(n\\,${jobs.first.frameNumber})';
    }

    final first = jobs.first.frameNumber;
    final last = jobs.last.frameNumber;
    final step = jobs[1].frameNumber - jobs[0].frameNumber;
    final isArithmetic =
        step > 0 &&
        jobs.indexed.every((entry) {
          final expected = first + entry.$1 * step;
          return entry.$2.frameNumber == expected;
        });

    if (!isArithmetic) {
      return jobs.map((job) => 'eq(n\\,${job.frameNumber})').join('+');
    }

    if (step == 1) {
      return 'between(n\\,$first\\,$last)';
    }

    return 'between(n\\,$first\\,$last)*not(mod(n-$first\\,$step))';
  }

  Future<void> _exportAnnotatedFrameRange({
    required String ffmpegPath,
    required String videoPath,
    required List<_PlannedFrameExportJob> jobs,
    required VideoMetadata metadata,
    required AnnotationData annotationData,
    ({int x, int y, int width, int height})? cropPixels,
  }) async {
    Directory? tempDir;
    try {
      tempDir = await Directory.systemTemp.createTemp(
        'framesketch_annotated_frames_',
      );
      final overlayCache = <int, String>{};

      for (var index = 0; index < jobs.length; index += 1) {
        _throwIfExportCancelled();
        final job = jobs[index];
        if (job.visibleStrokes.isEmpty) {
          final exported = await _extractFrameAtCancellable(
            videoPath,
            timestamp: job.timestamp,
            outputPath: job.outputPath,
            ffmpegPath: ffmpegPath,
            cropPixels: cropPixels,
          );
          if (exported == null) {
            throw StateError('Failed to export frame.');
          }
          _updateFrameRangeProgress(index + 1, jobs.length);
          continue;
        }

        final keyframeMs = job.activeKeyframeMs ?? job.timestamp.inMilliseconds;
        var overlayPath = overlayCache[keyframeMs];
        if (overlayPath == null) {
          overlayPath =
              '${tempDir.path}${Platform.pathSeparator}overlay_${overlayCache.length.toString().padLeft(4, '0')}.png';
          await _overlayRenderer.renderOverlayImage(
            outputPath: overlayPath,
            strokes: job.visibleStrokes,
            width: metadata.width,
            height: metadata.height,
            viewportWidth: annotationData.viewportWidth,
            viewportHeight: annotationData.viewportHeight,
          );
          overlayCache[keyframeMs] = overlayPath;
        }

        await _exportAnnotatedFrameImageWithOverlay(
          ffmpegPath: ffmpegPath,
          videoPath: videoPath,
          timestamp: job.timestamp,
          outputPath: job.outputPath,
          overlayPath: overlayPath,
          cropPixels: cropPixels,
        );
        _updateFrameRangeProgress(index + 1, jobs.length);
      }
    } finally {
      if (tempDir != null && await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
      _activeFrameExportProcess = null;
    }
  }

  Future<void> _exportAnnotatedFrameImageWithOverlay({
    required String ffmpegPath,
    required String videoPath,
    required Duration timestamp,
    required String outputPath,
    required String overlayPath,
    ({int x, int y, int width, int height})? cropPixels,
  }) async {
    final seconds = (timestamp.inMicroseconds / 1000000.0).toStringAsFixed(6);
    _throwIfExportCancelled();
    final filterComplex = cropPixels != null
        ? '[0:v]crop=${cropPixels.width}:${cropPixels.height}:${cropPixels.x}:${cropPixels.y}[cropped];[cropped][1:v]overlay=0:0'
        : '[0:v][1:v]overlay=0:0';
    final process = await Process.start(ffmpegPath, [
      '-hide_banner',
      '-ss',
      seconds,
      '-i',
      videoPath,
      '-i',
      overlayPath,
      '-filter_complex',
      filterComplex,
      '-frames:v',
      '1',
      '-q:v',
      '2',
      '-y',
      outputPath,
    ]);
    _activeFrameExportProcess = process;
    unawaited(process.stdout.drain<void>());
    unawaited(process.stderr.drain<void>());

    final exitCode = await process.exitCode.timeout(
      const Duration(minutes: 2),
      onTimeout: () {
        process.kill();
        throw TimeoutException('FFmpeg frame export exceeded 2 minute timeout');
      },
    );
    _activeFrameExportProcess = null;
    _throwIfExportCancelled();
    if (exitCode != 0) {
      throw StateError('Failed to burn annotations into frame.');
    }
  }

  void _updateFrameRangeProgress(int completedFrames, int totalFrames) {
    if (!mounted) return;
    final progressPercent = ((completedFrames / totalFrames) * 100).round();
    setState(() {
      _loadingOverlayMessage =
          'Exporting frame $completedFrames/$totalFrames ($progressPercent%)';
    });
  }

  void _requestExportCancel() {
    _exportCancelRequested = true;
    _activeFrameExportProcess?.kill();
    if (!mounted) return;
    setState(() {
      _loadingOverlayMessage = 'Cancelling export...';
    });
  }

  void _throwIfExportCancelled() {
    if (_exportCancelRequested) {
      throw const _ExportCancelledException();
    }
  }

  void _showExportCancelledSnackBar() {
    _scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        content: const Text('Export cancelled'),
        backgroundColor: _activePalette.warning,
      ),
    );
  }

  Future<void> _exportAnnotationFile(
    _ExportRequest request,
    AnnotationData annotationData,
  ) async {
    final playerState = ref.read(playerProvider);
    if (!playerState.isLocalFileSource) {
      _showErrorDialog(
        'Annotation file export is only available for local video files.',
      );
      return;
    }

    final extension = request.annotationExtension;
    final selectedPath = await FilePicker.platform.saveFile(
      dialogTitle: 'Export Annotation File',
      fileName: '${request.suggestedBaseName}.$extension',
      type: FileType.custom,
      allowedExtensions: ['framesketch', 'json'],
    );

    if (selectedPath == null) {
      return;
    }

    final outputPath = _ensureFileExtension(selectedPath, extension);
    final success = await ref
        .read(annotationProvider.notifier)
        .saveAnnotationsToFile(outputPath);

    if (!mounted) return;
    if (success) {
      _scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text('Annotation file exported: $outputPath'),
          backgroundColor: _activePalette.success,
        ),
      );
    } else {
      _showErrorDialog('Failed to export annotation file');
    }
  }

  Duration _durationForFrame(int frame, double fps) {
    if (fps <= 0) {
      return Duration(milliseconds: frame * 33);
    }
    final micros = ((frame * 1000000.0) / fps).round();
    return Duration(microseconds: micros);
  }

  String _ensureFileExtension(String path, String extension) {
    final normalizedExtension = extension.startsWith('.')
        ? extension.substring(1)
        : extension;
    final lowerPath = path.toLowerCase();
    final suffix = '.${normalizedExtension.toLowerCase()}';
    if (lowerPath.endsWith(suffix)) {
      return path;
    }
    return '$path.$normalizedExtension';
  }

  String _buildSafeOutputBaseName(String input) {
    final sanitized = input
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    if (sanitized.isEmpty) {
      return 'export';
    }

    const maxLen = 64;
    if (sanitized.length <= maxLen) {
      return sanitized;
    }

    return sanitized.substring(0, maxLen).trimRight();
  }

  void _openSettings(BuildContext context) {
    _settingsActions.openSettings(context);
  }

  void _openThemeManager(BuildContext context) {
    _settingsActions.openThemeManager(context);
  }

  Future<void> _handleMenuAction(String action, BuildContext context) {
    return _settingsActions.handleMenuAction(action);
  }

  void _showInfoDialog(String title, String message) {
    final context = _navigatorKey.currentContext;
    if (context == null || !mounted) return;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _focusNode.requestFocus();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    final context = _navigatorKey.currentContext;
    if (context == null || !mounted) return;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _focusNode.requestFocus();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

enum _ExportMode { frame, frames, video, annotationFile }

enum _FrameExportFormat { png, jpg }

enum _AnnotationExportFormat { framesketch, json }

class _ExportCancelledException implements Exception {
  const _ExportCancelledException();
}

class _ProcessResult {
  final int exitCode;
  final String stdout;
  final String stderr;

  _ProcessResult(this.exitCode, this.stdout, this.stderr);
}

class _FrameExportJob {
  final int frameNumber;
  final Duration timestamp;
  final String outputPath;

  const _FrameExportJob({
    required this.frameNumber,
    required this.timestamp,
    required this.outputPath,
  });
}

class _PlannedFrameExportJob extends _FrameExportJob {
  final int? activeKeyframeMs;
  final List<Stroke> visibleStrokes;

  const _PlannedFrameExportJob({
    required super.frameNumber,
    required super.timestamp,
    required super.outputPath,
    required this.activeKeyframeMs,
    required this.visibleStrokes,
  });
}

class _ExportRequest {
  final _ExportMode mode;
  final String suggestedBaseName;
  final int startFrame;
  final int endFrame;
  final int frameStep;
  final _FrameExportFormat frameFormat;
  final _AnnotationExportFormat annotationFormat;
  final VideoExportPreset videoPreset;
  final ({int x, int y, int width, int height})? cropPixels;

  const _ExportRequest({
    required this.mode,
    required this.suggestedBaseName,
    required this.startFrame,
    required this.endFrame,
    this.frameStep = 1,
    this.frameFormat = _FrameExportFormat.png,
    this.annotationFormat = _AnnotationExportFormat.framesketch,
    this.videoPreset = VideoExportPreset.compatible,
    this.cropPixels,
  });

  String get frameExtension =>
      frameFormat == _FrameExportFormat.jpg ? 'jpg' : 'png';

  String get annotationExtension =>
      annotationFormat == _AnnotationExportFormat.json ? 'json' : 'framesketch';
}

class _ExportOptionsDialog extends StatefulWidget {
  final int initialFrame;
  final VideoMetadata metadata;
  final String suggestedBaseName;
  final Duration? exportStart;
  final Duration? exportEnd;
  final bool isLocalSource;

  const _ExportOptionsDialog({
    required this.initialFrame,
    required this.metadata,
    required this.suggestedBaseName,
    required this.exportStart,
    required this.exportEnd,
    required this.isLocalSource,
  });

  @override
  State<_ExportOptionsDialog> createState() => _ExportOptionsDialogState();
}

class _ExportOptionsDialogState extends State<_ExportOptionsDialog> {
  late _ExportMode _mode;
  late _FrameExportFormat _frameFormat;
  late _AnnotationExportFormat _annotationFormat;
  late VideoExportPreset _videoPreset;
  late final TextEditingController _frameController;
  late final TextEditingController _startFrameController;
  late final TextEditingController _endFrameController;
  late final TextEditingController _stepController;
  String? _validationMessage;

  @override
  void initState() {
    super.initState();
    _mode = widget.isLocalSource ? _ExportMode.video : _ExportMode.frame;
    _frameFormat = _FrameExportFormat.png;
    _annotationFormat = _AnnotationExportFormat.framesketch;
    _videoPreset = VideoExportPreset.compatible;

    final startFrame = widget.exportStart == null
        ? 0
        : _frameFromDuration(widget.exportStart!);
    final endFrame = widget.exportEnd == null
        ? _maxFrame
        : (_frameFromDuration(widget.exportEnd!) - 1).clamp(0, _maxFrame);

    _frameController = TextEditingController(
      text: widget.initialFrame.toString(),
    );
    _startFrameController = TextEditingController(text: startFrame.toString());
    _endFrameController = TextEditingController(text: endFrame.toString());
    _stepController = TextEditingController(text: '1');
  }

  @override
  void dispose() {
    _frameController.dispose();
    _startFrameController.dispose();
    _endFrameController.dispose();
    _stepController.dispose();
    super.dispose();
  }

  int get _maxFrame => widget.metadata.frameCount > 0
      ? widget.metadata.frameCount - 1
      : widget.initialFrame;

  int _frameFromDuration(Duration duration) {
    final seconds = duration.inMicroseconds / 1000000.0;
    return (seconds * widget.metadata.fps).round().clamp(0, _maxFrame);
  }

  int? _parseFrame(TextEditingController controller) {
    return int.tryParse(controller.text.trim());
  }

  void _submit() {
    final frame = _parseFrame(_frameController);
    final startFrame = _parseFrame(_startFrameController);
    final endFrame = _parseFrame(_endFrameController);
    final step = _parseFrame(_stepController);

    String? validationMessage;
    if (_mode == _ExportMode.frame) {
      if (frame == null || frame < 0 || frame > _maxFrame) {
        validationMessage = 'Enter a frame between 0 and $_maxFrame.';
      }
    } else if (_mode == _ExportMode.frames) {
      if (startFrame == null || endFrame == null) {
        validationMessage = 'Enter a valid frame range.';
      } else if (startFrame < 0 ||
          endFrame > _maxFrame ||
          startFrame > endFrame) {
        validationMessage = 'Frame range must stay between 0 and $_maxFrame.';
      } else if (step == null || step <= 0) {
        validationMessage = 'Step must be 1 or greater.';
      }
    } else if (_mode == _ExportMode.video) {
      if (startFrame == null || endFrame == null) {
        validationMessage = 'Enter a valid video frame range.';
      } else if (startFrame < 0 ||
          endFrame > _maxFrame ||
          startFrame > endFrame) {
        validationMessage = 'Video range must stay between 0 and $_maxFrame.';
      }
    }

    if (validationMessage != null) {
      setState(() {
        _validationMessage = validationMessage;
      });
      return;
    }

    final resolvedEndFrame = _mode == _ExportMode.frame
        ? frame!
        : (_mode == _ExportMode.annotationFile
              ? (endFrame ?? _maxFrame)
              : endFrame!);

    Navigator.of(context).pop(
      _ExportRequest(
        mode: _mode,
        suggestedBaseName: widget.suggestedBaseName,
        startFrame: _mode == _ExportMode.frame ? frame! : (startFrame ?? 0),
        endFrame: resolvedEndFrame,
        frameStep: step ?? 1,
        frameFormat: _frameFormat,
        annotationFormat: _annotationFormat,
        videoPreset: _videoPreset,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Export'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<_ExportMode>(
                initialValue: _mode,
                decoration: const InputDecoration(labelText: 'Export Mode'),
                items: _modeItems,
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _mode = value;
                    _validationMessage = null;
                  });
                },
              ),
              const SizedBox(height: 14),
              if (_mode == _ExportMode.frame) ...[
                _frameField(controller: _frameController, label: 'Frame'),
                const SizedBox(height: 12),
                DropdownButtonFormField<_FrameExportFormat>(
                  initialValue: _frameFormat,
                  decoration: const InputDecoration(labelText: 'Image Format'),
                  items: const [
                    DropdownMenuItem(
                      value: _FrameExportFormat.png,
                      child: Text('PNG'),
                    ),
                    DropdownMenuItem(
                      value: _FrameExportFormat.jpg,
                      child: Text('JPG'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _frameFormat = value);
                  },
                ),
              ],
              if (_mode == _ExportMode.frames) ...[
                _frameField(
                  controller: _startFrameController,
                  label: 'Start Frame',
                ),
                const SizedBox(height: 12),
                _frameField(
                  controller: _endFrameController,
                  label: 'End Frame',
                ),
                const SizedBox(height: 12),
                _frameField(
                  controller: _stepController,
                  label: 'Every N Frames',
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<_FrameExportFormat>(
                  initialValue: _frameFormat,
                  decoration: const InputDecoration(labelText: 'Image Format'),
                  items: const [
                    DropdownMenuItem(
                      value: _FrameExportFormat.png,
                      child: Text('PNG'),
                    ),
                    DropdownMenuItem(
                      value: _FrameExportFormat.jpg,
                      child: Text('JPG'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _frameFormat = value);
                  },
                ),
              ],
              if (_mode == _ExportMode.video) ...[
                _frameField(
                  controller: _startFrameController,
                  label: 'Start Frame',
                ),
                const SizedBox(height: 12),
                _frameField(
                  controller: _endFrameController,
                  label: 'End Frame',
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<VideoExportPreset>(
                  initialValue: _videoPreset,
                  decoration: const InputDecoration(
                    labelText: 'Speed / Quality',
                  ),
                  items: VideoExportPreset.values
                      .map(
                        (preset) => DropdownMenuItem(
                          value: preset,
                          child: Text(preset.displayName),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _videoPreset = value);
                  },
                ),
                const SizedBox(height: 8),
                Text(
                  _videoPreset.description,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              if (_mode == _ExportMode.annotationFile) ...[
                DropdownButtonFormField<_AnnotationExportFormat>(
                  initialValue: _annotationFormat,
                  decoration: const InputDecoration(labelText: 'File Format'),
                  items: const [
                    DropdownMenuItem(
                      value: _AnnotationExportFormat.framesketch,
                      child: Text('.framesketch'),
                    ),
                    DropdownMenuItem(
                      value: _AnnotationExportFormat.json,
                      child: Text('.json'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _annotationFormat = value);
                  },
                ),
                const SizedBox(height: 8),
                Text(
                  'Exports the current annotation project file for this local video.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              if (_validationMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  _validationMessage!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Continue')),
      ],
    );
  }

  Widget _frameField({
    required TextEditingController controller,
    required String label,
  }) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        helperText: '0 - $_maxFrame',
      ),
    );
  }

  List<DropdownMenuItem<_ExportMode>> get _modeItems {
    return [
      const DropdownMenuItem(
        value: _ExportMode.frame,
        child: Text('Single Frame'),
      ),
      const DropdownMenuItem(
        value: _ExportMode.frames,
        child: Text('Multiple Frames'),
      ),
      if (widget.isLocalSource) ...const [
        DropdownMenuItem(
          value: _ExportMode.video,
          child: Text('Annotated Video'),
        ),
        DropdownMenuItem(
          value: _ExportMode.annotationFile,
          child: Text('Annotation File'),
        ),
      ],
    ];
  }
}
