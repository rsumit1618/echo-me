import 'package:flutter/material.dart';

enum AppThemeMode { light, dark, elite }

class AppTheme {
  static ThemeData light() {
    return _base(
      ColorScheme.fromSeed(
        seedColor: const Color(0xFF0F9D58),
        surface: const Color(0xFFF8FAF9),
      ),
    );
  }

  static ThemeData dark() {
    return _base(
      ColorScheme.fromSeed(
        seedColor: const Color(0xFF0F9D58),
        brightness: Brightness.dark,
        surface: const Color(0xFF151A18),
      ),
    );
  }

  static ThemeData elite() {
    const gold = Color(0xFFC9A227);
    const ink = Color(0xFF101418);
    return _base(
      ColorScheme.fromSeed(
        seedColor: gold,
        brightness: Brightness.dark,
        surface: const Color(0xFF151A20),
      ),
      scaffoldBackgroundColor: ink,
      appBarTheme: const AppBarTheme(
        backgroundColor: ink,
        foregroundColor: gold,
      ),
      navigationBarTheme: NavigationBarThemeData(
        indicatorColor: gold.withValues(alpha: .18),
        labelTextStyle: WidgetStateProperty.all(
          const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  static ThemeData _base(
    ColorScheme colorScheme, {
    Color? scaffoldBackgroundColor,
    AppBarTheme? appBarTheme,
    NavigationBarThemeData? navigationBarTheme,
  }) {
    return ThemeData(
      colorScheme: colorScheme,
      scaffoldBackgroundColor: scaffoldBackgroundColor ?? colorScheme.surface,
      appBarTheme:
          appBarTheme ??
          AppBarTheme(
            centerTitle: false,
            elevation: 0,
            scrolledUnderElevation: 0,
            backgroundColor: colorScheme.surface,
            foregroundColor: colorScheme.onSurface,
            titleTextStyle: TextStyle(
              color: colorScheme.onSurface,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        clipBehavior: Clip.antiAlias,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: .42),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.6),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      navigationBarTheme:
          navigationBarTheme ??
          NavigationBarThemeData(
            height: 72,
            indicatorShape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            labelTextStyle: WidgetStateProperty.all(
              const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: ZoomPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
      useMaterial3: true,
    );
  }
}
