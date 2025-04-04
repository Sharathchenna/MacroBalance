// food_search_page.dart
// ignore_for_file: unused_import, file_names, library_private_types_in_public_api, avoid_print, use_build_context_synchronously

import 'dart:convert';
import 'dart:io'; // For Platform check and File operations
import 'dart:typed_data'; // For Uint8List

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
// import 'package:macrotracker/camera/camera.dart'; // No longer needed

// Define the expected result structure at the top level
typedef CameraResult = Map<String, dynamic>;

class FoodSearchPage extends StatefulWidget {
  final String? selectedMeal;

  const FoodSearchPage({Key? key, this.selectedMeal}) : super(key: key);

  @override
  _FoodSearchPageState createState() => _FoodSearchPageState();
}

class _FoodSearchPageState extends State<FoodSearchPage>
    with SingleTickerProviderStateMixin {
  // Method Channel for the native camera view
  static const MethodChannel _nativeCameraViewChannel =
      MethodChannel('com.macrotracker/native_camera_view');

  final TextEditingController _searchController = TextEditingController();
  List<FoodItem> _searchResults = [];
  List<String> _autoCompleteResults = [];
  bool _isLoading = false;
  // final ApiService _apiService = ApiService(); // Remove ApiService instance
  Timer? _debouncer;

  // Supabase Edge Function URL
  final String _fatSecretProxyUrl =
      'https://mdivtblabmnftdqlgysv.supabase.co/functions/v1/fatsecret-proxy';
  final _supabase = Supabase.instance.client; // Get Supabase client instance

  late AnimationController _loadingController;
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _setupNativeCameraHandler(); // Set up the handler
    // _initializeApi(); // Remove API initialization
    _loadingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
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

  Future<void> _getAutocompleteSuggestions(String query) async {
    if (query.isEmpty) {
      // Removed token check
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

  void _onSearchChanged(String query) {
    if (_debouncer?.isActive ?? false) _debouncer!.cancel();
    _debouncer = Timer(const Duration(milliseconds: 50), () {
      _getAutocompleteSuggestions(query);
    });
  }

  Future<void> _searchFood(String query) async {
    if (query.isEmpty) return; // Removed token check

    setState(() {
      _isLoading = true;
      _autoCompleteResults = []; // Clear suggestions when searching
    });

    // Call the proxy function
    final proxyResponse = await _callFatSecretProxy(
      endpoint: 'search',
      query: query,
    );

    if (proxyResponse != null) {
      // Assuming the Edge Function returns the same structure FatSecret did
      // Adjust parsing based on your Edge Function's actual response format
      print('Food Search Proxy Response:');
      print(const JsonEncoder.withIndent('  ').convert(proxyResponse));

      // Example parsing (adjust based on actual response)
      final searchData = proxyResponse['foods_search'];
      if (searchData != null &&
          searchData['results'] != null &&
          searchData['results']['food'] != null) {
        final foods = searchData['results']['food'] as List;
        setState(() {
          _searchResults =
              foods.map((food) => FoodItem.fromFatSecretJson(food)).toList();
        });
      } else {
        setState(() => _searchResults = []);
      }
    } else {
      // Error handled in _callFatSecretProxy
      setState(() => _searchResults = []);
    }

    // Ensure loading state is turned off regardless of success/failure
    if (mounted) {
      // Check if the widget is still in the tree
      setState(() {
        _isLoading = false;
      });
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


  // --- Native Camera Handling (Adapted from Dashboard) ---

  void _setupNativeCameraHandler() {
    _nativeCameraViewChannel.setMethodCallHandler((call) async {
      print('[Flutter SearchPage] Received method call: ${call.method}');
      switch (call.method) {
        case 'cameraResult':
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) {
              print(
                  '[Flutter SearchPage] Post-frame callback: Widget is unmounted. Ignoring result.');
              return;
            }
            final Map<dynamic, dynamic> result = call.arguments as Map;
            final String type = result['type'] as String;
            final currentContext = context;

            if (type == 'barcode') {
              final String barcode = result['value'] as String;
              print('[Flutter SearchPage] Post-frame: Handling barcode: $barcode');
              _handleBarcodeResult(currentContext, barcode);
            } else if (type == 'photo') {
              final Uint8List photoData = result['value'] as Uint8List;
              print(
                  '[Flutter SearchPage] Post-frame: Handling photo data: ${photoData.lengthInBytes} bytes');
              _handlePhotoResult(currentContext, photoData);
            } else if (type == 'cancel') {
              print('[Flutter SearchPage] Post-frame: Handling cancel.');
            } else {
              print(
                  '[Flutter SearchPage] Post-frame: Unknown camera result type: $type');
              if (mounted) {
                _showErrorSnackbar('Received unknown result from camera.');
              }
            }
          });
          break;
        default:
          print(
              '[Flutter SearchPage] Unknown method call from native: ${call.method}');
      }
    });
  }

  Future<void> _showNativeCamera() async {
    FocusScope.of(context).unfocus(); // Hide keyboard before opening camera
    if (!Platform.isIOS) {
      print('[Flutter SearchPage] Native camera view only supported on iOS.');
      if (mounted) {
        _showErrorSnackbar('Camera feature is only available on iOS.');
      }
      return;
    }
    try {
      print('[Flutter SearchPage] Invoking showNativeCamera...');
      await _nativeCameraViewChannel.invokeMethod('showNativeCamera');
      print('[Flutter SearchPage] showNativeCamera invoked successfully.');
    } on PlatformException catch (e) {
      print('[Flutter SearchPage] Error showing native camera: ${e.message}');
      if (mounted) {
        _showErrorSnackbar('Failed to open camera: ${e.message}');
      }
    }
  }

  // --- Result Handling (Adapted from Dashboard) ---

  void _handleBarcodeResult(BuildContext safeContext, String barcode) {
    print('[Flutter SearchPage] Navigating to BarcodeResults');
    if (!mounted) return;
    Navigator.push(
      safeContext,
      MaterialPageRoute(builder: (context) => BarcodeResults(barcode: barcode)),
    );
  }

  Future<void> _handlePhotoResult(
      BuildContext safeContext, Uint8List photoData) async {
    if (!mounted) return;
    _showLoadingDialog('Analyzing Image...');
    try {
      final Directory tempDir = await getTemporaryDirectory();
      final String tempPath = '${tempDir.path}/${DateTime.now().millisecondsSinceEpoch}.jpg';
      final File tempFile = File(tempPath);
      await tempFile.writeAsBytes(photoData);
      print('[Flutter SearchPage] Photo saved to temporary file: $tempPath');
      String jsonResponse = await processImageWithGemini(tempFile.path);
      print('[Flutter SearchPage] Gemini response received.');
      jsonResponse = jsonResponse.trim().replaceAll('```json', '').replaceAll('```', '');
      dynamic decodedJson = json.decode(jsonResponse);
      List<dynamic> mealData;
      if (decodedJson is Map<String, dynamic> && decodedJson.containsKey('meal') && decodedJson['meal'] is List) {
        mealData = decodedJson['meal'] as List;
      } else if (decodedJson is List) {
        mealData = decodedJson;
      } else if (decodedJson is Map<String, dynamic>) {
        mealData = [decodedJson];
      } else {
        throw Exception('Unexpected JSON structure from Gemini');
      }
      final List<AIFoodItem> foods = mealData.map((food) => AIFoodItem.fromJson(food as Map<String, dynamic>)).toList();

      if (mounted) {
        try { if (Navigator.of(safeContext, rootNavigator: true).canPop()) Navigator.of(safeContext, rootNavigator: true).pop(); }
        catch (e) { print("[Flutter SearchPage] Error dismissing loading dialog: $e"); }
      }
      if (!mounted) return;

      if (foods.isEmpty) {
        print('[Flutter SearchPage] Gemini returned an empty food list.');
        _showErrorSnackbar('Unable to identify food, try again');
      } else {
        print('[Flutter SearchPage] Navigating to ResultsPage');
        Navigator.push(
          safeContext,
          CupertinoPageRoute(builder: (context) => ResultsPage(foods: foods)),
        );
      }
    } catch (e) {
      print('[Flutter SearchPage] Error processing photo result: ${e.toString()}');
      if (mounted) {
        try { if (Navigator.of(safeContext, rootNavigator: true).canPop()) Navigator.of(safeContext, rootNavigator: true).pop(); }
        catch (e) { print("[Flutter SearchPage] Error dismissing loading dialog in catch: $e"); }
        _showErrorSnackbar('Something went wrong, try again');
      }
    }
  }

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

   void _showLoadingDialog(String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.3),
      builder: (BuildContext dialogContext) {
        return Dialog(
          backgroundColor: Theme.of(context).brightness == Brightness.light ? Colors.white : Colors.grey[850],
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Lottie.asset(
                  'assets/animations/food_loading.json',
                  width: 150, height: 150, fit: BoxFit.contain,
                ),
                const SizedBox(height: 20),
                Text(
                  message,
                  style: TextStyle(
                      color: Theme.of(context).brightness == Brightness.light ? Colors.black87 : Colors.white,
                      fontSize: 17),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // --- Original Methods ---

  @override
  Widget build(BuildContext context) {
    final customColors = Theme.of(context).extension<CustomColors>();

    return GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: Container(
            child: SafeArea(
              child: Column(
                children: [
                  SearchHeader(
                    controller: _searchController,
                    onSearch: _searchFood,
                    onChanged: _onSearchChanged,
                    onBack: () => Navigator.pop(context),
                    onCameraTap: _showNativeCamera, // Pass the method here
                  ),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 500),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      transitionBuilder:
                          (Widget child, Animation<double> animation) {
                        final offsetAnimation = Tween<Offset>(
                          begin: const Offset(0, 0.05),
                          end: Offset.zero,
                        ).animate(CurvedAnimation(
                          parent: animation,
                          curve: Curves.easeOutCubic,
                        ));

                        return FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position: offsetAnimation,
                            child: child,
                          ),
                        );
                      },
                      layoutBuilder: (currentChild, previousChildren) {
                        return Stack(
                          alignment: Alignment.topCenter,
                          children: <Widget>[
                            ...previousChildren,
                            if (currentChild != null) currentChild,
                          ],
                        );
                      },
                      child: _buildContent(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Add a floating action button to scroll to top that appears when scrolled down
          floatingActionButton: _searchResults.isNotEmpty &&
                  _scrollController.hasClients &&
                  _scrollController.offset > 200
              ? FloatingActionButton.small(
                  onPressed: () {
                    _scrollController.animateTo(
                      0,
                      duration: const Duration(milliseconds: 800),
                      curve: Curves.easeOutCubic,
                    );
                    // Add haptic feedback for a nice touch
                    HapticFeedback.lightImpact();
                  },
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  child: const Icon(Icons.arrow_upward_rounded),
                )
              : null,
        ));
  }

  Widget _buildContent() {
    // Use simple ValueKey for better performance instead of KeyedSubtree
    if (_isLoading) {
      return _buildLoadingState();
    }
    if (_autoCompleteResults.isNotEmpty) {
      return _buildSuggestions();
    }
    if (_searchResults.isNotEmpty) {
      return _buildSearchResults();
    }
    if (_searchResults.isEmpty && _searchController.text.isNotEmpty) {
      return const NoResultsFoundWidget();
    }
    return _buildEmptyState();
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
                  color: Colors.black.withOpacity(0.05),
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

  Widget _buildSearchResults() {
    return RefreshIndicator(
      onRefresh: () => _searchFood(_searchController.text),
      color: Theme.of(context).primaryColor,
      backgroundColor: Theme.of(context).cardColor,
      displacement: 20,
      edgeOffset: 20,
      child: _searchResults.isEmpty
          ? const NoResultsFoundWidget()
          : ListView.builder(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              itemCount: _searchResults.length,
              itemBuilder: (context, index) {
                // Simplify animation to improve performance
                return AnimatedOpacity(
                  duration: const Duration(milliseconds: 250),
                  opacity: 1.0,
                  child: _buildFoodCard(_searchResults[index]),
                );
              },
            ),
    );
  }

  void _navigateToFoodDetail(FoodItem food) {
    HapticFeedback.mediumImpact();

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

    // Simplify card structure to reduce complexity
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            offset: const Offset(0, 2),
            blurRadius: 8,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _onFoodItemTap(food),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Food icon/avatar - simplified with static colors
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: _categoryColor(food.name).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Icon(
                          _categoryIcon(food.name),
                          color: _categoryColor(food.name),
                          size: 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Food name and brand
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            food.name,
                            style: AppTypography.body1.copyWith(
                              color: customColors?.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (food.brandName.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              food.brandName,
                              style: AppTypography.caption.copyWith(
                                color: customColors?.textSecondary,
                              ),
                            ),
                          ],
                          if (defaultServing != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                'Per ${defaultServing.description}',
                                style: AppTypography.caption.copyWith(
                                  color: customColors?.textSecondary,
                                  fontSize: 12,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Simplified nutrition row
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

    return Row(
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
    );
  }

  Widget _buildNutrientChip(String text, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
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

    // Simplified empty state
    return SingleChildScrollView(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 40),
            // Simple illustration
            Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                color: customColors!.cardBackground,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 15,
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: Icon(
                Icons.restaurant_menu_rounded,
                size: 64,
                color: customColors.textPrimary.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'Find Foods',
              style: AppTypography.h2.copyWith(
                color: customColors.textPrimary,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'Search for any food to see nutrition information and track your macros.',
              style: AppTypography.body1.copyWith(
                color: customColors.textSecondary,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            // Quick search chips
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: [
                _buildQuickSearchChip('Chicken', Icons.egg_alt),
                _buildQuickSearchChip('Rice', Icons.grain),
                _buildQuickSearchChip('Broccoli', Icons.eco),
                _buildQuickSearchChip('Apple', Icons.apple),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickSearchChip(String text, IconData icon) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          _searchController.text = text;
          _searchFood(text);
        },
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          decoration: BoxDecoration(
            color: _categoryColor(text).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 14,
                color: _categoryColor(text),
              ),
              const SizedBox(width: 4),
              Text(
                text,
                style: TextStyle(
                  color: _categoryColor(text),
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSuggestions() {
    final customColors = Theme.of(context).extension<CustomColors>();

    // Simplified suggestions UI
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
            child: Text(
              'Suggestions',
              style: AppTypography.body1.copyWith(
                color: customColors?.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: _autoCompleteResults.isEmpty
                ? _buildSuggestionsEmptyState()
                : ListView.builder(
                    itemCount: _autoCompleteResults.length,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemBuilder: (context, index) {
                      if (index < 0 || index >= _autoCompleteResults.length) {
                        return const SizedBox.shrink();
                      }

                      final suggestion = _autoCompleteResults[index];
                      final Color accentColor = _categoryColor(suggestion);

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.03),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () {
                              FocusScope.of(context).unfocus();
                              _searchController.text = suggestion;
                              _searchFood(suggestion);
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 12, horizontal: 16),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: accentColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      _categoryIcon(suggestion),
                                      color: accentColor,
                                      size: 16,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      suggestion,
                                      style: AppTypography.body2.copyWith(
                                        color: customColors?.textPrimary,
                                        fontWeight: FontWeight.w500,
                                      ),
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
          ),
        ],
      ),
    );
  }

  // Simplified helper methods for colors and icons based on categories
  Color _categoryColor(String text) {
    final text_lc = text.toLowerCase();
    if (text_lc.contains('chicken') ||
        text_lc.contains('meat') ||
        text_lc.contains('beef')) {
      return Colors.redAccent;
    } else if (text_lc.contains('vegetable') ||
        text_lc.contains('broccoli') ||
        text_lc.contains('spinach')) {
      return Colors.green;
    } else if (text_lc.contains('rice') ||
        text_lc.contains('bread') ||
        text_lc.contains('pasta')) {
      return Colors.amber;
    } else if (text_lc.contains('fruit') ||
        text_lc.contains('apple') ||
        text_lc.contains('banana')) {
      return Colors.orange;
    } else if (text_lc.contains('fish') || text_lc.contains('seafood')) {
      return Colors.lightBlue;
    } else if (text_lc.contains('dairy') ||
        text_lc.contains('milk') ||
        text_lc.contains('cheese')) {
      return Colors.purple;
    } else {
      // Simple hash-based color that's consistent for the same text
      return Color.fromARGB(
        255,
        150 + (text.hashCode % 90),
        150 + ((text.hashCode >> 3) % 90),
        150 + ((text.hashCode >> 6) % 90),
      );
    }
  }

  IconData _categoryIcon(String text) {
    final text_lc = text.toLowerCase();
    if (text_lc.contains('chicken') ||
        text_lc.contains('meat') ||
        text_lc.contains('beef')) {
      return Icons.restaurant;
    } else if (text_lc.contains('vegetable') ||
        text_lc.contains('broccoli') ||
        text_lc.contains('spinach')) {
      return Icons.eco;
    } else if (text_lc.contains('rice') ||
        text_lc.contains('bread') ||
        text_lc.contains('pasta')) {
      return Icons.grain;
    } else if (text_lc.contains('fruit') ||
        text_lc.contains('apple') ||
        text_lc.contains('banana')) {
      return Icons.apple;
    } else if (text_lc.contains('fish') || text_lc.contains('seafood')) {
      return Icons.water;
    } else if (text_lc.contains('dairy') ||
        text_lc.contains('milk') ||
        text_lc.contains('cheese')) {
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
            color: customColors?.textSecondary.withOpacity(0.5),
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
        prefixIcon: Icon(Icons.search),
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
      calories = double.tryParse(defaultServing['calories'] ?? '0') ?? 0.0;
      // Extract ALL available nutrients from the default serving
      nutrients = {
        'Protein': double.tryParse(defaultServing['protein'] ?? '0') ?? 0.0,
        'Total lipid (fat)':
            double.tryParse(defaultServing['fat'] ?? '0') ?? 0.0,
        'Carbohydrate, by difference':
            double.tryParse(defaultServing['carbohydrate'] ?? '0') ?? 0.0,
        'Saturated fat':
            double.tryParse(defaultServing['saturated_fat'] ?? '0') ?? 0.0,
        'Polyunsaturated fat':
            double.tryParse(defaultServing['polyunsaturated_fat'] ?? '0') ??
                0.0,
        'Monounsaturated fat':
            double.tryParse(defaultServing['monounsaturated_fat'] ?? '0') ??
                0.0,
        'Cholesterol':
            double.tryParse(defaultServing['cholesterol'] ?? '0') ?? 0.0,
        'Sodium': double.tryParse(defaultServing['sodium'] ?? '0') ?? 0.0,
        'Potassium': double.tryParse(defaultServing['potassium'] ?? '0') ?? 0.0,
        'Fiber': double.tryParse(defaultServing['fiber'] ?? '0') ?? 0.0,
        'Sugar': double.tryParse(defaultServing['sugar'] ?? '0') ?? 0.0,
        'Vitamin A': double.tryParse(defaultServing['vitamin_a'] ?? '0') ?? 0.0,
        'Vitamin C': double.tryParse(defaultServing['vitamin_c'] ?? '0') ?? 0.0,
        'Calcium': double.tryParse(defaultServing['calcium'] ?? '0') ?? 0.0,
        'Iron': double.tryParse(defaultServing['iron'] ?? '0') ?? 0.0,
      };
      // Remove nutrients with value 0 to keep the map cleaner, unless it's a primary macro
      nutrients.removeWhere((key, value) =>
          value == 0.0 &&
          !['Protein', 'Total lipid (fat)', 'Carbohydrate, by difference']
              .contains(key));

      // Try to parse serving size
      servingSize =
          double.tryParse(defaultServing['metric_serving_amount'] ?? '100') ??
              100.0;
    }

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

  static Map<String, double> _parseFatSecretNutrients(String description) {
    final regex = RegExp(
      r'Calories:\s*(\d+).*?Fat:\s*(\d+).*?Carbs:\s*(\d+).*?Protein:\s*(\d+)',
      caseSensitive: false,
    );
    final match = regex.firstMatch(description);
    if (match != null) {
      return {
        'calories': double.parse(match.group(1) ?? '0'),
        'fat': double.parse(match.group(2) ?? '0'),
        'carbs': double.parse(match.group(3) ?? '0'),
        'protein': double.parse(match.group(4) ?? '0'),
      };
    }
    return {};
  }

  static Map<String, double> _parseServingInfo(String description) {
    // Try to find serving size in grams
    final servingSizeRegex =
        RegExp(r'Per\s+(\d+)\s*g\s+serving', caseSensitive: false);
    final match = servingSizeRegex.firstMatch(description);
    if (match != null) {
      return {
        'size': double.parse(match.group(1) ?? '100'),
      };
    }
    return {'size': 100.0}; // Default to 100g if no serving size found
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

  factory Serving.fromJson(Map<String, dynamic> json) {
    // Extract all nutrients
    Map<String, double> nutrients = {
      'Protein': double.tryParse(json['protein'] ?? '0') ?? 0.0,
      'Total lipid (fat)': double.tryParse(json['fat'] ?? '0') ?? 0.0,
      'Carbohydrate, by difference':
          double.tryParse(json['carbohydrate'] ?? '0') ?? 0.0,
      'Saturated fat': double.tryParse(json['saturated_fat'] ?? '0') ?? 0.0,
      'Polyunsaturated fat':
          double.tryParse(json['polyunsaturated_fat'] ?? '0') ?? 0.0,
      'Monounsaturated fat':
          double.tryParse(json['monounsaturated_fat'] ?? '0') ?? 0.0,
      'Cholesterol': double.tryParse(json['cholesterol'] ?? '0') ?? 0.0,
      'Sodium': double.tryParse(json['sodium'] ?? '0') ?? 0.0,
      'Potassium': double.tryParse(json['potassium'] ?? '0') ?? 0.0,
      'Fiber': double.tryParse(json['fiber'] ?? '0') ?? 0.0,
      'Sugar': double.tryParse(json['sugar'] ?? '0') ?? 0.0,
      'Vitamin A': double.tryParse(json['vitamin_a'] ?? '0') ?? 0.0,
      'Vitamin C': double.tryParse(json['vitamin_c'] ?? '0') ?? 0.0,
      'Calcium': double.tryParse(json['calcium'] ?? '0') ?? 0.0,
      'Iron': double.tryParse(json['iron'] ?? '0') ?? 0.0,
    };

    return Serving(
      description: json['serving_description'] ?? 'Default serving',
      metricAmount:
          double.tryParse(json['metric_serving_amount'] ?? '0') ?? 0.0,
      metricUnit: json['metric_serving_unit'] ?? 'g',
      calories: double.tryParse(json['calories'] ?? '0') ?? 0.0,
      nutrients: nutrients,
    );
  }
}

class NoResultsFoundWidget extends StatelessWidget {
  const NoResultsFoundWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final customColors = Theme.of(context).extension<CustomColors>();

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Simple icon instead of animation
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
              "Try a different search term or ask AI for help",
              style: AppTypography.body2.copyWith(
                color: customColors?.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // Simple button for AI help
            ElevatedButton.icon(
              onPressed: () {
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
