import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/saved_food_provider.dart';
import '../models/saved_food.dart';
import 'foodDetail.dart';
import '../theme/app_theme.dart';
import '../theme/typography.dart';
import '../services/posthog_service.dart';

class SavedFoodsScreen extends StatefulWidget {
  final String? selectedMeal;

  const SavedFoodsScreen({super.key, this.selectedMeal});

  @override
  _SavedFoodsScreenState createState() => _SavedFoodsScreenState();
}

class _SavedFoodsScreenState extends State<SavedFoodsScreen>
    with TickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  List<SavedFood> _filteredSavedFoods = [];
  String _searchQuery = '';
  bool _isLoading = true;
  late AnimationController _animationController;
  late AnimationController _searchAnimationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;
  late Animation<double> _searchFadeAnimation;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    
    _searchAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.8, curve: Curves.easeOutCubic),
      ),
    );

    _slideAnimation = Tween<double>(begin: 40.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.2, 1.0, curve: Curves.easeOutCubic),
      ),
    );

    _searchFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _searchAnimationController,
        curve: Curves.easeOut,
      ),
    );

    _initializeData();
  }

  Future<void> _initializeData() async {
    setState(() {
      _isLoading = true;
    });

    final savedFoodProvider =
        Provider.of<SavedFoodProvider>(context, listen: false);
    if (!savedFoodProvider.isInitialized) {
      await savedFoodProvider.initialize();
    }

    _filterSavedFoods();

    setState(() {
      _isLoading = false;
    });

    _animationController.forward();
    _searchAnimationController.forward();
    PostHogService.trackScreen('saved_foods_screen');
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.toLowerCase();
      _filterSavedFoods();
    });
  }

  void _filterSavedFoods() {
    final savedFoodProvider =
        Provider.of<SavedFoodProvider>(context, listen: false);
    final allSavedFoods = savedFoodProvider.savedFoods;

    if (_searchQuery.isEmpty) {
      _filteredSavedFoods = List.from(allSavedFoods);
    } else {
      _filteredSavedFoods = allSavedFoods.where((savedFood) {
        final name = savedFood.food.name.toLowerCase();
        final brand = savedFood.food.brandName.toLowerCase();
        final notes = savedFood.notes?.toLowerCase() ?? '';

        return name.contains(_searchQuery) ||
            brand.contains(_searchQuery) ||
            notes.contains(_searchQuery);
      }).toList();
    }

    _filteredSavedFoods.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _animationController.dispose();
    _searchAnimationController.dispose();
    super.dispose();
  }

  Future<void> _deleteSavedFood(String savedFoodId) async {
    HapticFeedback.mediumImpact();
    
    final savedFoodProvider =
        Provider.of<SavedFoodProvider>(context, listen: false);
    await savedFoodProvider.removeSavedFood(savedFoodId);

    setState(() {
      _filterSavedFoods();
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white, size: 20),
              const SizedBox(width: 12),
              Text(
                'Food removed from saved foods',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          backgroundColor: Colors.green.shade600,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
        ),
      );
    }

    PostHogService.trackEvent('delete_saved_food');
  }

  void _navigateToFoodDetail(SavedFood savedFood) {
    HapticFeedback.selectionClick();
    
    final searchFoodItem = savedFood.toSearchPageFoodItem();

    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => FoodDetailPage(
          food: searchFoodItem,
          selectedMeal: widget.selectedMeal,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(1.0, 0.0);
          const end = Offset.zero;
          const curve = Curves.easeInOutCubic;

          var tween = Tween(begin: begin, end: end).chain(
            CurveTween(curve: curve),
          );

          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final customColors = Theme.of(context).extension<CustomColors>();
    final colorScheme = Theme.of(context).colorScheme;
    
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 140,
            floating: false,
            pinned: true,
            elevation: 0,
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: customColors?.cardBackground?.withValues(alpha: 0.8),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.arrow_back_ios_new,
                  color: customColors?.textPrimary,
                  size: 18,
                ),
              ),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              title: AnimatedBuilder(
                animation: _fadeAnimation,
                builder: (context, child) {
                  return Opacity(
                    opacity: _fadeAnimation.value,
                    child: Text(
                      'Saved Foods',
                      style: GoogleFonts.poppins(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: customColors?.textPrimary,
                      ),
                    ),
                  );
                },
              ),
              centerTitle: true,
              titlePadding: const EdgeInsets.only(bottom: 16),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Theme.of(context).scaffoldBackgroundColor,
                      Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.8),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: AnimatedBuilder(
              animation: _searchFadeAnimation,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(0, 20 * (1 - _searchFadeAnimation.value)),
                  child: Opacity(
                    opacity: _searchFadeAnimation.value,
                    child: _buildSearchBar(customColors, colorScheme),
                  ),
                );
              },
            ),
          ),
          Consumer<SavedFoodProvider>(
            builder: (context, savedFoodProvider, child) {
              if (_isLoading || savedFoodProvider.isLoading) {
                return SliverToBoxAdapter(
                  child: Center(child: _buildLoadingState()),
                );
              }

              _filterSavedFoods();

              if (_filteredSavedFoods.isEmpty) {
                return SliverToBoxAdapter(
                  child: Center(child: _buildEmptyState(customColors)),
                );
              }

              return SliverToBoxAdapter(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 600),
                    child: Column(
                      children: _filteredSavedFoods.asMap().entries.map((entry) {
                        final index = entry.key;
                        final savedFood = entry.value;
                        return _buildFoodCard(savedFood, index, customColors, colorScheme);
                      }).toList(),
                    ),
                  ),
                ),
              );
            },
          ),
          const SliverToBoxAdapter(
            child: SizedBox(height: 100), // Bottom padding
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(CustomColors? customColors, ColorScheme colorScheme) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Container(
          margin: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      decoration: BoxDecoration(
        color: customColors?.cardBackground,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).brightness == Brightness.light
                ? Colors.grey.shade300.withValues(alpha: 0.6)
                : Colors.black.withValues(alpha: 0.2),
            blurRadius: 16,
            spreadRadius: 0,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search your saved foods...',
          hintStyle: GoogleFonts.poppins(
            color: customColors?.textSecondary,
            fontSize: 16,
            fontWeight: FontWeight.w400,
          ),
          prefixIcon: Container(
            padding: const EdgeInsets.all(12),
            child: Icon(
              Icons.search_rounded,
              color: colorScheme.primary,
              size: 22,
            ),
          ),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.close,
                      color: colorScheme.primary,
                      size: 16,
                    ),
                  ),
                  onPressed: () {
                    _searchController.clear();
                    HapticFeedback.selectionClick();
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 18,
          ),
        ),
                 style: GoogleFonts.poppins(
           color: customColors?.textPrimary,
           fontSize: 16,
           fontWeight: FontWeight.w500,
         ),
       ),
     ),
   ),
 );
}

  Widget _buildLoadingState() {
    return Container(
      height: 400,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(
                  Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Loading your saved foods...',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Theme.of(context).extension<CustomColors>()?.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFoodCard(SavedFood savedFood, int index, CustomColors? customColors, ColorScheme colorScheme) {
    final food = savedFood.food;
    
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        final delay = index * 0.1;
        final animationValue = Tween<double>(
          begin: 0.0,
          end: 1.0,
        ).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Interval(
              delay.clamp(0.0, 0.8),
              (delay + 0.3).clamp(0.0, 1.0),
              curve: Curves.easeOutCubic,
            ),
          ),
        );

        return Transform.translate(
          offset: Offset(0, _slideAnimation.value * (1 - animationValue.value)),
          child: Opacity(
            opacity: animationValue.value,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Dismissible(
                key: Key(savedFood.id),
                direction: DismissDirection.endToStart,
                background: _buildDismissBackground(colorScheme),
                confirmDismiss: (direction) async {
                  HapticFeedback.heavyImpact();
                  return true;
                },
                onDismissed: (direction) => _deleteSavedFood(savedFood.id),
                child: Container(
                  decoration: BoxDecoration(
                    color: customColors?.cardBackground,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Theme.of(context).brightness == Brightness.light
                            ? Colors.grey.shade300.withValues(alpha: 0.5)
                            : Colors.black.withValues(alpha: 0.15),
                        blurRadius: 20,
                        spreadRadius: 0,
                        offset: const Offset(0, 6),
                      ),
                    ],
                    border: Border.all(
                      color: Theme.of(context).brightness == Brightness.light
                          ? Colors.grey.withValues(alpha: 0.08)
                          : Colors.white.withValues(alpha: 0.05),
                      width: 0.5,
                    ),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _navigateToFoodDetail(savedFood),
                      borderRadius: BorderRadius.circular(20),
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildFoodHeader(food, customColors, colorScheme),
                            const SizedBox(height: 16),
                            _buildMacroRow(food, customColors, colorScheme),
                            if (savedFood.notes?.isNotEmpty == true) ...[
                              const SizedBox(height: 12),
                              _buildNotesSection(savedFood.notes!, customColors),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDismissBackground(ColorScheme colorScheme) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.red.shade400,
            Colors.red.shade600,
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.delete_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Remove',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFoodHeader(dynamic food, CustomColors? customColors, ColorScheme colorScheme) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                colorScheme.primary.withValues(alpha: 0.1),
                colorScheme.primary.withValues(alpha: 0.05),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: colorScheme.primary.withValues(alpha: 0.1),
              width: 1,
            ),
          ),
          child: Icon(
            Icons.restaurant_rounded,
            color: colorScheme.primary,
            size: 22,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                food.name,
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: customColors?.textPrimary,
                  height: 1.2,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (food.brandName.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  food.brandName,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: customColors?.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Colors.green.withValues(alpha: 0.2),
              width: 0.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.bookmark_rounded,
                size: 12,
                color: Colors.green.shade600,
              ),
              const SizedBox(width: 4),
              Text(
                'Saved',
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Colors.green.shade600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMacroRow(dynamic food, CustomColors? customColors, ColorScheme colorScheme) {
    final macros = [
      {'label': 'Cal', 'value': food.calories.toInt().toString(), 'icon': Icons.local_fire_department_rounded, 'color': Colors.orange},
      {'label': 'Protein', 'value': '${food.protein.toInt()}g', 'icon': Icons.fitness_center_rounded, 'color': Colors.blue},
      {'label': 'Carbs', 'value': '${food.carbs.toInt()}g', 'icon': Icons.grain_rounded, 'color': Colors.green},
      {'label': 'Fat', 'value': '${food.fat.toInt()}g', 'icon': Icons.opacity_rounded, 'color': Colors.purple},
    ];

    return Row(
      children: macros.map((macro) {
        final isLast = macro == macros.last;
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: isLast ? 0 : 8),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            decoration: BoxDecoration(
              color: (macro['color'] as Color).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: (macro['color'] as Color).withValues(alpha: 0.15),
                width: 0.5,
              ),
            ),
            child: Column(
              children: [
                Icon(
                  macro['icon'] as IconData,
                  size: 18,
                  color: macro['color'] as Color,
                ),
                const SizedBox(height: 6),
                Text(
                  macro['value'] as String,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: customColors?.textPrimary,
                  ),
                ),
                Text(
                  macro['label'] as String,
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: customColors?.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildNotesSection(String notes, CustomColors? customColors) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: customColors?.textSecondary?.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: customColors?.textSecondary?.withValues(alpha: 0.1) ?? Colors.grey.withValues(alpha: 0.1),
          width: 0.5,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.note_alt_rounded,
            size: 16,
            color: customColors?.textSecondary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              notes,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: customColors?.textSecondary,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(CustomColors? customColors) {
    return AnimatedBuilder(
      animation: _fadeAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - _fadeAnimation.value)),
          child: Opacity(
            opacity: _fadeAnimation.value,
            child: Container(
              height: 500,
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                          Theme.of(context).colorScheme.primary.withValues(alpha: 0.05),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Icon(
                      _searchQuery.isEmpty ? Icons.bookmark_border_rounded : Icons.search_off_rounded,
                      size: 48,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    _searchQuery.isEmpty
                        ? 'No Saved Foods Yet'
                        : 'No Results Found',
                    style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: customColors?.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _searchQuery.isEmpty
                        ? 'Save your favorite foods for quick access during meal logging. Look for the bookmark icon when viewing food details.'
                        : 'Try adjusting your search terms or check the spelling.',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                      color: customColors?.textSecondary,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (_searchQuery.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    TextButton.icon(
                      onPressed: () {
                        _searchController.clear();
                        HapticFeedback.selectionClick();
                      },
                      icon: const Icon(Icons.clear_rounded),
                      label: Text(
                        'Clear Search',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
} 