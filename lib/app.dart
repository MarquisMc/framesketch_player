import 'dart:async';
import 'dart:io' show File;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'core/models/project_library_entry.dart';
import 'features/player/providers/player_provider.dart';
import 'features/annotations/providers/annotation_provider.dart';
import 'features/annotations/models/stroke.dart';
import 'core/models/annotation_data.dart';
import 'core/models/keyboard_shortcuts.dart';
import 'features/projects/providers/project_library_provider.dart';
import 'features/projects/widgets/project_library_actions.dart';
import 'features/projects/widgets/project_browser.dart';
import 'features/settings/providers/auto_save_provider.dart';
import 'features/settings/providers/keyboard_shortcuts_provider.dart';
import 'features/settings/widgets/settings_actions.dart';
import 'features/export/widgets/export_actions.dart';
import 'features/loop/providers/loop_provider.dart';
import 'features/crop/providers/crop_provider.dart';
import 'features/player/widgets/source_open_actions.dart';
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
  late final ExportActions _exportActions;
  late final ProviderSubscription<(bool, DateTime?)> _autoSaveSubscription;
  late final ProviderSubscription<({int strokeCount, int undoCount})>
  _historyFeedbackSubscription;
  late final ProviderSubscription<({bool isEditingText, bool isInteracting})>
  _annotationFocusSubscription;
  Timer? _keyRepeatTimer;
  Timer? _exportIconTimer;
  Timer? _autoSaveTimer;
  Timer? _historyFeedbackTimer;
  Timer? _autoSaveIndicatorTimer;
  LogicalKeyboardKey? _lastPressedKey;
  int _keyRepeatGeneration = 0;
  bool _isFullscreen = false;
  bool _showInspector = true;
  bool _showToolsPanel = true;
  bool _showToolsStrip = false;
  bool _showCommandPalette = false;
  bool _showCropExportPanel = false;
  bool _showExportHourglassBottom = false;
  bool _showAutoSaveIndicator = false;
  bool _isHistoryFeedbackVisible = false;
  String? _historyFeedbackLabel;
  IconData? _historyFeedbackIcon;
  int _loadingOverlayDepth = 0;
  String _loadingOverlayMessage = 'Loading...';
  String? _loadingOverlayCancelLabel;
  VoidCallback? _loadingOverlayCancelAction;
  bool _isAutoSaving = false;
  AppPalette get _activePalette =>
      ref.read(themeControllerProvider).activePalette;
  KeyboardShortcuts get _shortcuts => ref.read(keyboardShortcutsProvider);
  bool get _autoSaveEnabled => ref.read(autoSaveProvider);

  @override
  void initState() {
    super.initState();
    _exportActions = ExportActions(
      ref: ref,
      navigatorKey: _navigatorKey,
      scaffoldMessengerKey: _scaffoldMessengerKey,
      focusNode: _focusNode,
      isMounted: () => mounted,
      activePalette: () => _activePalette,
      runWithLoadingOverlay: _runWithLoadingOverlay,
      showErrorDialog: _showErrorDialog,
      buildSuggestedAnnotationFileBaseName:
          _buildSuggestedAnnotationFileBaseName,
      setLoadingOverlayMessage: _setLoadingOverlayMessage,
    );
    _autoSaveSubscription = ref.listenManual<(bool, DateTime?)>(
      annotationProvider.select(
        (state) => (state.hasUnsavedChanges, state.annotationData?.updatedAt),
      ),
      (previous, next) {
        _handleAutoSaveStateChanged(hasUnsavedChanges: next.$1);
      },
    );
    _historyFeedbackSubscription = ref
        .listenManual<({int strokeCount, int undoCount})>(
          annotationProvider.select(
            (state) => (
              strokeCount: state.allStrokes.length,
              undoCount: state.undoStack.length,
            ),
          ),
          (previous, next) {
            if (previous == null) return;

            final didUndo =
                next.strokeCount == previous.strokeCount - 1 &&
                next.undoCount == previous.undoCount + 1;
            final didRedo =
                next.strokeCount == previous.strokeCount + 1 &&
                next.undoCount == previous.undoCount - 1;

            if (didUndo) {
              _showHistoryFeedback('Undo', Icons.undo);
            } else if (didRedo) {
              _showHistoryFeedback('Redo', Icons.redo);
            }
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
      _hideAutoSaveIndicator();
      return;
    }

    _showAutoSaveIndicatorNow();
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

    _setAutoSaving(true);
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
      _setAutoSaving(false);
      final latestState = ref.read(annotationProvider);
      if (_autoSaveEnabled && latestState.hasUnsavedChanges) {
        _handleAutoSaveStateChanged(hasUnsavedChanges: true);
      }
    }
  }

  void _setAutoSaving(bool value) {
    _isAutoSaving = value;
    _autoSaveIndicatorTimer?.cancel();

    if (value) {
      _showAutoSaveIndicatorNow();
      return;
    }

    _autoSaveIndicatorTimer = Timer(const Duration(milliseconds: 1400), () {
      if (!mounted) return;
      setState(() {
        _showAutoSaveIndicator = false;
      });
    });
  }

  void _showAutoSaveIndicatorNow() {
    _autoSaveIndicatorTimer?.cancel();
    if (!mounted || _showAutoSaveIndicator) return;
    setState(() {
      _showAutoSaveIndicator = true;
    });
  }

  void _hideAutoSaveIndicator() {
    _autoSaveIndicatorTimer?.cancel();
    if (!mounted || !_showAutoSaveIndicator) return;
    setState(() {
      _showAutoSaveIndicator = false;
    });
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
    _exportActions.dispose();
    _autoSaveSubscription.close();
    _historyFeedbackSubscription.close();
    _annotationFocusSubscription.close();
    _keyRepeatTimer?.cancel();
    _exportIconTimer?.cancel();
    _autoSaveTimer?.cancel();
    _historyFeedbackTimer?.cancel();
    _autoSaveIndicatorTimer?.cancel();
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
                _HistoryFeedbackOverlay(
                  label: _historyFeedbackLabel,
                  icon: _historyFeedbackIcon,
                  isVisible: _isHistoryFeedbackVisible,
                  palette: _activePalette,
                ),
                _AutoSaveIndicator(
                  isVisible: _showAutoSaveIndicator,
                  palette: _activePalette,
                ),
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

  void _showHistoryFeedback(String label, IconData icon) {
    if (!mounted) return;

    _historyFeedbackTimer?.cancel();
    setState(() {
      _isHistoryFeedbackVisible = true;
      _historyFeedbackLabel = label;
      _historyFeedbackIcon = icon;
    });
    _historyFeedbackTimer = Timer(const Duration(milliseconds: 850), () {
      if (!mounted) return;
      setState(() {
        _isHistoryFeedbackVisible = false;
      });
      _historyFeedbackTimer = Timer(const Duration(milliseconds: 120), () {
        if (!mounted || _isHistoryFeedbackVisible) return;
        setState(() {
          _historyFeedbackLabel = null;
          _historyFeedbackIcon = null;
        });
      });
    });
  }

  void _setLoadingOverlayMessage(String message) {
    if (!mounted) return;
    setState(() {
      _loadingOverlayMessage = message;
    });
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

  Future<void> _exportVideoFromTopBar() {
    return _exportActions.exportVideoFromTopBar();
  }

  Future<void> _exportFramesFromPanel({
    required int startFrame,
    required int endFrame,
    required int step,
    required bool isPng,
  }) {
    return _exportActions.exportFramesFromPanel(
      startFrame: startFrame,
      endFrame: endFrame,
      step: step,
      isPng: isPng,
    );
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

class _HistoryFeedbackOverlay extends StatelessWidget {
  final String? label;
  final IconData? icon;
  final bool isVisible;
  final AppPalette palette;

  const _HistoryFeedbackOverlay({
    required this.label,
    required this.icon,
    required this.isVisible,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 72,
      left: 0,
      right: 0,
      child: IgnorePointer(
        child: AnimatedOpacity(
          opacity: isVisible ? 1 : 0,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          child: AnimatedScale(
            scale: isVisible ? 1 : 0.92,
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOut,
            child: Center(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: palette.panelElevated.withValues(alpha: 0.94),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: palette.accentBright),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.22),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 9,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        icon ?? Icons.undo,
                        size: 18,
                        color: palette.accentBright,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        label ?? '',
                        style: TextStyle(
                          color: palette.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AutoSaveIndicator extends StatelessWidget {
  final bool isVisible;
  final AppPalette palette;

  const _AutoSaveIndicator({required this.isVisible, required this.palette});

  @override
  Widget build(BuildContext context) {
    if (!isVisible) {
      return const SizedBox.shrink();
    }

    return Positioned(
      top: 14,
      right: 14,
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: palette.panelElevated.withValues(alpha: 0.96),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: palette.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: palette.accentBright,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Auto saving',
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
