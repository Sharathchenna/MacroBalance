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
        Break down the meal into different foods and do the nutrition analysis for each food.
        give nutrition info for each food in the meal with different serving sizes. the serving sizes can be in grams, ounces, tablespoons, teaspoons, cups etc.
        Return only the numerical values for calories, protein, carbohydrates, fat, and fiber.
        Format the response in json exactly like this example, do not include any other information in the response, just the json object, not even the json title in the response.:
        meal: [
          {
            food: "food name",
            serving_size: "serving size",
            calories: 100,
            protein: 10,
            carbohydrates: 20,
            fat: 5,
            fiber: 3
          },
          {
            food: "food name",
            serving_size: "serving size",
            calories: 100,
            protein: 10,
            carbohydrates: 20,
            fat: 5,
            fiber: 3
          }
        ]
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
