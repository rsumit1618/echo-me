import 'package:flutter/material.dart';

enum AppThemeMode { light, dark, elite }

class AppTheme {
  static ThemeData fromMode(AppThemeMode mode) {
    return switch (mode) {
      AppThemeMode.light => light(),
      AppThemeMode.dark => dark(),
      AppThemeMode.elite => elite(),
    };
  }

  static ThemeData light() {
    const seed = Color(0xFF2481F2);
    return _base(
      ColorScheme.fromSeed(
        seedColor: seed,
        secondary: const Color(0xFF0EA5E9),
        tertiary: const Color(0xFF10B981),
        surface: const Color(0xFFF8FBFF),
        surfaceContainerHighest: const Color(0xFFEAF4FF),
      ),
      scaffoldBackgroundColor: const Color(0xFFF3F8FF),
    );
  }

  static ThemeData dark() {
    const seed = Color(0xFF54A3FF);
    return _base(
      ColorScheme.fromSeed(
        seedColor: seed,
        brightness: Brightness.dark,
        secondary: const Color(0xFF38BDF8),
        tertiary: const Color(0xFF34D399),
        surface: const Color(0xFF111827),
        surfaceContainerHighest: const Color(0xFF1F2A44),
      ),
      scaffoldBackgroundColor: const Color(0xFF0B1220),
    );
  }

  static ThemeData elite() {
    const gold = Color(0xFFC9A227);
    const ink = Color(0xFF101418);
    const panel = Color(0xFF171C22);
    return _base(
      ColorScheme.fromSeed(
        seedColor: gold,
        brightness: Brightness.dark,
        surface: panel,
        primary: gold,
        secondary: const Color(0xFFE0C46C),
        tertiary: const Color(0xFF6EC6B8),
        surfaceContainerHighest: const Color(0xFF242A32),
      ),
      scaffoldBackgroundColor: ink,
      appBarTheme: const AppBarTheme(
        backgroundColor: ink,
        foregroundColor: gold,
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        backgroundColor: panel.withValues(alpha: .94),
        shadowColor: Colors.black.withValues(alpha: .18),
        indicatorColor: gold.withValues(alpha: .18),
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
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
            backgroundColor: scaffoldBackgroundColor ?? colorScheme.surface,
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
        fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: .55),
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
            backgroundColor: colorScheme.surface.withValues(alpha: .94),
            shadowColor: colorScheme.shadow.withValues(alpha: .12),
            indicatorColor: colorScheme.primaryContainer.withValues(alpha: .72),
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
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: colorScheme.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: colorScheme.primary,
        textColor: colorScheme.onSurface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colorScheme.surface,
        modalBackgroundColor: colorScheme.surface,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: colorScheme.inverseSurface,
        contentTextStyle: TextStyle(color: colorScheme.onInverseSurface),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant.withValues(alpha: .6),
      ),
      useMaterial3: true,
    );
  }
}
