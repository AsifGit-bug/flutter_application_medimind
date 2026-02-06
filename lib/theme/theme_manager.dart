import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeManager {
  static final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(
    ThemeMode.light,
  );

  static final ThemeData lightTheme = ThemeData(
    brightness: Brightness.light,
    primaryColor: const Color(0xFF4DB6AC), // Mint/Teal 300
    scaffoldBackgroundColor: const Color(0xFFE0F2F1), // Teal 50 - Light mint
    cardColor: const Color(0xFFFFFFFF), // White cards for contrast
    dividerColor: const Color(0xFFB2DFDB), // Teal 100
    colorScheme: const ColorScheme.light(
      primary: Color(0xFF4DB6AC),
      secondary: Color(0xFF009688), // Octal Teal
      surface: Colors.white,
      error: Colors.red,
      onSurface: Color(0xFF1E232C), // Text Color
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFFE0F2F1), // Match scaffold
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
    primaryColor: const Color(0xFF80CBC4), // Lighter Teal for Dark Mode
    scaffoldBackgroundColor: const Color(0xFF121212),
    cardColor: const Color(0xFF1E1E1E),
    dividerColor: const Color(0xFF2C2C2C),
    colorScheme: const ColorScheme.dark(
      primary: Color(0xFF80CBC4),
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

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final isDark = prefs.getBool('isDarkMode') ?? false;
    themeNotifier.value = isDark ? ThemeMode.dark : ThemeMode.light;
  }

  static void toggleTheme() async {
    themeNotifier.value = themeNotifier.value == ThemeMode.light
        ? ThemeMode.dark
        : ThemeMode.light;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', themeNotifier.value == ThemeMode.dark);
  }
}
