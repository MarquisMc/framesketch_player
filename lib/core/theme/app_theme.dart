import 'package:flutter/material.dart';
import 'app_palette.dart';

/// A full app theme containing both light and dark palettes.
class AppThemeDefinition {
  final String id;
  final String name;
  final AppPalette lightPalette;
  final AppPalette darkPalette;
  final bool builtIn;

  const AppThemeDefinition({
    required this.id,
    required this.name,
    required this.lightPalette,
    required this.darkPalette,
    this.builtIn = false,
  });

  factory AppThemeDefinition.fromSeed({
    required String id,
    required String name,
    required Color seedColor,
    bool builtIn = false,
  }) {
    return AppThemeDefinition(
      id: id,
      name: name,
      builtIn: builtIn,
      lightPalette: AppPalette.fromSeed(
        seedColor: seedColor,
        brightness: Brightness.light,
      ),
      darkPalette: AppPalette.fromSeed(
        seedColor: seedColor,
        brightness: Brightness.dark,
      ),
    );
  }

  AppPalette paletteFor(Brightness brightness) {
    return brightness == Brightness.dark ? darkPalette : lightPalette;
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'builtIn': builtIn,
      'lightPalette': lightPalette.toJson(),
      'darkPalette': darkPalette.toJson(),
    };
  }

  factory AppThemeDefinition.fromJson(Map<String, dynamic> json) {
    return AppThemeDefinition(
      id: json['id'] as String,
      name: json['name'] as String,
      builtIn: (json['builtIn'] as bool?) ?? false,
      lightPalette: AppPalette.fromJson(
        (json['lightPalette'] as Map).cast<String, dynamic>(),
      ),
      darkPalette: AppPalette.fromJson(
        (json['darkPalette'] as Map).cast<String, dynamic>(),
      ),
    );
  }
}

class AppThemeCatalog {
  static const String currentThemeId = 'current_theme';
  static const String legacyThemeId = 'legacy_theme';

  static const AppThemeDefinition currentTheme = AppThemeDefinition(
    id: currentThemeId,
    name: 'Current Theme',
    builtIn: true,
    lightPalette: AppPalette.light,
    darkPalette: AppPalette.dark,
  );

  // Old app look from before AppPalette migration.
  static const AppThemeDefinition legacyTheme = AppThemeDefinition(
    id: legacyThemeId,
    name: 'Old Theme (Legacy)',
    builtIn: true,
    lightPalette: AppPalette(
      background: Color(0xFFF5F5F5),
      panel: Color(0xFFFFFFFF),
      panelElevated: Color(0xFFE8E8E8),
      panelOverlay: Color(0xCCDCDCDC),
      border: Color(0xFFC5C5C5),
      accent: Color(0xFFD32F2F),
      accentBright: Color(0xFFB71C1C),
      accentSoft: Color(0x44D32F2F),
      textPrimary: Color(0xFF151515),
      textSecondary: Color(0xFF3A3A3A),
      textMuted: Color(0xFF656565),
      textDisabled: Color(0xFF8B8B8B),
      success: Color(0xFF2E9E5E),
      warning: Color(0xFFCB7D22),
      error: Color(0xFFC62828),
      loopA: Color(0xFF2E9E5E),
      loopB: Color(0xFFCB7D22),
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
    ),
    darkPalette: AppPalette(
      background: Color(0xFF212121),
      panel: Color(0xFF2A2A2A),
      panelElevated: Color(0xFF343434),
      panelOverlay: Color(0xCC1A1A1A),
      border: Color(0xFF4B4B4B),
      accent: Color(0xFFE53935),
      accentBright: Color(0xFFFF6E67),
      accentSoft: Color(0x55E53935),
      textPrimary: Color(0xFFF5F5F5),
      textSecondary: Color(0xFFD1D1D1),
      textMuted: Color(0xFFA5A5A5),
      textDisabled: Color(0xFF7D7D7D),
      success: Color(0xFF55C27D),
      warning: Color(0xFFF0A95A),
      error: Color(0xFFFF6E67),
      loopA: Color(0xFF55C27D),
      loopB: Color(0xFFF0A95A),
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
    ),
  );

  static const List<AppThemeDefinition> builtInThemes = <AppThemeDefinition>[
    currentTheme,
    legacyTheme,
  ];
}
