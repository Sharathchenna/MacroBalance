// food_search_page.dart
// ignore_for_file: unused_import, file_names, library_private_types_in_public_api, avoid_print, use_build_context_synchronously

import 'dart:convert';
import 'dart:io'; // For Platform check and File operations
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:macrotracker/camera/barcode_results.dart';
import 'package:macrotracker/camera/results_page.dart';
import 'package:macrotracker/models/ai_food_item.dart';
import 'package:macrotracker/screens/askAI.dart';
import 'package:macrotracker/services/food_icon_service.dart';
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
import 'package:macrotracker/services/ai_food_search_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
// import 'package:macrotracker/camera/camera.dart'; // No longer needed

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
  // Method Channel for the native camera view
  static const MethodChannel _nativeCameraViewChannel =
      MethodChannel('com.macrotracker/native_camera_view');

  final TextEditingController _searchController = TextEditingController();
  List<FoodItem> _searchResults = [];
  List<FoodItem> _aiSearchResults = [];
  bool _isLoading = false;
  // Track if the search was triggered by the search button
  bool _searchButtonClicked = false;
  final AIFoodSearchService _aiSearchService = AIFoodSearchService();

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
    
    // Track screen view
    PostHogService.trackScreen('food_search_page');
    
    _loadingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    // Add listener to the search controller to detect when it's cleared
    _searchController.addListener(() {
      // Check if the search text is empty and clear results
      if (_searchController.text.isEmpty) {
        setState(() {
          _searchResults = [];
          _isLoading = false;
          _searchButtonClicked = false;
        });
      }
    });
  }

  @override
  void dispose() {
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
      // Autocomplete removed
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
          // Autocomplete removed
        });
      }
      // --- End Refined Parsing ---
    } else {
      // Error handled in _callFatSecretProxy
      if (mounted) {
        // Add mounted check
        // Autocomplete removed
      }
    }
  }
  */

  void _onSearchChanged(String query) {
    // Only clear results if query is empty - no real-time search
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
      });
    }
  }

  Future<void> _searchFood(String query,
      {bool fromSearchButton = false}) async {
    // If query is empty, just clear results without loading indicator
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _aiSearchResults = [];
        // No autocomplete to clear
        _isLoading = false;
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
      _isLoading = true;
      _searchButtonClicked = fromSearchButton;
    });

    // Run both database and AI search concurrently
    await Future.wait([
      _searchDatabase(query),
      _searchAI(query),
    ]);

    // Ensure loading state is turned off regardless of success/failure
    if (mounted) {
      // Check if the widget is still in the tree
      setState(() {
        _isLoading = false;
        // Don't reset _searchButtonClicked here to keep animation state consistent
      });
    }
  }

  Future<void> _searchDatabase(String query) async {
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
        if (mounted) {
          setState(() {
            _searchResults =
                foods.map((food) => FoodItem.fromFatSecretJson(food)).toList();
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _searchResults = [];
          });
        }
      }
    } else {
      // Error handled in _callFatSecretProxy
      if (mounted) {
        setState(() {
          _searchResults = [];
          _aiSearchResults = [];
        });
      }
    }
  }

  Future<void> _searchAI(String query) async {
    try {
      final aiSuggestions = await _aiSearchService.searchFoodsWithAI(query);
      if (mounted) {
        setState(() {
          _aiSearchResults = aiSuggestions.map((suggestion) => suggestion.toFoodItem()).toList();
        });
      }
    } catch (e) {
      print('Error searching AI: $e');
      if (mounted) {
        setState(() {
          _aiSearchResults = [];
        });
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
              print(
                  '[Flutter SearchPage] Post-frame: Handling barcode: $barcode');
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
    FocusScope.of(context).unfocus();
    if (!Platform.isIOS) {
      print('[Flutter SearchPage] Native camera view only supported on iOS.');
      if (mounted) {
        _showErrorSnackbar('Camera feature is only available on iOS.');
      }
      return;
    }

    // Track camera usage
    PostHogService.trackFeatureUsage(
      'camera_search',
      properties: {
        'platform': Platform.operatingSystem,
      },
    );

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
      final String tempPath =
          '${tempDir.path}/${DateTime.now().millisecondsSinceEpoch}.jpg';
      final File tempFile = File(tempPath);
      await tempFile.writeAsBytes(photoData);
      print('[Flutter SearchPage] Photo saved to temporary file: $tempPath');
      String jsonResponse = await processImageWithGemini(tempFile.path);
      print('[Flutter SearchPage] Gemini response received.');
      jsonResponse =
          jsonResponse.trim().replaceAll('```json', '').replaceAll('```', '');
      dynamic decodedJson = json.decode(jsonResponse);
      List<dynamic> mealData;
      if (decodedJson is Map<String, dynamic> &&
          decodedJson.containsKey('meal') &&
          decodedJson['meal'] is List) {
        mealData = decodedJson['meal'] as List;
      } else if (decodedJson is List) {
        mealData = decodedJson;
      } else if (decodedJson is Map<String, dynamic>) {
        mealData = [decodedJson];
      } else {
        throw Exception('Unexpected JSON structure from Gemini');
      }
      final List<AIFoodItem> foods = mealData
          .map((food) => AIFoodItem.fromJson(food as Map<String, dynamic>))
          .toList();

      if (mounted) {
        try {
          if (Navigator.of(safeContext, rootNavigator: true).canPop())
            Navigator.of(safeContext, rootNavigator: true).pop();
        } catch (e) {
          print("[Flutter SearchPage] Error dismissing loading dialog: $e");
        }
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
      print(
          '[Flutter SearchPage] Error processing photo result: ${e.toString()}');
      if (mounted) {
        try {
          if (Navigator.of(safeContext, rootNavigator: true).canPop())
            Navigator.of(safeContext, rootNavigator: true).pop();
        } catch (e) {
          print(
              "[Flutter SearchPage] Error dismissing loading dialog in catch: $e");
        }
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
          backgroundColor: Theme.of(context).brightness == Brightness.light
              ? Colors.white
              : Colors.grey[850],
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Lottie.asset(
                  'assets/animations/food_loading.json',
                  width: 150,
                  height: 150,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 20),
                Text(
                  message,
                  style: TextStyle(
                      color: Theme.of(context).brightness == Brightness.light
                          ? Colors.black87
                          : Colors.white,
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
                    onSearch: (query) =>
                        _searchFood(query, fromSearchButton: true),
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
    // Show Lottie animation only when search button is clicked
    if (_isLoading && _searchButtonClicked) {
      return _buildLoadingState();
    }
    // Show placeholder cards during debounced loading (typing)
    if (_isLoading && !_searchButtonClicked) {
      return _buildPlaceholderCards();
    }
    // Show search results
    if (_searchResults.isNotEmpty || _aiSearchResults.isNotEmpty) {
      return _buildCombinedSearchResults();
    }
    if (_searchResults.isEmpty && _aiSearchResults.isEmpty && _searchController.text.isNotEmpty) {
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

  Widget _buildCombinedSearchResults() {
    return RefreshIndicator(
      onRefresh: () => _searchFood(_searchController.text),
      color: Theme.of(context).primaryColor,
      backgroundColor: Theme.of(context).cardColor,
      displacement: 20,
      edgeOffset: 20,
      child: CustomScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          // AI Results Section
          if (_aiSearchResults.isNotEmpty) ...[
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              sliver: SliverToBoxAdapter(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.purple.withOpacity(0.8),
                            Colors.blue.withOpacity(0.8),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.smart_toy_rounded,
                            color: Colors.white,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'AI Suggestions',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'AI-generated food suggestions',
                        style: TextStyle(
                          color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.6),
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    if (index < 0 || index >= _aiSearchResults.length) {
                      return const SizedBox.shrink();
                    }
                    return AnimatedOpacity(
                      duration: const Duration(milliseconds: 250),
                      opacity: 1.0,
                      child: _buildFoodCard(_aiSearchResults[index], isAI: true),
                    );
                  },
                  childCount: _aiSearchResults.length,
                ),
              ),
            ),
          ],
          
          // Database Results Section
          if (_searchResults.isNotEmpty) ...[
            SliverPadding(
              padding: EdgeInsets.fromLTRB(16, _aiSearchResults.isNotEmpty ? 16 : 16, 16, 8),
              sliver: SliverToBoxAdapter(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.storage,
                            color: Colors.white,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Database Results',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'From nutrition database',
                        style: TextStyle(
                          color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.6),
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    if (index < 0 || index >= _searchResults.length) {
                      return const SizedBox.shrink();
                    }
                    return AnimatedOpacity(
                      duration: const Duration(milliseconds: 250),
                      opacity: 1.0,
                      child: _buildFoodCard(_searchResults[index], isAI: false),
                    );
                  },
                  childCount: _searchResults.length,
                ),
              ),
            ),
          ],
          
          // Empty state if no results
          if (_searchResults.isEmpty && _aiSearchResults.isEmpty)
            const SliverToBoxAdapter(
              child: NoResultsFoundWidget(),
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
                // Safety check to avoid index out of range errors
                if (index < 0 || index >= _searchResults.length) {
                  return const SizedBox.shrink();
                }

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

  Widget _buildFoodCard(FoodItem food, {bool isAI = false}) {
    // Get the default serving (first serving)
    final defaultServing =
        food.servings.isNotEmpty ? food.servings.first : null;
    final customColors = Theme.of(context).extension<CustomColors>();
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final accentColor = _categoryColor(food.name);

    // Enhanced premium card design with AI indicator
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            offset: const Offset(0, 3),
            blurRadius: 10,
            spreadRadius: 0,
          ),
          BoxShadow(
            color: accentColor.withOpacity(0.025),
            offset: const Offset(0, 1),
            blurRadius: 8,
            spreadRadius: 0,
          ),
        ],
        border: Border.all(
          color: isAI 
              ? Colors.purple.withOpacity(0.2)
              : isDarkMode
                  ? Colors.grey.withOpacity(0.1)
                  : Colors.grey.withOpacity(0.08),
          width: isAI ? 1.0 : 0.5,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _onFoodItemTap(food),
          splashColor: accentColor.withOpacity(0.1),
          highlightColor: accentColor.withOpacity(0.05),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Enhanced food icon with gradient
                    Stack(
                      children: [
                        Container(
                          width: 54,
                          height: 54,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                accentColor.withOpacity(0.15),
                                accentColor.withOpacity(0.05),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: accentColor.withOpacity(0.15),
                                offset: const Offset(0, 2),
                                blurRadius: 6,
                                spreadRadius: -2,
                              ),
                            ],
                          ),
                          child: Center(
                            child: _buildFoodIcon(food.name, accentColor, 24),
                          ),
                        ),
                        // AI badge
                        if (isAI)
                          Positioned(
                            top: -2,
                            right: -2,
                            child: Container(
                              width: 18,
                              height: 18,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.purple.withOpacity(0.9),
                                    Colors.blue.withOpacity(0.9),
                                  ],
                                ),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.purple.withOpacity(0.3),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Icon(
                                  Icons.smart_toy_rounded,
                                  color: Colors.white,
                                  size: 10,
                                ),
                              ),
                            ),
                          ),
                      ],
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
                                    ?.withOpacity(0.9),
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
                                      .withOpacity(0.8),
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

    // Enhanced premium empty state
    return SingleChildScrollView(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 60),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 40),
            // Premium visual element - layered containers with gradient
            Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Theme.of(context).primaryColor.withOpacity(0.1),
                    Theme.of(context).primaryColor.withOpacity(0.05),
                  ],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context).primaryColor.withOpacity(0.15),
                    blurRadius: 30,
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: Center(
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                      colors: [
                        Theme.of(context).primaryColor.withOpacity(0.2),
                        Theme.of(context).primaryColor.withOpacity(0.1),
                      ],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Theme.of(context).primaryColor.withOpacity(0.1),
                        blurRadius: 20,
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 15,
                            spreadRadius: 0,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Icon(
                          Icons.search_rounded,
                          size: 40,
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'Discover Foods',
              style: AppTypography.h2.copyWith(
                color: customColors?.textPrimary,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'Search for any food to see detailed nutrition information and track your daily macros.',
              style: AppTypography.body1.copyWith(
                color: customColors?.textSecondary,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            // const SizedBox(height: 32),
            // Enhanced quick search chips
            // Wrap(
            //   spacing: 12,
            //   runSpacing: 12,
            //   alignment: WrapAlignment.center,
            //   children: [
            //     _buildQuickSearchChip('Chicken', Icons.egg_alt),
            //     _buildQuickSearchChip('Rice', Icons.grain),
            //     _buildQuickSearchChip('Broccoli', Icons.eco),
            //     _buildQuickSearchChip('Apple', Icons.apple),
            //   ],
            // ),
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
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: _categoryColor(text).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 16,
                  color: _categoryColor(text),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                text,
                style: TextStyle(
                  color: Theme.of(context).brightness == Brightness.light
                      ? Colors.black87
                      : Colors.white70,
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
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

  Widget _buildFoodIcon(String foodName, Color accentColor, double size) {
    return FutureBuilder<String?>(
      future: FoodIconService.getFoodIconUrl(foodName),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data != null) {
          // Show actual food image
          return ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: CachedNetworkImage(
              imageUrl: snapshot.data!,
              width: size * 1.5,
              height: size * 1.5,
              fit: BoxFit.cover,
              placeholder: (context, url) => SizedBox(
                width: size,
                height: size,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                ),
              ),
              errorWidget: (context, url, error) => Icon(
                _categoryIcon(foodName),
                color: accentColor,
                size: size,
              ),
            ),
          );
        } else {
          // Show fallback icon while loading or if no image found
          return Icon(
            _categoryIcon(foodName),
            color: accentColor,
            size: size,
          );
        }
      },
    );
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
            color: Colors.black.withOpacity(0.05),
            offset: const Offset(0, 3),
            blurRadius: 10,
            spreadRadius: 0,
          ),
        ],
        border: Border.all(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.grey.withOpacity(0.1)
              : Colors.grey.withOpacity(0.08),
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
                    color: Colors.grey.withOpacity(0.2),
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
                          color: Colors.grey.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 12,
                        width: 120,
                        decoration: BoxDecoration(
                          color: Colors.grey.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 10,
                        width: 80,
                        decoration: BoxDecoration(
                          color: Colors.grey.withOpacity(0.1),
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
                    color: Colors.grey.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  height: 22,
                  width: 60,
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  height: 22,
                  width: 65,
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.15),
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
              "Try a different search term or ask AI for help",
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
