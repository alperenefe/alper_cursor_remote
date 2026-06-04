import 'package:flutter/material.dart';

import 'design_tokens.dart';

abstract final class AppTheme {
  static ThemeData dark() {
    const scheme = ColorScheme.dark(
      surface: DesignTokens.slate950,
      primary: DesignTokens.blue600,
      secondary: DesignTokens.violet500,
      onPrimary: DesignTokens.white,
      onSurface: DesignTokens.slate200,
      outline: DesignTokens.slate600,
      surfaceContainerHighest: DesignTokens.slate800,
      error: Color(0xFFF87171),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: DesignTokens.slate950,
      appBarTheme: const AppBarTheme(
        backgroundColor: DesignTokens.slate950,
        foregroundColor: DesignTokens.white,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: DesignTokens.cardBg,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: DesignTokens.borderSubtle),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: DesignTokens.slate900,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: DesignTokens.borderSubtle),
        ),
        labelStyle: const TextStyle(color: DesignTokens.slate400),
        hintStyle: const TextStyle(color: DesignTokens.slate500),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 68,
        backgroundColor: DesignTokens.slate900,
        surfaceTintColor: Colors.transparent,
        indicatorColor: DesignTokens.blue600.withValues(alpha: 0.35),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? DesignTokens.white : DesignTokens.slate500,
            size: 24,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            color: selected ? DesignTokens.white : DesignTokens.slate400,
          );
        }),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: DesignTokens.slate800,
        contentTextStyle: const TextStyle(color: DesignTokens.slate200),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: DesignTokens.borderSubtle),
        ),
      ),
    );
  }
}
