import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/keyboard_shortcuts.dart';
import '../../core/theme/theme_provider.dart';
import '../../features/annotations/providers/annotation_provider.dart';
import '../../features/crop/providers/crop_provider.dart';
import '../../features/loop/providers/loop_provider.dart';
import '../../features/player/providers/player_provider.dart';
import 'command_palette_model.dart';

typedef AsyncCommand = Future<void> Function();

class EditorCommandFactory {
  const EditorCommandFactory({
    required this.ref,
    required this.shortcuts,
    required this.markerColor,
    required this.isFullscreen,
    required this.onOpenFile,
    required this.onOpenRecent,
    required this.onSaveAnnotations,
    required this.onExportVideoFromTopBar,
    required this.onOpenThemeManager,
    required this.onToggleFullscreen,
  });

  final WidgetRef ref;
  final KeyboardShortcuts shortcuts;
  final Color markerColor;
  final bool isFullscreen;
  final AsyncCommand onOpenFile;
  final AsyncCommand onOpenRecent;
  final AsyncCommand onSaveAnnotations;
  final AsyncCommand onExportVideoFromTopBar;
  final VoidCallback onOpenThemeManager;
  final VoidCallback onToggleFullscreen;

  List<PaletteCommand> build() {
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
      PaletteCommand(
        id: 'open-video',
        label: 'Open Video...',
        category: 'File',
        icon: Icons.folder_open_outlined,
        shortcut: formatShortcutLabel(shortcuts.openFile),
        run: () {
          unawaited(onOpenFile());
          return null;
        },
      ),
      PaletteCommand(
        id: 'open-recent',
        label: 'Open Recent...',
        category: 'File',
        icon: Icons.history,
        run: () {
          unawaited(onOpenRecent());
          return null;
        },
      ),
      PaletteCommand(
        id: 'save-project',
        label: 'Save Project',
        category: 'File',
        icon: Icons.save_outlined,
        shortcut: formatShortcutLabel(shortcuts.saveAnnotations),
        enabled: hasAnnotations,
        run: () {
          unawaited(onSaveAnnotations());
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
          unawaited(onExportVideoFromTopBar());
          return null;
        },
      ),
      PaletteCommand(
        id: 'go-to-frame',
        label: 'Go to Frame...',
        category: 'Playback',
        icon: Icons.skip_next_outlined,
        enabled: hasVideo,
        run: _goToFrameStep,
      ),
      PaletteCommand(
        id: 'set-a',
        label: 'Set Loop A (start)...',
        category: 'Loop',
        icon: Icons.flag_outlined,
        shortcut: formatShortcutLabel(shortcuts.setLoopStart),
        enabled: hasVideo,
        run: () => _setLoopPointStep(isA: true),
      ),
      PaletteCommand(
        id: 'set-b',
        label: 'Set Loop B (end)...',
        category: 'Loop',
        icon: Icons.outlined_flag,
        shortcut: formatShortcutLabel(shortcuts.setLoopEnd),
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
        shortcut: formatShortcutLabel(shortcuts.toggleSectionLoop),
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
        shortcut: formatShortcutLabel(shortcuts.toggleFullLoop),
        enabled: hasVideo,
        run: () {
          ref.read(loopProvider.notifier).toggleFullVideoLoop();
          return null;
        },
      ),
      PaletteCommand(
        id: 'toggle-crop',
        label: cropState.isCropModeActive
            ? 'Exit Crop Mode'
            : 'Enter Crop Mode',
        category: 'Crop',
        icon: Icons.crop,
        shortcut: formatShortcutLabel(shortcuts.toggleCropMode),
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
              .upsertMarker(label: 'Marker $frame', color: markerColor);
          return null;
        },
      ),
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
        label: 'Open Theme Manager...',
        category: 'View',
        icon: Icons.palette_outlined,
        run: () {
          onOpenThemeManager();
          return null;
        },
      ),
      PaletteCommand(
        id: 'toggle-fullscreen',
        label: isFullscreen ? 'Exit Fullscreen' : 'Enter Fullscreen',
        category: 'View',
        icon: Icons.fullscreen,
        shortcut: formatShortcutLabel(shortcuts.toggleFullscreen),
        run: () {
          onToggleFullscreen();
          return null;
        },
      ),
      ..._buildShortcutDiscoveryCommands(),
    ];
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

  List<PaletteCommand> _buildShortcutDiscoveryCommands() {
    final entries = <(String, KeyboardShortcut)>[
      ('Open Command Palette', shortcuts.openCommandPalette),
      ('Play / Pause', shortcuts.playPause),
      ('Next Frame', shortcuts.nextFrame),
      ('Previous Frame', shortcuts.previousFrame),
      ('Jump Forward 1s', shortcuts.jumpForward),
      ('Jump Backward 1s', shortcuts.jumpBackward),
      ('Next Marker', shortcuts.nextMarker),
      ('Previous Marker', shortcuts.previousMarker),
      ('Undo', shortcuts.undo),
      ('Redo', shortcuts.redo),
      ('Open File', shortcuts.openFile),
      ('Save Annotations', shortcuts.saveAnnotations),
      ('Toggle Fullscreen', shortcuts.toggleFullscreen),
      ('Pen Tool', shortcuts.selectPenTool),
      ('Eraser', shortcuts.selectEraserTool),
      ('Select Tool', shortcuts.selectSelectionTool),
      ('Rectangle', shortcuts.selectRectangleTool),
      ('Circle', shortcuts.selectCircleTool),
      ('Line', shortcuts.selectLineTool),
      ('Arrow', shortcuts.selectArrowTool),
      ('Text', shortcuts.selectTextTool),
      ('Toggle Keyframe Mode', shortcuts.toggleKeyframeMode),
      ('Create Manual Keyframe', shortcuts.createManualKeyframe),
      ('Set Loop A', shortcuts.setLoopStart),
      ('Set Loop B', shortcuts.setLoopEnd),
      ('Toggle Section Loop', shortcuts.toggleSectionLoop),
      ('Toggle Full Video Loop', shortcuts.toggleFullLoop),
      ('Toggle Crop Mode', shortcuts.toggleCropMode),
    ];

    return entries
        .map(
          (e) => PaletteCommand(
            id: 'shortcut-${e.$1}',
            label: e.$1,
            category: 'Keyboard Shortcuts',
            icon: Icons.keyboard_outlined,
            shortcut: formatShortcutLabel(e.$2),
            subtitle: 'Shortcut reference (read-only)',
            enabled: false,
          ),
        )
        .toList();
  }
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

String formatShortcutLabel(KeyboardShortcut shortcut) {
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
