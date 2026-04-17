import 'package:flutter/material.dart';

/// Semantic UI palette with matched dark and light variants.
class AppPalette {
  final Color background;
  final Color panel;
  final Color panelElevated;
  final Color panelOverlay;
  final Color border;

  final Color accent;
  final Color accentBright;
  final Color accentSoft;

  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color textDisabled;

  final Color success;
  final Color warning;
  final Color error;

  final Color loopA;
  final Color loopB;

  final List<Color> annotationSwatches;

  const AppPalette({
    required this.background,
    required this.panel,
    required this.panelElevated,
    required this.panelOverlay,
    required this.border,
    required this.accent,
    required this.accentBright,
    required this.accentSoft,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.textDisabled,
    required this.success,
    required this.warning,
    required this.error,
    required this.loopA,
    required this.loopB,
    required this.annotationSwatches,
  });

  static const AppPalette dark = AppPalette(
    background: Color(0xFF15181D),
    panel: Color(0xFF1D2128),
    panelElevated: Color(0xFF252B34),
    panelOverlay: Color(0x99101317),
    border: Color(0xFF313947),
    accent: Color(0xFF39B7A8),
    accentBright: Color(0xFF58D3C4),
    accentSoft: Color(0x5539B7A8),
    textPrimary: Color(0xFFF0F3F7),
    textSecondary: Color(0xFFB4BDC9),
    textMuted: Color(0xFF8791A0),
    textDisabled: Color(0xFF5B6675),
    success: Color(0xFF5AC98C),
    warning: Color(0xFFF0A95A),
    error: Color(0xFFE16F72),
    loopA: Color(0xFF67C88C),
    loopB: Color(0xFFF2B061),
    annotationSwatches: <Color>[
      Color(0xFF58D3C4), // Cyan (default)
      Color(0xFF11B9D6), // Blue
      Color(0xFF1FA1D6), // Dark blue
      Color(0xFF22C55E), // Green
      Color(0xFFEAB308), // Yellow
      Color(0xFFF97316), // Orange
      Color(0xFFEF4444), // Red
      Color(0xFFEC4899), // Pink
      Color(0xFF8B5CF6), // Purple
      Color(0xFF000000), // Black
      Color(0xFFF8FAFC), // Near-white for light surfaces
    ],
  );

  static const AppPalette light = AppPalette(
    background: Color(0xFFF3F5F8),
    panel: Color(0xFFFFFFFF),
    panelElevated: Color(0xFFE9EEF4),
    panelOverlay: Color(0xCCDFE6EF),
    border: Color(0xFFB9C5D4),
    accent: Color(0xFF0E8D80),
    accentBright: Color(0xFF0BA597),
    accentSoft: Color(0x33108D80),
    textPrimary: Color(0xFF17202B),
    textSecondary: Color(0xFF334155),
    textMuted: Color(0xFF5A6778),
    textDisabled: Color(0xFF8B97A8),
    success: Color(0xFF2E9E5E),
    warning: Color(0xFFC4761F),
    error: Color(0xFFC0444A),
    loopA: Color(0xFF2E9E5E),
    loopB: Color(0xFFC77A22),
    annotationSwatches: <Color>[
      Color(0xFF58D3C4), // Cyan (default)
      Color(0xFF11B9D6), // Blue
      Color(0xFF1FA1D6), // Dark blue
      Color(0xFF22C55E), // Green
      Color(0xFFEAB308), // Yellow
      Color(0xFFF97316), // Orange
      Color(0xFFEF4444), // Red
      Color(0xFFEC4899), // Pink
      Color(0xFF8B5CF6), // Purple
      Color(0xFF000000), // Black
      Color(0xFFFFFFFF), // White
    ],
  );

  static AppPalette forBrightness(Brightness brightness) {
    return brightness == Brightness.dark ? dark : light;
  }

  static AppPalette of(BuildContext context) {
    final themedPalette = Theme.of(
      context,
    ).extension<AppPaletteThemeExtension>();
    if (themedPalette != null) {
      return themedPalette.palette;
    }
    return forBrightness(Theme.of(context).brightness);
  }

  static ThemeData themeData(Brightness brightness, {AppPalette? palette}) {
    final p = palette ?? forBrightness(brightness);
    final isDark = brightness == Brightness.dark;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: p.background,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: p.accent,
        onPrimary: p.textPrimary,
        secondary: p.loopB,
        onSecondary: p.textPrimary,
        error: p.error,
        onError: p.textPrimary,
        surface: p.panel,
        onSurface: p.textPrimary,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: p.panel,
        foregroundColor: p.textPrimary,
      ),
      dividerColor: p.border,
      iconTheme: IconThemeData(color: p.textSecondary),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: p.panelElevated,
        contentTextStyle: TextStyle(color: p.textPrimary),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: p.accent,
        inactiveTrackColor: p.border,
        thumbColor: p.accentBright,
        overlayColor: p.accentSoft,
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: p.accentBright),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: p.textSecondary,
          side: BorderSide(color: p.border),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: p.accent,
          foregroundColor: isDark ? p.textPrimary : Colors.white,
        ),
      ),
      extensions: <ThemeExtension<dynamic>>[
        AppPaletteThemeExtension(palette: p),
      ],
    );
  }

  static AppPalette fromSeed({
    required Color seedColor,
    required Brightness brightness,
  }) {
    final scheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: brightness,
    );
    final isDark = brightness == Brightness.dark;

    return AppPalette(
      background: isDark ? const Color(0xFF181B20) : const Color(0xFFF4F6FA),
      panel: isDark ? const Color(0xFF1F232B) : const Color(0xFFFFFFFF),
      panelElevated: isDark ? const Color(0xFF292F38) : const Color(0xFFE9EEF5),
      panelOverlay: isDark ? const Color(0x9910151D) : const Color(0xCCDFE6F0),
      border: scheme.outlineVariant,
      accent: scheme.primary,
      accentBright: _shiftLightness(scheme.primary, isDark ? 0.18 : -0.08),
      accentSoft: scheme.primary.withValues(alpha: isDark ? 0.35 : 0.2),
      textPrimary: scheme.onSurface,
      textSecondary: scheme.onSurfaceVariant,
      textMuted: scheme.outline,
      textDisabled: scheme.onSurface.withValues(alpha: 0.45),
      success: isDark ? const Color(0xFF65D491) : const Color(0xFF2B9658),
      warning: isDark ? const Color(0xFFF4B667) : const Color(0xFFC1711E),
      error: scheme.error,
      loopA: _mixColors(
        scheme.primary,
        isDark ? const Color(0xFF6ADB9A) : const Color(0xFF2E9E5E),
        0.45,
      ),
      loopB: _mixColors(
        scheme.primary,
        isDark ? const Color(0xFFF2B061) : const Color(0xFFC77A22),
        0.45,
      ),
      annotationSwatches: _buildAnnotationSwatches(seedColor),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'background': _colorToInt(background),
      'panel': _colorToInt(panel),
      'panelElevated': _colorToInt(panelElevated),
      'panelOverlay': _colorToInt(panelOverlay),
      'border': _colorToInt(border),
      'accent': _colorToInt(accent),
      'accentBright': _colorToInt(accentBright),
      'accentSoft': _colorToInt(accentSoft),
      'textPrimary': _colorToInt(textPrimary),
      'textSecondary': _colorToInt(textSecondary),
      'textMuted': _colorToInt(textMuted),
      'textDisabled': _colorToInt(textDisabled),
      'success': _colorToInt(success),
      'warning': _colorToInt(warning),
      'error': _colorToInt(error),
      'loopA': _colorToInt(loopA),
      'loopB': _colorToInt(loopB),
      'annotationSwatches': annotationSwatches.map(_colorToInt).toList(),
    };
  }

  factory AppPalette.fromJson(Map<String, dynamic> json) {
    final swatchesRaw = json['annotationSwatches'];
    return AppPalette(
      background: Color((json['background'] as num).toInt()),
      panel: Color((json['panel'] as num).toInt()),
      panelElevated: Color((json['panelElevated'] as num).toInt()),
      panelOverlay: Color((json['panelOverlay'] as num).toInt()),
      border: Color((json['border'] as num).toInt()),
      accent: Color((json['accent'] as num).toInt()),
      accentBright: Color((json['accentBright'] as num).toInt()),
      accentSoft: Color((json['accentSoft'] as num).toInt()),
      textPrimary: Color((json['textPrimary'] as num).toInt()),
      textSecondary: Color((json['textSecondary'] as num).toInt()),
      textMuted: Color((json['textMuted'] as num).toInt()),
      textDisabled: Color((json['textDisabled'] as num).toInt()),
      success: Color((json['success'] as num).toInt()),
      warning: Color((json['warning'] as num).toInt()),
      error: Color((json['error'] as num).toInt()),
      loopA: Color((json['loopA'] as num).toInt()),
      loopB: Color((json['loopB'] as num).toInt()),
      annotationSwatches: swatchesRaw is List
          ? swatchesRaw.map((value) => Color((value as num).toInt())).toList()
          : <Color>[
              Colors.red,
              Colors.green,
              Colors.blue,
              const Color(0xFFF8FAFC),
              Colors.black,
              Colors.orange,
              Colors.purple,
              Colors.yellow,
            ],
    );
  }

  static int _colorToInt(Color color) {
    int toChannel(double value) =>
        (value * 255.0).round().clamp(0, 255).toInt();

    final a = toChannel(color.a);
    final r = toChannel(color.r);
    final g = toChannel(color.g);
    final b = toChannel(color.b);

    return (a << 24) | (r << 16) | (g << 8) | b;
  }

  static Color _mixColors(Color a, Color b, double amount) {
    return Color.lerp(a, b, amount) ?? a;
  }

  static Color _shiftLightness(Color color, double delta) {
    final hsl = HSLColor.fromColor(color);
    final lightness = (hsl.lightness + delta).clamp(0.0, 1.0);
    return hsl.withLightness(lightness).toColor();
  }

  static List<Color> _buildAnnotationSwatches(Color seedColor) {
    final hsl = HSLColor.fromColor(seedColor);
    Color tone(double offset, double saturation, double lightness) {
      final hue = (hsl.hue + offset) % 360;
      return HSLColor.fromAHSL(
        1.0,
        hue,
        saturation.clamp(0.0, 1.0),
        lightness.clamp(0.0, 1.0),
      ).toColor();
    }

    return <Color>[
      tone(0, 0.72, 0.58),
      tone(120, 0.65, 0.5),
      tone(210, 0.72, 0.56),
      tone(45, 0.8, 0.58),
      tone(20, 0.78, 0.58),
      tone(280, 0.6, 0.62),
      const Color(0xFFF8FAFC),
      const Color(0xFF13161B),
    ];
  }
}

class AppPaletteThemeExtension
    extends ThemeExtension<AppPaletteThemeExtension> {
  final AppPalette palette;

  const AppPaletteThemeExtension({required this.palette});

  @override
  AppPaletteThemeExtension copyWith({AppPalette? palette}) {
    return AppPaletteThemeExtension(palette: palette ?? this.palette);
  }

  @override
  AppPaletteThemeExtension lerp(
    covariant ThemeExtension<AppPaletteThemeExtension>? other,
    double t,
  ) {
    if (other is! AppPaletteThemeExtension) {
      return this;
    }
    return t < 0.5 ? this : other;
  }
}
