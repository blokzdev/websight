import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:websight/config/webview_config.dart';
import 'package:websight/utils/helpers.dart';

/// The AppTheme class is responsible for generating the application's theme
/// based on the dynamic configuration provided in `webview_config.yaml`.
class AppTheme {
  final ThemeConfig config;

  AppTheme({required this.config});

  /// Builds the `ThemeData` for the application.
  ///
  /// It determines whether to create a light or dark theme and applies
  /// custom colors and fonts from the configuration.
  ThemeData buildTheme() {
    // Generate the color scheme from the primary seed color.
    final colorScheme = ColorScheme.fromSeed(
      seedColor: parseColor(config.primary),
      brightness:
          config.brightness == 'dark' ? Brightness.dark : Brightness.light,
      surface: config.surface != null ? parseColor(config.surface!) : null,
      onSurface:
          config.onSurface != null ? parseColor(config.onSurface!) : null,
    );

    // Get the text theme, applying a custom font if specified.
    final textTheme = _buildTextTheme(config.brightness == 'dark'
        ? Typography.whiteCupertino
        : Typography.blackCupertino);

    // Combine everything into the final ThemeData.
    return ThemeData(
      useMaterial3: config.useMaterial3,
      colorScheme: colorScheme,
      textTheme: textTheme,
      primaryColor: colorScheme.primary,
      scaffoldBackgroundColor: colorScheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0, // Modern, flat look
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        selectedItemColor: colorScheme.primary,
        unselectedItemColor: colorScheme.onSurface.withAlpha(153),
        backgroundColor: colorScheme.surface,
      ),
      drawerTheme: DrawerThemeData(
        backgroundColor: colorScheme.surface,
      ),
    );
  }

  /// Creates a `TextTheme` by applying the configured font family.
  /// If a font family is specified, it uses the `google_fonts` package.
  /// Otherwise, it returns the base text theme.
  TextTheme _buildTextTheme(TextTheme baseTextTheme) {
    if (config.fontFamily != null && config.fontFamily!.isNotEmpty) {
      try {
        // `GoogleFonts.getFont` provides a simple way to apply a font family
        // to the entire text theme.
        return GoogleFonts.getTextTheme(config.fontFamily!, baseTextTheme);
      } catch (e) {
        // Fallback to the base theme if the font name is invalid.
        debugPrint(
            "Error loading font '${config.fontFamily}': $e. Falling back to default font.");
        return baseTextTheme;
      }
    }
    return baseTextTheme;
  }
}
