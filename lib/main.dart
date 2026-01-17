import 'package:flutter/material.dart';
import 'splash_page.dart';

import 'theme_manager.dart';

void main() {
  runApp(
    ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeManager.themeNotifier,
      builder: (context, themeMode, child) {
        return MaterialApp(
          home: const SplashPage(),
          debugShowCheckedModeBanner: false,
          theme: ThemeManager.lightTheme,
          darkTheme: ThemeManager.darkTheme,
          themeMode: themeMode,
        );
      },
    ),
  );
}
