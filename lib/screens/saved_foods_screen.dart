import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/saved_food_provider.dart';
import '../models/saved_food.dart';
import 'foodDetail.dart';
import '../theme/app_theme.dart';
import '../services/posthog_service.dart';

class SavedFoodsScreen extends StatefulWidget {
  final String? selectedMeal;

  const SavedFoodsScreen({super.key, this.selectedMeal});

  @override
  // ignore: library_private_types_in_public_api
  _SavedFoodsScreenState createState() => _SavedFoodsScreenState();
}

class _SavedFoodsScreenState extends State<SavedFoodsScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  List<SavedFood> _filteredSavedFoods = [];
  String _searchQuery = '';
  bool _isLoading = true;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
    _initializeData();
  }

  Future<void> _initializeData() async {
    setState(() {
      _isLoading = true;
    });

    // Initialize the provider if needed
    final savedFoodProvider =
        Provider.of<SavedFoodProvider>(context, listen: false);
    if (!savedFoodProvider.isInitialized) {
      await savedFoodProvider.initialize();
    }

    // Apply initial filtering
    _filterSavedFoods();

    setState(() {
      _isLoading = false;
    });

    // Track screen view
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

    // Sort by most recent first
    _filteredSavedFoods.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _deleteSavedFood(String savedFoodId) async {
    final savedFoodProvider =
        Provider.of<SavedFoodProvider>(context, listen: false);
    await savedFoodProvider.removeSavedFood(savedFoodId);

    // Re-filter to update the UI
    setState(() {
      _filterSavedFoods();
    });

    // Show a snackbar
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Food removed from saved foods')),
      );
    }

    // Track deletion
    PostHogService.trackEvent('delete_saved_food');
  }

  void _navigateToFoodDetail(SavedFood savedFood) {
    // Convert our model's FoodItem to the SearchPage FoodItem type
    final searchFoodItem = savedFood.toSearchPageFoodItem();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FoodDetailPage(
          food: searchFoodItem,
          selectedMeal: widget.selectedMeal,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved Foods'),
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(72),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Hero(
              tag: 'searchBar',
              child: Material(
                color: Colors.transparent,
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search saved foods...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surface,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      body: Consumer<SavedFoodProvider>(
        builder: (context, savedFoodProvider, child) {
          if (_isLoading || savedFoodProvider.isLoading) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    'Loading your saved foods...',
                    style: PremiumTypography.bodyMedium.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                ],
              ),
            );
          }

          _filterSavedFoods();

          if (_filteredSavedFoods.isEmpty) {
            return FadeTransition(
              opacity: _fadeAnimation,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.bookmark_border,
                        size: 80,
                        color: Theme.of(context).colorScheme.outline,
                      ),
                      const SizedBox(height: 24),
                      Text(
                        _searchQuery.isEmpty
                            ? 'No saved foods yet'
                            : 'No saved foods match "$_searchQuery"',
                        style: PremiumTypography.h4.copyWith(
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      if (_searchQuery.isEmpty) ...[
                        const SizedBox(height: 16),
                        Text(
                          'Save your favorite foods for quick access while logging meals',
                          style: PremiumTypography.bodyMedium.copyWith(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: () {
                            // Navigate to search foods screen
                            Navigator.pop(context);
                          },
                          icon: const Icon(Icons.add),
                          label: const Text('Add Foods'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
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
          }

          return AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: ListView.builder(
              key: ValueKey<String>(_searchQuery),
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: _filteredSavedFoods.length,
              itemBuilder: (context, index) {
                final savedFood = _filteredSavedFoods[index];
                final food = savedFood.food;

                return Dismissible(
                  key: Key(savedFood.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.error,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 24),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.delete,
                              color: Colors.white,
                              size: 28,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Swipe to delete',
                              style: PremiumTypography.bodySmall.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 24),
                      ],
                    ),
                  ),
                  onDismissed: (direction) {
                    _deleteSavedFood(savedFood.id);
                  },
                  child: Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 2,
                    color: Theme.of(context)
                        .colorScheme
                        .surface
                        .withValues(alpha: 0.9),
                    child: InkWell(
                      onTap: () => _navigateToFoodDetail(savedFood),
                      borderRadius: BorderRadius.circular(16),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        food.name,
                                        style: PremiumTypography.h4.copyWith(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurface,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      if (food.brandName.isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          food.brandName,
                                          style: PremiumTypography.bodySmall
                                              .copyWith(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurface
                                                .withValues(alpha: 0.7),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  _MacroChip(
                                    label: 'Calories',
                                    value: food.calories.toInt().toString(),
                                    icon: Icons.local_fire_department,
                                  ),
                                  const SizedBox(width: 8),
                                  _MacroChip(
                                    label: 'Protein',
                                    value: '${food.protein.toInt()}g',
                                    icon: Icons.fitness_center,
                                  ),
                                  const SizedBox(width: 8),
                                  _MacroChip(
                                    label: 'Carbs',
                                    value: '${food.carbs.toInt()}g',
                                    icon: Icons.grain,
                                  ),
                                  const SizedBox(width: 8),
                                  _MacroChip(
                                    label: 'Fat',
                                    value: '${food.fat.toInt()}g',
                                    icon: Icons.opacity,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _MacroChip extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _MacroChip({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: colorScheme.primary,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: PremiumTypography.bodySmall.copyWith(
              color: colorScheme.onSurface.withValues(alpha: 0.8),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            value,
            style: PremiumTypography.bodySmall.copyWith(
              fontWeight: FontWeight.w600,
              color: colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}
