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
      Color(0xFFF06A6E),
      Color(0xFF59CC8B),
      Color(0xFF59A8F2),
      Color(0xFFF3C765),
      Color(0xFFF39A5E),
      Color(0xFFBE8CF2),
      Color(0xFFF6F8FA),
      Color(0xFF13161B),
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
      Color(0xFFD8474B),
      Color(0xFF2FA662),
      Color(0xFF2E7DCC),
      Color(0xFFD7A82E),
      Color(0xFFCE7431),
      Color(0xFF8C5BD1),
      Color(0xFFFDFDFD),
      Color(0xFF111318),
    ],
  );

  static AppPalette forBrightness(Brightness brightness) {
    return brightness == Brightness.dark ? dark : light;
  }

  static AppPalette of(BuildContext context) {
    return forBrightness(Theme.of(context).brightness);
  }

  static ThemeData themeData(Brightness brightness) {
    final p = forBrightness(brightness);
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
    );
  }
}
