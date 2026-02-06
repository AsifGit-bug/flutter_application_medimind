import 'package:flutter/material.dart';
import 'login_page.dart';
import 'register_page.dart';
import 'auth_logo.dart';

class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context) {
    // Custom Colors matching the design (Mint/Teal)
    const Color mintBackground = Color(0xFFE0F7FA);
    const Color tealPrimary = Color(0xFF26A69A);
    const Color textDark = Color(0xFF37474F);

    return Scaffold(
      backgroundColor: mintBackground,
      // No AppBar to enforce "No Theme Toggle" and cleaner look
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const SizedBox(height: 20), // Top spacer
              // --- CENTER CONTENT ---
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Logo
                  const AuthLogo(),
                  const SizedBox(height: 48),

                  // "Welcome To"
                  Text(
                    "Welcome To",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors
                          .orange[800], // Using a warm accent like in image? Or stick to Teal?
                      // The image has "Welcome To" in orange/gold. Let's try to match that subtle pop.
                    ),
                  ),
                  const SizedBox(height: 8),

                  // "MediMind"
                  const Text(
                    "MediMind",
                    style: TextStyle(
                      fontSize: 42,
                      fontWeight: FontWeight.bold,
                      color:
                          textDark, // Or Teal? Let's use blue/teal to match logo
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Subtitle
                  const Text(
                    "Your personal assistant for managing\nyour medication schedule.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                      height: 1.5,
                    ),
                  ),
                ],
              ),

              // --- BOTTOM BUTTONS ---
              Column(
                children: [
                  // Login Button (Filled)
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const LoginPage(),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: tealPrimary, // Teal filled
                        foregroundColor: Colors.white,
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        "Login",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Register Button (Outlined)
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const RegisterPage(),
                          ),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: tealPrimary, width: 2),
                        foregroundColor: tealPrimary,
                        backgroundColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        "Register",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
