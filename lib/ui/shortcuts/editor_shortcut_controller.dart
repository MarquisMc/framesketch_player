import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/keyboard_shortcuts.dart';
import '../../features/annotations/models/stroke.dart';
import '../../features/annotations/providers/annotation_provider.dart';
import '../../features/loop/providers/loop_provider.dart';
import '../../features/player/providers/player_provider.dart';

/// Routes global key events to editor actions.
///
/// Owns the key-repeat state machine (initial delay, chained repeats that
/// never overlap seeks) and the rules for when shortcuts are suppressed,
/// e.g. while an editable text field has focus.
class EditorShortcutController {
  EditorShortcutController({
    required this.ref,
    required this.focusNode,
    required this.shortcuts,
    required this.isFullscreen,
    required this.setFullscreen,
    required this.toggleFullscreen,
    required this.isCropExportPanelOpen,
    required this.closeCropExportPanel,
    required this.toggleCropExportPanel,
    required this.openCommandPalette,
    required this.openFile,
    required this.saveAnnotations,
    required this.openMarkerEditorAtCurrentFrame,
  });

  final WidgetRef ref;
  final FocusNode focusNode;
  final KeyboardShortcuts Function() shortcuts;
  final bool Function() isFullscreen;
  final void Function(bool enabled) setFullscreen;
  final VoidCallback toggleFullscreen;
  final bool Function() isCropExportPanelOpen;
  final VoidCallback closeCropExportPanel;
  final VoidCallback toggleCropExportPanel;
  final VoidCallback openCommandPalette;
  final VoidCallback openFile;
  final VoidCallback saveAnnotations;
  final bool Function() openMarkerEditorAtCurrentFrame;

  Timer? _keyRepeatTimer;
  LogicalKeyboardKey? _lastPressedKey;
  int _keyRepeatGeneration = 0;

  void dispose() {
    _stopKeyRepeat();
  }

  void _stopKeyRepeat() {
    _keyRepeatGeneration++;
    _keyRepeatTimer?.cancel();
    _keyRepeatTimer = null;
    _lastPressedKey = null;
  }

  KeyEventResult handleKeyEvent(KeyEvent event) {
    final playerNotifier = ref.read(playerProvider.notifier);
    final annotationNotifier = ref.read(annotationProvider.notifier);
    final loopNotifier = ref.read(loopProvider.notifier);
    final annotationState = ref.read(annotationProvider);
    final shortcuts = this.shortcuts();

    // Only process app-wide shortcuts while keyboard focus is in the editor
    // shell. Editable text descendants keep their normal text behavior.
    if (!focusNode.hasFocus || _isEditableTextFocused()) {
      _stopKeyRepeat();
      return KeyEventResult.ignored;
    }

    // When focus is inside editable text, let the field consume normal
    // character input instead of routing those keys through global shortcuts.
    if (annotationState.pendingTextStrokeId != null) {
      _stopKeyRepeat();
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
        _stopKeyRepeat();
      }
      return KeyEventResult.ignored;
    }

    // Only handle key down events for actions
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    if (matchesShortcut(shortcuts.toggleFullscreen)) {
      toggleFullscreen();
      return KeyEventResult.handled;
    }

    // General shortcuts
    if (shortcuts.generalShortcutsEnabled) {
      if (matchesShortcut(shortcuts.openCommandPalette)) {
        openCommandPalette();
        return KeyEventResult.handled;
      }

      // Next frame (with repeat)
      if (matchesShortcut(shortcuts.nextFrame)) {
        startKeyRepeat(() async => playerNotifier.stepForward());
        return KeyEventResult.handled;
      }

      // Previous frame (with repeat)
      if (matchesShortcut(shortcuts.previousFrame)) {
        startKeyRepeat(() async => playerNotifier.stepBackward());
        return KeyEventResult.handled;
      }

      // Play/Pause (no repeat)
      if (matchesShortcut(shortcuts.playPause)) {
        playerNotifier.togglePlayPause();
        return KeyEventResult.handled;
      }

      // Jump forward (with repeat, slower)
      if (matchesShortcut(shortcuts.jumpForward)) {
        startKeyRepeat(
          () async => playerNotifier.jumpForward(const Duration(seconds: 1)),
          interval: const Duration(milliseconds: 100),
        );
        return KeyEventResult.handled;
      }

      // Jump backward (with repeat, slower)
      if (matchesShortcut(shortcuts.jumpBackward)) {
        startKeyRepeat(
          () async => playerNotifier.jumpBackward(const Duration(seconds: 1)),
          interval: const Duration(milliseconds: 100),
        );
        return KeyEventResult.handled;
      }

      // Open file (no repeat)
      if (matchesShortcut(shortcuts.openFile)) {
        openFile();
        return KeyEventResult.handled;
      }

      // Save annotations (no repeat)
      if (matchesShortcut(shortcuts.saveAnnotations)) {
        saveAnnotations();
        return KeyEventResult.handled;
      }

      // Undo (no repeat)
      if (matchesShortcut(shortcuts.undo)) {
        if (annotationNotifier.canUndo) {
          annotationNotifier.undo();
          return KeyEventResult.handled;
        }
      }

      // Redo (no repeat)
      if (matchesShortcut(shortcuts.redo)) {
        if (annotationNotifier.canRedo) {
          annotationNotifier.redo();
          return KeyEventResult.handled;
        }
      }

      if (matchesShortcut(shortcuts.addMarker)) {
        return openMarkerEditorAtCurrentFrame()
            ? KeyEventResult.handled
            : KeyEventResult.ignored;
      }

      // Duplicate selected annotation (no repeat)
      if (event.logicalKey == LogicalKeyboardKey.keyD &&
          isCtrl &&
          !isShift &&
          !isAlt &&
          annotationNotifier.canDuplicateSelectedStroke) {
        annotationNotifier.duplicateSelectedStroke();
        return KeyEventResult.handled;
      }

      if (matchesShortcut(shortcuts.nextMarker)) {
        unawaited(annotationNotifier.seekToNextMarker());
        return KeyEventResult.handled;
      }

      if (matchesShortcut(shortcuts.previousMarker)) {
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
    if (shortcuts.annotationToolsShortcutsEnabled) {
      // Select selection tool (no repeat)
      if (matchesShortcut(shortcuts.selectSelectionTool)) {
        annotationNotifier.setTool(DrawingTool.select);
        return KeyEventResult.handled;
      }

      // Select pen tool (no repeat)
      if (matchesShortcut(shortcuts.selectPenTool)) {
        annotationNotifier.setTool(DrawingTool.pen);
        return KeyEventResult.handled;
      }

      // Select eraser tool (no repeat)
      if (matchesShortcut(shortcuts.selectEraserTool)) {
        annotationNotifier.setTool(DrawingTool.eraser);
        return KeyEventResult.handled;
      }

      // Select rectangle tool (no repeat)
      if (matchesShortcut(shortcuts.selectRectangleTool)) {
        annotationNotifier.setTool(DrawingTool.rectangle);
        return KeyEventResult.handled;
      }

      // Select circle tool (no repeat)
      if (matchesShortcut(shortcuts.selectCircleTool)) {
        annotationNotifier.setTool(DrawingTool.circle);
        return KeyEventResult.handled;
      }

      // Select line tool (no repeat)
      if (matchesShortcut(shortcuts.selectLineTool)) {
        annotationNotifier.setTool(DrawingTool.line);
        return KeyEventResult.handled;
      }

      // Select arrow tool (no repeat)
      if (matchesShortcut(shortcuts.selectArrowTool)) {
        annotationNotifier.setTool(DrawingTool.arrow);
        return KeyEventResult.handled;
      }

      // Select text tool (no repeat)
      if (matchesShortcut(shortcuts.selectTextTool)) {
        annotationNotifier.setTool(DrawingTool.text);
        return KeyEventResult.handled;
      }

      // Toggle keyframe creation mode (no repeat)
      if (matchesShortcut(shortcuts.toggleKeyframeMode)) {
        annotationNotifier.setKeyframeCreationMode(
          switch (annotationState.keyframeCreationMode) {
            KeyframeCreationMode.automatic => KeyframeCreationMode.manual,
            KeyframeCreationMode.manual => KeyframeCreationMode.whiteboard,
            KeyframeCreationMode.whiteboard => KeyframeCreationMode.automatic,
          },
        );
        return KeyEventResult.handled;
      }

      // Create manual keyframe at current frame (no repeat)
      if (matchesShortcut(shortcuts.createManualKeyframe)) {
        annotationNotifier.createManualKeyframeAtCurrentFrame();
        return KeyEventResult.handled;
      }
    }

    // Loop controls shortcuts
    if (shortcuts.loopControlsShortcutsEnabled) {
      // Toggle full video loop (no repeat)
      if (matchesShortcut(shortcuts.toggleFullLoop)) {
        loopNotifier.toggleFullVideoLoop();
        return KeyEventResult.handled;
      }

      // Set loop start point (A) (no repeat)
      if (matchesShortcut(shortcuts.setLoopStart)) {
        loopNotifier.setAPoint();
        return KeyEventResult.handled;
      }

      // Set loop end point (B) (no repeat)
      if (matchesShortcut(shortcuts.setLoopEnd)) {
        loopNotifier.setBPoint();
        return KeyEventResult.handled;
      }

      // Toggle section loop (A-B) (no repeat)
      if (matchesShortcut(shortcuts.toggleSectionLoop)) {
        loopNotifier.toggleSectionLoop();
        return KeyEventResult.handled;
      }
    }

    // Crop controls shortcuts
    if (shortcuts.cropControlsShortcutsEnabled) {
      if (matchesShortcut(shortcuts.toggleCropMode)) {
        toggleCropExportPanel();
        return KeyEventResult.handled;
      }
    }

    // Escape key - close crop/export panel or exit fullscreen
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      if (isFullscreen()) {
        setFullscreen(false);
        return KeyEventResult.handled;
      }
      if (isCropExportPanelOpen()) {
        closeCropExportPanel();
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
}
