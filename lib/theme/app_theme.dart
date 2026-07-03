import 'package:flutter/material.dart';

class AppTheme {
  static const Color primaryBlue = Color(0xFF0D47A1);
  static const Color primaryBlueDark = Color(0xFF002171);
  static const Color accentBlue = Color(0xFF1565C0);
  static const Color lightBlue = Color(0xFFE3F2FD);
  static const Color sidebarBg = Color(0xFF0A3471);
  static const Color sidebarSelectedBg = Color(0xFF1565C0);
  static const Color white = Colors.white;

  static ThemeData get lightTheme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primaryBlue,
      brightness: Brightness.light,
      primary: primaryBlue,
      onPrimary: white,
      secondary: accentBlue,
      surface: white,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: const Color(0xFFEEF1F6),
      appBarTheme: const AppBarTheme(
        backgroundColor: primaryBlue,
        foregroundColor: white,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: white,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
      ),
      cardTheme: CardThemeData(
        color: white,
        elevation: 3,
        shadowColor: Colors.black.withValues(alpha: 0.12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryBlue,
          foregroundColor: white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: primaryBlueDark),
        headlineMedium: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: primaryBlueDark),
        headlineSmall: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: primaryBlueDark),
        titleLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF1A237E)),
        bodyLarge: TextStyle(fontSize: 14, color: Color(0xFF37474F)),
        bodyMedium: TextStyle(fontSize: 13, color: Color(0xFF546E7A)),
      ),
      dividerTheme: const DividerThemeData(color: Color(0xFFE0E0E0), thickness: 1),
    );
  }

  static ThemeData get darkTheme {
    const darkSurface  = Color(0xFF1E1E2A);
    const darkBg       = Color(0xFF12121C);
    const darkCard     = Color(0xFF252535);
    const darkPrimary  = Color(0xFF90CAF9);
    const onDark       = Color(0xFFE0E0F0);
    const subDark      = Color(0xFF9E9EB8);

    final colorScheme = ColorScheme(
      brightness:     Brightness.dark,
      primary:        darkPrimary,
      onPrimary:      const Color(0xFF003A75),
      secondary:      const Color(0xFF80BBFF),
      onSecondary:    const Color(0xFF003A75),
      error:          Colors.red.shade300,
      onError:        Colors.black,
      surface:        darkSurface,
      onSurface:      onDark,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: darkBg,
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF0A0A18),
        foregroundColor: onDark,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: onDark,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
      ),
      cardTheme: CardThemeData(
        color: darkCard,
        elevation: 2,
        shadowColor: Colors.black38,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: darkPrimary,
          foregroundColor: const Color(0xFF003A75),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF1A1A2E),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF3A3A5C)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF3A3A5C)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: darkPrimary, width: 2),
        ),
        labelStyle: const TextStyle(color: subDark),
        hintStyle: const TextStyle(color: Color(0xFF6060A0)),
      ),
      textTheme: const TextTheme(
        headlineLarge:  TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: darkPrimary),
        headlineMedium: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: darkPrimary),
        headlineSmall:  TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: darkPrimary),
        titleLarge:     TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: onDark),
        bodyLarge:      TextStyle(fontSize: 14, color: onDark),
        bodyMedium:     TextStyle(fontSize: 13, color: subDark),
      ),
      dividerTheme: const DividerThemeData(color: Color(0xFF2E2E4A), thickness: 1),
      dialogTheme: const DialogThemeData(backgroundColor: darkCard),
      drawerTheme: const DrawerThemeData(backgroundColor: darkCard),
      bottomSheetTheme: const BottomSheetThemeData(backgroundColor: darkCard),
      popupMenuTheme: const PopupMenuThemeData(color: darkCard),
      listTileTheme: const ListTileThemeData(textColor: onDark, iconColor: subDark),
    );
  }
}
