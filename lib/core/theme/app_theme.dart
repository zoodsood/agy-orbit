import 'package:flutter/material.dart';

/// Antigravity Orbit Design System.
/// Built for high-density information display, syntax diffs, and terminal outputs.
class AppTheme {
  static const Color darkBackground = Color(0xFF0F1117);
  static const Color surface = Color(0xFF181B24);
  static const Color surfaceElevated = Color(0xFF222634);
  static const Color primaryBlue = Color(0xFF388BFD);
  static const Color accentCyan = Color(0xFF39D353);
  static const Color terminalBlack = Color(0xFF090D13);

  // Status Colors
  static const Color statusPlanning = Color(0xFFE3B341);
  static const Color statusExecuting = Color(0xFF58A6FF);
  static const Color statusReadingLogs = Color(0xFFBC8CFF);
  static const Color statusBrowserQa = Color(0xFFFF7B72);
  static const Color statusSuccess = Color(0xFF3FB950);
  static const Color statusFailed = Color(0xFFF85149);
  static const Color statusWarning = Color(0xFFD29922);
  static const Color statusError = Color(0xFFF85149);

  // Diff Colors
  static const Color diffAddedBg = Color(0x26238636);
  static const Color diffAddedText = Color(0xFF7EE787);
  static const Color diffRemovedBg = Color(0x2EDA3636);
  static const Color diffRemovedText = Color(0xFFFFA198);
  static const Color diffContextText = Color(0xFF8B949E);

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: darkBackground,
      colorScheme: const ColorScheme.dark(
        primary: primaryBlue,
        secondary: accentCyan,
        surface: surface,
        error: statusFailed,
        onSurface: Color(0xFFC9D1D9),
      ),
      cardTheme: CardTheme(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: Color(0xFF30363D), width: 1),
        ),
      ),
      dividerColor: const Color(0xFF30363D),
      appBarTheme: const AppBarTheme(
        backgroundColor: surface,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Color(0xFFF0F6FC),
          letterSpacing: 0.5,
        ),
      ),
      textTheme: const TextTheme(
        bodyMedium: TextStyle(color: Color(0xFFC9D1D9), fontSize: 13),
        bodySmall: TextStyle(color: Color(0xFF8B949E), fontSize: 12),
        titleMedium: TextStyle(
          color: Color(0xFFF0F6FC),
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),
    );
  }
}
