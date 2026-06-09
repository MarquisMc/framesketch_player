import 'dart:math' as math;

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
  HSVColor _seedColor = HSVColor.fromColor(const Color(0xFF39B7A8));
  String? _errorText;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeState = ref.watch(themeControllerProvider);
    final controller = ref.read(themeControllerProvider.notifier);
    final selectedSeed = _seedColor.toColor();

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
              _SeedColorPicker(
                color: _seedColor,
                onChanged: (color) {
                  setState(() {
                    _seedColor = color;
                    _errorText = null;
                  });
                },
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: selectedSeed,
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(color: Colors.grey.shade500),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'This seed will generate both dark and light palettes.',
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
    final color = _seedColor.toColor();
    if (name.isEmpty) {
      setState(() {
        _errorText = 'Theme name is required.';
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
}

class _SeedColorPicker extends StatelessWidget {
  final HSVColor color;
  final ValueChanged<HSVColor> onChanged;

  const _SeedColorPicker({required this.color, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _ColorWheel(color: color, onChanged: onChanged),
        const SizedBox(width: 18),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Seed Color',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),
              Slider(
                value: color.value,
                min: 0.2,
                max: 1.0,
                onChanged: (value) => onChanged(color.withValue(value)),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: const [
                  Color(0xFF39B7A8),
                  Color(0xFF4F8DFF),
                  Color(0xFFEF4444),
                  Color(0xFFF59E0B),
                  Color(0xFF8B5CF6),
                ].map((preset) {
                  final selected =
                      preset.toARGB32() == color.toColor().toARGB32();
                  return _PresetColorButton(
                    color: preset,
                    selected: selected,
                    onTap: () => onChanged(HSVColor.fromColor(preset)),
                  );
                }).toList(growable: false),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ColorWheel extends StatelessWidget {
  final HSVColor color;
  final ValueChanged<HSVColor> onChanged;

  const _ColorWheel({required this.color, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    const size = 172.0;
    final position = _positionForColor(color, size);
    return GestureDetector(
      onPanDown: (details) => _select(details.localPosition, size),
      onPanUpdate: (details) => _select(details.localPosition, size),
      child: CustomPaint(
        size: const Size.square(size),
        painter: _ColorWheelPainter(),
        foregroundPainter: _ColorWheelThumbPainter(position: position),
      ),
    );
  }

  void _select(Offset position, double size) {
    final center = Offset(size / 2, size / 2);
    final vector = position - center;
    final maxRadius = size / 2;
    final radius = vector.distance.clamp(0.0, maxRadius).toDouble();
    final angle = math.atan2(vector.dy, vector.dx);
    final hue = ((angle * 180 / math.pi) + 360) % 360;
    final saturation = (radius / maxRadius).clamp(0.0, 1.0).toDouble();
    onChanged(color.withHue(hue).withSaturation(saturation));
  }

  Offset _positionForColor(HSVColor color, double size) {
    final radius = (size / 2) * color.saturation;
    final angle = color.hue * math.pi / 180;
    return Offset(
      size / 2 + math.cos(angle) * radius,
      size / 2 + math.sin(angle) * radius,
    );
  }
}

class _ColorWheelPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;
    const rings = 36;
    const steps = 180;

    for (var ring = rings; ring >= 1; ring--) {
      final saturation = ring / rings;
      final ringRadius = radius * saturation;
      for (var step = 0; step < steps; step++) {
        final hue = step * 360.0 / steps;
        final start = step * 2 * math.pi / steps;
        final sweep = 2 * math.pi / steps + 0.01;
        final paint = Paint()
          ..color = HSVColor.fromAHSV(1, hue, saturation, 1).toColor()
          ..style = PaintingStyle.stroke
          ..strokeWidth = radius / rings + 1;
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: ringRadius),
          start,
          sweep,
          false,
          paint,
        );
      }
    }
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Colors.black.withValues(alpha: 0.18),
    );
  }

  @override
  bool shouldRepaint(covariant _ColorWheelPainter oldDelegate) => false;
}

class _ColorWheelThumbPainter extends CustomPainter {
  final Offset position;

  const _ColorWheelThumbPainter({required this.position});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawCircle(
      position,
      7,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = Colors.white,
    );
    canvas.drawCircle(
      position,
      7,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Colors.black.withValues(alpha: 0.42),
    );
  }

  @override
  bool shouldRepaint(covariant _ColorWheelThumbPainter oldDelegate) {
    return oldDelegate.position != position;
  }
}

class _PresetColorButton extends StatelessWidget {
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _PresetColorButton({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(99),
      child: Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? Theme.of(context).colorScheme.primary : Colors.grey,
            width: selected ? 2 : 1,
          ),
        ),
      ),
    );
  }
}
