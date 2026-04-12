import 'dart:async';
import 'dart:convert';
import 'dart:io' show File;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/models/project_library_entry.dart';
import 'features/player/providers/player_provider.dart';
import 'features/annotations/providers/annotation_provider.dart';
import 'features/annotations/models/stroke.dart';
import 'core/services/annotation_storage_service.dart';
import 'core/services/project_library_service.dart';
import 'core/services/youtube_video_source_service.dart';
import 'core/models/annotation_data.dart';
import 'core/models/keyboard_shortcuts.dart';
import 'features/projects/widgets/project_browser.dart';
import 'features/settings/widgets/settings_dialog.dart';
import 'features/settings/widgets/theme_dialog.dart';
import 'features/loop/providers/loop_provider.dart';
import 'features/crop/providers/crop_provider.dart';
import 'core/services/file_association_service.dart';
import 'core/theme/app_palette.dart';
import 'core/theme/theme_provider.dart';
import 'ui/editor_scaffold.dart';

/// Main application widget
class FrameSketchPlayerApp extends ConsumerStatefulWidget {
  final String? initialVideoPath;

  const FrameSketchPlayerApp({super.key, this.initialVideoPath});

  @override
  ConsumerState<FrameSketchPlayerApp> createState() =>
      _FrameSketchPlayerAppState();
}

class _FrameSketchPlayerAppState extends ConsumerState<FrameSketchPlayerApp> {
  static const String _autoSaveEnabledKey = 'auto_save_enabled';
  final FocusNode _focusNode = FocusNode();
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();
  final ProjectLibraryService _projectLibraryService = ProjectLibraryService();
  late KeyboardShortcuts _shortcuts;
  late final ProviderSubscription<(bool, DateTime?)> _autoSaveSubscription;
  Timer? _keyRepeatTimer;
  Timer? _exportIconTimer;
  Timer? _autoSaveTimer;
  LogicalKeyboardKey? _lastPressedKey;
  int _keyRepeatGeneration = 0;
  bool _isFullscreen = false;
  bool _showInspector = true;
  bool _showExportHourglassBottom = false;
  int _loadingOverlayDepth = 0;
  String _loadingOverlayMessage = 'Loading...';
  bool _autoSaveEnabled = true;
  bool _isAutoSaving = false;
  bool _projectsLoading = false;
  List<ProjectLibraryEntry> _projects = const [];
  AppPalette get _activePalette =>
      ref.read(themeControllerProvider).activePalette;

  @override
  void initState() {
    super.initState();
    _shortcuts = defaultKeyboardShortcuts;
    _loadShortcuts();
    _loadAutoSavePreference();
    _loadProjects();
    _autoSaveSubscription = ref.listenManual<(bool, DateTime?)>(
      annotationProvider.select(
        (state) => (state.hasUnsavedChanges, state.annotationData?.updatedAt),
      ),
      (previous, next) {
        _handleAutoSaveStateChanged(hasUnsavedChanges: next.$1);
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

  Future<void> _loadShortcuts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString('keyboard_shortcuts');
      if (json != null) {
        _shortcuts = KeyboardShortcuts.fromJson(
          jsonDecode(json) as Map<String, dynamic>,
        );
        setState(() {});
      }
    } catch (e) {
      _shortcuts = defaultKeyboardShortcuts;
    }
  }

  Future<void> _saveShortcuts(KeyboardShortcuts shortcuts) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'keyboard_shortcuts',
        jsonEncode(shortcuts.toJson()),
      );
      setState(() {
        _shortcuts = shortcuts;
      });
    } catch (e) {
      debugPrint('Error saving shortcuts: $e');
    }
  }

  Future<void> _loadAutoSavePreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final storedValue = prefs.getBool(_autoSaveEnabledKey);
      if (storedValue == null || !mounted) {
        return;
      }

      setState(() {
        _autoSaveEnabled = storedValue;
      });
    } catch (e) {
      debugPrint('Error loading auto save preference: $e');
    }
  }

  Future<void> _setAutoSaveEnabled(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_autoSaveEnabledKey, enabled);
      if (!mounted) return;

      setState(() {
        _autoSaveEnabled = enabled;
      });

      if (enabled) {
        _handleAutoSaveStateChanged(
          hasUnsavedChanges: ref.read(annotationProvider).hasUnsavedChanges,
        );
      } else {
        _autoSaveTimer?.cancel();
      }
    } catch (e) {
      debugPrint('Error saving auto save preference: $e');
    }
  }

  Future<void> _loadProjects() async {
    if (mounted) {
      setState(() {
        _projectsLoading = true;
      });
    }

    try {
      final projects = await _projectLibraryService.getProjects();
      if (!mounted) return;

      setState(() {
        _projects = projects;
        _projectsLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading projects: $e');
      if (!mounted) return;

      setState(() {
        _projectsLoading = false;
      });
    }
  }

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

    await _projectLibraryService.upsertProject(
      annotationData: annotationData,
      sourceLabel: playerState.currentSourceLabel!,
      projectTitle: projectTitle,
      duration: playerState.duration,
    );
    await _loadProjects();
  }

  Future<void> _openProject(ProjectLibraryEntry project) async {
    if (project.isYouTubeProject) {
      final youtubeUrl = project.youtubeUrl;
      if (youtubeUrl == null || youtubeUrl.trim().isEmpty) {
        _showErrorDialog('This YouTube project is missing its source URL.');
        return;
      }
      await _loadYouTubeUrl(youtubeUrl);
      return;
    }

    final sourcePath = project.sourcePath;
    if (sourcePath.trim().isEmpty || !await File(sourcePath).exists()) {
      _showErrorDialog(
        'The video file for this project could not be found:\n$sourcePath',
      );
      return;
    }

    await _loadInitialVideo(sourcePath);
  }

  Future<void> _openProjectsDialog() async {
    final dialogHostContext = _navigatorKey.currentContext;
    if (dialogHostContext == null || !mounted) {
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
            child: ProjectBrowser(
              projects: _projects,
              isLoading: _projectsLoading,
              onOpenProject: (project) {
                Navigator.of(dialogContext).pop(project);
              },
              onRenameProject: _renameProjectFromBrowser,
              onRevertProjectName: _revertProjectNameFromBrowser,
              onDeleteProject: _deleteProjectFromBrowser,
              onRefresh: _loadProjects,
            ),
          ),
        );
      },
    );

    if (selectedProject != null) {
      await _openProject(selectedProject);
    }

    _focusNode.requestFocus();
  }

  Future<void> _renameProjectFromBrowser(ProjectLibraryEntry project) async {
    final dialogHostContext = _navigatorKey.currentContext;
    if (dialogHostContext == null || !mounted) {
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
      await _runWithLoadingOverlay(
        message: 'Renaming project...',
        action: () async {
          await _projectLibraryService.renameProject(
            project: project,
            newTitle: trimmedTitle,
          );
          await _loadProjects();
        },
      );

      if (!mounted) return;
      _scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text('Renamed project to $trimmedTitle'),
          backgroundColor: _activePalette.success,
        ),
      );
    } catch (e) {
      if (mounted) {
        _showErrorDialog('Error renaming project: $e');
      }
    } finally {
      _focusNode.requestFocus();
    }
  }

  Future<void> _deleteProjectFromBrowser(ProjectLibraryEntry project) async {
    final dialogHostContext = _navigatorKey.currentContext;
    if (dialogHostContext == null || !mounted) {
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
      await _runWithLoadingOverlay(
        message: 'Deleting project...',
        action: () async {
          await _projectLibraryService.deleteProject(project);
          await _loadProjects();
        },
      );

      if (!mounted) return;
      _scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text('Deleted project ${project.title}'),
          backgroundColor: _activePalette.success,
        ),
      );
    } catch (e) {
      if (mounted) {
        _showErrorDialog('Error deleting project: $e');
      }
    } finally {
      _focusNode.requestFocus();
    }
  }

  Future<void> _revertProjectNameFromBrowser(
    ProjectLibraryEntry project,
  ) async {
    if (!project.canRevertToOriginalName) {
      return;
    }

    final dialogHostContext = _navigatorKey.currentContext;
    if (dialogHostContext == null || !mounted) {
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
      await _runWithLoadingOverlay(
        message: 'Reverting project name...',
        action: () async {
          await _projectLibraryService.revertProjectToOriginalName(project);
          await _loadProjects();
        },
      );

      if (!mounted) return;
      _scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text('Reverted project name to $originalTitle'),
          backgroundColor: _activePalette.success,
        ),
      );
    } catch (e) {
      if (mounted) {
        _showErrorDialog('Error reverting project name: $e');
      }
    } finally {
      _focusNode.requestFocus();
    }
  }

  @override
  void dispose() {
    _autoSaveSubscription.close();
    _keyRepeatTimer?.cancel();
    _exportIconTimer?.cancel();
    _autoSaveTimer?.cancel();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeState = ref.watch(themeControllerProvider);
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
                  projectBrowser: ProjectBrowser(
                    projects: _projects,
                    isLoading: _projectsLoading,
                    onOpenProject: (project) {
                      unawaited(_openProject(project));
                    },
                    onRenameProject: _renameProjectFromBrowser,
                    onRevertProjectName: _revertProjectNameFromBrowser,
                    onDeleteProject: _deleteProjectFromBrowser,
                    onOpenFile: _openFile,
                    onOpenYouTube: _openYouTubeUrl,
                    onRefresh: _loadProjects,
                  ),
                  onToggleFullscreen: _toggleFullscreenMode,
                  onToggleInspector: _toggleInspectorVisibility,
                  onOpenFile: _openFile,
                  onOpenYouTube: _openYouTubeUrl,
                  onOpenAnnotation: _openAnnotationJson,
                  onOpenProjects: _openProjectsDialog,
                  onSaveAnnotations: _saveAnnotations,
                  onSaveAnnotationsAs: _saveAnnotationsAs,
                  onExportVideo: _exportVideoFromTopBar,
                  onOpenSettings: () => _openSettings(context),
                  onOpenThemeManager: () => _openThemeManager(context),
                  isExporting: isExporting,
                  showExportHourglassBottom: _showExportHourglassBottom,
                  onMenuAction: _handleMenuAction,
                ),
                if (_loadingOverlayDepth > 0)
                  _buildGlobalLoadingOverlay(context),
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
  }) async {
    if (mounted) {
      setState(() {
        _loadingOverlayDepth += 1;
        _loadingOverlayMessage = message;
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
    final cropNotifier = ref.read(cropProvider.notifier);
    final annotationState = ref.read(annotationProvider);

    // While editing a text annotation, disable all global shortcuts so
    // the text field can consume normal character input.
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
      // Toggle crop mode (no repeat)
      if (matchesShortcut(_shortcuts.toggleCropMode)) {
        final cropStateBefore = ref.read(cropProvider);
        cropNotifier.toggleCropMode();
        if (!cropStateBefore.isCropModeActive) {
          final loopState = ref.read(loopProvider);
          cropNotifier.setExportRange(
            start: loopState.loopStart,
            end: loopState.loopEnd,
          );
        }
        return KeyEventResult.handled;
      }
    }

    // Escape key - exit crop mode
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      if (_isFullscreen) {
        _setFullscreenMode(false);
        return KeyEventResult.handled;
      }

      final cropState = ref.read(cropProvider);
      if (cropState.isCropModeActive) {
        cropNotifier.exitCropMode();
        return KeyEventResult.handled;
      }
    }

    return KeyEventResult.ignored;
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

  void _setFullscreenMode(bool enabled) {
    if (_isFullscreen == enabled) {
      return;
    }
    setState(() {
      _isFullscreen = enabled;
    });
    _focusNode.requestFocus();
  }

  Future<void> _loadInitialVideo(String filePath) async {
    if (_isAnnotationJsonPath(filePath)) {
      await _openAnnotationJsonPath(filePath);
      return;
    }

    final uri = Uri.tryParse(filePath);
    if (uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        _looksLikeYouTubeUrl(filePath)) {
      await _loadYouTubeUrl(filePath);
      return;
    }

    try {
      await _runWithLoadingOverlay(
        message: 'Loading video...',
        action: () async {
          // Load video
          final playerNotifier = ref.read(playerProvider.notifier);
          await playerNotifier.loadVideo(filePath);

          // Check if video loaded successfully
          final playerState = ref.read(playerProvider);
          if (playerState.metadata == null) {
            if (mounted) {
              _showErrorDialog(
                'Failed to load video. The video file may be corrupted or in an unsupported format.',
              );
            }
            return;
          }

          // Initialize annotations
          final annotationNotifier = ref.read(annotationProvider.notifier);
          await annotationNotifier.initializeForVideo(
            filePath,
            playerState.metadata!.fps,
          );

          // Add to recent files
          final storageService = AnnotationStorageService();
          await storageService.addToRecentFiles(filePath);
          await _registerCurrentProject();

          // Refocus
          _focusNode.requestFocus();
        },
      );
    } catch (e) {
      if (mounted) {
        _showErrorDialog('Error opening file: $e');
      }
    }
  }

  Future<void> _openFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mp4', 'mov', 'mkv', 'avi', 'webm', 'flv', 'm4v'],
        dialogTitle: 'Select Video File',
      );

      if (result == null || result.files.isEmpty) return;

      final filePath = result.files.first.path;
      if (filePath == null) return;

      await _runWithLoadingOverlay(
        message: 'Loading video...',
        action: () async {
          // Load video
          final playerNotifier = ref.read(playerProvider.notifier);
          await playerNotifier.loadVideo(filePath);

          // Check if video loaded successfully
          final playerState = ref.read(playerProvider);
          if (playerState.metadata == null) {
            if (mounted) {
              _showErrorDialog(
                'Failed to load video. The video file may be corrupted or in an unsupported format.',
              );
            }
            return;
          }

          // Initialize annotations
          final annotationNotifier = ref.read(annotationProvider.notifier);
          await annotationNotifier.initializeForVideo(
            filePath,
            playerState.metadata!.fps,
          );

          // Add to recent files
          final storageService = AnnotationStorageService();
          await storageService.addToRecentFiles(filePath);
          await _registerCurrentProject();

          // Refocus
          _focusNode.requestFocus();
        },
      );
    } catch (e) {
      if (mounted) {
        _showErrorDialog('Error opening file: $e');
      }
    }
  }

  Future<void> _openYouTubeUrl() async {
    final dialogHostContext = _navigatorKey.currentContext;
    if (dialogHostContext == null || !mounted) {
      return;
    }

    String enteredUrl = '';
    final url = await showDialog<String>(
      context: dialogHostContext,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Open YouTube URL'),
          content: TextField(
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'https://www.youtube.com/watch?v=...',
            ),
            onChanged: (value) => enteredUrl = value,
            onSubmitted: (value) => Navigator.of(dialogContext).pop(value),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(enteredUrl),
              child: const Text('Open'),
            ),
          ],
        );
      },
    );

    if (url == null || url.trim().isEmpty) {
      _focusNode.requestFocus();
      return;
    }

    await _loadYouTubeUrl(url);
  }

  Future<void> _loadYouTubeUrl(String url) async {
    try {
      if (!_looksLikeYouTubeUrl(url)) {
        _showErrorDialog('Please enter a valid YouTube URL.');
        return;
      }

      await _runWithLoadingOverlay(
        message: 'Loading YouTube video...',
        action: () async {
          final youtubeService = YouTubeVideoSourceService();
          final resolved = await youtubeService.resolve(url);

          final playerNotifier = ref.read(playerProvider.notifier);
          await playerNotifier.loadNetworkVideo(
            mediaUrl: resolved.streamUri.toString(),
            sourceLabel: resolved.canonicalUrl,
            externalAudioUrl: resolved.externalAudioUri?.toString(),
          );

          final playerState = ref.read(playerProvider);
          if (playerState.metadata == null) {
            if (mounted) {
              _showErrorDialog('Failed to load YouTube video stream.');
            }
            return;
          }

          final annotationNotifier = ref.read(annotationProvider.notifier);
          await annotationNotifier.initializeForYouTubeVideo(
            youtubeVideoId: resolved.videoId,
            youtubeUrl: resolved.canonicalUrl,
            fps: playerState.metadata!.fps,
          );
          await _registerCurrentProject(projectTitle: resolved.title);

          if (mounted) {
            final qualityParts = <String>[];
            final selectedLabel = resolved.selectedQualityLabel?.trim();
            final selectedWidth = resolved.selectedWidth;
            final selectedHeight = resolved.selectedHeight;

            if (selectedLabel != null && selectedLabel.isNotEmpty) {
              qualityParts.add(selectedLabel);
            }

            if (selectedWidth != null &&
                selectedWidth > 0 &&
                selectedHeight != null &&
                selectedHeight > 0) {
              qualityParts.add('${selectedWidth}x$selectedHeight');
            }

            if (resolved.usesHls) {
              qualityParts.add('HLS');
            }
            if (resolved.externalAudioUri != null) {
              qualityParts.add('split A/V');
            }

            if (qualityParts.isEmpty) {
              qualityParts.add(
                '${playerState.metadata!.width}x${playerState.metadata!.height}',
              );
            }

            _scaffoldMessengerKey.currentState?.showSnackBar(
              SnackBar(
                content: Text(
                  'Loaded YouTube video: ${resolved.title} (${qualityParts.join(' | ')})',
                ),
                backgroundColor: _activePalette.success,
              ),
            );
          }

          _focusNode.requestFocus();
        },
      );
    } catch (e) {
      if (mounted) {
        if (e is YouTubeSourceLoadException) {
          _showErrorDialog(e.userMessage);
        } else {
          _showErrorDialog('Error loading YouTube URL: $e');
        }
      }
    }
  }

  Future<void> _openAnnotationJson() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['framesketch', 'json'],
        dialogTitle: 'Select Annotation File',
      );

      if (result == null || result.files.isEmpty) return;
      final filePath = result.files.first.path;
      if (filePath == null) return;

      await _openAnnotationJsonPath(filePath);
    } catch (e) {
      if (mounted) {
        if (e is YouTubeSourceLoadException) {
          _showErrorDialog(
            'The annotation file was loaded, but the linked YouTube video could not be opened.\n\n${e.userMessage}',
          );
        } else {
          _showErrorDialog('Error opening annotation file: $e');
        }
      }
    }
  }

  Future<void> _openAnnotationJsonPath(String annotationPath) async {
    try {
      await _runWithLoadingOverlay(
        message: 'Loading annotations...',
        action: () async {
          final storageService = AnnotationStorageService();
          final data = await storageService.loadAnnotationsFromFile(
            annotationPath,
          );
          if (data == null) {
            _showErrorDialog('Unable to read annotation file.');
            return;
          }

          await _loadSourceForAnnotationData(data);
          await _registerCurrentProject();

          if (mounted) {
            _scaffoldMessengerKey.currentState?.showSnackBar(
              SnackBar(
                content: Text(
                  'Loaded annotations from ${File(annotationPath).path}',
                ),
                backgroundColor: _activePalette.success,
              ),
            );
          }

          _focusNode.requestFocus();
        },
      );
    } catch (e) {
      if (mounted) {
        _showErrorDialog('Error opening annotation file: $e');
      }
    }
  }

  Future<void> _loadSourceForAnnotationData(AnnotationData data) async {
    final playerNotifier = ref.read(playerProvider.notifier);
    final annotationNotifier = ref.read(annotationProvider.notifier);

    if (data.youtubeUrl != null && data.youtubeUrl!.trim().isNotEmpty) {
      final youtubeService = YouTubeVideoSourceService();
      final storageService = AnnotationStorageService();
      final resolved = await youtubeService.resolve(data.youtubeUrl!);
      await playerNotifier.loadNetworkVideo(
        mediaUrl: resolved.streamUri.toString(),
        sourceLabel: resolved.canonicalUrl,
        externalAudioUrl: resolved.externalAudioUri?.toString(),
      );
      if (ref.read(playerProvider).metadata == null) {
        throw StateError('Failed to load YouTube source from annotation JSON');
      }
      annotationNotifier.initializeFromAnnotationData(
        data.copyWith(
          videoPath: storageService.buildYouTubeAnnotationKey(resolved.videoId),
          youtubeUrl: resolved.canonicalUrl,
        ),
      );
      return;
    }

    final localPath = data.videoPath;
    if (localPath.isEmpty || !await File(localPath).exists()) {
      throw StateError(
        'Annotation JSON references a local video that was not found:\n$localPath',
      );
    }

    await playerNotifier.loadVideo(localPath);
    if (ref.read(playerProvider).metadata == null) {
      throw StateError('Failed to load local video from annotation JSON');
    }
    annotationNotifier.initializeFromAnnotationData(data);
  }

  bool _looksLikeYouTubeUrl(String value) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null) return false;
    final host = uri.host.toLowerCase();
    return host.contains('youtube.com') || host.contains('youtu.be');
  }

  bool _isAnnotationJsonPath(String value) {
    final lower = value.toLowerCase();
    return lower.endsWith('.framesketch') ||
        lower.endsWith('.annotations.json') ||
        lower.endsWith('.json');
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
      final cropState = ref.read(cropProvider);
      final cropNotifier = ref.read(cropProvider.notifier);

      if (playerState.currentVideoPath == null) {
        _showErrorDialog('No video loaded');
        return;
      }
      if (!playerState.isLocalFileSource) {
        _showErrorDialog(
          'Export is only available for local video files. YouTube sources are playback/annotation only.',
        );
        return;
      }

      if (cropState.exportStatus == ExportStatus.exporting) {
        return;
      }

      final inputFile = File(playerState.currentVideoPath!);
      final inputName = inputFile.uri.pathSegments.isNotEmpty
          ? inputFile.uri.pathSegments.last
          : 'video';
      final extIndex = inputName.lastIndexOf('.');
      final nameWithoutExt = extIndex > 0
          ? inputName.substring(0, extIndex)
          : inputName;
      final safeBaseName = _buildSafeOutputBaseName(nameWithoutExt);

      final outputPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Export Annotated Video',
        fileName: '${safeBaseName}_annotated.mp4',
        type: FileType.video,
      );

      if (outputPath == null) {
        _focusNode.requestFocus();
        return;
      }

      await ref.read(annotationProvider.notifier).saveAnnotations();
      await cropNotifier.exportCroppedVideo(
        outputPath,
        annotationData: ref.read(annotationProvider).annotationData,
      );

      if (!mounted) return;

      final updatedCropState = ref.read(cropProvider);
      switch (updatedCropState.exportStatus) {
        case ExportStatus.success:
          _scaffoldMessengerKey.currentState?.showSnackBar(
            SnackBar(
              content: Text(
                'Export complete: ${updatedCropState.exportedFilePath ?? outputPath}',
              ),
              backgroundColor: _activePalette.success,
            ),
          );
          break;
        case ExportStatus.cancelled:
          _scaffoldMessengerKey.currentState?.showSnackBar(
            SnackBar(
              content: Text('Export cancelled'),
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

      _focusNode.requestFocus();
    } catch (e) {
      if (mounted) {
        _showErrorDialog('Error exporting video: $e');
      }
    }
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
    debugPrint('Opening settings dialog...');
    debugPrint('Current shortcuts: $_shortcuts');
    try {
      showDialog(
        context: context,
        builder: (dialogContext) {
          debugPrint('Building dialog...');
          return SettingsDialog(
            shortcuts: _shortcuts,
            autoSaveEnabled: _autoSaveEnabled,
            onSave: (shortcuts, autoSaveEnabled) {
              _saveShortcuts(shortcuts);
              _setAutoSaveEnabled(autoSaveEnabled);
              _focusNode.requestFocus();
            },
          );
        },
      );
    } catch (e) {
      debugPrint('Error opening settings dialog: $e');
      _showErrorDialog('Error opening settings: $e');
    }
  }

  void _openThemeManager(BuildContext context) {
    try {
      showDialog(context: context, builder: (_) => const ThemeManagerDialog());
    } catch (e) {
      _showErrorDialog('Error opening theme manager: $e');
    }
  }

  Future<void> _handleMenuAction(String action, BuildContext context) async {
    final service = FileAssociationService();

    switch (action) {
      case 'register':
        try {
          final success = await service.registerFileAssociations();
          if (mounted) {
            if (success) {
              _showInfoDialog(
                'File Associations Registered',
                'FrameSketch Player has been registered for video files and .framesketch files.\n\n'
                    'To set it as default for video files:\n'
                    '1. Right-click any video file\n'
                    '2. Select "Open with" → "Choose another app"\n'
                    '3. Select "FrameSketch Player"\n'
                    '4. Check "Always use this app"\n\n'
                    '.framesketch files should now open directly with FrameSketch Player.',
              );
            } else {
              _showErrorDialog(
                'Failed to register file associations. Please try running as administrator.',
              );
            }
          }
        } catch (e) {
          if (mounted) {
            _showErrorDialog('Error registering file associations: $e');
          }
        }
        break;

      case 'unregister':
        try {
          final success = await service.unregisterFileAssociations();
          if (mounted) {
            if (success) {
              _scaffoldMessengerKey.currentState?.showSnackBar(
                SnackBar(
                  content: Text(
                    'Video and annotation file associations removed successfully',
                  ),
                  backgroundColor: _activePalette.success,
                ),
              );
            } else {
              _showErrorDialog('Failed to remove file associations.');
            }
          }
        } catch (e) {
          if (mounted) {
            _showErrorDialog('Error removing file associations: $e');
          }
        }
        break;

      case 'check':
        try {
          final isRegistered = await service.isRegistered();
          if (mounted) {
            _showInfoDialog(
              'Registration Status',
              isRegistered
                  ? 'FrameSketch Player is currently registered for video files and .framesketch files.'
                  : 'FrameSketch Player is not registered.\n\nUse "Register Video + Annotation Files" to register it.',
            );
          }
        } catch (e) {
          if (mounted) {
            _showErrorDialog('Error checking registration status: $e');
          }
        }
        break;
    }
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
