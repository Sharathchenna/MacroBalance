import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/ai_food_item.dart';
import '../screens/searchPage.dart';

class AIFoodSearchService {
  static const String _aiSearchUrl = 'https://mdivtblabmnftdqlgysv.supabase.co/functions/v1/ai-food-search';
  final _supabase = Supabase.instance.client;

  /// Returns AI food suggestions in the same multi-serving shape the photo and
  /// Ask AI flows use, so all three open the same detail screen.
  Future<List<AIFoodItem>> searchFoodsWithAI(String query) async {
    try {
      final session = _supabase.auth.currentSession;
      if (session == null) {
        throw Exception('User not authenticated');
      }

      final response = await http
          .post(
            Uri.parse(_aiSearchUrl),
            headers: {
              'Authorization': 'Bearer ${session.accessToken}',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'query': query,
              'max_results': 3, // Limit AI suggestions to avoid overwhelming UI
            }),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final items = responseData['items'] as List?;
        if (items != null) {
          return items
              .map((item) => _tryParse(() => AIFoodItem.fromJson(item)))
              .whereType<AIFoodItem>()
              .toList();
        }
        // Older deployments of the edge function only return `suggestions`.
        final suggestions = responseData['suggestions'] as List?;
        if (suggestions != null) {
          return suggestions
              .map((s) => _tryParse(() => AIFoodSuggestion.fromJson(s).toAIFoodItem()))
              .whereType<AIFoodItem>()
              .toList();
        }
      }
    } catch (e) {
      // AI suggestions are optional; database results still show.
    }

    return [];
  }

  static AIFoodItem? _tryParse(AIFoodItem Function() parse) {
    try {
      return parse();
    } catch (_) {
      return null;
    }
  }
}

/// Converts an AI item's first serving into a [FoodItem] for the search result
/// cards, which are shared with database results.
FoodItem aiItemToDisplayFoodItem(AIFoodItem item) {
  final nutrients = {
    'Protein': item.protein.first,
    'Carbohydrate, by difference': item.carbohydrates.first,
    'Total lipid (fat)': item.fat.first,
    'Fiber': item.fiber.first,
  };
  return FoodItem(
    fdcId: 'ai_${item.name.hashCode}',
    name: item.name,
    calories: item.calories.first,
    nutrients: nutrients,
    brandName: 'AI Generated',
    mealType: 'breakfast',
    servingSize: 1,
    // Lets the card read "Per 1 slice (35g)" rather than a fixed 100g.
    servings: [
      Serving(
        description: item.servingSizes.first,
        metricAmount: 1,
        metricUnit: 'serving',
        calories: item.calories.first,
        nutrients: nutrients,
      ),
    ],
  );
}

/// Legacy single-serving response from older edge function deployments.
class AIFoodSuggestion {
  final String name;
  final double calories;
  final double protein;
  final double carbohydrates;
  final double fat;
  final double fiber;
  final String servingSize;

  AIFoodSuggestion({
    required this.name,
    required this.calories,
    required this.protein,
    required this.carbohydrates,
    required this.fat,
    required this.fiber,
    required this.servingSize,
  });

  factory AIFoodSuggestion.fromJson(Map<String, dynamic> json) {
    return AIFoodSuggestion(
      name: json['name'] ?? 'Unknown Food',
      calories: (json['calories'] as num?)?.toDouble() ?? 0.0,
      protein: (json['protein'] as num?)?.toDouble() ?? 0.0,
      carbohydrates: (json['carbohydrates'] as num?)?.toDouble() ?? 0.0,
      fat: (json['fat'] as num?)?.toDouble() ?? 0.0,
      fiber: (json['fiber'] as num?)?.toDouble() ?? 0.0,
      servingSize: json['serving_size'] ?? '100g',
    );
  }

  AIFoodItem toAIFoodItem() {
    return AIFoodItem(
      name: name,
      servingSizes: [servingSize],
      calories: [calories],
      protein: [protein],
      carbohydrates: [carbohydrates],
      fat: [fat],
      fiber: [fiber],
    );
  }
}
