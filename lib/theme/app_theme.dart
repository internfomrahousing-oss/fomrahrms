import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/color_theme_notifier.dart';

class AppTheme {
  // ── Active color theme (set by ColorThemeNotifier, Management-controlled) ──
  static AppColorTheme _active = AppColorTheme.midnightBlue;
  static ColorThemeTokens get _t => kColorThemes[_active]!;

  static void setActiveColorTheme(AppColorTheme theme) => _active = theme;
  static AppColorTheme get activeColorTheme => _active;

  // ── Design tokens ────────────────────────────────────────────────────────
  static Color get primaryBlue => _t.primary;
  static Color get primaryBlueDark => _t.primaryDark;
  static Color get accentBlue => _t.accent;
  static Color get lightBlue => _t.lightTint;
  static Color get sidebarBg => _t.sidebarBg;
  static Color get sidebarSelectedBg => _t.sidebarSelectedBg;
  // Muted icon/text color for unselected nav items — a pale tint of the
  // active theme's accent, so menus read as themed rather than always blue.
  static Color get sidebarMuted => Color.lerp(_t.accent, Colors.white, 0.65)!;
  static const Color white = Colors.white;

  // Shared dark->primary gradient for the app's top surfaces (top bars,
  // mobile app bars, the dashboard welcome banner) so they read as one
  // continuous surface instead of stacked flat-color bands.
  static LinearGradient get headerGradient {
    final dark = primaryBlueDark;
    final mid = Color.lerp(dark, primaryBlue, 0.55)!;
    return LinearGradient(
      colors: [dark, mid, primaryBlue],
      stops: const [0.0, 0.55, 1.0],
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
    );
  }

  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color purple = Color(0xFF8B5CF6);
  static const Color pink = Color(0xFFEC4899);
  static const Color pageBackground = Color(0xFFF8FAFC);
  static const Color textPrimary = Color(0xFF111827);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color borderSubtle = Color(0xFFEEF2F7);

  static const double cardRadius = 18;
  static const double controlRadius = 14;
  static const double pillRadius = 999;

  // ── 8px spacing system ──────────────────────────────────────────────────
  static const double space1 = 4;
  static const double space2 = 8;
  static const double space3 = 16;
  static const double space4 = 24;
  static const double space5 = 32;
  static const double space6 = 40;

  static const Duration fastAnim = Duration(milliseconds: 150);

  // ── Card shadow (subtle by default, deeper on hover) ─────────────────────
  static const List<BoxShadow> cardShadow = [
    BoxShadow(color: Color.fromRGBO(16, 24, 40, 0.04), blurRadius: 2, offset: Offset(0, 1)),
  ];
  static const List<BoxShadow> cardShadowHover = [
    BoxShadow(color: Color.fromRGBO(16, 24, 40, 0.08), blurRadius: 30, offset: Offset(0, 10)),
  ];

  // ── Typography scale ─────────────────────────────────────────────────────
  static TextStyle get pageHeading => GoogleFonts.inter(fontSize: 36, fontWeight: FontWeight.w700, color: textPrimary);
  static TextStyle get sectionHeading => GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700, color: textPrimary);
  static TextStyle get cardHeading => GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: textPrimary);
  static TextStyle get bodyText => GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: textPrimary);
  static TextStyle get captionText => GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: textSecondary);
  static TextStyle get kpiNumber => GoogleFonts.inter(fontSize: 48, fontWeight: FontWeight.w700, color: textPrimary);

  static TextTheme _interTextTheme(Color body, Color heading) {
    return GoogleFonts.interTextTheme().copyWith(
      headlineLarge: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.bold, color: heading),
      headlineMedium: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w600, color: heading),
      headlineSmall: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600, color: heading),
      titleLarge: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: body),
      bodyLarge: GoogleFonts.inter(fontSize: 14, color: body),
      bodyMedium: GoogleFonts.inter(fontSize: 13, color: body),
    );
  }

  static ThemeData get lightTheme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primaryBlue,
      brightness: Brightness.light,
      primary: primaryBlue,
      onPrimary: white,
      secondary: accentBlue,
      error: error,
      surface: white,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: pageBackground,
      textTheme: _interTextTheme(textPrimary, textPrimary),
      appBarTheme: AppBarTheme(
        backgroundColor: primaryBlue,
        foregroundColor: white,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.inter(
          color: white,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
      ),
      cardTheme: CardThemeData(
        color: white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.black.withValues(alpha: 0.10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardRadius),
          side: const BorderSide(color: borderSubtle),
        ),
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryBlue,
          foregroundColor: white,
          elevation: 0,
          shadowColor: primaryBlue.withValues(alpha: 0.35),
          animationDuration: fastAnim,
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(controlRadius)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ).copyWith(
          overlayColor: WidgetStateProperty.all(white.withValues(alpha: 0.08)),
          elevation: WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.hovered) ? 4 : 0),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryBlue,
          side: const BorderSide(color: borderSubtle),
          animationDuration: fastAnim,
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(controlRadius)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryBlue,
          animationDuration: fastAnim,
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(controlRadius)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: pageBackground,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(controlRadius),
          borderSide: const BorderSide(color: borderSubtle),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(controlRadius),
          borderSide: const BorderSide(color: borderSubtle),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(controlRadius),
          borderSide: BorderSide(color: primaryBlue, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(controlRadius),
          borderSide: const BorderSide(color: error),
        ),
        labelStyle: GoogleFonts.inter(color: textSecondary),
        hintStyle: GoogleFonts.inter(color: textSecondary),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: pageBackground,
        selectedColor: lightBlue,
        labelStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: textPrimary),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: borderSubtle),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        menuStyle: MenuStyle(
          backgroundColor: const WidgetStatePropertyAll(white),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          elevation: const WidgetStatePropertyAll(4),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(controlRadius)),
          ),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: white,
        surfaceTintColor: Colors.transparent,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(controlRadius)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: textPrimary,
        contentTextStyle: GoogleFonts.inter(color: white, fontSize: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(controlRadius)),
        behavior: SnackBarBehavior.floating,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: textPrimary.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: GoogleFonts.inter(color: white, fontSize: 12),
      ),
      dividerTheme: const DividerThemeData(color: borderSubtle, thickness: 1),
      iconTheme: const IconThemeData(color: textSecondary),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected) ? primaryBlue : Colors.grey.shade50),
        trackColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected) ? primaryBlue.withValues(alpha: 0.5) : borderSubtle),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected) ? primaryBlue : Colors.transparent),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected) ? primaryBlue : textSecondary),
      ),
    );
  }
}
