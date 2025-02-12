import 'package:flutter/material.dart';
import 'package:macrotracker/loginscreen.dart';
import 'package:macrotracker/signup.dart';

class Welcomescreen extends StatelessWidget {
  const Welcomescreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(48, 361, 34, 361),
              child: SizedBox(
                width: 302,
                child: Text(
                  'Commit to your workout and watch your goals take shape',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: const Color(0xFF1C1C1C),
                    fontSize: 23,
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w400,
                    height: 1.30,
                  ),
                ),
              ),
            ),
          ),
          Positioned( 
            bottom: MediaQuery.of(context).size.height * 0.1, // Adjust this value to move up/down
            left: 15,
            right: 0,
            child: Center(
              child: TextButton(
                onPressed: () {
                  Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => Signup()),
                );
                },
                child: Container(
                  width: 295,
                  height: 50,
                  decoration: ShapeDecoration(
                    color: const Color(0xFF0076B8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Center(
                    child: Text(
                      'Create Account',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Positioned(
                left: 40,
                top: 725, // Original position below Create Account button
                child: TextButton(
                  onPressed: () {
                    Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => LoginScreen()),
                );
                  },
                  child: Container(
                    width: 295,
                    height: 50,
                    padding: const EdgeInsets.symmetric(vertical: 12), // Simplified padding
                    decoration: ShapeDecoration(
                      shape: RoundedRectangleBorder(
                        side: const BorderSide(width: 1, color: Color(0xFF0076B8)),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'Login',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFF0076B8),
                        fontSize: 16,
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w400,
                      ),
                    ),
    ),
  ),
),

        ],
      ),
    );
  }
}
