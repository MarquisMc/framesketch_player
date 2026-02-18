import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'features/player/providers/player_provider.dart';
import 'features/player/widgets/video_viewport.dart';
import 'features/player/widgets/playback_controls.dart';
import 'features/timeline/widgets/timeline_scrubber.dart';
import 'features/annotations/widgets/drawing_tools_panel.dart';
import 'features/annotations/widgets/annotation_keyframe_timeline.dart';
import 'features/annotations/providers/annotation_provider.dart';
import 'features/annotations/providers/annotation_keyframe_timeline_provider.dart';
import 'features/annotations/models/stroke.dart';
import 'core/services/annotation_storage_service.dart';
import 'core/models/keyboard_shortcuts.dart';
import 'features/settings/widgets/settings_dialog.dart';
import 'features/settings/widgets/theme_dialog.dart';
import 'features/loop/providers/loop_provider.dart';
import 'features/crop/providers/crop_provider.dart';
import 'features/crop/widgets/crop_controls.dart';
import 'core/services/file_association_service.dart';
import 'core/theme/app_palette.dart';
import 'core/theme/theme_provider.dart';
import 'dart:io' show File, Platform;

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
  late KeyboardShortcuts _shortcuts;
  Timer? _keyRepeatTimer;
  Timer? _exportIconTimer;
  LogicalKeyboardKey? _lastPressedKey;
  bool _isFullscreen = false;
  bool _showExportHourglassBottom = false;
  AppPalette get _activePalette =>
      ref.read(themeControllerProvider).activePalette;

  @override
  void initState() {
    super.initState();
    _shortcuts = defaultKeyboardShortcuts;
    _loadShortcuts();
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

  @override
  void dispose() {
    _keyRepeatTimer?.cancel();
    _exportIconTimer?.cancel();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeState = ref.watch(themeControllerProvider);
    final selectedTheme = themeState.selectedTheme;
    final themeController = ref.read(themeControllerProvider.notifier);
    final showAnnotationTimeline = ref.watch(
      annotationKeyframeTimelineVisibleProvider,
    );
    final playerState = ref.watch(playerProvider);
    final cropState = ref.watch(cropProvider);
    final hasVideoLoaded = playerState.currentVideoPath != null;
    final isExporting = cropState.exportStatus == ExportStatus.exporting;
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
            appBar: _isFullscreen
                ? null
                : AppBar(
                    title: const Text('FrameSketch Player'),
                    actions: [
                      IconButton(
                        icon: Icon(
                          isExporting
                              ? (_showExportHourglassBottom
                                    ? Icons.hourglass_bottom
                                    : Icons.hourglass_top)
                              : Icons.file_download,
                        ),
                        onPressed: hasVideoLoaded && !isExporting
                            ? _exportVideoFromTopBar
                            : null,
                        tooltip: isExporting ? 'Exporting...' : 'Export Video',
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        icon: const Icon(Icons.folder_open),
                        onPressed: _openFile,
                        tooltip: 'Open Video (Ctrl+O)',
                      ),
                      IconButton(
                        icon: const Icon(Icons.save),
                        onPressed: _saveAnnotations,
                        tooltip: 'Save Annotations (Ctrl+S)',
                      ),
                      const SizedBox(width: 8),
                      // Crop mode toggle button
                      const CropModeToggleButton(),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: Icon(
                          themeState.mode == ThemeMode.dark
                              ? Icons.light_mode
                              : Icons.dark_mode,
                        ),
                        onPressed: themeController.toggleThemeMode,
                        tooltip: themeState.mode == ThemeMode.dark
                            ? 'Switch to Light Mode'
                            : 'Switch to Dark Mode',
                      ),
                      IconButton(
                        icon: const Icon(Icons.palette_outlined),
                        onPressed: () => _openThemeManager(context),
                        tooltip: 'Theme Manager',
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        icon: const Icon(Icons.settings),
                        onPressed: () => _openSettings(context),
                        tooltip: 'Keyboard Shortcuts',
                      ),
                      // File associations menu (Windows only)
                      if (Platform.isWindows)
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert),
                          tooltip: 'More Options',
                          onSelected: (value) =>
                              _handleMenuAction(value, context),
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'register',
                              child: Row(
                                children: [
                                  Icon(Icons.check_circle_outline),
                                  SizedBox(width: 8),
                                  Text('Set as Default Video Player'),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'unregister',
                              child: Row(
                                children: [
                                  Icon(Icons.cancel_outlined),
                                  SizedBox(width: 8),
                                  Text('Remove File Associations'),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'check',
                              child: Row(
                                children: [
                                  Icon(Icons.info_outline),
                                  SizedBox(width: 8),
                                  Text('Check Registration Status'),
                                ],
                              ),
                            ),
                          ],
                        ),
                      const SizedBox(width: 8),
                    ],
                  ),
            body: Column(
              children: [
                // Main content area
                Expanded(
                  child: Row(
                    children: [
                      // Video and annotation area
                      Expanded(
                        child: VideoViewport(showOverlays: !_isFullscreen),
                      ),

                      // Drawing tools panel
                      if (!_isFullscreen) const DrawingToolsPanel(),
                    ],
                  ),
                ),

                // Crop controls panel (shows when crop mode is active)
                if (!_isFullscreen) const CropControlsPanel(),

                // Timeline scrubber
                TimelineScrubber(showAnnotationTimelineToggle: !_isFullscreen),

                // Annotation keyframe timeline (separate from playback timeline)
                if (!_isFullscreen && showAnnotationTimeline)
                  const AnnotationKeyframeTimeline(),

                // Playback controls
                PlaybackControls(
                  isFullscreen: _isFullscreen,
                  onToggleFullscreen: _toggleFullscreenMode,
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

  KeyEventResult _handleKeyEvent(KeyEvent event) {
    final playerNotifier = ref.read(playerProvider.notifier);
    final annotationNotifier = ref.read(annotationProvider.notifier);
    final loopNotifier = ref.read(loopProvider.notifier);
    final cropNotifier = ref.read(cropProvider.notifier);

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

    // Helper to start key repeat
    void startKeyRepeat(VoidCallback action, {Duration? interval}) {
      _keyRepeatTimer?.cancel();
      _lastPressedKey = event.logicalKey;

      // Execute immediately
      action();

      // Start repeating after initial delay
      _keyRepeatTimer = Timer(const Duration(milliseconds: 500), () {
        _keyRepeatTimer = Timer.periodic(
          interval ?? const Duration(milliseconds: 50),
          (timer) => action(),
        );
      });
    }

    // Handle key up events - stop repeat
    if (event is KeyUpEvent) {
      if (_lastPressedKey == event.logicalKey) {
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
        startKeyRepeat(() => playerNotifier.stepForward());
        return KeyEventResult.handled;
      }

      // Previous frame (with repeat)
      if (matchesShortcut(_shortcuts.previousFrame)) {
        startKeyRepeat(() => playerNotifier.stepBackward());
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
          () => playerNotifier.jumpForward(const Duration(seconds: 1)),
          interval: const Duration(milliseconds: 100),
        );
        return KeyEventResult.handled;
      }

      // Jump backward (with repeat, slower)
      if (matchesShortcut(_shortcuts.jumpBackward)) {
        startKeyRepeat(
          () => playerNotifier.jumpBackward(const Duration(seconds: 1)),
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

      // Delete selected annotation (no repeat)
      if (event.logicalKey == LogicalKeyboardKey.delete) {
        final annotationState = ref.read(annotationProvider);
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
        final annotationState = ref.read(annotationProvider);
        annotationNotifier.setKeyframeCreationMode(
          annotationState.keyframeCreationMode == KeyframeCreationMode.manual
              ? KeyframeCreationMode.automatic
              : KeyframeCreationMode.manual,
        );
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
    try {
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

      // Refocus
      _focusNode.requestFocus();
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

      // Refocus
      _focusNode.requestFocus();
    } catch (e) {
      if (mounted) {
        _showErrorDialog('Error opening file: $e');
      }
    }
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

  Future<void> _exportVideoFromTopBar() async {
    try {
      final playerState = ref.read(playerProvider);
      final cropState = ref.read(cropProvider);
      final cropNotifier = ref.read(cropProvider.notifier);

      if (playerState.currentVideoPath == null) {
        _showErrorDialog('No video loaded');
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
          return KeyboardShortcutsDialog(
            shortcuts: _shortcuts,
            onSave: (shortcuts) {
              _saveShortcuts(shortcuts);
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
                'FrameSketch Player has been registered as a video player.\n\n'
                    'To set it as default:\n'
                    '1. Right-click any video file\n'
                    '2. Select "Open with" → "Choose another app"\n'
                    '3. Select "FrameSketch Player"\n'
                    '4. Check "Always use this app"',
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
                  content: Text('File associations removed successfully'),
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
                  ? 'FrameSketch Player is currently registered as a video player.'
                  : 'FrameSketch Player is not registered.\n\nUse "Set as Default Video Player" to register it.',
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
