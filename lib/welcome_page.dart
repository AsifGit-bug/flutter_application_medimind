import 'package:flutter/material.dart';
import 'login_page.dart';
import 'register_page.dart';

class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  final Color primaryBlue = const Color(0xFF1565C0);
  final Color accentOrange = const Color(0xFFFF7043);
  final Color subtitleGrey = const Color(0xFF546E7A);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(flex: 1),
              // Illustration Placeholder
              Container(
                height: 220,
                alignment: Alignment.center,
                child: const Icon(Icons.medical_services, size: 100, color: Color(0xFF1565C0)), 
                // Note: replace with Image.asset('assets/welcome_illustration.png') when file is ready
              ),
              const SizedBox(height: 32),
              Text('Welcome To', textAlign: TextAlign.center,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: accentOrange),
              ),
              Text('MediMind', textAlign: TextAlign.center,
                style: TextStyle(fontSize: 42, fontWeight: FontWeight.w900, color: primaryBlue),
              ),
              const SizedBox(height: 16),
              Text('Your personal assistant for managing your medication schedule.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: subtitleGrey, height: 1.4),
              ),
              const Spacer(flex: 2),
              
              // Login Button
              ElevatedButton(
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const LoginPage()));
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Login'),
              ),
              const SizedBox(height: 16),
              
              // Register Button
              OutlinedButton(
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const RegisterPage()));
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: primaryBlue,
                  side: BorderSide(color: primaryBlue, width: 2),
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Register'),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}