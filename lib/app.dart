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
import 'features/annotations/providers/annotation_provider.dart';
import 'core/services/annotation_storage_service.dart';
import 'core/models/keyboard_shortcuts.dart';
import 'features/settings/widgets/settings_dialog.dart';
import 'features/loop/providers/loop_provider.dart';
import 'features/crop/providers/crop_provider.dart';
import 'features/crop/widgets/crop_controls.dart';
import 'features/crop/widgets/crop_overlay.dart';

/// Main application widget
class FrameSketchPlayerApp extends ConsumerStatefulWidget {
  const FrameSketchPlayerApp({super.key});

  @override
  ConsumerState<FrameSketchPlayerApp> createState() => _FrameSketchPlayerAppState();
}

class _FrameSketchPlayerAppState extends ConsumerState<FrameSketchPlayerApp> {
  final FocusNode _focusNode = FocusNode();
  late KeyboardShortcuts _shortcuts;
  Timer? _keyRepeatTimer;
  LogicalKeyboardKey? _lastPressedKey;

  @override
  void initState() {
    super.initState();
    _shortcuts = defaultKeyboardShortcuts;
    _loadShortcuts();
    // Request focus on startup
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
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
      print('Error saving shortcuts: $e');
    }
  }

  @override
  void dispose() {
    _keyRepeatTimer?.cancel();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FrameSketch Player',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        scaffoldBackgroundColor: Colors.grey[900],
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.red,
          brightness: Brightness.dark,
        ),
      ),
      home: Focus(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: (node, event) => _handleKeyEvent(event),
        child: Builder(
          builder: (context) => Scaffold(
            appBar: AppBar(
              title: const Text('FrameSketch Player'),
              actions: [
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
                  icon: const Icon(Icons.settings),
                  onPressed: () => _openSettings(context),
                  tooltip: 'Keyboard Shortcuts',
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
                    const Expanded(
                      child: VideoViewport(),
                    ),

                    // Drawing tools panel
                    const DrawingToolsPanel(),
                  ],
                ),
              ),

              // Crop controls panel (shows when crop mode is active)
              const CropControlsPanel(),

              // Timeline scrubber
              const TimelineScrubber(),

              // Playback controls
              const PlaybackControls(),
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

    // Toggle crop mode (no repeat)
    if (matchesShortcut(_shortcuts.toggleCropMode)) {
      cropNotifier.toggleCropMode();
      return KeyEventResult.handled;
    }

    // Escape key - exit crop mode
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      final cropState = ref.read(cropProvider);
      if (cropState.isCropModeActive) {
        cropNotifier.exitCropMode();
        return KeyEventResult.handled;
      }
    }

    return KeyEventResult.ignored;
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
          _showErrorDialog('Failed to load video. The video file may be corrupted or in an unsupported format.');
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
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Annotations saved successfully'),
              backgroundColor: Colors.green,
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

  void _openSettings(BuildContext context) {
    print('Opening settings dialog...');
    print('Current shortcuts: $_shortcuts');
    try {
      showDialog(
        context: context,
        builder: (dialogContext) {
          print('Building dialog...');
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
      print('Error opening settings dialog: $e');
      _showErrorDialog('Error opening settings: $e');
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _focusNode.requestFocus();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
