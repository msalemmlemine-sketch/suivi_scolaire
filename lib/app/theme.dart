import 'package:flutter/material.dart';

class AppColors {
  static const teal = Color(0xFF0E5A5A);
  static const tealDark = Color(0xFF0A3F40);
  static const tealSoft = Color(0xFFDDEEEC);
  static const amber = Color(0xFFC98A1B);
  static const ink = Color(0xFF14232B);
  static const muted = Color(0xFF5B6B72);
  static const surface = Color(0xFFF3F6F6);
  static const line = Color(0xFFDCE4E4);
  static const success = Color(0xFF2E7D5B);
  static const danger = Color(0xFFB3402F);
}

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: AppColors.teal).copyWith(
    primary: AppColors.teal,
    onPrimary: Colors.white,
    secondary: AppColors.amber,
    surface: Colors.white,
    onSurface: AppColors.ink,
    error: AppColors.danger,
    outlineVariant: AppColors.line,
  );
  final base = ThemeData(colorScheme: scheme, useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: AppColors.surface,
    visualDensity: VisualDensity.standard,
    textTheme: base.textTheme.apply(bodyColor: AppColors.ink, displayColor: AppColors.ink).copyWith(
      headlineSmall: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, height: 1.25, color: AppColors.ink),
      titleLarge: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, height: 1.3, color: AppColors.ink),
      titleMedium: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, height: 1.35, color: AppColors.ink),
      bodyLarge: const TextStyle(fontSize: 16, height: 1.5, color: AppColors.ink),
      bodyMedium: const TextStyle(fontSize: 14, height: 1.5, color: AppColors.ink),
      bodySmall: const TextStyle(fontSize: 12, height: 1.45, color: AppColors.muted),
      labelMedium: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.teal,
      foregroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      toolbarHeight: 60,
      titleTextStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: const BorderSide(color: AppColors.line)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFFFAFCFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.line)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.line)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.teal, width: 1.6)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.danger)),
    ),
    filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(
      minimumSize: const Size(48, 48), padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
    )),
    outlinedButtonTheme: OutlinedButtonThemeData(style: OutlinedButton.styleFrom(
      minimumSize: const Size(44, 44), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    )),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 8,
      height: 72,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      indicatorColor: AppColors.tealSoft,
      iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(size: 23, color: s.contains(WidgetState.selected) ? AppColors.teal : AppColors.muted)),
      labelTextStyle: WidgetStateProperty.resolveWith((s) => TextStyle(
        fontSize: 10.5, height: 1.1, fontWeight: s.contains(WidgetState.selected) ? FontWeight.w800 : FontWeight.w600,
        color: s.contains(WidgetState.selected) ? AppColors.teal : AppColors.muted,
      )),
    ),
    dividerTheme: const DividerThemeData(color: AppColors.line, space: 1, thickness: 1),
    snackBarTheme: SnackBarThemeData(behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
  );
}
