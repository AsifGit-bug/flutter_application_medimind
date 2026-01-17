import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ThemeManager {
  static final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(
    ThemeMode.dark,
  );

  static final ThemeData lightTheme = ThemeData(
    brightness: Brightness.light,
    primaryColor: const Color(0xFF1565C0), // Primary Blue
    scaffoldBackgroundColor: const Color(0xFFF7F8F9),
    cardColor: Colors.white,
    dividerColor: const Color(0xFFE8ECF4),
    colorScheme: const ColorScheme.light(
      primary: Color(0xFF1565C0),
      secondary: Color(0xFF009688), // Octal Teal
      surface: Colors.white,
      error: Colors.red,
      onSurface: Color(0xFF1E232C), // Text Color
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: Colors.black,
      elevation: 0,
    ),
    textTheme: GoogleFonts.poppinsTextTheme(
      const TextTheme(
        bodyLarge: TextStyle(color: Color(0xFF1E232C)), // Primary Text
        bodyMedium: TextStyle(color: Color(0xFF8391A1)), // Secondary Text
        titleLarge: TextStyle(
          color: Color(0xFF1E232C),
          fontWeight: FontWeight.bold,
        ),
      ),
    ),
    iconTheme: const IconThemeData(color: Color(0xFF1E232C)),
  );

  static final ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    primaryColor: const Color(0xFF90CAF9), // Lighter Blue for Dark Mode
    scaffoldBackgroundColor: const Color(0xFF121212),
    cardColor: const Color(0xFF1E1E1E),
    dividerColor: const Color(0xFF2C2C2C),
    colorScheme: const ColorScheme.dark(
      primary: Color(0xFF90CAF9),
      secondary: Color(0xFF80CBC4),
      surface: Color(0xFF1E1E1E),
      error: Color(0xFFCF6679),
      onSurface: Colors.white, // Text Color
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF121212),
      foregroundColor: Colors.white,
      elevation: 0,
    ),
    textTheme: GoogleFonts.poppinsTextTheme(
      const TextTheme(
        bodyLarge: TextStyle(color: Colors.white), // Primary Text
        bodyMedium: TextStyle(color: Color(0xFFB0BEC5)), // Secondary Text
        titleLarge: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
    ),
    iconTheme: const IconThemeData(color: Colors.white70),
  );

  static void toggleTheme() {
    themeNotifier.value = themeNotifier.value == ThemeMode.light
        ? ThemeMode.dark
        : ThemeMode.light;
  }
}
