// ignore_for_file: avoid_print

import 'dart:io';
import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';

Future<String> processImageWithGemini(String imagePath) async {
  try {
    const apiKey = 'AIzaSyDe8qpEeJHOYJtJviyr4GVH2_ssCUy9gZc';
    final model = GenerativeModel(
      model: 'gemini-2.0-flash-lite-preview-02-05',
      apiKey: apiKey,
    );

    final prompt = '''
        Analyze this food item and return ONLY a JSON object with this exact structure:
        {
          "food": "Exact Food Name",
          "servingSizes": [
            {
              "unit": "100g",
              "nutritionInfo": {
                "calories": number,
                "protein": number,
                "carbohydrates": number,
                "fat": number,
                "fiber": number
              }
            }
          ]
        }

        Requirements:
        - First serving MUST be "100g"
        - Include at least 2 common serving sizes
        - All values must be numbers, not strings
        - All fields are required
        - Return only the JSON, no other text
        ''';

    final imageBytes = await File(imagePath).readAsBytes();
    final content = [
      Content.multi([
        TextPart(prompt),
        DataPart('image/jpeg', imageBytes),
      ]),
    ];

    final response = await model.generateContent(content);
    if (response.text == null || response.text!.isEmpty) {
      throw Exception('Empty response from Gemini');
    }

    String cleanedResponse = response.text!.trim();

    // Remove markdown code blocks if present
    if (cleanedResponse.startsWith('```json')) {
      cleanedResponse = cleanedResponse.substring(7);
    }
    if (cleanedResponse.endsWith('```')) {
      cleanedResponse =
          cleanedResponse.substring(0, cleanedResponse.length - 3);
    }

    // Parse JSON to validate structure
    final decodedJson = json.decode(cleanedResponse);
    if (decodedJson == null) {
      throw Exception('Invalid JSON response');
    }

    return cleanedResponse;
  } catch (e) {
    print('Error processing image with Gemini: $e');
    throw Exception('Failed to process image: $e');
  }
}
