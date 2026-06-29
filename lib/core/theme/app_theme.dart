import 'package:flutter/material.dart';

/// Brand theme. [accent] comes from the active flavor.
class AppTheme {
  static ThemeData light(Color accent) {
    final scheme = ColorScheme.fromSeed(
      seedColor: accent,
      primary: accent,
      brightness: Brightness.light,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: const Color(0xFFECF2F6), // Pwa.bg
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1A1A1A),
        elevation: 0,
        centerTitle: false,
        titleTextStyle: const TextStyle(
          color: Color(0xFF1A1A1A),
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.grey.shade200),
        ),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: accent, width: 1.6),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  /// Status → color, mirroring the web badges.
  static Color statusColor(String status) {
    final s = status.toUpperCase();
    if (s.contains('COMPLETE') || s.contains('CLOSED') || s.contains('LOADED') || s.contains('APPROVED')) {
      return const Color(0xFF1B9C4A);
    }
    if (s.contains('REJECT') || s.contains('CANCEL') || s.contains('SHORT')) {
      return const Color(0xFFD64545);
    }
    if (s.contains('RELEASE') || s.contains('PROGRESS') || s.contains('PROCESS') || s.contains('TRANSIT')) {
      return const Color(0xFFE08A00);
    }
    if (s.contains('INVOICED') || s.contains('RACKING')) {
      return const Color(0xFF2F6FED);
    }
    return const Color(0xFF5B6470);
  }
}
