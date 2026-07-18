import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

class AppTheme {
  // Ivory & Forest Green Palette
  static const Color primaryIvory = Color(0xFFFFFDF0); // Main Background
  static const Color secondaryIvory = Color(0xFFF0EDCF); // Cards / Input
  static const Color accentForest = Color(0xFF153422); // Buttons / Headers
  static const Color charcoalBlack = Color(0xFF1A1A1A); // Main Text
  static const Color graphiteGray = Color(0xFF4A4A4A); // Secondary Text

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: accentForest,
      scaffoldBackgroundColor: primaryIvory,
      colorScheme: const ColorScheme.light(
        primary: accentForest,
        secondary: accentForest,
        surface: secondaryIvory,
        onSurface: charcoalBlack,
        onPrimary: Colors.white,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: accentForest,
        foregroundColor: primaryIvory,
        centerTitle: true,
        elevation: 0,
        titleTextStyle: TextStyle(
          color: primaryIvory,
          fontSize: 20,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
      cardTheme: CardThemeData(
        color: secondaryIvory,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.symmetric(vertical: 8),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accentForest,
          foregroundColor: primaryIvory,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: accentForest),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: accentForest.withValues(alpha: 0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: accentForest, width: 2),
        ),
        labelStyle: const TextStyle(color: graphiteGray),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: const CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: const CupertinoPageTransitionsBuilder(),
        },
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(color: charcoalBlack, fontWeight: FontWeight.bold),
        titleLarge: TextStyle(color: charcoalBlack, fontWeight: FontWeight.bold),
        bodyLarge: TextStyle(color: charcoalBlack),
        bodyMedium: TextStyle(color: graphiteGray),
      ),
    );
  }

  // Helper for transparency
  static Color forestWithValues({double alpha = 1.0}) => accentForest.withValues(alpha: alpha);
}
