import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:macrotracker/theme/app_theme.dart';
import 'package:macrotracker/theme/typography.dart';
// import 'package:macrotracker/camera/camera.dart'; // Removed import
import 'package:macrotracker/screens/askAI.dart';

class SearchHeader extends StatefulWidget {
  final TextEditingController controller;
  final Function(String) onSearch;
  final Function(String) onChanged;
  final VoidCallback onBack;
  final VoidCallback onCameraTap; // Added camera tap callback

  const SearchHeader({
    super.key,
    required this.controller,
    required this.onSearch,
    required this.onChanged,
    required this.onBack,
    required this.onCameraTap, // Make it required
  });

  @override
  State<SearchHeader> createState() => _SearchHeaderState();
}

class _SearchHeaderState extends State<SearchHeader> {
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  // Removed _navigateToCameraScreen method

  void _navigateToAskAI(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const Askai(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final customColors = Theme.of(context).extension<CustomColors>();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Hero(
                tag: 'back_button',
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: widget.onBack,
                    borderRadius: BorderRadius.circular(40),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      child: Icon(
                        Icons.arrow_back_ios_rounded,
                        size: 16,
                        color: customColors!.textPrimary,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  'Find Foods',
                  style: AppTypography.h2.copyWith(
                    color: customColors.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              // Camera button
              // Material(
              //   color: Colors.transparent,
              //   child: InkWell(
              //     borderRadius: BorderRadius.circular(40),
              //     onTap: () {
              //       HapticFeedback.lightImpact();
              //       widget.onCameraTap(); // Call the passed callback
              //     },
              //     child: Container(
              //       padding: const EdgeInsets.all(8),
              //       child: Icon(
              //         CupertinoIcons.camera,
              //         size: 25,
              //         color: const Color(0xFFFFC107),
              //       ),
              //     ),
              //   ),
              // ),
              const SizedBox(width: 8),
              // AI button
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(40),
                  onTap: () {
                    HapticFeedback.lightImpact();
                    _navigateToAskAI(context);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    child: Image.asset(
                      'assets/icons/AI Icon.png',
                      width: 25,
                      height: 25,
                      color: const Color(0xFFFFC107),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(((0.05) * 255).round()),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: TextField(
              controller: widget.controller,
              focusNode: _focusNode,
              onChanged: widget.onChanged,
              onSubmitted: widget.onSearch,
              textInputAction: TextInputAction.search,
              style: AppTypography.body1.copyWith(
                color: customColors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                hintText: 'Search foods, recipes, brands...',
                hintStyle: AppTypography.body1.copyWith(
                  color: customColors.textPrimary.withAlpha(((0.5) * 255).round()),
                ),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: customColors.textPrimary.withAlpha(((0.7) * 255).round()),
                ),
                suffixIcon: widget.controller.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.close_rounded,
                            color: customColors.textPrimary.withAlpha(((0.7) * 255).round())),
                        onPressed: () {
                          widget.controller.clear();
                          // Use the search function with empty string to clear results
                          widget.onSearch('');
                          // Also trigger the onChanged to update suggestions
                          widget.onChanged('');
                          // Clear focus
                          _focusNode.unfocus();
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
