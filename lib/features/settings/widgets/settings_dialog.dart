import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/models/keyboard_shortcuts.dart';

/// Dialog for editing keyboard shortcuts
class KeyboardShortcutsDialog extends StatefulWidget {
  final KeyboardShortcuts shortcuts;
  final Function(KeyboardShortcuts) onSave;

  const KeyboardShortcutsDialog({
    super.key,
    required this.shortcuts,
    required this.onSave,
  });

  @override
  State<KeyboardShortcutsDialog> createState() =>
      _KeyboardShortcutsDialogState();
}

class _KeyboardShortcutsDialogState extends State<KeyboardShortcutsDialog> {
  late KeyboardShortcuts _shortcuts;

  @override
  void initState() {
    super.initState();
    _shortcuts = widget.shortcuts;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Keyboard Shortcuts'),
      content: SizedBox(
        width: 600,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'General Shortcuts',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                title: const Text('Enable General Shortcuts'),
                value: _shortcuts.generalShortcutsEnabled,
                onChanged: (value) {
                  setState(() {
                    _shortcuts = _shortcuts.copyWith(
                      generalShortcutsEnabled: value,
                    );
                  });
                },
              ),
              const SizedBox(height: 16),
              _ShortcutRow(
                label: 'Next Frame',
                shortcut: _shortcuts.nextFrame,
                onChanged: (shortcut) {
                  setState(() {
                    _shortcuts = _shortcuts.copyWith(nextFrame: shortcut);
                  });
                },
              ),
              const SizedBox(height: 16),
              _ShortcutRow(
                label: 'Previous Frame',
                shortcut: _shortcuts.previousFrame,
                onChanged: (shortcut) {
                  setState(() {
                    _shortcuts = _shortcuts.copyWith(previousFrame: shortcut);
                  });
                },
              ),
              const SizedBox(height: 16),
              _ShortcutRow(
                label: 'Play / Pause',
                shortcut: _shortcuts.playPause,
                onChanged: (shortcut) {
                  setState(() {
                    _shortcuts = _shortcuts.copyWith(playPause: shortcut);
                  });
                },
              ),
              const SizedBox(height: 16),
              _ShortcutRow(
                label: 'Jump Forward 1s',
                shortcut: _shortcuts.jumpForward,
                onChanged: (shortcut) {
                  setState(() {
                    _shortcuts = _shortcuts.copyWith(jumpForward: shortcut);
                  });
                },
              ),
              const SizedBox(height: 16),
              _ShortcutRow(
                label: 'Jump Backward 1s',
                shortcut: _shortcuts.jumpBackward,
                onChanged: (shortcut) {
                  setState(() {
                    _shortcuts = _shortcuts.copyWith(jumpBackward: shortcut);
                  });
                },
              ),
              const SizedBox(height: 16),
              _ShortcutRow(
                label: 'Toggle Fullscreen',
                shortcut: _shortcuts.toggleFullscreen,
                onChanged: (shortcut) {
                  setState(() {
                    _shortcuts = _shortcuts.copyWith(
                      toggleFullscreen: shortcut,
                    );
                  });
                },
              ),
              const SizedBox(height: 16),
              _ShortcutRow(
                label: 'Open File',
                shortcut: _shortcuts.openFile,
                onChanged: (shortcut) {
                  setState(() {
                    _shortcuts = _shortcuts.copyWith(openFile: shortcut);
                  });
                },
              ),
              const SizedBox(height: 16),
              _ShortcutRow(
                label: 'Save Annotations',
                shortcut: _shortcuts.saveAnnotations,
                onChanged: (shortcut) {
                  setState(() {
                    _shortcuts = _shortcuts.copyWith(saveAnnotations: shortcut);
                  });
                },
              ),
              const SizedBox(height: 16),
              _ShortcutRow(
                label: 'Undo',
                shortcut: _shortcuts.undo,
                onChanged: (shortcut) {
                  setState(() {
                    _shortcuts = _shortcuts.copyWith(undo: shortcut);
                  });
                },
              ),
              const SizedBox(height: 16),
              _ShortcutRow(
                label: 'Redo',
                shortcut: _shortcuts.redo,
                onChanged: (shortcut) {
                  setState(() {
                    _shortcuts = _shortcuts.copyWith(redo: shortcut);
                  });
                },
              ),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 8),
              const Text(
                'Annotation Tools',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                title: const Text('Enable Annotation Tools Shortcuts'),
                value: _shortcuts.annotationToolsShortcutsEnabled,
                onChanged: (value) {
                  setState(() {
                    _shortcuts = _shortcuts.copyWith(
                      annotationToolsShortcutsEnabled: value,
                    );
                  });
                },
              ),
              const SizedBox(height: 16),
              _ShortcutRow(
                label: 'Select Selection Tool',
                shortcut: _shortcuts.selectSelectionTool,
                onChanged: (shortcut) {
                  setState(() {
                    _shortcuts = _shortcuts.copyWith(
                      selectSelectionTool: shortcut,
                    );
                  });
                },
              ),
              const SizedBox(height: 16),
              _ShortcutRow(
                label: 'Select Pen Tool',
                shortcut: _shortcuts.selectPenTool,
                onChanged: (shortcut) {
                  setState(() {
                    _shortcuts = _shortcuts.copyWith(selectPenTool: shortcut);
                  });
                },
              ),
              const SizedBox(height: 16),
              _ShortcutRow(
                label: 'Select Eraser Tool',
                shortcut: _shortcuts.selectEraserTool,
                onChanged: (shortcut) {
                  setState(() {
                    _shortcuts = _shortcuts.copyWith(
                      selectEraserTool: shortcut,
                    );
                  });
                },
              ),
              const SizedBox(height: 16),
              _ShortcutRow(
                label: 'Select Rectangle Tool',
                shortcut: _shortcuts.selectRectangleTool,
                onChanged: (shortcut) {
                  setState(() {
                    _shortcuts = _shortcuts.copyWith(
                      selectRectangleTool: shortcut,
                    );
                  });
                },
              ),
              const SizedBox(height: 16),
              _ShortcutRow(
                label: 'Select Circle Tool',
                shortcut: _shortcuts.selectCircleTool,
                onChanged: (shortcut) {
                  setState(() {
                    _shortcuts = _shortcuts.copyWith(
                      selectCircleTool: shortcut,
                    );
                  });
                },
              ),
              const SizedBox(height: 16),
              _ShortcutRow(
                label: 'Select Line Tool',
                shortcut: _shortcuts.selectLineTool,
                onChanged: (shortcut) {
                  setState(() {
                    _shortcuts = _shortcuts.copyWith(selectLineTool: shortcut);
                  });
                },
              ),
              const SizedBox(height: 16),
              _ShortcutRow(
                label: 'Select Arrow Tool',
                shortcut: _shortcuts.selectArrowTool,
                onChanged: (shortcut) {
                  setState(() {
                    _shortcuts = _shortcuts.copyWith(selectArrowTool: shortcut);
                  });
                },
              ),
              const SizedBox(height: 16),
              _ShortcutRow(
                label: 'Select Text Tool',
                shortcut: _shortcuts.selectTextTool,
                onChanged: (shortcut) {
                  setState(() {
                    _shortcuts = _shortcuts.copyWith(selectTextTool: shortcut);
                  });
                },
              ),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 8),
              const Text(
                'Loop Controls',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                title: const Text('Enable Loop Controls Shortcuts'),
                value: _shortcuts.loopControlsShortcutsEnabled,
                onChanged: (value) {
                  setState(() {
                    _shortcuts = _shortcuts.copyWith(
                      loopControlsShortcutsEnabled: value,
                    );
                  });
                },
              ),
              const SizedBox(height: 16),
              _ShortcutRow(
                label: 'Toggle Full Video Loop',
                shortcut: _shortcuts.toggleFullLoop,
                onChanged: (shortcut) {
                  setState(() {
                    _shortcuts = _shortcuts.copyWith(toggleFullLoop: shortcut);
                  });
                },
              ),
              const SizedBox(height: 16),
              _ShortcutRow(
                label: 'Set Loop Start (A Point)',
                shortcut: _shortcuts.setLoopStart,
                onChanged: (shortcut) {
                  setState(() {
                    _shortcuts = _shortcuts.copyWith(setLoopStart: shortcut);
                  });
                },
              ),
              const SizedBox(height: 16),
              _ShortcutRow(
                label: 'Set Loop End (B Point)',
                shortcut: _shortcuts.setLoopEnd,
                onChanged: (shortcut) {
                  setState(() {
                    _shortcuts = _shortcuts.copyWith(setLoopEnd: shortcut);
                  });
                },
              ),
              const SizedBox(height: 16),
              _ShortcutRow(
                label: 'Toggle Section Loop (A-B)',
                shortcut: _shortcuts.toggleSectionLoop,
                onChanged: (shortcut) {
                  setState(() {
                    _shortcuts = _shortcuts.copyWith(
                      toggleSectionLoop: shortcut,
                    );
                  });
                },
              ),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 8),
              const Text(
                'Crop Controls',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                title: const Text('Enable Crop Controls Shortcuts'),
                value: _shortcuts.cropControlsShortcutsEnabled,
                onChanged: (value) {
                  setState(() {
                    _shortcuts = _shortcuts.copyWith(
                      cropControlsShortcutsEnabled: value,
                    );
                  });
                },
              ),
              const SizedBox(height: 16),
              _ShortcutRow(
                label: 'Toggle Crop Mode',
                shortcut: _shortcuts.toggleCropMode,
                onChanged: (shortcut) {
                  setState(() {
                    _shortcuts = _shortcuts.copyWith(toggleCropMode: shortcut);
                  });
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            setState(() {
              _shortcuts = defaultKeyboardShortcuts;
            });
          },
          child: const Text('Reset to Defaults'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            widget.onSave(_shortcuts);
            Navigator.pop(context);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _ShortcutRow extends StatefulWidget {
  final String label;
  final KeyboardShortcut shortcut;
  final Function(KeyboardShortcut) onChanged;

  const _ShortcutRow({
    required this.label,
    required this.shortcut,
    required this.onChanged,
  });

  @override
  State<_ShortcutRow> createState() => _ShortcutRowState();
}

class _ShortcutRowState extends State<_ShortcutRow> {
  late bool _isListening;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _isListening = false;
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(flex: 2, child: Text(widget.label)),
        Expanded(
          flex: 3,
          child: Focus(
            focusNode: _focusNode,
            onKeyEvent: (node, event) {
              if (!_isListening) return KeyEventResult.ignored;

              if (event is KeyDownEvent) {
                final logicalKey = event.logicalKey;
                final isCtrl = HardwareKeyboard.instance.isControlPressed;
                final isShift = HardwareKeyboard.instance.isShiftPressed;
                final isAlt = HardwareKeyboard.instance.isAltPressed;

                // Don't record modifier-only keys
                if (logicalKey == LogicalKeyboardKey.control ||
                    logicalKey == LogicalKeyboardKey.shift ||
                    logicalKey == LogicalKeyboardKey.alt) {
                  return KeyEventResult.ignored;
                }

                final newShortcut = KeyboardShortcut(
                  key: logicalKey,
                  ctrlPressed: isCtrl,
                  shiftPressed: isShift,
                  altPressed: isAlt,
                );

                setState(() {
                  _isListening = false;
                });

                widget.onChanged(newShortcut);

                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(4),
                color: _isListening ? Colors.blue.shade100 : Colors.transparent,
              ),
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _isListening = !_isListening;
                  });
                  if (_isListening) {
                    _focusNode.requestFocus();
                  }
                },
                child: _isListening
                    ? const Text(
                        'Press a key...',
                        style: TextStyle(
                          fontStyle: FontStyle.italic,
                          color: Colors.blue,
                        ),
                      )
                    : Text(
                        _formatShortcut(widget.shortcut),
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _formatShortcut(KeyboardShortcut shortcut) {
    final parts = <String>[];

    if (shortcut.ctrlPressed) parts.add('Ctrl');
    if (shortcut.shiftPressed) parts.add('Shift');
    if (shortcut.altPressed) parts.add('Alt');

    final keyLabel = _getKeyLabel(shortcut.key);
    parts.add(keyLabel);

    return parts.join(' + ');
  }

  String _getKeyLabel(LogicalKeyboardKey key) {
    if (key == LogicalKeyboardKey.space) return 'Space';
    if (key == LogicalKeyboardKey.arrowLeft) return 'Left Arrow';
    if (key == LogicalKeyboardKey.arrowRight) return 'Right Arrow';
    if (key == LogicalKeyboardKey.arrowUp) return 'Up Arrow';
    if (key == LogicalKeyboardKey.arrowDown) return 'Down Arrow';
    if (key == LogicalKeyboardKey.f11) return 'F11';
    if (key == LogicalKeyboardKey.enter) return 'Enter';
    if (key == LogicalKeyboardKey.period) return '.';
    if (key == LogicalKeyboardKey.comma) return ',';
    if (key == LogicalKeyboardKey.keyZ) return 'Z';
    if (key == LogicalKeyboardKey.keyS) return 'S';
    if (key == LogicalKeyboardKey.keyO) return 'O';
    if (key == LogicalKeyboardKey.keyY) return 'Y';
    if (key == LogicalKeyboardKey.keyV) return 'V';
    if (key == LogicalKeyboardKey.keyP) return 'P';
    if (key == LogicalKeyboardKey.keyE) return 'E';
    if (key == LogicalKeyboardKey.keyR) return 'R';
    if (key == LogicalKeyboardKey.keyA) return 'A';
    if (key == LogicalKeyboardKey.keyL) return 'L';
    if (key == LogicalKeyboardKey.keyI) return 'I';
    if (key == LogicalKeyboardKey.keyC) return 'C';
    if (key == LogicalKeyboardKey.keyT) return 'T';
    if (key == LogicalKeyboardKey.bracketLeft) return '[';

    final debugName = key.debugName;
    if (debugName != null) {
      return debugName.replaceAll('LogicalKeyboardKey.', '');
    }
    return 'Unknown';
  }
}
