import 'package:flutter/material.dart';

class AppTheme {
  // Colors
  static const Color primaryBlue = Color(0xFF1E88E5);
  static const Color primaryPurple = Color(0xFF8E24AA);
  static const Color backgroundStart = Color(0xFF1A1A2E);
  static const Color backgroundMiddle = Color(0xFF16213E);
  static const Color backgroundEnd = Color(0xFF0F3460);

  static const Color textWhite = Colors.white;
  static const Color textWhite70 = Colors.white70;
  static const Color textWhite54 = Colors.white54;

  static const Color glassBorder = Colors.white10;
  static const Color glassBackground = Color(0x0DFFFFFF); // 5% opacity white

  // Gradient
  static const LinearGradient mainGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [backgroundStart, backgroundMiddle, backgroundEnd],
  );

  static const LinearGradient activeGradient = LinearGradient(
    colors: [primaryBlue, primaryPurple],
  );

  static const LinearGradient inactiveGradient = LinearGradient(
    colors: [Colors.grey, Colors.black12],
  );

  // Text Styles
  static const TextStyle heading = TextStyle(
    color: textWhite,
    fontSize: 24,
    fontWeight: FontWeight.bold,
  );

  static const TextStyle subHeading = TextStyle(
    color: textWhite,
    fontSize: 16,
    fontWeight: FontWeight.bold,
  );

  static const TextStyle sectionTitle = TextStyle(
    color: textWhite70,
    fontSize: 12,
    fontWeight: FontWeight.bold,
    letterSpacing: 1.2,
  );

  static const TextStyle bodySmall = TextStyle(
    color: textWhite54,
    fontSize: 14,
  );

  // Theme Data
  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      primarySwatch: Colors.blue,
      useMaterial3: true,
      scaffoldBackgroundColor: backgroundStart,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: primaryBlue,
        inactiveTrackColor: glassBorder,
        thumbColor: textWhite,
        overlayColor: primaryBlue.withOpacity(0.2),
      ),
      cardTheme: CardThemeData(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color: glassBackground,
      ),
    );
  }
}
