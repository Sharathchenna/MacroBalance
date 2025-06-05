// food_search_page.dart
// ignore_for_file: unused_import, file_names, library_private_types_in_public_api, avoid_print, use_build_context_synchronously

import 'dart:convert';
import 'dart:io'; // For Platform check and File operations
// For Uint8List

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:macrotracker/camera/barcode_results.dart';
import 'package:macrotracker/camera/results_page.dart';
import 'package:macrotracker/models/ai_food_item.dart';
import 'package:macrotracker/screens/askAI.dart';
import 'package:path_provider/path_provider.dart'; // For temp directory
import '../AI/gemini.dart'; // Import Gemini processing
import 'package:supabase_flutter/supabase_flutter.dart'; // Import Supabase
import 'package:macrotracker/theme/app_theme.dart';
import 'package:macrotracker/screens/foodDetail.dart';
import 'package:flutter/cupertino.dart';
import 'package:macrotracker/services/api_service.dart';
import 'package:macrotracker/theme/typography.dart';
import 'package:macrotracker/widgets/search_header.dart';
import 'dart:async';
import 'package:lottie/lottie.dart';
import 'package:macrotracker/services/posthog_service.dart';
import 'package:macrotracker/services/camera_service.dart';
import 'package:macrotracker/widgets/camera/camera_controls.dart';
import 'package:provider/provider.dart'; // Added for Provider
import '../providers/food_entry_provider.dart'; // Added for FoodEntryProvider
import '../providers/saved_food_provider.dart'; // Added for SavedFoodProvider
import '../widgets/food_suggestion_tile.dart'; // Added for FoodSuggestionTile
import '../providers/search_provider.dart';

// Define the expected result structure at the top level
typedef CameraResult = Map<String, dynamic>;

class FoodSearchPage extends StatefulWidget {
  final String? selectedMeal;

  const FoodSearchPage({super.key, this.selectedMeal});

  @override
  _FoodSearchPageState createState() => _FoodSearchPageState();
}

class _FoodSearchPageState extends State<FoodSearchPage>
    with SingleTickerProviderStateMixin {
  // Note: Native camera method channel removed - using Flutter camera now

  final TextEditingController _searchController = TextEditingController();
  List<FoodItem> _searchResults = [];
  List<String> _autoCompleteResults = [];
  bool _isLoading = false;
  // Track if the search was triggered by the search button
  bool _searchButtonClicked = false;
  // final ApiService _apiService = ApiService(); // Remove ApiService instance
  Timer? _debouncer;
  late SearchProvider _searchProvider;

  // Supabase Edge Function URL
  final String _fatSecretProxyUrl =
      'https://mdivtblabmnftdqlgysv.supabase.co/functions/v1/fatsecret-proxy';
  final _supabase = Supabase.instance.client; // Get Supabase client instance

  late AnimationController _loadingController;
  final _scrollController = ScrollController();
  final _foodListKey = GlobalKey<AnimatedListState>();

  @override
  void initState() {
    super.initState();
    // Removed native camera handler setup - using Flutter camera now
    // _initializeApi(); // Remove API initialization
    _searchProvider = Provider.of<SearchProvider>(context, listen: false);
    _loadingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    _searchController.addListener(_onSearchTextChanged);
  }

  @override
  void dispose() {
    _debouncer?.cancel();
    _loadingController.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // Removed _initializeApi and _getAccessToken

  // --- New Function to Call Supabase Edge Function ---
  Future<Map<String, dynamic>?> _callFatSecretProxy({
    required String endpoint,
    required dynamic
        query, // Can be string for search/autocomplete, ID for get, etc.
  }) async {
    final session = _supabase.auth.currentSession;
    if (session == null) {
      print('Error: User not authenticated.');
      _showError('Authentication required. Please log in again.');
      return null;
    }

    try {
      final response = await http.post(
        Uri.parse(_fatSecretProxyUrl),
        headers: {
          'Authorization': 'Bearer ${session.accessToken}',
          'Content-Type': 'application/json',
          // 'apikey': _supabase.anonKey, // Removed - Edge function has env access
        },
        body: jsonEncode({
          'endpoint': endpoint,
          'query': query,
          // Add any other parameters needed by your Edge Function here
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        print(
            'Proxy Function Error (${response.statusCode}): ${response.body}');
        _showError(
            'Failed to fetch data (${response.statusCode}). Please try again.');
        return null;
      }
    } catch (e) {
      print('Error calling proxy function: $e');
      _showError('Network error. Please check your connection.');
      return null;
    }
  }
  // --- End New Function ---

  /*
  Future<void> _getAutocompleteSuggestions(String query) async {
    if (query.isEmpty || _isLoading) {
      // Don't show suggestions while loading search results
      setState(() => _autoCompleteResults = []);
      return;
    }

    // Call the proxy function
    final proxyResponse = await _callFatSecretProxy(
      endpoint: 'autocomplete',
      query: query,
    );

    if (proxyResponse != null) {
      // Assuming the Edge Function returns the same structure FatSecret did
      // Adjust parsing based on your Edge Function's actual response format
      print('Autocomplete Proxy Response:');
      print(const JsonEncoder.withIndent('  ').convert(proxyResponse));

      // --- Refined Autocomplete Parsing ---
      List<String> suggestionsList = []; // Initialize empty list
      try {
        final suggestionsData =
            proxyResponse['suggestions']; // Could be Map or List
        print('Raw suggestionsData: $suggestionsData'); // Add detailed log

        if (suggestionsData is Map && suggestionsData['suggestion'] is List) {
          // Handles { "suggestions": { "suggestion": [...] } }
          print('Parsing suggestions from Map structure...'); // Add log
          // Ensure items are strings before adding
          suggestionsList = List<String>.from(
              suggestionsData['suggestion'].map((item) => item.toString()));
        } else if (suggestionsData is List) {
          // Handles { "suggestions": [...] }
          print('Parsing suggestions from List structure...'); // Add log
          // Ensure items are strings before adding
          suggestionsList =
              List<String>.from(suggestionsData.map((item) => item.toString()));
        } else {
          print(
              'Autocomplete response format not recognized or empty. suggestionsData type: ${suggestionsData?.runtimeType}'); // Add log
        }
      } catch (e) {
        print('Error parsing autocomplete suggestions: $e');
        suggestionsList = []; // Ensure list is empty on error
      }

      print('Parsed suggestions: $suggestionsList');

      if (mounted) {
        // Add mounted check before setState
        setState(() {
          _autoCompleteResults = suggestionsList;
        });
      }
      // --- End Refined Parsing ---
    } else {
      // Error handled in _callFatSecretProxy
      if (mounted) {
        // Add mounted check
        setState(() => _autoCompleteResults = []);
      }
    }
  }
  */

  void _onSearchTextChanged() {
    if (_searchController.text.isEmpty) {
      setState(() {
        _searchResults = [];
        _autoCompleteResults = [];
        _searchButtonClicked = false;
      });
    } else {
      _debouncedSearch();
    }
  }

  void _debouncedSearch() {
    if (_debouncer?.isActive ?? false) _debouncer!.cancel();
    _debouncer = Timer(const Duration(milliseconds: 300), () {
      _searchFood(_searchController.text);
    });
  }

  Future<void> _searchFood(String query,
      {bool fromSearchButton = false}) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _autoCompleteResults = [];
        _searchButtonClicked = false;
      });
      return;
    }

    // Track the search event
    PostHogService.trackSearch(
      query,
      properties: {
        'from_search_button': fromSearchButton,
        'result_count': _searchResults.length,
      },
    );

    setState(() {
      _searchButtonClicked = fromSearchButton;
      _autoCompleteResults = [];
    });

    try {
      final results = await _searchProvider.searchFood(query);

      if (mounted) {
        setState(() {
          _searchResults = results;
          _autoCompleteResults = [];
        });
      }
    } catch (e) {
      if (mounted) {
        _showError('Failed to search: ${e.toString()}');
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.red[700],
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: 'Retry',
          onPressed: () => _searchFood(_searchController.text),
          textColor: Colors.white,
        ),
      ),
    );
  }

  // --- Native Camera Handling (DEPRECATED - using Flutter camera now) ---

  // Note: These methods are kept for reference but no longer used
  // The search page now uses the Flutter camera implementation directly

  Future<void> _showFlutterCamera() async {
    FocusScope.of(context).unfocus();

    // Track camera usage
    PostHogService.trackFeatureUsage(
      'camera_search',
      properties: {
        'platform': Platform.operatingSystem,
      },
    );

    try {
      print(
          '[Flutter SearchPage] Invoking Flutter camera with barcode mode...');

      // Use CameraService to show the Flutter camera with barcode mode
      final CameraService cameraService = CameraService();
      final result = await cameraService.showCamera(
        context: context,
        initialMode: CameraMode.barcode, // Start in barcode mode for search
      );

      print('[Flutter SearchPage] Camera result received: $result');
      print('[Flutter SearchPage] Widget mounted after camera: $mounted');

      if (result != null && mounted) {
        final String type = result['type'] as String;
        print('[Flutter SearchPage] Camera result type: $type');

        if (type == 'barcode') {
          final String barcode = result['value'] as String;
          print('[Flutter SearchPage] Barcode value detected: $barcode');
          _handleBarcodeResult(context, barcode);
        } else if (type == 'photo') {
          final imageBytes = result['value'];
          print(
              '[Flutter SearchPage] Photo captured: ${imageBytes.runtimeType}');
          // For now, just show a message since photo analysis isn't implemented yet
          _showErrorSnackbar(
              'Photo analysis not yet implemented. Please use barcode scanning.');
        }
      } else {
        print('[Flutter SearchPage] No result or widget not mounted');
        if (result == null) {
          print('[Flutter SearchPage] Result was null - camera was cancelled');
        }
      }
    } catch (e) {
      print(
          '[Flutter SearchPage] Error showing Flutter camera: ${e.toString()}');
      if (mounted) {
        _showErrorSnackbar('Failed to open camera: ${e.toString()}');
      }
    }
  }

  // --- Result Handling (Adapted from Dashboard) ---

  void _handleBarcodeResult(BuildContext safeContext, String barcode) {
    print(
        '[Flutter SearchPage] Navigating to BarcodeResults with barcode: $barcode');
    print('[Flutter SearchPage] Widget mounted: $mounted');
    print('[Flutter SearchPage] Context valid: ${safeContext.mounted}');

    if (!mounted) {
      print('[Flutter SearchPage] Widget not mounted, aborting navigation');
      return;
    }

    try {
      print('[Flutter SearchPage] Attempting navigation to BarcodeResults...');
      Navigator.push(
        safeContext,
        MaterialPageRoute(builder: (context) {
          print('[Flutter SearchPage] Building BarcodeResults widget');
          return BarcodeResults(barcode: barcode);
        }),
      ).then((value) {
        print('[Flutter SearchPage] Navigation to BarcodeResults completed');
      }).catchError((error) {
        print('[Flutter SearchPage] Navigation error: $error');
      });
      print('[Flutter SearchPage] Navigation call made successfully');
    } catch (e) {
      print('[Flutter SearchPage] Error during navigation: $e');
      _showErrorSnackbar('Failed to open product details: $e');
    }
  }

  // Note: Photo analysis removed for now - focusing on barcode scanning
  // The search page camera will primarily be used for barcode detection

  // --- UI Helper Methods (Adapted from Dashboard) ---

  void _showErrorSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.redAccent,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // Note: Loading dialog method removed - not needed for barcode scanning

  // --- Original Methods ---

  @override
  Widget build(BuildContext context) {
    return Consumer<SearchProvider>(
      builder: (context, searchProvider, child) {
        final isLoading = searchProvider.isLoading;

        return GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: Scaffold(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            body: SafeArea(
              child: Column(
                children: [
                  SearchHeader(
                    controller: _searchController,
                    onSearch: (query) =>
                        _searchFood(query, fromSearchButton: true),
                    onChanged: (query) {}, // Handled by listener
                    onBack: () => Navigator.pop(context),
                    onCameraTap: _showFlutterCamera,
                  ),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: _buildOptimizedContent(isLoading),
                    ),
                  ),
                ],
              ),
            ),
            floatingActionButton: _buildScrollToTopButton(),
          ),
        );
      },
    );
  }

  Widget _buildOptimizedContent(bool isLoading) {
    if (isLoading && _searchButtonClicked) {
      return _buildLoadingState();
    }
    if (isLoading && !_searchButtonClicked) {
      return _buildPlaceholderCards();
    }
    if (_searchResults.isNotEmpty) {
      return _buildOptimizedSearchResults();
    }
    if (_autoCompleteResults.isNotEmpty) {
      return _buildOptimizedSuggestions();
    }
    if (_searchResults.isEmpty && _searchController.text.isNotEmpty) {
      return const NoResultsFoundWidget();
    }

    return _buildSavedFoodsWithEmptyState();
  }

  Widget _buildOptimizedSearchResults() {
    return RefreshIndicator(
      onRefresh: () => _searchFood(_searchController.text),
      color: Theme.of(context).primaryColor,
      backgroundColor: Theme.of(context).cardColor,
      displacement: 20,
      edgeOffset: 20,
      child: ListView.builder(
        key: _foodListKey,
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        itemCount: _searchResults.length,
        itemBuilder: (context, index) {
          if (index < 0 || index >= _searchResults.length) {
            return const SizedBox.shrink();
          }

          return KeepAliveWidget(
            child: _buildFoodCard(_searchResults[index]),
          );
        },
      ),
    );
  }

  Widget _buildScrollToTopButton() {
    if (_searchResults.isNotEmpty &&
        _scrollController.hasClients &&
        _scrollController.offset > 200) {
      return FloatingActionButton.small(
        onPressed: () {
          _scrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOutCubic,
          );
          HapticFeedback.lightImpact();
        },
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        child: const Icon(Icons.arrow_upward_rounded),
      );
    }
    return const SizedBox.shrink(); // Return an empty widget instead of null
  }

  Widget _buildLoadingState() {
    final customColors = Theme.of(context).extension<CustomColors>();

    // Simplify loading state to reduce heaviness
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            height: 120,
            width: 120,
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(((0.05) * 255).round()),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Lottie.asset(
              'assets/animations/potato_walking.json',
              fit: BoxFit.contain,
              // Keep loading animation simple
              errorBuilder: (context, error, stackTrace) =>
                  CircularProgressIndicator(
                color: Theme.of(context).primaryColor,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Looking for food...',
            style: AppTypography.body1.copyWith(
              color: customColors!.textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToFoodDetail(FoodItem food) {
    HapticFeedback.mediumImpact();

    // Track food selection
    PostHogService.trackFoodEntry(
      foodName: food.name,
      calories: food.calories,
      protein: food.nutrients['Protein'] ?? 0.0,
      carbs: food.nutrients['Carbohydrate, by difference'] ?? 0.0,
      fat: food.nutrients['Total lipid (fat)'] ?? 0.0,
      properties: {
        'brand_name': food.brandName,
        'meal_type': widget.selectedMeal ?? 'unspecified',
      },
    );

    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (context) => FoodDetailPage(
          food: food,
          selectedMeal: widget.selectedMeal,
        ),
      ),
    );
  }

  void _onFoodItemTap(FoodItem food) {
    _navigateToFoodDetail(food);
  }

  Widget _buildFoodCard(FoodItem food) {
    // Get the default serving (first serving)
    final defaultServing =
        food.servings.isNotEmpty ? food.servings.first : null;
    final customColors = Theme.of(context).extension<CustomColors>();
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final accentColor = _categoryColor(food.name);

    // Enhanced premium card design
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(((0.06) * 255).round()),
            offset: const Offset(0, 3),
            blurRadius: 10,
            spreadRadius: 0,
          ),
          BoxShadow(
            color: accentColor.withAlpha(((0.025) * 255).round()),
            offset: const Offset(0, 1),
            blurRadius: 8,
            spreadRadius: 0,
          ),
        ],
        border: Border.all(
          color: isDarkMode
              ? Colors.grey.withAlpha(((0.1) * 255).round())
              : Colors.grey.withAlpha(((0.08) * 255).round()),
          width: 0.5,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _onFoodItemTap(food),
          splashColor: accentColor.withAlpha(((0.1) * 255).round()),
          highlightColor: accentColor.withAlpha(((0.05) * 255).round()),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Enhanced food icon with gradient
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            accentColor.withAlpha(((0.15) * 255).round()),
                            accentColor.withAlpha(((0.05) * 255).round()),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color:
                                accentColor.withAlpha(((0.15) * 255).round()),
                            offset: const Offset(0, 2),
                            blurRadius: 6,
                            spreadRadius: -2,
                          ),
                        ],
                      ),
                      child: Center(
                        child: Icon(
                          _categoryIcon(food.name),
                          color: accentColor,
                          size: 24,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Food name and brand with improved typography
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            food.name,
                            style: GoogleFonts.onest(
                              fontSize: 16,
                              color: customColors?.textPrimary,
                              fontWeight: FontWeight.w600,
                              height: 1.3,
                              letterSpacing: -0.1,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (food.brandName.isNotEmpty) ...[
                            const SizedBox(height: 5),
                            Text(
                              food.brandName,
                              style: GoogleFonts.onest(
                                fontSize: 13,
                                color: customColors?.textSecondary
                                    .withAlpha(((0.9) * 255).round()),
                                letterSpacing: 0.1,
                              ),
                            ),
                          ],
                          if (defaultServing != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                'Per ${defaultServing.description}',
                                style: GoogleFonts.onest(
                                  color: Theme.of(context)
                                      .primaryColor
                                      .withAlpha(((0.8) * 255).round()),
                                  fontSize: 12,
                                  // fontStyle: FontStyle.italic,
                                  letterSpacing: 0.1,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Enhanced nutrition row
                _buildSimplifiedNutritionRow(food, defaultServing),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSimplifiedNutritionRow(FoodItem food, Serving? serving) {
    // Use serving values if available, otherwise fallback to per 100g values
    final calories = serving?.calories ?? food.calories;
    final protein =
        serving?.nutrients['Protein'] ?? food.nutrients['Protein'] ?? 0.0;
    final carbs = serving?.nutrients['Carbohydrate, by difference'] ??
        food.nutrients['Carbohydrate, by difference'] ??
        0.0;
    final fat = serving?.nutrients['Total lipid (fat)'] ??
        food.nutrients['Total lipid (fat)'] ??
        0.0;

    return SingleChildScrollView(
      // Wrap with SingleChildScrollView
      scrollDirection: Axis.horizontal, // Set scroll direction to horizontal
      child: Row(
        children: [
          _buildNutrientChip(
            '${calories.toStringAsFixed(0)} cal',
            Icons.local_fire_department_rounded,
            Colors.orange,
          ),
          const SizedBox(width: 8),
          _buildNutrientChip(
            '${protein.toStringAsFixed(1)}g P',
            Icons.fitness_center_rounded,
            Colors.blue,
          ),
          const SizedBox(width: 8),
          _buildNutrientChip(
            '${carbs.toStringAsFixed(1)}g C',
            Icons.grain_rounded,
            Colors.green,
          ),
          const SizedBox(width: 8),
          _buildNutrientChip(
            '${fat.toStringAsFixed(1)}g F',
            Icons.circle_outlined,
            Colors.red,
          ),
        ],
      ),
    );
  }

  Widget _buildNutrientChip(String text, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(((0.1) * 255).round()),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w500,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final customColors = Theme.of(context).extension<CustomColors>();

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search,
            size: 64,
            color: customColors?.textSecondary.withAlpha(((0.5) * 255).round()),
          ),
          const SizedBox(height: 16),
          Text(
            'Search for food',
            style: AppTypography.body1.copyWith(
              color: customColors?.textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'Search by name or scan a barcode',
              style: AppTypography.caption.copyWith(
                color: customColors?.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSavedFoodsWithEmptyState() {
    final savedFoodProvider =
        Provider.of<SavedFoodProvider>(context, listen: false);
    final foodEntryProvider =
        Provider.of<FoodEntryProvider>(context, listen: false);
    final customColors = Theme.of(context).extension<CustomColors>();

    // Check if we have any saved foods
    if (!savedFoodProvider.isInitialized) {
      // Provider is still initializing
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Theme.of(context).primaryColor),
            const SizedBox(height: 16),
            Text(
              'Loading saved foods...',
              style: AppTypography.body1.copyWith(
                color: customColors?.textPrimary,
              ),
            ),
          ],
        ),
      );
    }

    // Get frequent foods from the food entry provider
    final hasSavedFoods = savedFoodProvider.savedFoods.isNotEmpty;

    return FutureBuilder<List<FoodItem>>(
      future: foodEntryProvider.getFrequentlyLoggedItems(),
      builder: (context, snapshot) {
        final hasFrequentFoods = snapshot.hasData && snapshot.data!.isNotEmpty;

        if (!hasFrequentFoods && !hasSavedFoods) {
          // No saved or frequent foods, just show the empty state
          return _buildEmptyState();
        }

        // We have saved foods and/or frequent foods, show them with the empty state below
        return CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // Frequent Foods Section (if we have any)
            if (hasFrequentFoods) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.history_rounded,
                            size: 20,
                            color: Theme.of(context).primaryColor,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Frequently Used',
                            style: AppTypography.h3.copyWith(
                              color: customColors?.textPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Frequent Foods Horizontal List
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 140,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    itemCount:
                        snapshot.data!.length > 5 ? 5 : snapshot.data!.length,
                    itemBuilder: (context, index) {
                      final food = snapshot.data![index];
                      final color = _categoryColor(food.name);

                      return GestureDetector(
                        onTap: () => _navigateToFoodDetail(food),
                        child: Container(
                          width: 120,
                          margin: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 8),
                          decoration: BoxDecoration(
                            color: customColors?.cardBackground,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: color.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Icon(
                                    _categoryIcon(food.name),
                                    color: color,
                                    size: 20,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 8),
                                child: Text(
                                  food.name,
                                  style: AppTypography.bodySmall.copyWith(
                                    fontWeight: FontWeight.w500,
                                    color: customColors?.textPrimary,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${(food.servings.isNotEmpty ? food.servings.first.calories : food.calories).toInt()} kcal',
                                style: AppTypography.caption.copyWith(
                                  color: customColors?.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),

              // Add a small divider between sections
              if (hasSavedFoods)
                SliverToBoxAdapter(
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child:
                        Divider(color: customColors?.dateNavigatorBackground),
                  ),
                ),
            ],

            // Saved Foods Section (if we have any)
            if (hasSavedFoods) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.bookmark_rounded,
                            size: 20,
                            color: Theme.of(context).primaryColor,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Saved Foods',
                            style: AppTypography.h3.copyWith(
                              color: customColors?.textPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pushNamed(context, '/savedFoods',
                              arguments: widget.selectedMeal);
                        },
                        child: Text(
                          'View All',
                          style: AppTypography.button.copyWith(
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Saved Foods Horizontal List
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 140,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    itemCount: savedFoodProvider.savedFoods.length > 5
                        ? 5
                        : savedFoodProvider.savedFoods.length,
                    itemBuilder: (context, index) {
                      final savedFood = savedFoodProvider.savedFoods[index];
                      final food = savedFood.toSearchPageFoodItem();
                      final color = _categoryColor(food.name);

                      return GestureDetector(
                        onTap: () => _navigateToFoodDetail(food),
                        child: Container(
                          width: 120,
                          margin: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 8),
                          decoration: BoxDecoration(
                            color: customColors?.cardBackground,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: color.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Icon(
                                    _categoryIcon(food.name),
                                    color: color,
                                    size: 20,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 8),
                                child: Text(
                                  food.name,
                                  style: AppTypography.bodySmall.copyWith(
                                    fontWeight: FontWeight.w500,
                                    color: customColors?.textPrimary,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${(food.servings.isNotEmpty ? food.servings.first.calories : food.calories).toInt()} kcal',
                                style: AppTypography.caption.copyWith(
                                  color: customColors?.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],

            // Divider before empty state
            SliverToBoxAdapter(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                child: Divider(color: customColors?.dateNavigatorBackground),
              ),
            ),

            // Empty State at the bottom
            SliverFillRemaining(
              hasScrollBody: false,
              child: _buildEmptyState(),
            ),
          ],
        );
      },
    );
  }

  Widget _buildOptimizedSuggestions() {
    final customColors = Theme.of(context).extension<CustomColors>();
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        // Gradient removed
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Premium header with subtle divider
          Container(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: customColors!.cardBackground
                      .withAlpha(((0.1) * 255).round()),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.lightbulb_outline,
                  size: 18,
                  color: Theme.of(context)
                      .primaryColor
                      .withAlpha(((0.8) * 255).round()),
                ),
                const SizedBox(width: 10),
                Text(
                  'Suggestions',
                  style: GoogleFonts.onest(
                    color: customColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),

          // Suggestions list with improved styling
          Expanded(
            child: _autoCompleteResults.isEmpty
                ? _buildSuggestionsEmptyState()
                : Container(
                    margin: const EdgeInsets.only(top: 8),
                    child: ListView.builder(
                      itemCount: _autoCompleteResults.length,
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                      physics: const BouncingScrollPhysics(),
                      itemBuilder: (context, index) {
                        if (index < 0 || index >= _autoCompleteResults.length) {
                          return const SizedBox.shrink();
                        }

                        final suggestion = _autoCompleteResults[index];
                        final Color accentColor = _categoryColor(suggestion);

                        // Animate items with staggered effect
                        return AnimatedOpacity(
                          opacity: 1.0,
                          duration: Duration(milliseconds: 300 + (index * 30)),
                          curve: Curves.easeOutQuart,
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: isDarkMode
                                  ? Theme.of(context)
                                      .cardColor
                                      .withAlpha(((0.9) * 255).round())
                                  : Theme.of(context).cardColor,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black
                                      .withAlpha(((0.04) * 255).round()),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                  spreadRadius: 0,
                                ),
                              ],
                              border: Border.all(
                                color: Theme.of(context)
                                    .dividerColor
                                    .withAlpha(((0.08) * 255).round()),
                                width: 1,
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(16),
                                  splashColor: accentColor
                                      .withAlpha(((0.1) * 255).round()),
                                  highlightColor: accentColor
                                      .withAlpha(((0.05) * 255).round()),
                                  onTap: () {
                                    HapticFeedback.lightImpact();
                                    FocusScope.of(context).unfocus();
                                    _searchController.text = suggestion;
                                    _searchFood(suggestion);
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 14, horizontal: 16),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                              colors: [
                                                accentColor.withAlpha(
                                                    ((0.12) * 255).round()),
                                                accentColor.withAlpha(
                                                    ((0.05) * 255).round()),
                                              ],
                                            ),
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          child: Icon(
                                            _categoryIcon(suggestion),
                                            color: accentColor,
                                            size: 18,
                                          ),
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                suggestion,
                                                style: AppTypography.body2
                                                    .copyWith(
                                                  color:
                                                      customColors.textPrimary,
                                                  fontWeight: FontWeight.w500,
                                                  height: 1.3,
                                                ),
                                              ),
                                              Text(
                                                'Tap to search',
                                                style: AppTypography.caption
                                                    .copyWith(
                                                  color: customColors
                                                      .textSecondary
                                                      .withAlpha(((0.7) * 255)
                                                          .round()),
                                                  fontSize: 11,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Icon(
                                          Icons.chevron_right_rounded,
                                          color: customColors.textSecondary
                                              .withAlpha(((0.4) * 255).round()),
                                          size: 20,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  // Simplified helper methods for colors and icons based on categories
  Color _categoryColor(String foodName) {
    // Simple hash function to get consistent colors
    final int hash = foodName.toLowerCase().codeUnits.fold(0, (a, b) => a + b);

    // List of pleasant colors
    final colors = [
      const Color(0xFF4285F4), // blue
      const Color(0xFFEA4335), // red
      const Color(0xFFFBBC05), // yellow
      const Color(0xFF34A853), // green
      const Color(0xFF9C27B0), // purple
      const Color(0xFF00BCD4), // cyan
      const Color(0xFFFF9800), // orange
    ];

    return colors[hash % colors.length];
  }

  IconData _categoryIcon(String text) {
    final textLc = text.toLowerCase();
    if (textLc.contains('chicken') ||
        textLc.contains('meat') ||
        textLc.contains('beef')) {
      return Icons.restaurant;
    } else if (textLc.contains('vegetable') ||
        textLc.contains('broccoli') ||
        textLc.contains('spinach')) {
      return Icons.eco;
    } else if (textLc.contains('rice') ||
        textLc.contains('bread') ||
        textLc.contains('pasta')) {
      return Icons.grain;
    } else if (textLc.contains('fruit') ||
        textLc.contains('apple') ||
        textLc.contains('banana')) {
      return Icons.apple;
    } else if (textLc.contains('fish') || textLc.contains('seafood')) {
      return Icons.water;
    } else if (textLc.contains('dairy') ||
        textLc.contains('milk') ||
        textLc.contains('cheese')) {
      return Icons.coffee;
    } else {
      return Icons.fastfood;
    }
  }

  Widget _buildSuggestionsEmptyState() {
    final customColors = Theme.of(context).extension<CustomColors>();

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off_rounded,
            size: 64,
            color: customColors?.textSecondary.withAlpha(((0.5) * 255).round()),
          ),
          const SizedBox(height: 16),
          Text(
            'No suggestions found',
            style: AppTypography.body1.copyWith(
              color: customColors?.textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'Try typing a different search term',
              style: AppTypography.caption.copyWith(
                color: customColors?.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholderCards() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      itemCount: 5, // Show 5 placeholder cards
      itemBuilder: (context, index) {
        return _buildPlaceholderCard();
      },
    );
  }

  Widget _buildPlaceholderCard() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(((0.05) * 255).round()),
            offset: const Offset(0, 3),
            blurRadius: 10,
            spreadRadius: 0,
          ),
        ],
        border: Border.all(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.grey.withAlpha(((0.1) * 255).round())
              : Colors.grey.withAlpha(((0.08) * 255).round()),
          width: 0.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Placeholder icon
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: Colors.grey.withAlpha(((0.2) * 255).round()),
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                const SizedBox(width: 16),
                // Placeholder text
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 16,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.grey.withAlpha(((0.2) * 255).round()),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 12,
                        width: 120,
                        decoration: BoxDecoration(
                          color: Colors.grey.withAlpha(((0.15) * 255).round()),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 10,
                        width: 80,
                        decoration: BoxDecoration(
                          color: Colors.grey.withAlpha(((0.1) * 255).round()),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Placeholder nutrition chips
            Row(
              children: [
                Container(
                  height: 22,
                  width: 70,
                  decoration: BoxDecoration(
                    color: Colors.grey.withAlpha(((0.15) * 255).round()),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  height: 22,
                  width: 60,
                  decoration: BoxDecoration(
                    color: Colors.grey.withAlpha(((0.15) * 255).round()),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  height: 22,
                  width: 65,
                  decoration: BoxDecoration(
                    color: Colors.grey.withAlpha(((0.15) * 255).round()),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}

class SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final Function(String) onSearch;
  final Function(String) onChanged;

  const SearchBar({
    super.key,
    required this.controller,
    required this.onSearch,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final customColors = Theme.of(context).extension<CustomColors>();

    return TextField(
      controller: controller,
      decoration: InputDecoration(
        prefixIconColor: Theme.of(context).primaryColor,
        hintText: 'Search for food...',
        hintStyle: TextStyle(
          color: customColors?.textSecondary,
        ),
        prefixIcon: const Icon(Icons.search),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      style: TextStyle(
        color: customColors?.textPrimary,
      ),
      onSubmitted: onSearch,
      onChanged: onChanged,
    );
  }
}

class FoodList extends StatelessWidget {
  final List<FoodItem> foods;

  const FoodList({super.key, required this.foods});

  @override
  Widget build(BuildContext context) {
    final customColors = Theme.of(context).extension<CustomColors>();

    return ListView.builder(
      itemCount: foods.length,
      itemBuilder: (context, index) {
        final food = foods[index];
        return ListTile(
          title: Text(
            food.name,
            style: TextStyle(
              color: customColors?.textPrimary,
            ),
          ),
          subtitle: Text(
            '${food.calories.round()} calories',
            style: TextStyle(
              color: customColors?.textSecondary,
            ),
          ),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => FoodDetailPage(food: food),
              ),
            );
          },
        );
      },
    );
  }
}

class FoodItem {
  final String fdcId;
  final String name;
  final double calories;
  final String brandName;
  final Map<String, double> nutrients;
  final String mealType;
  final double servingSize;
  final List<Serving> servings;

  FoodItem({
    required this.fdcId,
    required this.name,
    required this.calories,
    required this.nutrients,
    required this.brandName,
    required this.mealType,
    required this.servingSize,
    required this.servings,
  });

  factory FoodItem.fromFatSecretJson(Map<String, dynamic> json) {
    // Extract food name and brand name
    final foodName = json['food_name'] ?? '';
    final brandName = json['brand_name'] ?? '';
    final foodId = json['food_id']?.toString() ?? '';

    // Store all available servings
    List<Serving> allServings = [];

    // Find the default serving (usually 100g)
    Map<String, dynamic>? defaultServing;

    if (json['servings'] != null && json['servings']['serving'] != null) {
      final servings = json['servings']['serving'];

      // If there's only one serving
      if (servings is Map) {
        defaultServing = Map<String, dynamic>.from(servings);
        allServings.add(Serving.fromJson(defaultServing));
      }
      // If there are multiple servings
      else if (servings is List) {
        // Add all servings to the list
        for (var serving in servings) {
          allServings.add(Serving.fromJson(serving));
        }

        // Find default (100g) serving for main nutrition display
        defaultServing = servings.firstWhere(
            (serving) => serving['serving_description'] == '100 g',
            orElse: () => servings.first);
      }
    }

    // Extract nutrition values or default to 0
    double calories = 0.0;
    Map<String, double> nutrients = {};
    double servingSize = 100.0; // Default to 100g

    if (defaultServing != null) {
      calories =
          double.tryParse(defaultServing['calories']?.toString() ?? '0') ?? 0.0;
      // Extract ALL available nutrients from the default serving
      nutrients = {
        'Protein':
            double.tryParse(defaultServing['protein']?.toString() ?? '0') ??
                0.0,
        'Total lipid (fat)':
            double.tryParse(defaultServing['fat']?.toString() ?? '0') ?? 0.0,
        'Carbohydrate, by difference': double.tryParse(
                defaultServing['carbohydrate']?.toString() ?? '0') ??
            0.0,
        'Saturated fat': double.tryParse(
                defaultServing['saturated_fat']?.toString() ?? '0') ??
            0.0,
        'Polyunsaturated fat': double.tryParse(
                defaultServing['polyunsaturated_fat']?.toString() ?? '0') ??
            0.0,
        'Monounsaturated fat': double.tryParse(
                defaultServing['monounsaturated_fat']?.toString() ?? '0') ??
            0.0,
        'Cholesterol':
            double.tryParse(defaultServing['cholesterol']?.toString() ?? '0') ??
                0.0,
        'Sodium':
            double.tryParse(defaultServing['sodium']?.toString() ?? '0') ?? 0.0,
        'Potassium':
            double.tryParse(defaultServing['potassium']?.toString() ?? '0') ??
                0.0,
        'Fiber':
            double.tryParse(defaultServing['fiber']?.toString() ?? '0') ?? 0.0,
        'Sugar':
            double.tryParse(defaultServing['sugar']?.toString() ?? '0') ?? 0.0,
        'Vitamin A':
            double.tryParse(defaultServing['vitamin_a']?.toString() ?? '0') ??
                0.0,
        'Vitamin C':
            double.tryParse(defaultServing['vitamin_c']?.toString() ?? '0') ??
                0.0,
        'Calcium':
            double.tryParse(defaultServing['calcium']?.toString() ?? '0') ??
                0.0,
        'Iron':
            double.tryParse(defaultServing['iron']?.toString() ?? '0') ?? 0.0,
      };

      // Try to parse serving size
      servingSize = double.tryParse(
              defaultServing['metric_serving_amount']?.toString() ?? '100') ??
          100.0;
    }

    // Remove nutrients with value 0 to keep the map cleaner, unless it's a primary macro
    nutrients.removeWhere((key, value) =>
        value == 0.0 &&
        !['Protein', 'Total lipid (fat)', 'Carbohydrate, by difference']
            .contains(key));

    return FoodItem(
      fdcId: foodId,
      name: foodName,
      calories: calories,
      nutrients: nutrients,
      brandName: brandName,
      mealType: 'breakfast', // Default meal type
      servingSize: servingSize,
      servings: allServings,
    );
  }
}

// Class to represent a single serving option
class Serving {
  final String description;
  final double metricAmount;
  final String metricUnit;
  final double calories;
  final Map<String, double> nutrients;

  Serving({
    required this.description,
    required this.metricAmount,
    required this.metricUnit,
    required this.calories,
    required this.nutrients,
  });

  // Method to serialize Serving object to JSON
  Map<String, dynamic> toJson() => {
        'serving_description': description,
        'metric_serving_amount': metricAmount,
        'metric_serving_unit': metricUnit,
        'calories': calories,
        // Serialize all nutrients
        'protein': nutrients['Protein'],
        'fat': nutrients['Total lipid (fat)'],
        'carbohydrate': nutrients['Carbohydrate, by difference'],
        'saturated_fat': nutrients['Saturated fat'],
        'polyunsaturated_fat': nutrients['Polyunsaturated fat'],
        'monounsaturated_fat': nutrients['Monounsaturated fat'],
        'cholesterol': nutrients['Cholesterol'],
        'sodium': nutrients['Sodium'],
        'potassium': nutrients['Potassium'],
        'fiber': nutrients['Fiber'],
        'sugar': nutrients['Sugar'],
        'vitamin_a': nutrients['Vitamin A'],
        'vitamin_c': nutrients['Vitamin C'],
        'calcium': nutrients['Calcium'],
        'iron': nutrients['Iron'],
        // Add any other nutrients stored in the map if necessary
      };

  factory Serving.fromJson(Map<String, dynamic> json) {
    // Extract all nutrients
    Map<String, double> nutrients = {
      'Protein': double.tryParse(json['protein']?.toString() ?? '0') ??
          0.0, // Added .toString() for safety
      'Total lipid (fat)': double.tryParse(json['fat']?.toString() ?? '0') ??
          0.0, // Added .toString()
      'Carbohydrate, by difference':
          double.tryParse(json['carbohydrate']?.toString() ?? '0') ??
              0.0, // Added .toString()
      'Saturated fat':
          double.tryParse(json['saturated_fat']?.toString() ?? '0') ??
              0.0, // Added .toString()
      'Polyunsaturated fat':
          double.tryParse(json['polyunsaturated_fat']?.toString() ?? '0') ??
              0.0, // Added .toString()
      'Monounsaturated fat':
          double.tryParse(json['monounsaturated_fat']?.toString() ?? '0') ??
              0.0, // Added .toString()
      'Cholesterol': double.tryParse(json['cholesterol']?.toString() ?? '0') ??
          0.0, // Added .toString()
      'Sodium': double.tryParse(json['sodium']?.toString() ?? '0') ??
          0.0, // Added .toString()
      'Potassium': double.tryParse(json['potassium']?.toString() ?? '0') ??
          0.0, // Added .toString()
      'Fiber': double.tryParse(json['fiber']?.toString() ?? '0') ??
          0.0, // Added .toString()
      'Sugar': double.tryParse(json['sugar']?.toString() ?? '0') ??
          0.0, // Added .toString()
      'Vitamin A': double.tryParse(json['vitamin_a']?.toString() ?? '0') ??
          0.0, // Added .toString()
      'Vitamin C': double.tryParse(json['vitamin_c']?.toString() ?? '0') ??
          0.0, // Added .toString()
      'Calcium': double.tryParse(json['calcium']?.toString() ?? '0') ??
          0.0, // Added .toString()
      'Iron': double.tryParse(json['iron']?.toString() ?? '0') ??
          0.0, // Added .toString()
    };

    // --- Logic to handle different serving amount/unit fields ---
    double metricAmount = 0.0;
    String metricUnit = 'unit'; // Default to 'unit' if no weight is found

    if (json['metric_serving_amount'] != null) {
      metricAmount =
          double.tryParse(json['metric_serving_amount'].toString()) ?? 0.0;
      metricUnit = json['metric_serving_unit']?.toString() ??
          'g'; // Default to 'g' if amount exists but unit doesn't
    } else if (json['number_of_units'] != null) {
      metricAmount = double.tryParse(json['number_of_units'].toString()) ?? 0.0;
      // Use measurement_description if available, otherwise keep 'unit'
      metricUnit = json['measurement_description']?.toString() ?? metricUnit;
    }
    // --- End Logic ---

    return Serving(
      description: json['serving_description'] ?? 'Default serving',
      metricAmount: metricAmount, // Use calculated amount
      metricUnit: metricUnit, // Use calculated unit
      calories: double.tryParse(json['calories']?.toString() ?? '0') ??
          0.0, // Added .toString()
      nutrients: nutrients,
    );
  }
}

class NoResultsFoundWidget extends StatelessWidget {
  const NoResultsFoundWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final customColors = Theme.of(context).extension<CustomColors>();

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 24),
            Text(
              'No results found',
              style: AppTypography.h3.copyWith(
                color: customColors?.textPrimary,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Try a different search term or ask AI for help',
              style: AppTypography.body2.copyWith(
                color: customColors?.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                // Track AI help usage
                PostHogService.trackFeatureUsage('ai_help');

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const Askai(),
                  ),
                );
              },
              icon: const Icon(Icons.smart_toy_rounded),
              label: const Text('Ask AI for Help'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Add this new widget to optimize list performance
class KeepAliveWidget extends StatefulWidget {
  final Widget child;

  const KeepAliveWidget({
    Key? key,
    required this.child,
  }) : super(key: key);

  @override
  _KeepAliveWidgetState createState() => _KeepAliveWidgetState();
}

class _KeepAliveWidgetState extends State<KeepAliveWidget>
    with AutomaticKeepAliveClientMixin {
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }

  @override
  bool get wantKeepAlive => true;
}
