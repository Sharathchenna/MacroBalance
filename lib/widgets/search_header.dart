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
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            offset: const Offset(0, 2),
            blurRadius: 8,
            spreadRadius: 0,
          ),
        ],
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
    return Row(
      children: [
        _buildBackButton(context),
        const SizedBox(width: 16),
        Text(
          'Search Foods',
          style: AppTypography.h1.copyWith(
            color: Theme.of(context).primaryColor,
          ),
        ),
      ],
    );
  }

  Widget _buildBackButton(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: IconButton(
        icon: Icon(
          Icons.arrow_back_ios_rounded,
          size: 18,
          color: Theme.of(context).primaryColor,
        ),
        onPressed: onBack,
      ),
    );
  }

  Widget _buildSearchField(BuildContext context) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            offset: const Offset(0, 2),
            blurRadius: 5,
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        style: AppTypography.body1.copyWith(
          color: Theme.of(context).primaryColor,
        ),
        decoration: InputDecoration(
          hintText: 'Search foods...',
          hintStyle: AppTypography.body1.copyWith(
            color: Theme.of(context).primaryColor.withOpacity(0.5),
          ),
          prefixIcon: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Icon(
              Icons.search_rounded,
              color: Theme.of(context).primaryColor.withOpacity(0.7),
              size: 24,
            ),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        ),
        onSubmitted: onSearch,
        onChanged: onChanged,
      ),
    );
  }
}
