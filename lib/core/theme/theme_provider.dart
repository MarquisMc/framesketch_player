import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_palette.dart';
import 'app_theme.dart';

class ThemeState {
  final ThemeMode mode;
  final List<AppThemeDefinition> themes;
  final String selectedThemeId;
  final bool isLoaded;

  const ThemeState({
    required this.mode,
    required this.themes,
    required this.selectedThemeId,
    required this.isLoaded,
  });

  factory ThemeState.initial() {
    return const ThemeState(
      mode: ThemeMode.dark,
      themes: AppThemeCatalog.builtInThemes,
      selectedThemeId: AppThemeCatalog.currentThemeId,
      isLoaded: false,
    );
  }

  ThemeState copyWith({
    ThemeMode? mode,
    List<AppThemeDefinition>? themes,
    String? selectedThemeId,
    bool? isLoaded,
  }) {
    return ThemeState(
      mode: mode ?? this.mode,
      themes: themes ?? this.themes,
      selectedThemeId: selectedThemeId ?? this.selectedThemeId,
      isLoaded: isLoaded ?? this.isLoaded,
    );
  }

  AppThemeDefinition get selectedTheme {
    for (final theme in themes) {
      if (theme.id == selectedThemeId) {
        return theme;
      }
    }
    return themes.first;
  }

  List<AppThemeDefinition> get customThemes {
    return themes.where((theme) => !theme.builtIn).toList(growable: false);
  }

  AppPalette get activePalette {
    return selectedTheme.paletteFor(
      mode == ThemeMode.light ? Brightness.light : Brightness.dark,
    );
  }
}

class ThemeController extends StateNotifier<ThemeState> {
  static const String _themeModeKey = 'theme_mode';
  static const String _selectedThemeIdKey = 'selected_theme_id';
  static const String _customThemesKey = 'custom_themes';

  ThemeController() : super(ThemeState.initial()) {
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final customThemes = _decodeThemes(prefs.getString(_customThemesKey));
      final themes = <AppThemeDefinition>[
        ...AppThemeCatalog.builtInThemes,
        ...customThemes,
      ];
      final selectedThemeId =
          prefs.getString(_selectedThemeIdKey) ??
          AppThemeCatalog.currentThemeId;
      final mode = _decodeThemeMode(prefs.getString(_themeModeKey));
      final hasSelectedTheme = themes.any(
        (theme) => theme.id == selectedThemeId,
      );

      state = state.copyWith(
        mode: mode,
        themes: themes,
        selectedThemeId: hasSelectedTheme
            ? selectedThemeId
            : AppThemeCatalog.currentThemeId,
        isLoaded: true,
      );
    } catch (_) {
      state = state.copyWith(isLoaded: true);
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (mode == ThemeMode.system) {
      mode = ThemeMode.dark;
    }
    state = state.copyWith(mode: mode);
    await _saveThemeMode(mode);
  }

  Future<void> toggleThemeMode() async {
    final next = state.mode == ThemeMode.dark
        ? ThemeMode.light
        : ThemeMode.dark;
    await setThemeMode(next);
  }

  Future<void> selectTheme(String themeId) async {
    if (!state.themes.any((theme) => theme.id == themeId)) {
      return;
    }
    state = state.copyWith(selectedThemeId: themeId);
    await _saveSelectedThemeId(themeId);
  }

  Future<void> createTheme({
    required String name,
    required Color seedColor,
  }) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      return;
    }

    final customTheme = AppThemeDefinition.fromSeed(
      id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
      name: trimmedName,
      seedColor: seedColor,
    );

    final nextThemes = <AppThemeDefinition>[...state.themes, customTheme];
    state = state.copyWith(themes: nextThemes, selectedThemeId: customTheme.id);
    await _saveCustomThemes(state.customThemes);
    await _saveSelectedThemeId(customTheme.id);
  }

  Future<void> deleteCustomTheme(String themeId) async {
    AppThemeDefinition? toDelete;
    for (final theme in state.themes) {
      if (theme.id == themeId) {
        toDelete = theme;
        break;
      }
    }
    if (toDelete == null || toDelete.builtIn) {
      return;
    }

    final nextThemes = state.themes
        .where((theme) => theme.id != themeId)
        .toList();
    final nextSelectedThemeId = state.selectedThemeId == themeId
        ? AppThemeCatalog.currentThemeId
        : state.selectedThemeId;

    state = state.copyWith(
      themes: nextThemes,
      selectedThemeId: nextSelectedThemeId,
    );
    await _saveCustomThemes(state.customThemes);
    await _saveSelectedThemeId(nextSelectedThemeId);
  }

  ThemeMode _decodeThemeMode(String? raw) {
    return switch (raw) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.dark,
    };
  }

  Future<void> _saveThemeMode(ThemeMode mode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = mode == ThemeMode.light ? 'light' : 'dark';
      await prefs.setString(_themeModeKey, raw);
    } catch (_) {}
  }

  Future<void> _saveSelectedThemeId(String themeId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_selectedThemeIdKey, themeId);
    } catch (_) {}
  }

  Future<void> _saveCustomThemes(List<AppThemeDefinition> customThemes) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = jsonEncode(
        customThemes.map((theme) => theme.toJson()).toList(),
      );
      await prefs.setString(_customThemesKey, json);
    } catch (_) {}
  }

  List<AppThemeDefinition> _decodeThemes(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return const <AppThemeDefinition>[];
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return const <AppThemeDefinition>[];
      }
      return decoded
          .whereType<Map>()
          .map(
            (item) => AppThemeDefinition.fromJson(item.cast<String, dynamic>()),
          )
          .toList(growable: false);
    } catch (_) {
      return const <AppThemeDefinition>[];
    }
  }
}

final themeControllerProvider =
    StateNotifierProvider<ThemeController, ThemeState>((ref) {
      return ThemeController();
    });
