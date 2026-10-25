// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:macrotracker/theme/typography.dart';
import 'package:macrotracker/auth/auth_actions.dart';
import 'package:macrotracker/auth/auth_gate.dart';
import 'package:macrotracker/screens/signup.dart';
import 'package:macrotracker/theme/app_theme.dart';
import 'dart:io';
import 'package:macrotracker/services/auth_service.dart';
import 'package:macrotracker/screens/forgot_password_screen.dart';
import 'package:macrotracker/services/posthog_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final AuthService _authService = AuthService();
  bool isPasswordVisible = false;
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
    
    // Track screen view
    PostHogService.trackScreen('login_screen');
    
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    // Unfocus the keyboard
    FocusScope.of(context).unfocus();

    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter both email and password'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => isLoading = true);
    final result = await AuthActions.signInWithEmail(
      email: _emailController.text,
      password: _passwordController.text,
    );
    if (mounted) setState(() => isLoading = false);
    if (!mounted) return;
    if (result.signedIn) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const AuthGate()),
        (route) => false,
      );
    } else if (result.outcome == AuthOutcome.failed) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${result.message}'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
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
          content: Text('There was a problem signing in with google'),
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
                    const SizedBox(height: 40),
                    Text(
                      'Welcome Back',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: customColors!.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Login to continue tracking your fitness journey',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: customColors!.textPrimary.withOpacity(0.7),
                      ),
                    ),
                    const SizedBox(height: 40),

                    // Email Field
                    _buildInputLabel('Email'),
                    const SizedBox(height: 8),
                    _buildTextField(
                      controller: _emailController,
                      hintText: 'Enter your email',
                      keyboardType: TextInputType.emailAddress,
                      prefixIcon: Icons.email_outlined,
                    ),

                    const SizedBox(height: 20),

                    // Password Field
                    _buildInputLabel('Password'),
                    const SizedBox(height: 8),
                    _buildTextField(
                      controller: _passwordController,
                      hintText: 'Enter your password',
                      isPassword: true,
                      prefixIcon: Icons.lock_outline,
                    ),

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
                              vertical: 8, horizontal: 12),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          'Forgot password?',
                          style: TextStyle(
                            color: theme.colorScheme.secondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 30),

                    // Login Button
                    ElevatedButton(
                      onPressed: isLoading ? null : _login,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: customColors!.textPrimary,
                        foregroundColor: theme.colorScheme.onPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
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
                                    theme.colorScheme.onPrimary),
                              ),
                            )
                          : Text(
                              "Login",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.onPrimary,
                              ),
                            ),
                    ),

                    const SizedBox(height: 24),

                    // Or divider
                    Row(
                      children: [
                        Expanded(
                          child: Divider(
                            color: customColors.textPrimary.withOpacity(0.2),
                            thickness: 1,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            'OR',
                            style: TextStyle(
                              color: customColors.textPrimary.withOpacity(0.6),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Divider(
                            color: theme.primaryColor.withOpacity(0.2),
                            thickness: 1,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Google Sign In Button
                    OutlinedButton.icon(
                      onPressed: isLoading ? null : _nativeGoogleSignIn,
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                            color: customColors.textPrimary.withOpacity(0.3)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
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

                    const SizedBox(height: 16),

                    // Apple Sign In Button - only show on iOS
                    if (Platform.isIOS) ...[
                      OutlinedButton.icon(
                        onPressed: isLoading ? null : _signInWithApple,
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                              color: customColors.textPrimary.withOpacity(0.3)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: Icon(
                          Icons.apple,
                          size: 22,
                          color: theme.primaryColor,
                        ),
                        label: Text(
                          'Continue with Apple',
                          style: TextStyle(
                            color: customColors.textPrimary.withOpacity(0.8),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // Registration prompt
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Don\'t have an account? ',
                          style: TextStyle(
                            color: customColors.textPrimary.withOpacity(0.7),
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            Navigator.of(context).pushReplacement(
                              MaterialPageRoute(
                                builder: (context) => const Signup(),
                              ),
                            );
                          },
                          child: Text(
                            'Sign up',
                            style: TextStyle(
                              color: theme.colorScheme.secondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 40),
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
    TextInputType keyboardType = TextInputType.text,
  }) {
    final customColors = Theme.of(context).extension<CustomColors>();
    return TextFormField(
      controller: controller,
      obscureText: isPassword && !isPasswordVisible,
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
                  isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                  color: Theme.of(context).primaryColor.withOpacity(0.5),
                  size: 22,
                ),
                onPressed: () {
                  setState(() {
                    isPasswordVisible = !isPasswordVisible;
                  });
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
