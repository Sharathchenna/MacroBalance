import 'package:flutter/material.dart';
import 'package:macrotracker/theme/typography.dart';

class SearchHeader extends StatelessWidget {
  final TextEditingController controller;
  final Function(String) onSearch;
  final Function(String) onChanged;
  final VoidCallback onBack;

  const SearchHeader({
    super.key,
    required this.controller,
    required this.onSearch,
    required this.onChanged,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: const BoxDecoration(
        color: Colors.transparent,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTopBar(context),
          const SizedBox(height: 16),
          _buildSearchField(context),
        ],
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Center title
        Positioned.fill(
          child: Center(
            child: Text(
              'Search Foods',
              style: AppTypography.h1.copyWith(
                color: Theme.of(context).primaryColor,
                fontSize: 24,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.5,
              ),
            ),
          ),
        ),
        // Back button aligned to the left
        Align(
          alignment: Alignment.centerLeft,
          child: _buildBackButton(context),
        ),
      ],
    );
  }

  Widget _buildBackButton(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(
          Icons.chevron_left_rounded,
          size: 24,
          color: Theme.of(context).primaryColor,
        ),
        onPressed: onBack,
        padding: EdgeInsets.zero,
      ),
    );
  }

  Widget _buildSearchField(BuildContext context) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            offset: const Offset(0, 2),
            blurRadius: 8,
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        style: AppTypography.body1.copyWith(
          color: Theme.of(context).primaryColor,
          fontSize: 16,
        ),
        decoration: InputDecoration(
          hintText: 'Search foods...',
          hintStyle: AppTypography.body1.copyWith(
            color: Theme.of(context).primaryColor.withValues(alpha: 0.5),
            fontSize: 16,
          ),
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 16, right: 8),
            child: Icon(
              Icons.search_rounded,
              color: Theme.of(context).primaryColor.withValues(alpha: 0.7),
              size: 24,
            ),
          ),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
          suffixIcon: controller.text.isNotEmpty
              ? IconButton(
                  icon: Icon(
                    Icons.clear_rounded,
                    color:
                        Theme.of(context).primaryColor.withValues(alpha: 0.5),
                    size: 20,
                  ),
                  onPressed: () {
                    controller.clear();
                    onChanged('');
                  },
                )
              : null,
        ),
        onSubmitted: onSearch,
        onChanged: onChanged,
        textAlignVertical: TextAlignVertical.center,
      ),
    );
  }
}
