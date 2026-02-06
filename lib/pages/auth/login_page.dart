import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/auth_service.dart';
import '../../services/database_service.dart';
import 'register_page.dart';
import '../patient/patient_dashboard.dart';
import '../monitor/monitor_dashboard.dart';
import '../admin/admin_dashboard.dart';
import 'role_selection_page.dart';
import 'welcome_page.dart';
import 'auth_logo.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscurePassword = true;

  final AuthService _authService = AuthService();
  final DatabaseService _dbService = DatabaseService();
  bool _isLoading = false;

  // Custom Colors from design
  static const Color _mintBackground = Color(0xFFE0F7FA); // Light Mint
  static const Color _tealPrimary = Color(0xFF26A69A); // Teal 400
  static const Color _textDark = Color(0xFF37474F); // Blue Grey 800

  @override
  Widget build(BuildContext context) {
    // We ignore the global theme for this page to match the requested specific design
    // unless it's dark mode, where we might want to adapt key elements.
    // However, the request was "look like this", implying strict adherence to the light design shown.
    // I will implement a "Design Mode" wrapper.

    return Scaffold(
      backgroundColor: _mintBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: _textDark),
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const WelcomePage()),
            );
          },
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // --- LOGO SECTION ---
              // --- LOGO SECTION ---
              const AuthLogo(),
              const Text(
                "MediMind",
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: _textDark,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "Your Daily Health Companion",
                style: TextStyle(fontSize: 16, color: Colors.black54),
              ),
              const SizedBox(height: 48),

              // --- CARD SECTION ---
              Card(
                elevation: 8,
                shadowColor: Colors.black.withValues(alpha: 0.1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32.0,
                    vertical: 40.0,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 350),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            "Welcome Back",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: _textDark,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            "Sign in to continue",
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 14, color: Colors.grey),
                          ),
                          const SizedBox(height: 32),

                          // Email
                          const Text(
                            "Email",
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: _textDark,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _emailController,
                            textAlignVertical: TextAlignVertical.center,
                            style: const TextStyle(color: _textDark),
                            decoration: _buildInputDecoration(
                              "you@example.com",
                              Icons.email_outlined,
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your email';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // Password
                          const Text(
                            "Password",
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: _textDark,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _passwordController,
                            textAlignVertical: TextAlignVertical.center,
                            obscureText: _obscurePassword,
                            style: const TextStyle(color: _textDark),
                            decoration:
                                _buildInputDecoration(
                                  "••••••••",
                                  Icons.lock_outline,
                                ).copyWith(
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_off_outlined
                                          : Icons.visibility_outlined,
                                      color: Colors.grey,
                                      size: 20,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _obscurePassword = !_obscurePassword;
                                      });
                                    },
                                  ),
                                ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your password';
                              }
                              return null;
                            },
                          ),

                          const SizedBox(height: 24),

                          // Sign In Button
                          SizedBox(
                            height: 50,
                            child: ElevatedButton(
                              onPressed: _handleLogin,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _tealPrimary,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text(
                                      "Sign In",
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Forgot Password
                          Center(
                            child: GestureDetector(
                              onTap: _showForgotPasswordDialog,
                              child: const Text(
                                "Forgot Password?",
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 24),

                          // Sign Up Link (Inside Card per Image? Or User wants it outside?
                          // The image usually has the footer. I'll put it at the bottom.
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text(
                                "Don't have an account? ",
                                style: TextStyle(
                                  color: _textDark,
                                  fontSize: 13,
                                ),
                              ),
                              GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const RegisterPage(),
                                    ),
                                  );
                                },
                                child: const Text(
                                  "Sign Up",
                                  style: TextStyle(
                                    color: _tealPrimary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _buildInputDecoration(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey.withValues(alpha: 0.7)),
      prefixIcon: Icon(icon, color: Colors.grey, size: 20),
      filled: true,
      fillColor: Colors.grey.withValues(alpha: 0.05), // Very light fill
      contentPadding: const EdgeInsets.symmetric(
        vertical: 14,
        horizontal: 10,
      ), // Increased vertical padding
      // Use UnderlineInputBorder or minimal OutlineInputBorder as seen in common modern designs
      // The user image description said "inputs with icons... clear underlining or borders".
      // I'll stick to a clean Underline for "Mint" look or minimal Outline.
      // Let's use Underline as it matches the "clean" vibe often found in this template style.
      border: const UnderlineInputBorder(
        borderSide: BorderSide(color: Colors.grey),
      ),
      enabledBorder: UnderlineInputBorder(
        borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
      ),
      focusedBorder: const UnderlineInputBorder(
        borderSide: BorderSide(color: _tealPrimary),
      ),
    );
  }

  Future<void> _handleLogin() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      try {
        // 1. Sign In
        UserCredential userCred = await _authService.signIn(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );

        if (userCred.user != null) {
          String uid = userCred.user!.uid;
          String email = _emailController.text.trim().toLowerCase();

          // ---------------------------------------------------------
          // SELF-HEALING & AUTO-ADMIN LOGIC
          // ---------------------------------------------------------
          final adminEmails = [
            'asifabar43@gmail.com',
            'srhridoy133@gmail.com',
            'jahanispa02@gmail.com',
          ];

          bool isAdminEmail = adminEmails.contains(email);
          if (!isAdminEmail && !userCred.user!.emailVerified) {
            if (mounted) {
              await showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => AlertDialog(
                  title: const Text("Email Not Verified"),
                  content: const Text(
                    "Please verify your email address to log in.\nCheck your inbox and spam folder.",
                  ),
                  actions: [
                    TextButton(
                      onPressed: () async {
                        try {
                          await userCred.user?.sendEmailVerification();
                          if (context.mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  "Verification email sent! Check your inbox and spam folder.",
                                ),
                              ),
                            );
                            await _authService.signOut();
                          }
                        } catch (e) {
                          /* ignore */
                        }
                      },
                      child: const Text("Resend Email"),
                    ),
                    TextButton(
                      onPressed: () async {
                        Navigator.pop(context);
                        await _authService.signOut();
                      },
                      child: const Text("OK"),
                    ),
                  ],
                ),
              );
              setState(() => _isLoading = false);
            }
            return;
          }

          if (userCred.user!.emailVerified) {
            await _dbService.verifyUser(uid);
          }

          Map<String, dynamic>? userData = await _dbService.getUserData(uid);
          String role = 'pending';

          if (isAdminEmail) {
            await _dbService.ensureAdminUser(uid, email);
            role = 'admin';
          } else {
            if (userData == null) {
              await _authService.signOut();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      "Your account has been deleted. Please contact support.",
                    ),
                    backgroundColor: Colors.red,
                  ),
                );
                setState(() => _isLoading = false);
                return;
              }
            } else {
              role = userData['role'] ?? 'patient';
            }

            bool isActive = userData?['active'] ?? true;
            bool isDeleted = userData?['isDeleted'] ?? false;
            if (!isActive || isDeleted) {
              await _authService.signOut();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      "Your account has been suspended or deleted.",
                    ),
                    backgroundColor: Colors.red,
                  ),
                );
                setState(() => _isLoading = false);
                return;
              }
            }
          }

          if (mounted) {
            if (role == 'admin') {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const AdminDashboard()),
              );
            } else if (role == 'monitor' || role == 'guardian') {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => const MonitorDashboard(),
                ),
              );
            } else if (role == 'patient') {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => const PatientDashboard(),
                ),
              );
            } else {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => RoleSelectionPage(uid: uid),
                ),
              );
            }
          }
        }
      } on FirebaseAuthException catch (e) {
        if (mounted) {
          String message = "Login Failed: ${e.message}";
          if (e.code == 'invalid-credential') {
            message =
                "Invalid email or password. Please check your credentials.";
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message), backgroundColor: Colors.red),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text("Error: ${e.toString()}")));
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  void _showForgotPasswordDialog() {
    final TextEditingController resetEmailController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Reset Password"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Enter your email address and we'll send you a password reset link.",
            ),
            const SizedBox(height: 16),
            TextField(
              controller: resetEmailController,
              decoration: const InputDecoration(
                labelText: "Email",
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              final email = resetEmailController.text.trim();
              if (email.isNotEmpty) {
                try {
                  await _authService.sendPasswordResetEmail(email);
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          "Password reset email sent! Check your inbox and spam folder.",
                        ),
                      ),
                    );
                  }
                } catch (e) {
                  // handle
                }
              }
            },
            child: const Text("Send Link"),
          ),
        ],
      ),
    );
  }
}
