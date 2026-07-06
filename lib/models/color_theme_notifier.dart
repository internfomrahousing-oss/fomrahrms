import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';

enum AppColorTheme {
  midnightBlue,
  forestAndSand,
  coastalBlue,
  executiveInk,
  walnutAndCream,
  pantoneScarlet,
  stoneAndSlate,
}

class ColorThemeTokens {
  final String label;
  final Color primary;
  final Color primaryDark;
  final Color accent;
  final Color sidebarBg;
  final Color sidebarSelectedBg;
  final Color lightTint;

  const ColorThemeTokens({
    required this.label,
    required this.primary,
    required this.primaryDark,
    required this.accent,
    required this.sidebarBg,
    required this.sidebarSelectedBg,
    required this.lightTint,
  });
}

const Map<AppColorTheme, ColorThemeTokens> kColorThemes = {
  AppColorTheme.midnightBlue: ColorThemeTokens(
    label: 'Midnight Blue',
    primary: Color(0xFF2563EB),
    primaryDark: Color(0xFF0B1220),
    accent: Color(0xFF3B82F6),
    sidebarBg: Color(0xFF0B1220),
    sidebarSelectedBg: Color(0xFF1D4ED8),
    lightTint: Color(0xFFEFF6FF),
  ),
  AppColorTheme.forestAndSand: ColorThemeTokens(
    label: 'Forest & Sand',
    primary: Color(0xFF1B4332),
    primaryDark: Color(0xFF10281F),
    accent: Color(0xFF2D6A4F),
    sidebarBg: Color(0xFF10281F),
    sidebarSelectedBg: Color(0xFF2D6A4F),
    lightTint: Color(0xFFF0FDF4),
  ),
  AppColorTheme.coastalBlue: ColorThemeTokens(
    label: 'Coastal Blue',
    primary: Color(0xFF0369A1),
    primaryDark: Color(0xFF0C2A38),
    accent: Color(0xFF0891B2),
    sidebarBg: Color(0xFF0C2A38),
    sidebarSelectedBg: Color(0xFF0891B2),
    lightTint: Color(0xFFF0F9FF),
  ),
  AppColorTheme.executiveInk: ColorThemeTokens(
    label: 'Executive Ink',
    primary: Color(0xFF111827),
    primaryDark: Color(0xFF0A0A0F),
    accent: Color(0xFFB45309),
    sidebarBg: Color(0xFF0A0A0F),
    sidebarSelectedBg: Color(0xFFB45309),
    lightTint: Color(0xFFFFFBEB),
  ),
  AppColorTheme.walnutAndCream: ColorThemeTokens(
    label: 'Walnut & Cream',
    primary: Color(0xFF6F4518),
    primaryDark: Color(0xFF3A2410),
    accent: Color(0xFFB08968),
    sidebarBg: Color(0xFF3A2410),
    sidebarSelectedBg: Color(0xFFB08968),
    lightTint: Color(0xFFFBF8F3),
  ),
  AppColorTheme.pantoneScarlet: ColorThemeTokens(
    label: 'Pantone Scarlet & White',
    primary: Color(0xFFDA291C),
    primaryDark: Color(0xFF1A1A1A),
    accent: Color(0xFFB71C1C),
    sidebarBg: Color(0xFF1A1A1A),
    sidebarSelectedBg: Color(0xFFB71C1C),
    lightTint: Color(0xFFFEF2F2),
  ),
  AppColorTheme.stoneAndSlate: ColorThemeTokens(
    label: 'Stone & Slate',
    primary: Color(0xFF334155),
    primaryDark: Color(0xFF1E293B),
    accent: Color(0xFF64748B),
    sidebarBg: Color(0xFF1E293B),
    sidebarSelectedBg: Color(0xFF475569),
    lightTint: Color(0xFFF1F5F9),
  ),
};

String colorThemeKey(AppColorTheme t) => t.name;

AppColorTheme colorThemeFromKey(String? key) => AppColorTheme.values.firstWhere(
      (t) => t.name == key,
      orElse: () => AppColorTheme.midnightBlue,
    );

class ColorThemeNotifier extends ValueNotifier<AppColorTheme> {
  ColorThemeNotifier() : super(AppColorTheme.midnightBlue) {
    AppTheme.setActiveColorTheme(value);
  }

  // Keep AppTheme's active tokens in sync *before* any listener rebuilds run,
  // so every widget reading AppTheme.primaryBlue etc. sees the new theme on
  // the same frame, regardless of which listener happens to fire first.
  @override
  set value(AppColorTheme newValue) {
    AppTheme.setActiveColorTheme(newValue);
    super.value = newValue;
  }

  /// Call once at app startup — reads the theme Management last chose, shared
  /// across every user, so it doesn't re-persist what it just loaded.
  Future<void> loadInitial() async {
    final key = await SupabaseService.fetchColorTheme();
    value = colorThemeFromKey(key);
  }

  /// Called when Management actively picks a new theme — persists globally so
  /// every other role's dashboard picks it up on their next load.
  Future<void> setTheme(AppColorTheme theme) async {
    value = theme;
    await SupabaseService.setColorTheme(colorThemeKey(theme));
  }
}

final colorThemeNotifier = ColorThemeNotifier();
