// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _supabase = Supabase.instance.client;
  bool isPasswordVisible = false; // Toggles password visibility
  bool isLoading = false; // Add this line

  Future<void> _login() async {
    setState(() {
      isLoading = true; // Start loading
    });

    try {
      final response = await _supabase.auth.signInWithPassword(
        email: _emailController.text,
        password: _passwordController.text,
      );
      if (response.user != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Login successful!')),
        );
      }
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${error.toString()}')),
      );
    } finally {
      setState(() {
        isLoading = false; // Stop loading
      });
    }
  }

  Future<void> _nativeGoogleSignIn() async {
    try {
      /// Web Client ID that you registered with Google Cloud.
      const webClientId = '362662407469-tq90edhg69p21s816herauenvckhbes6.apps.googleusercontent.com';
      /// iOS Client ID that you registered with Google Cloud.
      const iosClientId = '362662407469-vntsu0nvlv04mrk01bsusddqdtunq154.apps.googleusercontent.com';

      final GoogleSignIn googleSignIn = GoogleSignIn(
        clientId: iosClientId,
        serverClientId: webClientId,
      );
      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        // Sign in aborted.
        return;
      }
      final googleAuth = await googleUser.authentication;
      final accessToken = googleAuth.accessToken;
      final idToken = googleAuth.idToken;

      if (accessToken == null) {
        throw 'No Access Token found.';
      }
      if (idToken == null) {
        throw 'No ID Token found.';
      }

      await _supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );
    } catch (error) {
      // Log error or show error message.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Google sign-in error: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 50),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Login',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF292929),
                fontSize: 30,
                fontFamily: 'Hamon',
                fontWeight: FontWeight.w700,
                height: 2,
                letterSpacing: 0.90,
              ),
            ),
            Padding(
              padding: EdgeInsets.only(left: 20, top: 70),
              child: const Text(
                'Email',
                style: TextStyle(
                  color: Color(0xFF292929),
                  fontSize: 16.43,
                  fontFamily: 'Hamon',
                  fontWeight: FontWeight.w400,
                  height: 1.57,
                  letterSpacing: 0.82,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: EdgeInsets.only(left: 10, right: 10),
              child: TextFormField(
                controller: _emailController,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Color(0xFFFCFCFC),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(width: 1.17, color: Color(0xFFD1D1D1)),
                    borderRadius: BorderRadius.circular(17.60),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(width: 1.17, color: Color(0xFFD1D1D1)),
                    borderRadius: BorderRadius.circular(17.60),
                  ),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
            ),
            SizedBox(height: 10),
            Padding(
              padding: EdgeInsets.only(left: 20),
              child: const Text(
                'Enter your password',
                style: TextStyle(
                  color: Color(0xFF292929),
                  fontSize: 16.43,
                  fontFamily: 'Hamon',
                  fontWeight: FontWeight.w400,
                  height: 1.57,
                  letterSpacing: 0.82,
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.only(left: 10, right: 10),
              child: TextFormField(
                controller: _passwordController,
                obscureText: !isPasswordVisible,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Color(0xFFFCFCFC),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(width: 1.17, color: Color(0xFFD1D1D1)),
                    borderRadius: BorderRadius.circular(17.60),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(width: 1.17, color: Color(0xFFD1D1D1)),
                    borderRadius: BorderRadius.circular(17.60),
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(isPasswordVisible
                        ? Icons.visibility
                        : Icons.visibility_off),
                    onPressed: () {
                      setState(() {
                        isPasswordVisible = !isPasswordVisible;
                      });
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(height: 2),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {},
                child: const Text(
                  'forgot password?',
                  style: TextStyle(
                    color: Color(0xFF292929),
                    fontSize: 16.43,
                    fontFamily: 'Hamon',
                    fontWeight: FontWeight.w400,
                    height: 1.57,
                    letterSpacing: 0.82,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: () {
                _login();
              },
              child: Container(
                width: 352,
                height: 56.32,
                decoration: ShapeDecoration(
                  color: const Color(0xFF151515),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(17.60),
                  ),
                ),
                alignment: Alignment.center,
                child: isLoading
                    ? CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      )
                    : const Text(
                        "Login",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center, // Center aligns the text
              children: const [
                Text(
                  'or',
                  style: TextStyle(
                    color: Color(0xFF696969),
                    fontSize: 16.43,
                    fontFamily: 'Hamon',
                    fontWeight: FontWeight.w700,
                  ),
                )
              ],
            ),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: () {
                _nativeGoogleSignIn();
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 15),
                decoration: ShapeDecoration(
                  color: const Color(0xFFFCFCFC),
                  shape: RoundedRectangleBorder(
                    side: const BorderSide(width: 1.17, color: Color(0xFFD1D1D1)),
                    borderRadius: BorderRadius.circular(17.60),
                  ),
                ),
                alignment: Alignment.center,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Ensure flutter_svg is added in your pubspec.yaml dependencies.
                    SvgPicture.asset(
                      "assets/icons/Google.svg",
                      width: 24,
                      height: 24,
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'Continue with Google',
                      style: TextStyle(
                        color: Color(0xFF292929),
                        fontSize: 16.43,
                        fontFamily: 'Hamon',
                        fontWeight: FontWeight.w400,
                        height: 1,
                      ),
                    )
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            
          ],
        ),
      ),
    );
  }
}