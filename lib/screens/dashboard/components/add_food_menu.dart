import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../screens/askAI.dart';
import '../../../screens/saved_foods_screen.dart';
import '../../../screens/searchPage.dart';

/// A slide-up modal menu for adding food with multiple options.
/// Shows options for Saved foods, Search database, and AI search.
class AddFoodMenu extends StatelessWidget {
  const AddFoodMenu({super.key});

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 1),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: ModalRoute.of(context)!.animation!,
        curve: Curves.easeOutCubic,
      )),
      child: FadeTransition(
        opacity: ModalRoute.of(context)!.animation!,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            margin: EdgeInsets.fromLTRB(20, 0, 20, screenHeight * 0.07),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: Theme.of(context).brightness == Brightness.light
                        ? [
                            Colors.white.withOpacity(0.9),
                            Colors.grey.shade50.withOpacity(0.8),
                          ]
                        : [
                            Colors.grey.shade900.withOpacity(0.6),
                            Colors.grey.shade900.withOpacity(0.8),
                          ],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Theme.of(context).brightness == Brightness.light
                        ? Colors.white.withOpacity(0.5)
                        : Colors.grey.shade800.withOpacity(0.5),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 20,
                      spreadRadius: 0,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        const SizedBox(width: 40),
                        Expanded(
                          child: Center(
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: Theme.of(context).brightness == Brightness.light
                                      ? [
                                          Colors.white.withOpacity(0.9),
                                          Colors.grey.shade50.withOpacity(0.8),
                                        ]
                                      : [
                                          Colors.grey.shade900.withOpacity(0.6),
                                          Colors.grey.shade900.withOpacity(0.8),
                                        ],
                                ),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Theme.of(context).brightness == Brightness.light
                                      ? Colors.black.withOpacity(0.8)
                                      : Colors.white.withOpacity(0.1),
                                  width: 1,
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                child: Text(
                                  'Add Food',
                                  style: GoogleFonts.poppins(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: Theme.of(context).brightness == Brightness.light
                                        ? Colors.black87
                                        : Colors.white,
                                    decoration: TextDecoration.none,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Material(
                          color: Colors.transparent.withOpacity(0.4),
                          borderRadius: BorderRadius.circular(16),
                          child: InkWell(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              Navigator.pop(context);
                            },
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: Theme.of(context).brightness == Brightness.light
                                      ? [
                                          Colors.white.withOpacity(0.9),
                                          Colors.grey.shade50.withOpacity(0.8),
                                        ]
                                      : [
                                          Colors.grey.shade900.withOpacity(0.6),
                                          Colors.grey.shade900.withOpacity(0.8),
                                        ],
                                ),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Theme.of(context).brightness == Brightness.light
                                      ? Colors.black.withOpacity(0.8)
                                      : Colors.white.withOpacity(0.1),
                                  width: 1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Theme.of(context).brightness == Brightness.light
                                        ? Colors.black.withOpacity(0.1)
                                        : Colors.black.withOpacity(0.2),
                                    blurRadius: 15,
                                    spreadRadius: 0,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Icon(
                                CupertinoIcons.xmark,
                                color: Theme.of(context).brightness == Brightness.light
                                    ? Colors.grey.shade900
                                    : Colors.grey.shade300,
                                size: 24,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildMenuButton(
                            context: context,
                            icon: CupertinoIcons.bookmark,
                            title: 'Saved',
                            subtitle: 'Your foods',
                            color: Theme.of(context).brightness == Brightness.light
                                ? Colors.grey.shade900
                                : Colors.grey.shade300,
                            onTap: () {
                              Navigator.pop(context);
                              Navigator.pushNamed(context, '/savedFoods');
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildMenuButton(
                            context: context,
                            icon: CupertinoIcons.search,
                            title: 'Search',
                            subtitle: 'Database',
                            color: Theme.of(context).brightness == Brightness.light
                                ? Colors.grey.shade900
                                : Colors.grey.shade300,
                            onTap: () {
                              Navigator.pop(context);
                              Navigator.push(
                                context,
                                CupertinoPageRoute(
                                  builder: (context) => const FoodSearchPage(),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildMenuButton(
                            context: context,
                            icon: Icons.auto_awesome,
                            title: 'AI',
                            subtitle: 'search',
                            color: Theme.of(context).brightness == Brightness.light
                                ? Colors.grey.shade900
                                : Colors.grey.shade300,
                            onTap: () {
                              Navigator.pop(context);
                              Navigator.push(
                                context,
                                CupertinoPageRoute(
                                  builder: (context) => const Askai(),
                                ),
                              );
                            },
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
      ),
    );
  }

  Widget _buildMenuButton({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent.withOpacity(0.4),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: Theme.of(context).brightness == Brightness.light
                  ? [
                      Colors.white.withOpacity(0.9),
                      Colors.grey.shade50.withOpacity(0.8),
                    ]
                  : [
                      Colors.grey.shade900.withOpacity(0.6),
                      Colors.grey.shade900.withOpacity(0.8),
                    ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Theme.of(context).brightness == Brightness.light
                  ? Colors.black.withOpacity(0.8)
                  : Colors.white.withOpacity(0.1),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Theme.of(context).brightness == Brightness.light
                    ? Colors.black.withOpacity(0.1)
                    : Colors.black.withOpacity(0.2),
                blurRadius: 15,
                spreadRadius: 0,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 44,
                child: Icon(
                  icon,
                  color: color,
                  size: 22,
                ),
              ),
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).brightness == Brightness.light
                      ? Colors.black87
                      : Colors.white.withOpacity(0.95),
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w400,
                  color: Theme.of(context).brightness == Brightness.light
                      ? Colors.grey.shade600
                      : Colors.grey.shade400,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shows the add food menu as a slide-up dialog.
void showAddFoodMenu(BuildContext context) {
  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: '',
    transitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (context, animation1, animation2) => Container(),
    transitionBuilder: (context, animation1, animation2, child) {
      return Stack(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              color: Colors.black.withOpacity(0.3),
            ),
          ),
          SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 1),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation1,
              curve: Curves.easeOutCubic,
            )),
            child: FadeTransition(
              opacity: animation1,
              child: const AddFoodMenu(),
            ),
          ),
        ],
      );
    },
  );
}
