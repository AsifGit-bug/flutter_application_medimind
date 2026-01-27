import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/auth_service.dart';
import '../../services/database_service.dart';
import 'register_page.dart';
import '../patient/patient_dashboard.dart';
import '../monitor/monitor_dashboard.dart';
import '../admin/admin_dashboard.dart';
import 'role_selection_page.dart';

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

  @override
  Widget build(BuildContext context) {
    // Access Theme Colors
    final theme = Theme.of(context);
    final primaryColor = theme.primaryColor;
    final textColor = theme.textTheme.bodyLarge!.color!;
    final secondaryTextColor = theme.textTheme.bodyMedium!.color!;
    final cardColor = theme.cardColor;
    final scaffoldBg = theme.scaffoldBackgroundColor;
    final borderColor = theme.dividerColor;

    return Scaffold(
      backgroundColor: scaffoldBg,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Header outside the card
                Text(
                  "Welcome back",
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Sign in to your MediMind account",
                  style: TextStyle(fontSize: 16, color: secondaryTextColor),
                ),
                const SizedBox(height: 32),

                // Card Layout
                Card(
                  elevation: 4,
                  shadowColor: Colors.black12,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  color: cardColor,
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Sign In",
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "Enter your credentials to continue",
                            style: TextStyle(
                              fontSize: 14,
                              color: secondaryTextColor,
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Email Label & Input
                          _buildLabel("Email", textColor),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            style: TextStyle(color: textColor),
                            decoration: _inputDecoration(
                              "you@example.com",
                              Icons.email_outlined,
                              textColor,
                              secondaryTextColor,
                              cardColor,
                              primaryColor,
                              borderColor,
                            ),
                            validator: (value) {
                              final emailRegex = RegExp(
                                r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                              );
                              if (value == null || value.isEmpty) {
                                return 'Please enter your email';
                              } else if (!emailRegex.hasMatch(value)) {
                                return 'Please enter a valid email';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // Password Label & Input
                          _buildLabel("Password", textColor),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            style: TextStyle(color: textColor),
                            decoration: InputDecoration(
                              hintText: "••••••••",
                              prefixIcon: Icon(
                                Icons.lock_outline,
                                color: secondaryTextColor,
                                size: 20,
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                  color: secondaryTextColor,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                              ),
                              hintStyle: TextStyle(color: secondaryTextColor),
                              filled: true,
                              fillColor: theme.brightness == Brightness.dark
                                  ? Colors.grey.withValues(alpha: 0.1)
                                  : Colors.white,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: borderColor),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: primaryColor),
                              ),
                              errorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(color: Colors.red),
                              ),
                              focusedErrorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(color: Colors.red),
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

                          // Login Button
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              onPressed: _handleLogin,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryColor,
                                foregroundColor: theme.colorScheme.onPrimary,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                elevation: 0,
                              ),
                              child: _isLoading
                                  ? const CircularProgressIndicator(
                                      color: Colors.white,
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
                          Align(
                            alignment: Alignment.center,
                            child: TextButton(
                              onPressed: _showForgotPasswordDialog,
                              child: Text(
                                "Forgot your password?",
                                style: TextStyle(
                                  color: primaryColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Footer
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Don't have an account? ",
                      style: TextStyle(color: textColor),
                    ),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const RegisterPage(),
                          ),
                        );
                      },
                      child: Text(
                        "Sign up",
                        style: TextStyle(
                          color: primaryColor,
                          fontWeight: FontWeight.bold,
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
          // --- CHECK EMAIL VERIFICATION (Bypass for Admins) ---
          if (!isAdminEmail && !userCred.user!.emailVerified) {
            // DO NOT Sign out immediately! Wait for user action.
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
                        // Resend Email
                        try {
                          await userCred.user?.sendEmailVerification();
                          if (context.mounted) {
                            Navigator.pop(context); // Close dialog
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("Verification email sent!"),
                              ),
                            );
                            await _authService.signOut(); // Now sign out
                          }
                        } catch (e) {
                          // ignore errors if already sent recently
                        }
                      },
                      child: const Text("Resend Email"),
                    ),
                    TextButton(
                      onPressed: () async {
                        Navigator.pop(context); // Close dialog
                        await _authService.signOut();
                      },
                      child: const Text("OK"),
                    ),
                  ],
                ),
              );
              setState(() => _isLoading = false);
            }
            return; // Stop execution
          }

          // --- SYNC VERIFICATION STATUS ---
          // Use a separate write so we don't block the UI flow unnecessarily, but good to await to ensure consistency
          if (userCred.user!.emailVerified) {
            await _dbService.verifyUser(uid);
          }

          // Fetch user data
          Map<String, dynamic>? userData = await _dbService.getUserData(uid);

          String role = 'pending'; // Default

          if (isAdminEmail) {
            // FORCE ADMIN & RESURRECT IF NEEDED
            // This ensures email verification, role, and active status are all set correctly
            // even if the user document was deleted.
            await _dbService.ensureAdminUser(uid, email);
            role = 'admin';
            // Normal User
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
                    duration: Duration(seconds: 5),
                  ),
                );
                setState(() => _isLoading = false);
                return;
              }
            } else {
              role = userData['role'] ?? 'patient';
            }

            // --- CRITICAL: CHECK IF BANNED OR DELETED ---
            bool isActive = userData?['active'] ?? true;
            bool isDeleted = userData?['isDeleted'] ?? false;

            if (!isActive || isDeleted) {
              await _authService.signOut(); // Force logout
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      "Your account has been suspended or deleted. Please contact support.",
                    ),
                    backgroundColor: Colors.red,
                    duration: Duration(seconds: 5),
                  ),
                );
                setState(() => _isLoading = false);
                return; // Stop execution
              }
            }
          }

          if (mounted) {
            // 3. Route based on role
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
              // Pending or Unknown -> Role Selection
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
                  if (context.mounted) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text("Error: $e")));
                  }
                }
              }
            },
            child: const Text("Send Link"),
          ),
        ],
      ),
    );
  }

  Widget _buildLabel(String text, Color color) {
    return Text(
      text,
      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: color),
    );
  }

  InputDecoration _inputDecoration(
    String hint,
    IconData icon,
    Color textColor,
    Color hintColor,
    Color fillColor,
    Color focusedColor,
    Color borderColor,
  ) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, color: hintColor, size: 20),
      hintStyle: TextStyle(color: hintColor),
      filled: true,
      fillColor: Theme.of(context).brightness == Brightness.dark
          ? Colors.grey.withValues(alpha: 0.1)
          : Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: focusedColor),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.red),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.red),
      ),
    );
  }
}
