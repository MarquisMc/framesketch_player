import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_palette.dart';
import 'command_palette_model.dart';

/// Command palette overlay.
///
/// Searchable, keyboard-driven list of actions. Supports a secondary input
/// step for commands that need a value (frame number, A/B position).
class CommandPalette extends StatefulWidget {
  final List<PaletteCommand> commands;
  final VoidCallback onClose;

  const CommandPalette({
    super.key,
    required this.commands,
    required this.onClose,
  });

  @override
  State<CommandPalette> createState() => _CommandPaletteState();
}

class _CommandPaletteState extends State<CommandPalette> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  final ScrollController _scrollController = ScrollController();
  final Map<int, GlobalKey> _itemKeys = <int, GlobalKey>{};
  List<PaletteCommand>? _cachedFiltered;
  List<PaletteCommand>? _cachedCommands;
  String? _lastQuery;
  int _selectedIndex = 0;
  PaletteStep? _activeStep;
  String? _stepError;

  List<PaletteCommand> get _filtered {
    final query = _searchController.text.trim().toLowerCase();
    if (_cachedFiltered != null &&
        _lastQuery == query &&
        _hasSameCommands(_cachedCommands, widget.commands)) {
      return _cachedFiltered!;
    }

    _cachedCommands = List<PaletteCommand>.of(widget.commands);
    _lastQuery = query;
    if (query.isEmpty) {
      _cachedFiltered = _sortCommandsByCategory(_cachedCommands!);
      return _cachedFiltered!;
    }

    _cachedFiltered = _sortCommandsByCategory(
      widget.commands.where((c) {
        return c.label.toLowerCase().contains(query) ||
            c.category.toLowerCase().contains(query) ||
            (c.subtitle?.toLowerCase().contains(query) ?? false);
      }),
    );
    return _cachedFiltered!;
  }

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_handleSearchChanged);
    _recomputeFiltered();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocus.requestFocus();
    });
  }

  @override
  void didUpdateWidget(covariant CommandPalette oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_hasSameCommands(oldWidget.commands, widget.commands)) {
      _recomputeFiltered();
    }
  }

  @override
  void dispose() {
    _searchController.removeListener(_handleSearchChanged);
    _searchController.dispose();
    _searchFocus.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _handleSearchChanged() {
    _recomputeFiltered();
  }

  void _recomputeFiltered() {
    final query = _searchController.text.trim().toLowerCase();
    _cachedCommands = List<PaletteCommand>.of(widget.commands);
    _lastQuery = query;
    if (query.isEmpty) {
      _cachedFiltered = _sortCommandsByCategory(_cachedCommands!);
      return;
    }

    _cachedFiltered = _sortCommandsByCategory(
      widget.commands.where((c) {
        return c.label.toLowerCase().contains(query) ||
            c.category.toLowerCase().contains(query) ||
            (c.subtitle?.toLowerCase().contains(query) ?? false);
      }),
    );
  }

  List<PaletteCommand> _sortCommandsByCategory(
    Iterable<PaletteCommand> commands,
  ) {
    final indexed = commands.toList().asMap().entries.toList();
    indexed.sort((a, b) {
      final categoryCompare = a.value.category.toLowerCase().compareTo(
        b.value.category.toLowerCase(),
      );
      if (categoryCompare != 0) {
        return categoryCompare;
      }
      return a.key.compareTo(b.key);
    });
    return indexed.map((entry) => entry.value).toList();
  }

  bool _hasSameCommands(
    List<PaletteCommand>? previous,
    List<PaletteCommand> current,
  ) {
    if (previous == null || previous.length != current.length) {
      return false;
    }
    for (var index = 0; index < current.length; index++) {
      if (previous[index] != current[index]) {
        return false;
      }
    }
    return true;
  }

  void _moveSelection(int delta) {
    final items = _filtered;
    if (items.isEmpty) return;
    setState(() {
      _selectedIndex = (_selectedIndex + delta).clamp(0, items.length - 1);
    });
    _ensureVisible();
  }

  void _ensureVisible() {
    final key = _itemKeys[_selectedIndex];
    final context = key?.currentContext;
    if (context == null) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final currentContext = key?.currentContext;
      if (currentContext == null || !mounted) return;
      Scrollable.ensureVisible(
        currentContext,
        duration: const Duration(milliseconds: 120),
        alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
      );
    });
  }

  void _runSelected() {
    final items = _filtered;
    if (items.isEmpty) return;
    final cmd = items[_selectedIndex];
    if (!cmd.enabled || cmd.run == null) return;

    final nextStep = cmd.run!();
    if (nextStep != null) {
      setState(() {
        _activeStep = nextStep;
        _stepError = null;
        _searchController.clear();
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _searchFocus.requestFocus();
      });
      return;
    }

    widget.onClose();
  }

  Future<void> _submitStep() async {
    final step = _activeStep;
    if (step == null) return;
    final error = await step.onSubmit(_searchController.text);
    if (!mounted) return;
    if (error == null) {
      widget.onClose();
    } else {
      setState(() {
        _stepError = error;
      });
    }
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    if (event.logicalKey == LogicalKeyboardKey.escape) {
      if (_activeStep != null) {
        setState(() {
          _activeStep = null;
          _stepError = null;
          _searchController.clear();
        });
        return KeyEventResult.handled;
      }
      widget.onClose();
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter) {
      if (_activeStep != null) {
        unawaited(_submitStep());
      } else {
        _runSelected();
      }
      return KeyEventResult.handled;
    }

    if (_activeStep == null) {
      if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        _moveSelection(1);
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        _moveSelection(-1);
        return KeyEventResult.handled;
      }
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onClose,
        child: Container(
          color: palette.panelOverlay,
          alignment: Alignment.topCenter,
          padding: const EdgeInsets.only(top: 96),
          child: GestureDetector(
            // Prevents tap from propagating to overlay dismiss handler
            onTap: () {},
            child: Focus(
              autofocus: true,
              onKeyEvent: _onKey,
              child: Container(
                width: 620,
                constraints: const BoxConstraints(maxHeight: 520),
                decoration: BoxDecoration(
                  color: palette.panelElevated,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: palette.border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.35),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildSearchRow(palette),
                    Divider(height: 1, color: palette.border),
                    Flexible(
                      child: _activeStep != null
                          ? _buildStepHelper(palette)
                          : _buildResults(palette),
                    ),
                    Divider(height: 1, color: palette.border),
                    _buildFooter(palette),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchRow(AppPalette palette) {
    final step = _activeStep;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Icon(
            step == null ? Icons.search : Icons.keyboard_arrow_right,
            size: 18,
            color: palette.textMuted,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocus,
              onChanged: (_) {
                setState(() {
                  _selectedIndex = 0;
                  _stepError = null;
                });
              },
              onSubmitted: (_) {
                if (_activeStep != null) {
                  unawaited(_submitStep());
                } else {
                  _runSelected();
                }
              },
              style: TextStyle(color: palette.textPrimary, fontSize: 14),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: step?.hint ?? 'Type a command or search...',
                hintStyle: TextStyle(color: palette.textMuted, fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepHelper(AppPalette palette) {
    final step = _activeStep!;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            step.title,
            style: TextStyle(
              color: palette.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (step.helper != null) ...[
            const SizedBox(height: 6),
            Text(
              step.helper!,
              style: TextStyle(color: palette.textMuted, fontSize: 12),
            ),
          ],
          if (_stepError != null) ...[
            const SizedBox(height: 10),
            Text(
              _stepError!,
              style: TextStyle(color: palette.error, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildResults(AppPalette palette) {
    final items = _filtered;
    _itemKeys.removeWhere((index, _) => index >= items.length);
    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'No matching commands',
          style: TextStyle(color: palette.textMuted, fontSize: 13),
        ),
      );
    }

    String? lastCategory;
    final rows = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      final cmd = items[i];
      if (cmd.category != lastCategory) {
        rows.add(_buildCategoryHeader(cmd.category, palette));
        lastCategory = cmd.category;
      }
      rows.add(_buildRow(cmd, i == _selectedIndex, palette, i));
    }

    return SingleChildScrollView(
      controller: _scrollController,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: rows,
      ),
    );
  }

  Widget _buildCategoryHeader(String name, AppPalette palette) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: Text(
        name.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: palette.textMuted,
        ),
      ),
    );
  }

  Widget _buildRow(
    PaletteCommand cmd,
    bool selected,
    AppPalette palette,
    int index,
  ) {
    final rowKey = _itemKeys.putIfAbsent(index, GlobalKey.new);
    final labelColor = cmd.enabled ? palette.textPrimary : palette.textDisabled;
    final iconColor = cmd.enabled
        ? (selected ? palette.accentBright : palette.textSecondary)
        : palette.textDisabled;

    return MouseRegion(
      cursor: cmd.enabled
          ? SystemMouseCursors.click
          : SystemMouseCursors.forbidden,
      child: GestureDetector(
        onTap: cmd.enabled
            ? () {
                setState(() => _selectedIndex = index);
                _ensureVisible();
                _runSelected();
              }
            : null,
        child: Container(
          key: rowKey,
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          color: selected ? palette.accentSoft : Colors.transparent,
          child: Row(
            children: [
              Icon(cmd.icon, size: 16, color: iconColor),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cmd.label,
                      style: TextStyle(fontSize: 13, color: labelColor),
                    ),
                    if (cmd.subtitle != null)
                      Text(
                        cmd.subtitle!,
                        style: TextStyle(
                          fontSize: 11,
                          color: palette.textMuted,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              if (cmd.shortcut != null)
                Text(
                  cmd.shortcut!,
                  style: TextStyle(
                    fontSize: 11,
                    color: palette.textMuted,
                    fontFamily: 'monospace',
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFooter(AppPalette palette) {
    final isStep = _activeStep != null;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        children: [
          _footerHint(
            isStep ? 'enter' : 'up/down',
            isStep ? 'confirm' : 'navigate',
            palette,
          ),
          const SizedBox(width: 16),
          _footerHint(
            isStep ? 'esc' : 'enter',
            isStep ? 'back' : 'run',
            palette,
          ),
          const SizedBox(width: 16),
          if (!isStep) _footerHint('esc', 'close', palette),
          const Spacer(),
          Text(
            'Command Palette',
            style: TextStyle(fontSize: 10, color: palette.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _footerHint(String key, String label, AppPalette palette) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: palette.panel,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: palette.border),
          ),
          child: Text(
            key,
            style: TextStyle(
              fontSize: 10,
              fontFamily: 'monospace',
              color: palette.textSecondary,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: 11, color: palette.textMuted)),
      ],
    );
  }
}
