import 'dart:convert';
import 'package:http/http.dart' as http;

class FoodIconService {
  static const String _unsplashAccessKey = 'YOUR_UNSPLASH_ACCESS_KEY'; // Replace with your key
  static const String _unsplashApiUrl = 'https://api.unsplash.com/search/photos';
  
  // Cache for food icons to avoid repeated API calls
  static final Map<String, String> _iconCache = {};
  
  /// Get food icon URL for a given food name
  /// Returns a URL to a food image or null if not found
  static Future<String?> getFoodIconUrl(String foodName) async {
    // Check cache first
    if (_iconCache.containsKey(foodName.toLowerCase())) {
      return _iconCache[foodName.toLowerCase()];
    }
    
    try {
      // Clean the food name for better search results
      final cleanFoodName = _cleanFoodName(foodName);
      
      final response = await http.get(
        Uri.parse('$_unsplashApiUrl?query=$cleanFoodName food&per_page=1&orientation=square'),
        headers: {
          'Authorization': 'Client-ID $_unsplashAccessKey',
        },
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final results = data['results'] as List?;
        
        if (results != null && results.isNotEmpty) {
          final imageUrl = results[0]['urls']['small'] as String?;
          if (imageUrl != null) {
            // Cache the result
            _iconCache[foodName.toLowerCase()] = imageUrl;
            return imageUrl;
          }
        }
      }
    } catch (e) {
      print('Error fetching food icon: $e');
    }
    
    return null;
  }
  
  /// Clean food name for better search results
  static String _cleanFoodName(String foodName) {
    // Remove common prefixes/suffixes and clean the name
    String cleaned = foodName.toLowerCase()
        .replaceAll(RegExp(r'\b(raw|cooked|fresh|frozen|organic|natural)\b'), '')
        .replaceAll(RegExp(r'\b(per|100g|serving|cup|slice)\b'), '')
        .replaceAll(RegExp(r'[^\w\s]'), '')
        .trim();
    
    // Take only the first 2-3 words for better search results
    List<String> words = cleaned.split(' ').where((word) => word.isNotEmpty).toList();
    if (words.length > 2) {
      words = words.take(2).toList();
    }
    
    return words.join(' ');
  }
  
  /// Get fallback food icon based on food category
  static String getFallbackIcon(String foodName) {
    final lowerName = foodName.toLowerCase();
    
    // Categorize foods and return appropriate fallback icons
    if (lowerName.contains('apple') || lowerName.contains('banana') || 
        lowerName.contains('orange') || lowerName.contains('fruit')) {
      return 'assets/icons/fruit.png';
    } else if (lowerName.contains('chicken') || lowerName.contains('beef') || 
               lowerName.contains('pork') || lowerName.contains('meat')) {
      return 'assets/icons/meat.png';
    } else if (lowerName.contains('bread') || lowerName.contains('rice') || 
               lowerName.contains('pasta') || lowerName.contains('grain')) {
      return 'assets/icons/grain.png';
    } else if (lowerName.contains('milk') || lowerName.contains('cheese') || 
               lowerName.contains('yogurt') || lowerName.contains('dairy')) {
      return 'assets/icons/dairy.png';
    } else if (lowerName.contains('lettuce') || lowerName.contains('carrot') || 
               lowerName.contains('vegetable') || lowerName.contains('salad')) {
      return 'assets/icons/vegetable.png';
    }
    
    return 'assets/icons/food_default.png';
  }
}