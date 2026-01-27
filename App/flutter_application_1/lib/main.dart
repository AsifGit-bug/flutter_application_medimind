import 'package:flutter/material.dart';
import 'package:flutter_application_1/screens/caregiver_dashboard.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MediMind Caregiver',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4CAF50), // Green seed
          primary: const Color(0xFF4CAF50),
        ),
        useMaterial3: true,
        fontFamily:
            'Roboto', // Default, but good to be explicit or leave system
      ),
      home: const CaregiverDashboard(),
    );
  }
}
