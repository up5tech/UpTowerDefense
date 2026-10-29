import 'package:flutter/material.dart';

/// Application-wide theming.
///
/// The palette is intentionally small and high-contrast so towers, enemies and
/// route markers stay readable on small screens. Art direction is finalised in
/// Phase 10; only structural decisions are made here.
abstract final class AppTheme {
  /// Deep base colours that keep the game world readable behind HUD panels.
  static const Color _background = Color(0xFF0D1117);
  static const Color _surface = Color(0xFF161D27);
  static const Color _seed = Color(0xFF37C2A0);

  /// Dark theme used by every screen in the shell.
  static ThemeData dark() {
    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: _seed,
          brightness: Brightness.dark,
        ).copyWith(
          surface: _surface,
        );

    return ThemeData(
      colorScheme: colorScheme,
      scaffoldBackgroundColor: _background,
      useMaterial3: true,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      // Landscape mobile layouts can be short; keep text compact but legible.
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
        titleMedium: TextStyle(fontWeight: FontWeight.w600),
      ),
    );
  }
}
