import 'dart:async';
import 'dart:convert';
import 'dart:io' show Directory, File, Platform, Process, SystemEncoding;
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
import 'core/services/annotation_overlay_renderer_service.dart';
import 'core/services/ffprobe_service.dart';
import 'core/services/project_library_service.dart';
import 'core/services/youtube_video_source_service.dart';
import 'core/models/annotation_data.dart';
import 'core/models/keyboard_shortcuts.dart';
import 'core/models/video_metadata.dart';
import 'features/projects/widgets/project_browser.dart';
import 'features/settings/widgets/settings_dialog.dart';
import 'features/settings/widgets/theme_dialog.dart';
import 'features/loop/providers/loop_provider.dart';
import 'features/crop/providers/crop_provider.dart';
import 'core/services/file_association_service.dart';
import 'core/theme/app_palette.dart';
import 'core/theme/theme_provider.dart';
import 'ui/editor_scaffold.dart';
import 'ui/command_palette/command_palette.dart';
import 'ui/command_palette/command_palette_model.dart';

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
  final FFprobeService _ffprobeService = FFprobeService();
  final AnnotationOverlayRendererService _overlayRenderer =
      AnnotationOverlayRendererService();
  late KeyboardShortcuts _shortcuts;
  late final ProviderSubscription<(bool, DateTime?)> _autoSaveSubscription;
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
  bool _showExportHourglassBottom = false;
  int _loadingOverlayDepth = 0;
  String _loadingOverlayMessage = 'Loading...';
  String? _loadingOverlayCancelLabel;
  VoidCallback? _loadingOverlayCancelAction;
  bool _exportCancelRequested = false;
  Process? _activeFrameExportProcess;
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
              onPinProject: _pinProjectFromBrowser,
              onDuplicateProject: _duplicateProjectFromBrowser,
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

  Future<void> _pinProjectFromBrowser(ProjectLibraryEntry project) async {
    try {
      await _runWithLoadingOverlay(
        message: 'Updating pin...',
        action: () async {
          await _projectLibraryService.togglePin(project);
          await _loadProjects();
        },
      );
    } catch (e) {
      if (mounted) {
        _showErrorDialog('Error updating pin: $e');
      }
    } finally {
      _focusNode.requestFocus();
    }
  }

  Future<void> _duplicateProjectFromBrowser(ProjectLibraryEntry project) async {
    try {
      await _runWithLoadingOverlay(
        message: 'Duplicating project...',
        action: () async {
          await _projectLibraryService.duplicateProject(project);
          await _loadProjects();
        },
      );

      if (!mounted) return;
      _scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text(
            'Duplicated \u201c${project.title}\u201d as a new revision',
          ),
          backgroundColor: _activePalette.success,
        ),
      );
    } catch (e) {
      if (mounted) {
        _showErrorDialog('Error duplicating project: $e');
      }
    } finally {
      _focusNode.requestFocus();
    }
  }

  @override
  void dispose() {
    _exportCancelRequested = true;
    _activeFrameExportProcess?.kill();
    _activeFrameExportProcess = null;
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
                  showToolsPanel: _showToolsPanel,
                  showToolsStrip: _showToolsStrip,
                  projectBrowser: ProjectBrowser(
                    projects: _projects,
                    isLoading: _projectsLoading,
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
                  onExportVideo: _exportVideoFromTopBar,
                  onOpenSettings: () => _openSettings(context),
                  onOpenThemeManager: () => _openThemeManager(context),
                  onOpenCommandPalette: _openCommandPalette,
                  commandPaletteShortcutLabel: _formatShortcutLabel(
                    _shortcuts.openCommandPalette,
                  ),
                  isExporting: isExporting,
                  showExportHourglassBottom: _showExportHourglassBottom,
                  onMenuAction: _handleMenuAction,
                ),
                if (_loadingOverlayDepth > 0)
                  _buildGlobalLoadingOverlay(context),
                if (_showCommandPalette)
                  CommandPalette(
                    commands: _buildPaletteCommands(),
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
    final cropNotifier = ref.read(cropProvider.notifier);
    final annotationState = ref.read(annotationProvider);

    // Only process app-wide shortcuts when the shell focus node itself owns
    // primary focus. If a child control is focused, let that control handle
    // the key event without global shortcut interference.
    if (!_focusNode.hasPrimaryFocus) {
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

  void _openCommandPalette() {
    if (_showCommandPalette) return;
    setState(() => _showCommandPalette = true);
  }

  void _closeCommandPalette() {
    if (!_showCommandPalette) return;
    setState(() => _showCommandPalette = false);
    _focusNode.requestFocus();
  }

  Future<void> _openRecentFromPalette() async {
    final recent = await AnnotationStorageService().getRecentFiles();
    if (!mounted) return;
    if (recent.isEmpty) {
      _scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(
          content: const Text('No recent files'),
          backgroundColor: _activePalette.warning,
        ),
      );
      return;
    }

    final dialogHostContext = _navigatorKey.currentContext;
    if (dialogHostContext == null) return;

    final chosen = await showDialog<String>(
      // ignore: use_build_context_synchronously
      context: dialogHostContext,
      builder: (dialogContext) {
        final palette = AppPalette.of(dialogContext);
        return Dialog(
          child: SizedBox(
            width: 560,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Open Recent',
                      style: TextStyle(
                        color: palette.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                Divider(height: 1, color: palette.border),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: recent.length,
                    itemBuilder: (_, i) {
                      final path = recent[i];
                      final name = path.replaceAll('\\', '/').split('/').last;
                      return ListTile(
                        leading: Icon(
                          Icons.movie_outlined,
                          size: 18,
                          color: palette.textSecondary,
                        ),
                        title: Text(name),
                        subtitle: Text(
                          path,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () => Navigator.of(dialogContext).pop(path),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (chosen != null) {
      await _loadInitialVideo(chosen);
    }
  }

  PaletteStep _goToFrameStep() {
    return PaletteStep(
      title: 'Go to frame',
      hint: 'Frame number (e.g. 120)',
      helper: 'Jumps the player to the given frame.',
      confirmLabel: 'Go',
      onSubmit: (value) {
        final frame = int.tryParse(value.trim());
        if (frame == null || frame < 0) {
          return 'Enter a valid frame number.';
        }
        final metadata = ref.read(playerProvider).metadata;
        if (metadata == null) return 'Open a video before jumping to a frame.';
        final targetMs = ((frame * 1000) / metadata.fps).round();
        unawaited(
          ref
              .read(playerProvider.notifier)
              .seek(Duration(milliseconds: targetMs)),
        );
        return null;
      },
    );
  }

  PaletteStep _setLoopPointStep({required bool isA}) {
    return PaletteStep(
      title: isA ? 'Set loop A (start)' : 'Set loop B (end)',
      hint: 'Time in ms, or s:ms (blank = current position)',
      helper: isA
          ? 'Leave blank to use the current playhead position.'
          : 'Must be after the A point.',
      confirmLabel: 'Set',
      onSubmit: (value) {
        final trimmed = value.trim();
        final loopNotifier = ref.read(loopProvider.notifier);

        if (trimmed.isEmpty) {
          if (isA) {
            loopNotifier.setAPoint();
          } else {
            loopNotifier.setBPoint();
          }
          return null;
        }

        final ms = _parsePaletteDurationMs(trimmed);
        if (ms == null) {
          return 'Enter milliseconds or a value like 1:23.456.';
        }
        final position = Duration(milliseconds: ms);
        if (isA) {
          loopNotifier.setAPointAt(position);
        } else {
          loopNotifier.setBPointAt(position);
        }
        return null;
      },
    );
  }

  int? _parsePaletteDurationMs(String input) {
    final direct = int.tryParse(input);
    if (direct != null) return direct < 0 ? null : direct;
    final parts = input.split(':');
    if (parts.length == 2) {
      final sec = int.tryParse(parts[0]);
      final ms = int.tryParse(parts[1]);
      if (sec != null && ms != null && sec >= 0 && ms >= 0) {
        return sec * 1000 + ms;
      }
    }
    return null;
  }

  String _formatShortcutLabel(KeyboardShortcut shortcut) {
    final parts = <String>[];
    if (shortcut.ctrlPressed) parts.add('Ctrl');
    if (shortcut.shiftPressed) parts.add('Shift');
    if (shortcut.altPressed) parts.add('Alt');
    parts.add(
      shortcut.key.keyLabel.isNotEmpty
          ? shortcut.key.keyLabel
          : shortcut.key.debugName ?? '',
    );
    return parts.join('+');
  }

  List<PaletteCommand> _buildPaletteCommands() {
    final playerState = ref.read(playerProvider);
    final loopState = ref.read(loopProvider);
    final cropState = ref.read(cropProvider);
    final annotationState = ref.read(annotationProvider);
    final themeState = ref.read(themeControllerProvider);
    final themeController = ref.read(themeControllerProvider.notifier);
    final hasVideo = playerState.hasLoadedSource;
    final hasLocal = playerState.isLocalFileSource;
    final hasAnnotations = annotationState.annotationData != null;

    return <PaletteCommand>[
      // ─── File ────────────────────────────────────────────────────
      PaletteCommand(
        id: 'open-video',
        label: 'Open Video\u2026',
        category: 'File',
        icon: Icons.folder_open_outlined,
        shortcut: _formatShortcutLabel(_shortcuts.openFile),
        run: () {
          unawaited(_openFile());
          return null;
        },
      ),
      PaletteCommand(
        id: 'open-recent',
        label: 'Open Recent\u2026',
        category: 'File',
        icon: Icons.history,
        run: () {
          unawaited(_openRecentFromPalette());
          return null;
        },
      ),
      PaletteCommand(
        id: 'save-project',
        label: 'Save Project',
        category: 'File',
        icon: Icons.save_outlined,
        shortcut: _formatShortcutLabel(_shortcuts.saveAnnotations),
        enabled: hasAnnotations,
        run: () {
          unawaited(_saveAnnotations());
          return null;
        },
      ),
      PaletteCommand(
        id: 'export-loop',
        label: 'Export Loop',
        category: 'File',
        icon: Icons.movie_creation_outlined,
        enabled: hasLocal && loopState.isSectionLoopValid,
        subtitle: loopState.isSectionLoopValid
            ? null
            : 'Requires a valid A/B loop section',
        run: () {
          final cropNotifier = ref.read(cropProvider.notifier);
          if (!cropState.isCropModeActive) {
            cropNotifier.toggleCropMode();
          }
          cropNotifier.setExportRange(
            start: loopState.loopStart,
            end: loopState.loopEnd,
          );
          unawaited(_exportVideoFromTopBar());
          return null;
        },
      ),

      // ─── Playback ────────────────────────────────────────────────
      PaletteCommand(
        id: 'go-to-frame',
        label: 'Go to Frame\u2026',
        category: 'Playback',
        icon: Icons.skip_next_outlined,
        enabled: hasVideo,
        run: () => _goToFrameStep(),
      ),

      // ─── Loop ────────────────────────────────────────────────────
      PaletteCommand(
        id: 'set-a',
        label: 'Set Loop A (start)\u2026',
        category: 'Loop',
        icon: Icons.flag_outlined,
        shortcut: _formatShortcutLabel(_shortcuts.setLoopStart),
        enabled: hasVideo,
        run: () => _setLoopPointStep(isA: true),
      ),
      PaletteCommand(
        id: 'set-b',
        label: 'Set Loop B (end)\u2026',
        category: 'Loop',
        icon: Icons.outlined_flag,
        shortcut: _formatShortcutLabel(_shortcuts.setLoopEnd),
        enabled: hasVideo,
        run: () => _setLoopPointStep(isA: false),
      ),
      PaletteCommand(
        id: 'toggle-loop',
        label: loopState.isSectionLoopActive
            ? 'Disable Section Loop'
            : 'Toggle Section Loop (A-B)',
        category: 'Loop',
        icon: Icons.loop,
        shortcut: _formatShortcutLabel(_shortcuts.toggleSectionLoop),
        enabled: loopState.isSectionLoopValid,
        run: () {
          ref.read(loopProvider.notifier).toggleSectionLoop();
          return null;
        },
      ),
      PaletteCommand(
        id: 'toggle-full-loop',
        label: loopState.isFullVideoLoopActive
            ? 'Disable Full Video Loop'
            : 'Toggle Full Video Loop',
        category: 'Loop',
        icon: Icons.repeat,
        shortcut: _formatShortcutLabel(_shortcuts.toggleFullLoop),
        enabled: hasVideo,
        run: () {
          ref.read(loopProvider.notifier).toggleFullVideoLoop();
          return null;
        },
      ),

      // ─── Crop ────────────────────────────────────────────────────
      PaletteCommand(
        id: 'toggle-crop',
        label: cropState.isCropModeActive
            ? 'Exit Crop Mode'
            : 'Enter Crop Mode',
        category: 'Crop',
        icon: Icons.crop,
        shortcut: _formatShortcutLabel(_shortcuts.toggleCropMode),
        enabled: hasVideo,
        run: () {
          final cropNotifier = ref.read(cropProvider.notifier);
          final wasActive = cropState.isCropModeActive;
          cropNotifier.toggleCropMode();
          if (!wasActive) {
            cropNotifier.setExportRange(
              start: loopState.loopStart,
              end: loopState.loopEnd,
            );
          }
          return null;
        },
      ),

      // ─── Markers ─────────────────────────────────────────────────
      PaletteCommand(
        id: 'add-marker',
        label: 'Add Marker at Current Frame',
        category: 'Markers',
        icon: Icons.bookmark_add_outlined,
        enabled: hasAnnotations,
        run: () {
          final frame = playerState.metadata == null
              ? 0
              : ((playerState.position.inMilliseconds *
                            playerState.metadata!.fps) /
                        1000)
                    .round();
          ref
              .read(annotationProvider.notifier)
              .upsertMarker(
                label: 'Marker $frame',
                color: _activePalette.accent,
              );
          return null;
        },
      ),

      // ─── View ────────────────────────────────────────────────────
      PaletteCommand(
        id: 'switch-theme',
        label: themeState.mode == ThemeMode.dark
            ? 'Switch to Light Mode'
            : 'Switch to Dark Mode',
        category: 'View',
        icon: themeState.mode == ThemeMode.dark
            ? Icons.light_mode_outlined
            : Icons.dark_mode_outlined,
        run: () {
          themeController.toggleThemeMode();
          return null;
        },
      ),
      PaletteCommand(
        id: 'open-theme-manager',
        label: 'Open Theme Manager\u2026',
        category: 'View',
        icon: Icons.palette_outlined,
        run: () {
          final ctx = _navigatorKey.currentContext;
          if (ctx != null) _openThemeManager(ctx);
          return null;
        },
      ),
      PaletteCommand(
        id: 'toggle-fullscreen',
        label: _isFullscreen ? 'Exit Fullscreen' : 'Enter Fullscreen',
        category: 'View',
        icon: Icons.fullscreen,
        shortcut: _formatShortcutLabel(_shortcuts.toggleFullscreen),
        run: () {
          _toggleFullscreenMode();
          return null;
        },
      ),

      // ─── Help ────────────────────────────────────────────────────
      ..._buildShortcutDiscoveryCommands(),
    ];
  }

  List<PaletteCommand> _buildShortcutDiscoveryCommands() {
    final entries = <(String, KeyboardShortcut)>[
      ('Open Command Palette', _shortcuts.openCommandPalette),
      ('Play / Pause', _shortcuts.playPause),
      ('Next Frame', _shortcuts.nextFrame),
      ('Previous Frame', _shortcuts.previousFrame),
      ('Jump Forward 1s', _shortcuts.jumpForward),
      ('Jump Backward 1s', _shortcuts.jumpBackward),
      ('Next Marker', _shortcuts.nextMarker),
      ('Previous Marker', _shortcuts.previousMarker),
      ('Undo', _shortcuts.undo),
      ('Redo', _shortcuts.redo),
      ('Open File', _shortcuts.openFile),
      ('Save Annotations', _shortcuts.saveAnnotations),
      ('Toggle Fullscreen', _shortcuts.toggleFullscreen),
      ('Pen Tool', _shortcuts.selectPenTool),
      ('Eraser', _shortcuts.selectEraserTool),
      ('Select Tool', _shortcuts.selectSelectionTool),
      ('Rectangle', _shortcuts.selectRectangleTool),
      ('Circle', _shortcuts.selectCircleTool),
      ('Line', _shortcuts.selectLineTool),
      ('Arrow', _shortcuts.selectArrowTool),
      ('Text', _shortcuts.selectTextTool),
      ('Toggle Keyframe Mode', _shortcuts.toggleKeyframeMode),
      ('Create Manual Keyframe', _shortcuts.createManualKeyframe),
      ('Set Loop A', _shortcuts.setLoopStart),
      ('Set Loop B', _shortcuts.setLoopEnd),
      ('Toggle Section Loop', _shortcuts.toggleSectionLoop),
      ('Toggle Full Video Loop', _shortcuts.toggleFullLoop),
      ('Toggle Crop Mode', _shortcuts.toggleCropMode),
    ];

    return entries
        .map(
          (e) => PaletteCommand(
            id: 'shortcut-${e.$1}',
            label: e.$1,
            category: 'Keyboard Shortcuts',
            icon: Icons.keyboard_outlined,
            shortcut: _formatShortcutLabel(e.$2),
            subtitle: 'Shortcut reference (read-only)',
            enabled: false,
          ),
        )
        .toList();
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
            displayLabel: resolved.title,
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
        displayLabel: resolved.title,
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
    final frameNumbers = <int>[];
    for (
      var frame = request.startFrame;
      frame <= request.endFrame;
      frame += request.frameStep
    ) {
      frameNumbers.add(frame);
    }

    await _runWithLoadingOverlay(
      message: 'Exporting ${frameNumbers.length} frames...',
      cancelLabel: 'Cancel Export',
      onCancel: _requestExportCancel,
      action: () async {
        _exportCancelRequested = false;
        final annotationData = ref.read(annotationProvider).annotationData;
        final totalFrames = frameNumbers.length;
        for (var index = 0; index < totalFrames; index += 1) {
          _throwIfExportCancelled();
          final frame = frameNumbers[index];
          if (mounted) {
            final completedFrames = index + 1;
            final progressPercent = ((completedFrames / totalFrames) * 100)
                .round();
            setState(() {
              _loadingOverlayMessage =
                  'Exporting frame $completedFrames/$totalFrames ($progressPercent%)';
            });
          }
          final outputPath =
              '${outputDirectory.path}${Platform.pathSeparator}'
              '${request.suggestedBaseName}_frame_${frame.toString().padLeft(6, '0')}.${request.frameExtension}';
          await _exportFrameImage(
            videoPath,
            timestamp: _durationForFrame(frame, metadata.fps),
            outputPath: outputPath,
            metadata: metadata,
            annotationData: annotationData,
          );
        }
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
          'Exported ${frameNumbers.length} frames to ${outputDirectory.path}',
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
      final process = await Process.start(ffmpegPath, [
        '-hide_banner',
        '-ss',
        seconds,
        '-i',
        videoPath,
        '-i',
        overlayPath,
        '-filter_complex',
        '[0:v][1:v]overlay=0:0',
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
  }) async {
    final ffmpegPath = await _ffprobeService.findFFmpegPath();
    if (ffmpegPath == null) {
      throw StateError('FFmpeg not found');
    }

    _throwIfExportCancelled();
    final seconds = (timestamp.inMicroseconds / 1000000.0).toStringAsFixed(6);
    final process = await Process.start(ffmpegPath, [
      '-ss',
      seconds,
      '-i',
      videoPath,
      '-frames:v',
      '1',
      '-q:v',
      '2',
      outputPath,
      '-y',
    ]);
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

class _ExportRequest {
  final _ExportMode mode;
  final String suggestedBaseName;
  final int startFrame;
  final int endFrame;
  final int frameStep;
  final _FrameExportFormat frameFormat;
  final _AnnotationExportFormat annotationFormat;

  const _ExportRequest({
    required this.mode,
    required this.suggestedBaseName,
    required this.startFrame,
    required this.endFrame,
    this.frameStep = 1,
    this.frameFormat = _FrameExportFormat.png,
    this.annotationFormat = _AnnotationExportFormat.framesketch,
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
                const SizedBox(height: 8),
                Text(
                  'Exports an annotated MP4 from the selected frame range.',
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
