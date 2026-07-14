import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Brand theme. [accent] comes from the active flavor.
class AppTheme {
  static ThemeData light(Color accent) {
    final scheme = ColorScheme.fromSeed(
      seedColor: accent,
      primary: accent,
      // Keep secondary/tertiary on the same teal so no widget (chips, switches,
      // selection handles, default tab indicators) leaks a derived off-brand hue.
      secondary: accent,
      brightness: Brightness.light,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: const Color(0xFFECF2F6), // exact PWA body bg (--ws-bg)
      // Teal PWA-style top bar app-wide, so EVERY screen (including any using a
      // plain AppBar) shares the warehouse PWA header look. Screens using
      // lightAppBar() layer the teal *gradient* on top of this solid teal base.
      appBarTheme: AppBarTheme(
        backgroundColor: accent,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: Colors.white),
        actionsIconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w800,
        ),
        // Light status-bar icons over the teal header, teal shows behind the bar.
        systemOverlayStyle: SystemUiOverlayStyle.light.copyWith(
          statusBarColor: Colors.transparent,
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
      // Default tabs (on a light background) use the teal brand — matches the PWA
      // segmented tabs. Tabs placed on the teal header override this with white.
      tabBarTheme: TabBarThemeData(
        labelColor: accent,
        unselectedLabelColor: const Color(0xFF64748B), // Pwa.muted
        indicatorColor: accent,
        dividerColor: Colors.transparent,
        labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
      ),
      // Text selection / cursor on the teal brand instead of a derived hue.
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: accent,
        selectionHandleColor: accent,
        selectionColor: accent.withOpacity(0.18),
      ),
    );
  }

  /// Status → foreground color, mirroring the web badges.
  static Color statusColor(String status) {
    final s = status.toUpperCase();
    if (s.contains('COMPLETE') || s.contains('CLOSED') || s.contains('LOADED') || s.contains('APPROVED')) {
      return const Color(0xFF16A34A);
    }
    if (s.contains('REJECT') || s.contains('CANCEL') || s.contains('SHORT')) {
      return const Color(0xFFDC2626);
    }
    if (s.contains('RELEASE') || s.contains('PROGRESS') || s.contains('PROCESS') || s.contains('TRANSIT') || s.contains('PENDING')) {
      return const Color(0xFFD97706);
    }
    if (s.contains('INVOICED') || s.contains('RACKING')) {
      return const Color(0xFF0C8E9C); // teal
    }
    return const Color(0xFF475569); // slate (OPEN / default)
  }

  /// Soft background tint for a status pill (12% of the foreground color).
  static Color statusBg(String status) => statusColor(status).withOpacity(0.12);

  /// Warehouse-scan PWA status pill palette — mirrors `statusPillClass()` in the
  /// PWA app.js so badges match 1:1:
  ///   • complete / verified / progress → green  (success)
  ///   • hold / short                   → amber  (warning)
  ///   • everything else                → teal   (default primary-soft)
  static Color pillFg(String status) {
    final s = status.toLowerCase();
    if (s.contains('complete') || s.contains('verified') || s.contains('progress')) {
      return const Color(0xFF15803D);
    }
    if (s.contains('hold') || s.contains('short')) {
      return const Color(0xFFB45309);
    }
    return const Color(0xFF026E78); // ws-primary-dark
  }

  static Color pillBg(String status) {
    final s = status.toLowerCase();
    if (s.contains('complete') || s.contains('verified') || s.contains('progress')) {
      return const Color(0xFFDCFCE7);
    }
    if (s.contains('hold') || s.contains('short')) {
      return const Color(0xFFFEF3C7);
    }
    return const Color(0xFFD7F2F4); // ws-primary-soft
  }
}
