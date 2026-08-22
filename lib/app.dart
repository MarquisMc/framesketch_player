import 'dart:async';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'core/models/project_library_entry.dart';
import 'core/models/keyboard_shortcuts.dart';
import 'core/utils/output_file_naming.dart';
import 'features/player/providers/player_provider.dart';
import 'features/annotations/providers/annotation_provider.dart';
import 'features/annotations/widgets/frame_marker_panel.dart';
import 'features/projects/providers/project_library_provider.dart';
import 'features/projects/widgets/project_library_actions.dart';
import 'features/projects/widgets/project_browser.dart';
import 'features/settings/application/auto_save_coordinator.dart';
import 'features/settings/application/update_check_flow.dart';
import 'features/settings/providers/keyboard_shortcuts_provider.dart';
import 'features/settings/widgets/settings_actions.dart';
import 'features/export/widgets/export_actions.dart';
import 'features/crop/providers/crop_provider.dart';
import 'features/player/widgets/source_open_actions.dart';
import 'core/theme/app_palette.dart';
import 'core/theme/theme_provider.dart';
import 'ui/editor_scaffold.dart';
import 'ui/command_palette/command_palette.dart';
import 'ui/command_palette/editor_command_factory.dart';
import 'ui/overlays/auto_save_indicator.dart';
import 'ui/overlays/global_loading_overlay.dart';
import 'ui/overlays/history_feedback_overlay.dart';
import 'ui/overlays/video_drop_overlay.dart';
import 'ui/shortcuts/editor_shortcut_controller.dart';

/// Main application widget
class FrameSketchPlayerApp extends ConsumerStatefulWidget {
  final String? initialVideoPath;
  final bool enableAutomaticUpdateChecks;

  const FrameSketchPlayerApp({
    super.key,
    this.initialVideoPath,
    this.enableAutomaticUpdateChecks = true,
  });

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
  late final EditorShortcutController _shortcutController;
  late final AutoSaveCoordinator _autoSaveCoordinator;
  late final UpdateCheckFlow _updateFlow;
  late final ProviderSubscription<(bool, DateTime?)> _autoSaveSubscription;
  late final ProviderSubscription<({int strokeCount, int undoCount})>
  _historyFeedbackSubscription;
  late final ProviderSubscription<({bool isEditingText, bool isInteracting})>
  _annotationFocusSubscription;
  Timer? _exportIconTimer;
  Timer? _historyFeedbackTimer;
  bool _isFullscreen = false;
  bool _showInspector = true;
  bool _showToolsPanel = true;
  bool _showToolsStrip = false;
  bool _showCommandPalette = false;
  bool _showCropExportPanel = false;
  bool _showExportHourglassBottom = false;
  bool _showAutoSaveIndicator = false;
  bool _isHistoryFeedbackVisible = false;
  bool _isDraggingVideoFile = false;
  String? _historyFeedbackLabel;
  IconData? _historyFeedbackIcon;
  int _loadingOverlayDepth = 0;
  String _loadingOverlayMessage = 'Loading...';
  String? _loadingOverlayCancelLabel;
  VoidCallback? _loadingOverlayCancelAction;
  AppPalette get _activePalette =>
      ref.read(themeControllerProvider).activePalette;
  KeyboardShortcuts get _shortcuts => ref.read(keyboardShortcutsProvider);

  @override
  void initState() {
    super.initState();
    _updateFlow = UpdateCheckFlow(
      navigatorKey: _navigatorKey,
      focusNode: _focusNode,
      isMounted: () => mounted,
      onStateChanged: () {
        if (mounted) setState(() {});
      },
      showInfoDialog: _showInfoDialog,
      showErrorDialog: _showErrorDialog,
    );
    _autoSaveCoordinator = AutoSaveCoordinator(
      ref: ref,
      isMounted: () => mounted,
      onIndicatorVisibilityChanged: (visible) {
        setState(() => _showAutoSaveIndicator = visible);
      },
      showErrorDialog: _showErrorDialog,
    );
    _shortcutController = EditorShortcutController(
      ref: ref,
      focusNode: _focusNode,
      shortcuts: () => _shortcuts,
      isFullscreen: () => _isFullscreen,
      setFullscreen: _setFullscreenMode,
      toggleFullscreen: _toggleFullscreenMode,
      isCropExportPanelOpen: () => _showCropExportPanel,
      closeCropExportPanel: _closeCropExportPanel,
      toggleCropExportPanel: _toggleCropExportPanel,
      openCommandPalette: _openCommandPalette,
      openFile: _openFile,
      saveAnnotations: _saveAnnotations,
      openMarkerEditorAtCurrentFrame: _openMarkerEditorAtCurrentFrame,
    );
    _exportActions = ExportActions(
      ref: ref,
      navigatorKey: _navigatorKey,
      scaffoldMessengerKey: _scaffoldMessengerKey,
      focusNode: _focusNode,
      isMounted: () => mounted,
      activePalette: () => _activePalette,
      runWithLoadingOverlay: _runWithLoadingOverlay,
      showErrorDialog: _showErrorDialog,
      setLoadingOverlayMessage: _setLoadingOverlayMessage,
    );
    _autoSaveSubscription = ref.listenManual<(bool, DateTime?)>(
      annotationProvider.select(
        (state) => (state.hasUnsavedChanges, state.annotationData?.updatedAt),
      ),
      (previous, next) {
        _autoSaveCoordinator.handleUnsavedChanges(hasUnsavedChanges: next.$1);
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
      if (widget.enableAutomaticUpdateChecks) {
        unawaited(_updateFlow.checkForUpdates());
      }
    });
  }

  Future<void> _loadProjects() =>
      ref.read(projectLibraryProvider.notifier).loadProjects();

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

  Future<void> _renameCurrentVideoFromToolbar(String newTitle) async {
    final trimmedTitle = newTitle.trim();
    if (trimmedTitle.isEmpty) return;

    ref.read(playerProvider.notifier).renameCurrentDisplayLabel(trimmedTitle);

    final annotationData = ref.read(annotationProvider).annotationData;
    if (annotationData == null) return;

    final projects = ref.read(projectLibraryProvider).projects;
    ProjectLibraryEntry? currentProject;
    for (final project in projects) {
      if (project.id == annotationData.videoId) {
        currentProject = project;
        break;
      }
    }

    if (currentProject == null || currentProject.title == trimmedTitle) {
      return;
    }

    try {
      await ref
          .read(projectLibraryProvider.notifier)
          .renameProject(project: currentProject, newTitle: trimmedTitle);
    } catch (e) {
      if (mounted) {
        _showErrorDialog('Error renaming video: $e');
      }
    }
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
    onAutoSaveChanged: _autoSaveCoordinator.setEnabled,
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

  Future<void> _renameProjectFromBrowser(ProjectLibraryEntry project) async {
    await _projectLibraryActions.renameProjectFromBrowser(project);
    _syncCurrentPlayerTitleFromProject(project.id);
  }

  Future<void> _deleteProjectFromBrowser(ProjectLibraryEntry project) {
    return _projectLibraryActions.deleteProjectFromBrowser(project);
  }

  Future<void> _revertProjectNameFromBrowser(
    ProjectLibraryEntry project,
  ) async {
    await _projectLibraryActions.revertProjectNameFromBrowser(project);
    _syncCurrentPlayerTitleFromProject(project.id);
  }

  void _syncCurrentPlayerTitleFromProject(String projectId) {
    final annotationData = ref.read(annotationProvider).annotationData;
    if (annotationData?.videoId != projectId) return;

    final projects = ref.read(projectLibraryProvider).projects;
    for (final project in projects) {
      if (project.id == projectId) {
        ref
            .read(playerProvider.notifier)
            .renameCurrentDisplayLabel(project.title);
        return;
      }
    }
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
    _shortcutController.dispose();
    _autoSaveCoordinator.dispose();
    _autoSaveSubscription.close();
    _historyFeedbackSubscription.close();
    _annotationFocusSubscription.close();
    _exportIconTimer?.cancel();
    _historyFeedbackTimer?.cancel();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeState = ref.watch(themeControllerProvider);
    final shortcuts = ref.watch(keyboardShortcutsProvider);
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
        onKeyEvent: (node, event) =>
            _shortcutController.handleKeyEvent(event),
        child: Builder(
          builder: (context) => Scaffold(
            body: DropTarget(
              onDragEntered: (_) {
                if (!_isDraggingVideoFile) {
                  setState(() => _isDraggingVideoFile = true);
                }
              },
              onDragExited: (_) {
                if (_isDraggingVideoFile) {
                  setState(() => _isDraggingVideoFile = false);
                }
              },
              onDragDone: (details) {
                if (_isDraggingVideoFile) {
                  setState(() => _isDraggingVideoFile = false);
                }
                unawaited(
                  _openDroppedFiles(details.files.map((file) => file.path)),
                );
              },
              child: Stack(
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
                    onCheckForUpdates: () =>
                        _updateFlow.checkForUpdates(notifyWhenCurrent: true),
                    isUpdateAvailable: _updateFlow.isUpdateAvailable,
                    isCheckingForUpdates: _updateFlow.isChecking,
                    onRenameCurrentVideo: _renameCurrentVideoFromToolbar,
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
                    GlobalLoadingOverlay(
                      message: _loadingOverlayMessage,
                      cancelLabel: _loadingOverlayCancelLabel,
                      onCancel: _loadingOverlayCancelAction,
                    ),
                  HistoryFeedbackOverlay(
                    label: _historyFeedbackLabel,
                    icon: _historyFeedbackIcon,
                    isVisible: _isHistoryFeedbackVisible,
                    palette: _activePalette,
                  ),
                  AutoSaveIndicator(
                    isVisible: _showAutoSaveIndicator,
                    palette: _activePalette,
                  ),
                  if (_isDraggingVideoFile)
                    VideoDropOverlay(palette: _activePalette),
                  if (_showCommandPalette)
                    CommandPalette(
                      commands: EditorCommandFactory(
                        ref: ref,
                        shortcuts: _shortcuts,
                        isFullscreen: _isFullscreen,
                        onOpenFile: _openFile,
                        onOpenRecent: _openRecentFromPalette,
                        onSaveAnnotations: _saveAnnotations,
                        onAddMarker: () async {
                          _openMarkerEditorAtCurrentFrame();
                        },
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

  void _openCommandPalette() {
    if (_showCommandPalette) return;
    setState(() => _showCommandPalette = true);
  }

  bool _openMarkerEditorAtCurrentFrame() {
    final playerState = ref.read(playerProvider);
    final annotationState = ref.read(annotationProvider);
    if (annotationState.annotationData == null ||
        playerState.metadata == null ||
        playerState.player == null) {
      return false;
    }
    final context = _navigatorKey.currentContext;
    if (context == null) {
      return false;
    }
    unawaited(
      openMarkerEditorDialog(
        context: context,
        ref: ref,
        defaultColor: _activePalette.annotationSwatches.first,
      ),
    );
    return true;
  }

  void _closeCommandPalette() {
    if (!_showCommandPalette) return;
    setState(() => _showCommandPalette = false);
    _focusNode.requestFocus();
  }

  void _toggleCropExportPanel() {
    final willOpen = !_showCropExportPanel;
    setState(() => _showCropExportPanel = willOpen);
    final cropNotifier = ref.read(cropProvider.notifier);
    if (willOpen) {
      cropNotifier.enterCropExportMode();
    } else {
      cropNotifier.exitCropExportMode();
    }
    _focusNode.requestFocus();
  }

  void _closeCropExportPanel() {
    setState(() => _showCropExportPanel = false);
    ref.read(cropProvider.notifier).exitCropExportMode();
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

  Future<void> _openDroppedFiles(Iterable<String> filePaths) {
    return _sourceOpenActions.openDroppedFiles(filePaths);
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
      final suggestedBaseName = buildSuggestedAnnotationFileBaseName(
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

      final outputPath = normalizeAnnotationJsonOutputPath(selectedPath);
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
