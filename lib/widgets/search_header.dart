import 'package:flutter/material.dart';
import 'package:macrotracker/theme/app_theme.dart';
import 'package:macrotracker/theme/typography.dart';
import 'package:macrotracker/camera/camera.dart';

class SearchHeader extends StatelessWidget {
  final TextEditingController controller;
  final Function(String) onSearch;
  final Function(String) onChanged;
  final VoidCallback onBack;

  const SearchHeader({
    Key? key,
    required this.controller,
    required this.onSearch,
    required this.onChanged,
    required this.onBack,
  }) : super(key: key);

  void _navigateToCameraScreen(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const CameraScreen(),
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
                    onTap: onBack,
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
            ],
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    onChanged: onChanged,
                    onSubmitted: onSearch,
                    textInputAction: TextInputAction.search,
                    style: AppTypography.body1.copyWith(
                      color: customColors.textPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search foods, recipes, brands...',
                      hintStyle: AppTypography.body1.copyWith(
                        color: customColors.textPrimary.withOpacity(0.5),
                      ),
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        color: customColors.textPrimary.withOpacity(0.7),
                      ),
                      suffixIcon: controller.text.isNotEmpty
                          ? IconButton(
                              icon: Icon(
                                Icons.close_rounded,
                                color:
                                    customColors.textPrimary.withOpacity(0.7),
                              ),
                              onPressed: () {
                                controller.clear();
                                onChanged('');
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: const BorderRadius.horizontal(
                        right: Radius.circular(16)),
                    onTap: () => _navigateToCameraScreen(context),
                    child: Container(
                      height: 56,
                      width: 48,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            customColors.accentPrimary.withOpacity(0.05),
                            customColors.accentPrimary.withOpacity(0.15)
                          ],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        borderRadius: const BorderRadius.horizontal(
                            right: Radius.circular(16)),
                      ),
                      child: Center(
                        child: Icon(
                          Icons.camera_alt_rounded,
                          color: customColors.accentPrimary,
                          size: 22,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
