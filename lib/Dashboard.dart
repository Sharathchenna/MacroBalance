// ignore_for_file: file_names

import 'package:flutter/material.dart';

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  @override
  Widget build(BuildContext context) {
    return  Scaffold(
        body: Stack(
          children: [
            // Green Header
            Container(
              height: 300, // Adjust height as needed
              decoration: const BoxDecoration(
                color: Color(0xFFA1CE4F),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
                child: Transform.translate(
                  offset: const Offset(0, -50), // Adjust upward shift as needed
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Left Icon
                      Image.asset(
                        'assets/images/left_icon.png', // Replace with your asset path
                        height: 40,
                        width: 40,
                      ),
                      // Center Text
                      const Text(
                        'FitBit',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      // Right Icon with Notification Dot
                      Stack(
                        alignment: Alignment.topRight,
                        children: [
                          Image.asset(
                            'assets/images/right_icon.png', // Replace with your asset path
                            height: 40,
                            width: 40,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // White Body
            Positioned.fill(
            top: 150, // Adjust this value to align with the green header
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(30), // Adjust radius as needed
                  topRight: Radius.circular(30),
                ),
              ),
            ),
          ),
          ],
        ),
      );
  }
}