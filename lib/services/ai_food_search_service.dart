import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../screens/searchPage.dart';

class AIFoodSearchService {
  static const String _aiSearchUrl = 'https://mdivtblabmnftdqlgysv.supabase.co/functions/v1/ai-food-search';
  final _supabase = Supabase.instance.client;

  Future<List<AIFoodSuggestion>> searchFoodsWithAI(String query) async {
    try {
      final session = _supabase.auth.currentSession;
      if (session == null) {
        throw Exception('User not authenticated');
      }

      final response = await http.post(
        Uri.parse(_aiSearchUrl),
        headers: {
          'Authorization': 'Bearer ${session.accessToken}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'query': query,
          'max_results': 3, // Limit AI suggestions to avoid overwhelming UI
        }),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final suggestions = responseData['suggestions'] as List?;
        
        if (suggestions != null) {
          return suggestions
              .map((suggestion) => AIFoodSuggestion.fromJson(suggestion))
              .toList();
        }
      } else {
        // Log error for debugging - consider using proper logging in production
        // print('AI Search Error (${response.statusCode}): ${response.body}');
      }
    } catch (e) {
      // Log error for debugging - consider using proper logging in production
      // print('Error calling AI food search: $e');
    }
    
    return [];
  }
}

class AIFoodSuggestion {
  final String name;
  final String brandName;
  final double calories;
  final double protein;
  final double carbohydrates;
  final double fat;
  final double fiber;
  final String servingSize;
  final String description;
  final bool isAIGenerated;

  AIFoodSuggestion({
    required this.name,
    required this.brandName,
    required this.calories,
    required this.protein,
    required this.carbohydrates,
    required this.fat,
    required this.fiber,
    required this.servingSize,
    required this.description,
    this.isAIGenerated = true,
  });

  factory AIFoodSuggestion.fromJson(Map<String, dynamic> json) {
    return AIFoodSuggestion(
      name: json['name'] ?? 'Unknown Food',
      brandName: json['brand_name'] ?? 'AI Generated',
      calories: (json['calories'] as num?)?.toDouble() ?? 0.0,
      protein: (json['protein'] as num?)?.toDouble() ?? 0.0,
      carbohydrates: (json['carbohydrates'] as num?)?.toDouble() ?? 0.0,
      fat: (json['fat'] as num?)?.toDouble() ?? 0.0,
      fiber: (json['fiber'] as num?)?.toDouble() ?? 0.0,
      servingSize: json['serving_size'] ?? '100g',
      description: json['description'] ?? 'AI-generated food suggestion',
      isAIGenerated: true,
    );
  }

  // Convert to FoodItem for compatibility with existing UI
  FoodItem toFoodItem() {
    return FoodItem(
      fdcId: 'ai_${name.hashCode}',
      name: name,
      calories: calories,
      nutrients: {
        'Protein': protein,
        'Carbohydrate, by difference': carbohydrates,
        'Total lipid (fat)': fat,
        'Fiber': fiber,
      },
      brandName: brandName,
      mealType: 'breakfast',
      servingSize: double.tryParse(servingSize.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 100.0,
      servings: [
        Serving(
          description: servingSize,
          metricAmount: double.tryParse(servingSize.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 100.0,
          metricUnit: servingSize.replaceAll(RegExp(r'[0-9.]'), '').trim(),
          calories: calories,
          nutrients: {
            'Protein': protein,
            'Carbohydrate, by difference': carbohydrates,
            'Total lipid (fat)': fat,
            'Fiber': fiber,
          },
        ),
      ],
    );
  }
}