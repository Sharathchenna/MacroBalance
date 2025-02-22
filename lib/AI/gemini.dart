// ignore_for_file: avoid_print

import 'dart:io';
import 'package:google_generative_ai/google_generative_ai.dart';

Future<String> processImageWithGemini(String imagePath) async {
  try {
    const apiKey =
        'AIzaSyDe8qpEeJHOYJtJviyr4GVH2_ssCUy9gZc'; // Replace with your actual API key
    final model = GenerativeModel(
      model: 'gemini-2.0-flash-lite-preview-02-05',
      apiKey: apiKey,
    );
    final prompt = '''
        Analyze the following meal and provide its nutritional content. 
        Return only the numerical values for calories, protein, carbohydrates, fat, and fiber.
        Format the response exactly like this example:
        Nutrition Content:
        • Calories: X kcal
        • Protein: X g
        • Carbohydrates: X g
        • Fat: X g
        • Fiber: X g
        ''';
    final imageBytes = await File(imagePath).readAsBytes();

    final content = [
      Content.multi([
        TextPart(prompt),
        DataPart('image/jpeg', imageBytes),
      ]),
    ];

    final response = await model.generateContent(content);
    return response.text ?? 'No response from Gemini';
  } catch (e) {
    print('Error processing image with Gemini: $e');
    return 'Error processing image: $e';
  }
}
