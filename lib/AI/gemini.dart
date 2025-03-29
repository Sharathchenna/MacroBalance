// ignore_for_file: avoid_print

import 'dart:io';
import 'package:firebase_vertexai/firebase_vertexai.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

Future<String> processImageWithGemini(String imagePath) async {
  try {
    print('[Gemini Debug] Starting Gemini processing at ${DateTime.now().toString()}');
    final startTime = DateTime.now();
    
    print('[Gemini Debug] Initializing model...');
    final model = FirebaseVertexAI.instance.generativeModel(model: 'gemini-2.0-flash');
    print('[Gemini Debug] Model initialized in ${DateTime.now().difference(startTime).inMilliseconds}ms');

    final promptText = '''
        Analyze the following meal and provide its nutritional content. 
        Break down the meal into different foods and do the nutrition analysis for each food.
        give nutrition info for each food in the meal with different serving sizes. the serving sizes can be in grams, ounces, tablespoons, teaspoons, cups etc.
        Return only the numerical values for calories, protein, carbohydrates, fat, and fiber.
        Format the response in json exactly like this example, do not include any other information in the response, just the json object, not even the json title in the response.:
        meal: [
          {
            food: "food name 1",
            serving_size: ["serving size 1", "serving size 2", "serving size 3"],
            calories: [calories for serving 1, calories for serving 2, calories for serving 3],
            protein: [protein for serving 1, protein for serving 2, protein for serving 3],
            carbohydrates: [carbohydrates for serving 1, carbohydrates for serving 2, carbohydrates for serving 3],
            fat: [fat for serving 1, fat for serving 2, fat for serving 3],
            fiber: [fiber for serving 1, fiber for serving 2, fiber for serving 3]
          },
          {
            food: "food name 2",
            serving_size: ["serving size 1", "serving size 2", "serving size 3"],
            calories: [calories for serving 1, calories for serving 2, calories for serving 3],
            protein: [protein for serving 1, protein for serving 2, protein for serving 3],
            carbohydrates: [carbohydrates for serving 1, carbohydrates for serving 2, carbohydrates for serving 3],
            fat: [fat for serving 1, fat for serving 2, fat for serving 3],
            fiber: [fiber for serving 1, fiber for serving 2, fiber for serving 3]
          },
        ]
        ''';
    
    print('[Gemini Debug] Reading and compressing image file...');
    final imageReadStart = DateTime.now();
    
    // Read original image size
    final File originalImage = File(imagePath);
    final originalBytes = await originalImage.readAsBytes();
    print('[Gemini Debug] Original image size: ${originalBytes.length} bytes');
    
    // Compress the image (reduce quality and size)
    final compressedImageStart = DateTime.now();
    final targetPath = imagePath.replaceFirst('.jpg', '_compressed.jpg');
    final compressedFile = await FlutterImageCompress.compressAndGetFile(
      imagePath,
      targetPath,
      quality: 50, // Adjust quality (0-100)
      minWidth: 1024, // Reduce dimensions if larger
      minHeight: 1024,
    );
    
    final imageBytes = await compressedFile!.readAsBytes();
    print('[Gemini Debug] Compressed to ${imageBytes.length} bytes (${(imageBytes.length / originalBytes.length * 100).toStringAsFixed(1)}% of original)');
    print('[Gemini Debug] Compression completed in ${DateTime.now().difference(compressedImageStart).inMilliseconds}ms');
    print('[Gemini Debug] Total image processing time: ${DateTime.now().difference(imageReadStart).inMilliseconds}ms');

    print('[Gemini Debug] Preparing content parts...');
    final prompt = TextPart(promptText);
    final imagePart = InlineDataPart('image/jpeg', imageBytes);

    print('[Gemini Debug] Sending request to Gemini API...');
    final apiCallStart = DateTime.now();
    final response = await model.generateContent([
      Content.multi([prompt, imagePart])
    ]);
    print('[Gemini Debug] Gemini API response received in ${DateTime.now().difference(apiCallStart).inMilliseconds}ms');
    
    // Clean up temp file
    try {
      await File(targetPath).delete();
      print('[Gemini Debug] Temporary compressed image deleted');
    } catch (e) {
      print('[Gemini Debug] Warning: Could not delete temp file: $e');
    }
    
    final responseText = response.text ?? 'No response from Gemini';
    print('[Gemini Debug] Total Gemini processing time: ${DateTime.now().difference(startTime).inMilliseconds}ms');
    
    return responseText;
  } catch (error) {
    print('Error processing image with Gemini: $error');
    return 'Error processing image: $error';
  }
}
