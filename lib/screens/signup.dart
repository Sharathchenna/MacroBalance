// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:macrotracker/auth/auth_actions.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:macrotracker/auth/auth_gate.dart';
import 'package:macrotracker/theme/typography.dart';
import 'package:macrotracker/screens/loginscreen.dart';
import 'package:macrotracker/theme/app_theme.dart';
import 'package:macrotracker/screens/forgot_password_screen.dart';
import 'dart:io';

class Signup extends StatefulWidget {
  const Signup({super.key});

  @override
  State<Signup> createState() => _SignupState();
}

class _SignupState extends State<Signup> with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool isPasswordVisible = false;
  bool isConfirmPasswordVisible = false;
  bool isLoading = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    // Unfocus the keyboard
    FocusScope.of(context).unfocus();

    if (_nameController.text.isEmpty ||
        _emailController.text.isEmpty ||
        _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all fields'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (_confirmPasswordController.text.isNotEmpty &&
        _passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Passwords do not match'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final email = _emailController.text.trim(); // Trim whitespace
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid email address'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => isLoading = true);
    final result = await AuthActions.signUpWithEmail(
      name: _nameController.text,
      email: email,
      password: _passwordController.text,
    );
    if (mounted) setState(() => isLoading = false);
    if (!mounted) return;

    switch (result.outcome) {
      case AuthOutcome.needsConfirmation:
        // User signed up but needs email confirmation
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Signup successful! Please check your email to confirm your account.'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        // Navigate to login screen after showing the message
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      case AuthOutcome.signedIn:
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const AuthGate()),
          (route) => false,
        );
      case AuthOutcome.failed:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${result.message}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      case AuthOutcome.cancelled:
        break;
    }
  }

  Future<void> _nativeGoogleSignIn() async {
    setState(() => isLoading = true);
    final result = await AuthActions.signInWithGoogle();
    if (mounted) setState(() => isLoading = false);
    if (!mounted) return;
    if (result.signedIn) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const AuthGate()),
        (route) => false,
      );
    } else if (result.outcome == AuthOutcome.failed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('There was a problem signing in with Google'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _signInWithApple() async {
    setState(() => isLoading = true);
    final result = await AuthActions.signInWithApple();
    if (mounted) setState(() => isLoading = false);
    if (!mounted) return;
    if (result.signedIn) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const AuthGate()),
        (route) => false,
      );
    } else if (result.outcome == AuthOutcome.failed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('There was a problem signing in with Apple'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final customColors = Theme.of(context).extension<CustomColors>();

    return GestureDetector(
      onTap: () {
        // Dismiss keyboard when tapping anywhere on the screen
        FocusScope.of(context).unfocus();
      },
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: FadeTransition(
          opacity: _fadeAnimation,
          child: SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 24), // Reduced from 40
                    Text(
                      'Create Account',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: customColors!.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4), // Reduced from 8
                    Text(
                      'Start your fitness journey today',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: customColors!.textPrimary.withOpacity(0.7),
                      ),
                    ),
                    const SizedBox(height: 24), // Reduced from 40

                    // Name field
                    _buildInputLabel('Name'),
                    const SizedBox(height: 4), // Reduced from 8
                    _buildTextField(
                      controller: _nameController,
                      hintText: 'Enter your name',
                      prefixIcon: Icons.person_outline,
                    ),

                    const SizedBox(height: 16), // Reduced from 20

                    // Email field
                    _buildInputLabel('Email'),
                    const SizedBox(height: 4), // Reduced from 8
                    _buildTextField(
                      controller: _emailController,
                      hintText: 'Enter your email',
                      keyboardType: TextInputType.emailAddress,
                      prefixIcon: Icons.email_outlined,
                    ),

                    const SizedBox(height: 16), // Reduced from 20

                    // Password field
                    _buildInputLabel('Password'),
                    const SizedBox(height: 4), // Reduced from 8
                    _buildTextField(
                      controller: _passwordController,
                      hintText: 'Create a password',
                      isPassword: true,
                      passwordVisibility: isPasswordVisible,
                      onPasswordVisibilityChanged: (value) {
                        setState(() {
                          isPasswordVisible = value;
                        });
                      },
                      prefixIcon: Icons.lock_outline,
                    ),

                    const SizedBox(height: 16), // Reduced from 20

                    // Confirm Password field
                    _buildInputLabel('Confirm Password'),
                    const SizedBox(height: 4), // Reduced from 8
                    _buildTextField(
                      controller: _confirmPasswordController,
                      hintText: 'Confirm your password',
                      isPassword: true,
                      passwordVisibility: isConfirmPasswordVisible,
                      onPasswordVisibilityChanged: (value) {
                        setState(() {
                          isConfirmPasswordVisible = value;
                        });
                      },
                      prefixIcon: Icons.lock_outline,
                    ),

                    // Forgot Password link
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const ForgotPasswordScreen(),
                            ),
                          );
                        },
                        style: TextButton.styleFrom(
                          minimumSize: Size.zero,
                          padding: const EdgeInsets.symmetric(
                              vertical: 4, horizontal: 8), // Reduced padding
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          'Forgot password?',
                          style: TextStyle(
                            color: theme.colorScheme.secondary,
                            fontWeight: FontWeight.w500,
                            fontSize: 13, // Slightly smaller font
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16), // Reduced from 30

                    // Sign Up Button
                    ElevatedButton(
                      onPressed: isLoading ? null : _signUp,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: customColors!.textPrimary,
                        foregroundColor: theme.colorScheme.onPrimary,
                        padding: const EdgeInsets.symmetric(
                            vertical: 14), // Reduced from 16
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: isLoading
                          ? SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  theme.colorScheme.onPrimary,
                                ),
                              ),
                            )
                          : Text(
                              "Sign Up",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.onPrimary,
                              ),
                            ),
                    ),

                    const SizedBox(height: 16), // Reduced from 24

                    // OR divider with reduced height
                    Row(
                      children: [
                        Expanded(
                          child: Divider(
                            color: customColors.textPrimary.withOpacity(0.2),
                            thickness: 1,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12), // Reduced from 16
                          child: Text(
                            'OR',
                            style: TextStyle(
                              color: customColors.textPrimary.withOpacity(0.6),
                              fontWeight: FontWeight.w500,
                              fontSize: 13, // Slightly smaller font
                            ),
                          ),
                        ),
                        Expanded(
                          child: Divider(
                            color: customColors.textPrimary.withOpacity(0.2),
                            thickness: 1,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16), // Reduced from 24

                    // Google Sign In Button
                    OutlinedButton.icon(
                      onPressed: isLoading ? null : _nativeGoogleSignIn,
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                            color: customColors.textPrimary.withOpacity(0.3)),
                        padding: const EdgeInsets.symmetric(
                            vertical: 12), // Reduced from 14
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: SvgPicture.asset(
                        "assets/icons/Google.svg",
                        width: 20,
                        height: 20,
                      ),
                      label: Text(
                        'Continue with Google',
                        style: TextStyle(
                          color: customColors.textPrimary.withOpacity(0.8),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),

                    if (Platform.isIOS) ...[
                      const SizedBox(height: 12), // Reduced from 16

                      // Apple Sign In Button - only show on iOS
                      OutlinedButton.icon(
                        onPressed: isLoading ? null : _signInWithApple,
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                              color: customColors.textPrimary.withOpacity(0.3)),
                          padding: const EdgeInsets.symmetric(
                              vertical: 12), // Reduced from 14
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: Icon(
                          Icons.apple,
                          size: 22,
                          color: customColors.textPrimary,
                        ),
                        label: Text(
                          'Continue with Apple',
                          style: TextStyle(
                            color: customColors.textPrimary.withOpacity(0.8),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 16), // Reduced from 20

                    // Login prompt with slightly smaller text
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Already have an account? ',
                          style: TextStyle(
                            color: customColors.textPrimary.withOpacity(0.7),
                            fontSize: 13, // Slightly smaller font
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            Navigator.of(context).pushReplacement(
                              MaterialPageRoute(
                                builder: (context) => const LoginScreen(),
                              ),
                            );
                          },
                          child: Text(
                            'Login',
                            style: TextStyle(
                              color: theme.colorScheme.secondary,
                              fontWeight: FontWeight.w600,
                              fontSize: 13, // Slightly smaller font
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16), // Reduced from 40
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputLabel(String label) {
    final customColors = Theme.of(context).extension<CustomColors>();
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        label,
        style: AppTypography.inputLabel.copyWith(
          color: customColors!.textPrimary,
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    IconData? prefixIcon,
    bool isPassword = false,
    bool? passwordVisibility,
    Function(bool)? onPasswordVisibilityChanged,
    TextInputType keyboardType = TextInputType.text,
  }) {
    final customColors = Theme.of(context).extension<CustomColors>();
    return TextFormField(
      controller: controller,
      obscureText: isPassword && !(passwordVisibility ?? false),
      keyboardType: keyboardType,
      style: AppTypography.inputText.copyWith(
        color: customColors!.textPrimary,
      ),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: AppTypography.inputHint.copyWith(
          color: customColors.textPrimary.withOpacity(0.5),
        ),
        filled: true,
        fillColor: Theme.of(context).cardColor,
        prefixIcon: prefixIcon != null
            ? Icon(
                prefixIcon,
                color: customColors.textPrimary.withOpacity(0.5),
                size: 22,
              )
            : null,
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  (passwordVisibility ?? false)
                      ? Icons.visibility
                      : Icons.visibility_off,
                  color: Theme.of(context).primaryColor.withOpacity(0.5),
                  size: 22,
                ),
                onPressed: () {
                  onPasswordVisibilityChanged
                      ?.call(!(passwordVisibility ?? false));
                },
              )
            : null,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            width: 1,
            color: Theme.of(context).primaryColor.withOpacity(0.1),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            width: 1.5,
            color: Theme.of(context).colorScheme.secondary,
          ),
        ),
      ),
    );
  }
}
