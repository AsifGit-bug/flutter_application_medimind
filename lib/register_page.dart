import 'package:flutter/material.dart';
import 'patient_dashboard.dart';
import 'monitor_dashboard.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  // Text field controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final _formKey = GlobalKey<FormState>();

  // Password visibility toggles
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;

  void _handleRegister() {
    if (_formKey.currentState!.validate()) {
      _showRoleSelectionDialog();
    }
  }

  void _showRoleSelectionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text("Who is using this app?"),
        content: const Text("Please select your role to continue."),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => const PatientDashboard(),
                ), // Assuming PatientDashboard is imported or needs import if not
              );
            },
            child: const Text("Patient"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => const MonitorDashboard(),
                ), // Assuming MonitorDashboard is imported or needs import
              );
            },
            child: const Text("Monitor"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.primaryColor;
    final textColor = theme.textTheme.bodyLarge!.color!;
    final secondaryTextColor = theme.textTheme.bodyMedium!.color!;
    final cardColor = theme.cardColor;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Header (Back button + Greeting)
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                    onPressed: () => Navigator.pop(context),
                    color: theme.iconTheme.color,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  "Hello! Sign up to get started",
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                  textAlign: TextAlign.center,
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
                          const SizedBox(height: 24),

                          // Name Input
                          _buildLabel("Name", theme),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _nameController,
                            style: TextStyle(color: textColor),
                            decoration: _inputDecoration(
                              "Enter your name",
                              Icons.person_outline,
                              theme,
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your name';
                              }
                              // Name validation: Starts with a letter, no numbers, allows spaces/hyphens
                              if (!RegExp(
                                r"^[a-zA-Z][a-zA-Z\s-]*$",
                              ).hasMatch(value)) {
                                return 'Name must start with a letter and contain no numbers';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // Email Input
                          _buildLabel("Email", theme),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            style: TextStyle(color: textColor),
                            decoration: _inputDecoration(
                              "Enter your email",
                              Icons.email_outlined,
                              theme,
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

                          // Password Input
                          _buildLabel("Password", theme),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: !_isPasswordVisible,
                            style: TextStyle(color: textColor),
                            decoration:
                                _inputDecoration(
                                  "••••••••",
                                  Icons.lock_outline,
                                  theme,
                                ).copyWith(
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _isPasswordVisible
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                      color: secondaryTextColor,
                                    ),
                                    onPressed: () => setState(
                                      () => _isPasswordVisible =
                                          !_isPasswordVisible,
                                    ),
                                  ),
                                ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter a password';
                              }
                              if (value.length < 8 || value.length > 16) {
                                return 'Password must be 8-16 characters';
                              }
                              if (!RegExp(r'(?=.*[a-z])').hasMatch(value)) {
                                // Lowercase
                                return 'Must include at least one lowercase letter';
                              }
                              if (!RegExp(r'(?=.*[A-Z])').hasMatch(value)) {
                                // Uppercase
                                return 'Must include at least one uppercase letter';
                              }
                              if (!RegExp(r'(?=.*[0-9])').hasMatch(value)) {
                                // Number
                                return 'Must include at least one number';
                              }
                              if (!RegExp(r'(?=.*[@$!%*?&])').hasMatch(value)) {
                                // Special Char
                                return 'Must include at least one special character (@\$!%*?&)';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // Confirm Password Input
                          _buildLabel("Confirm Password", theme),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _confirmPasswordController,
                            obscureText: !_isConfirmPasswordVisible,
                            style: TextStyle(color: textColor),
                            decoration:
                                _inputDecoration(
                                  "••••••••",
                                  Icons.lock_outline,
                                  theme,
                                ).copyWith(
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _isConfirmPasswordVisible
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                      color: secondaryTextColor,
                                    ),
                                    onPressed: () => setState(
                                      () => _isConfirmPasswordVisible =
                                          !_isConfirmPasswordVisible,
                                    ),
                                  ),
                                ),
                            validator: (value) {
                              if (value != _passwordController.text) {
                                return 'Passwords do not match';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 30),

                          // Register Button
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              onPressed: _handleRegister,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryColor,
                                foregroundColor: theme.colorScheme.onPrimary,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                elevation: 0,
                              ),
                              child: const Text(
                                "Sign Up",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
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

                // Login Now Link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Already have an account? ",
                      style: TextStyle(color: textColor),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Text(
                        "Sign In",
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

  Widget _buildLabel(String text, ThemeData theme) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: theme.textTheme.bodyLarge!.color,
      ),
    );
  }

  // Helper for Input Decoration - Matched with Login Page
  InputDecoration _inputDecoration(
    String hint,
    IconData icon,
    ThemeData theme,
  ) {
    final hintColor = theme.textTheme.bodyMedium!.color!;
    final borderColor = theme.dividerColor;
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, color: hintColor, size: 20),
      hintStyle: TextStyle(color: hintColor),
      filled: true,
      fillColor: theme.brightness == Brightness.dark
          ? Colors.grey.withValues(alpha: 0.1)
          : Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: theme.primaryColor),
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

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }
}
