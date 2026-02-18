import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/theme_provider.dart';

class ThemeManagerDialog extends ConsumerStatefulWidget {
  const ThemeManagerDialog({super.key});

  @override
  ConsumerState<ThemeManagerDialog> createState() => _ThemeManagerDialogState();
}

class _ThemeManagerDialogState extends ConsumerState<ThemeManagerDialog> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _seedController = TextEditingController(
    text: '#39B7A8',
  );
  String? _errorText;

  @override
  void dispose() {
    _nameController.dispose();
    _seedController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeState = ref.watch(themeControllerProvider);
    final controller = ref.read(themeControllerProvider.notifier);
    final parsedSeed = _parseSeedColor(_seedController.text);

    return AlertDialog(
      title: const Text('Theme Manager'),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Built-in examples include your current palette and the old palette from before the AppPalette update.',
              ),
              const SizedBox(height: 16),
              const Text(
                'Active Theme',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                key: ValueKey(themeState.selectedThemeId),
                initialValue: themeState.selectedThemeId,
                items: themeState.themes
                    .map(
                      (theme) => DropdownMenuItem<String>(
                        value: theme.id,
                        child: Text(
                          theme.builtIn
                              ? '${theme.name} (Example)'
                              : theme.name,
                        ),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (value) {
                  if (value == null) return;
                  controller.selectTheme(value);
                },
              ),
              const SizedBox(height: 16),
              const Text(
                'Mode',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              SegmentedButton<ThemeMode>(
                segments: const <ButtonSegment<ThemeMode>>[
                  ButtonSegment<ThemeMode>(
                    value: ThemeMode.dark,
                    icon: Icon(Icons.dark_mode),
                    label: Text('Dark'),
                  ),
                  ButtonSegment<ThemeMode>(
                    value: ThemeMode.light,
                    icon: Icon(Icons.light_mode),
                    label: Text('Light'),
                  ),
                ],
                selected: <ThemeMode>{
                  themeState.mode == ThemeMode.light
                      ? ThemeMode.light
                      : ThemeMode.dark,
                },
                onSelectionChanged: (selection) {
                  final value = selection.first;
                  controller.setThemeMode(value);
                },
              ),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 12),
              const Text(
                'Create New Theme',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Theme Name',
                  hintText: 'Ocean Mint',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _seedController,
                decoration: const InputDecoration(
                  labelText: 'Seed Color (Hex)',
                  hintText: '#39B7A8',
                ),
                onChanged: (_) {
                  setState(() {});
                },
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: parsedSeed ?? Colors.transparent,
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(color: Colors.grey.shade500),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    parsedSeed == null
                        ? 'Enter a valid hex color (example: #39B7A8)'
                        : 'This seed will generate both dark and light palettes.',
                  ),
                ],
              ),
              if (_errorText != null) ...[
                const SizedBox(height: 8),
                Text(
                  _errorText!,
                  style: const TextStyle(color: Colors.redAccent),
                ),
              ],
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => _createTheme(controller),
                icon: const Icon(Icons.save),
                label: const Text('Save Theme'),
              ),
              if (themeState.customThemes.isNotEmpty) ...[
                const SizedBox(height: 20),
                const Text(
                  'Saved Custom Themes',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ...themeState.customThemes.map(
                  (theme) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(theme.name),
                    subtitle: const Text('Includes light and dark palettes'),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      tooltip: 'Delete theme',
                      onPressed: () => controller.deleteCustomTheme(theme.id),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }

  Future<void> _createTheme(ThemeController controller) async {
    final name = _nameController.text.trim();
    final color = _parseSeedColor(_seedController.text);
    if (name.isEmpty) {
      setState(() {
        _errorText = 'Theme name is required.';
      });
      return;
    }
    if (color == null) {
      setState(() {
        _errorText = 'Seed color must be a valid 6-digit hex value.';
      });
      return;
    }

    await controller.createTheme(name: name, seedColor: color);
    if (!mounted) return;
    setState(() {
      _nameController.clear();
      _errorText = null;
    });
  }

  Color? _parseSeedColor(String raw) {
    final trimmed = raw.trim().replaceFirst('#', '');
    if (!RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(trimmed)) {
      return null;
    }
    return Color(int.parse('FF$trimmed', radix: 16));
  }
}
