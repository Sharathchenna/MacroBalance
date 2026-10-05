// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:macrotracker/models/ai_food_item.dart';

/// Why a meal photo couldn't be analysed, so the app can say something useful.
enum PhotoAnalysisFailure { noFood, noConnection, sessionExpired, server }

class PhotoAnalysisException implements Exception {
  final PhotoAnalysisFailure kind;
  final String detail;
  PhotoAnalysisException(this.kind, [this.detail = '']);

  /// Short message for the user.
  String get message {
    switch (kind) {
      case PhotoAnalysisFailure.noFood:
        return "Couldn't find food in this photo";
      case PhotoAnalysisFailure.noConnection:
        return 'No connection. Check your internet and try again';
      case PhotoAnalysisFailure.sessionExpired:
        return 'Please sign in again to analyze photos';
      case PhotoAnalysisFailure.server:
        return 'Analysis failed. Try again in a moment';
    }
  }

  @override
  String toString() => 'PhotoAnalysisException($kind): $detail';
}

/// Sends the photo to the process-withgemini edge function and returns the raw
/// JSON text from the model. Throws [PhotoAnalysisException].
Future<String> _requestAnalysis(String imagePath) async {
  final session = Supabase.instance.client.auth.currentSession;
  if (session == null) {
    throw PhotoAnalysisException(PhotoAnalysisFailure.sessionExpired);
  }

  // Compress the image (reduce quality and size)
  final targetPath = imagePath.replaceFirst('.jpg', '_compressed.jpg');
  final compressedFile = await FlutterImageCompress.compressAndGetFile(
    imagePath,
    targetPath,
    quality: 50,
    minWidth: 1024,
    minHeight: 1024,
  );
  final imageBytes = compressedFile != null
      ? await compressedFile.readAsBytes()
      : await File(imagePath).readAsBytes();

  final uri = Uri.parse('https://mdivtblabmnftdqlgysv.supabase.co/functions/v1/process-withgemini');
  final request = http.MultipartRequest('POST', uri);
  request.headers['Authorization'] = 'Bearer ${session.accessToken}';
  request.files.add(http.MultipartFile.fromBytes(
    'image',
    imageBytes,
    filename: 'image.jpg',
    contentType: MediaType('image', 'jpeg'),
  ));

  http.Response response;
  try {
    // Without a limit a request can wait as long as the OS keeps the
    // connection open.
    final streamedResponse =
        await request.send().timeout(const Duration(seconds: 45));
    response = await http.Response.fromStream(streamedResponse)
        .timeout(const Duration(seconds: 45));
  } on SocketException catch (e) {
    throw PhotoAnalysisException(PhotoAnalysisFailure.noConnection, e.message);
  } on TimeoutException {
    throw PhotoAnalysisException(PhotoAnalysisFailure.noConnection, 'timed out');
  } on http.ClientException catch (e) {
    throw PhotoAnalysisException(PhotoAnalysisFailure.noConnection, e.message);
  } finally {
    try {
      if (compressedFile != null) await File(targetPath).delete();
    } catch (_) {}
  }

  if (response.statusCode == 401 || response.statusCode == 403) {
    throw PhotoAnalysisException(PhotoAnalysisFailure.sessionExpired);
  }
  if (response.statusCode != 200) {
    throw PhotoAnalysisException(PhotoAnalysisFailure.server,
        'HTTP ${response.statusCode}: ${response.body}');
  }
  final result = json.decode(response.body)['result'];
  if (result is! String || result.trim().isEmpty) {
    throw PhotoAnalysisException(PhotoAnalysisFailure.server, 'empty result');
  }
  return result;
}

/// Analyses a meal photo and returns the foods found in it.
/// Throws [PhotoAnalysisException].
Future<List<AIFoodItem>> analyzeMealPhoto(String imagePath) async {
  final text = await _requestAnalysis(imagePath);
  final cleaned = text.trim().replaceAll('```json', '').replaceAll('```', '');
  dynamic decoded;
  try {
    decoded = json.decode(cleaned);
  } catch (_) {
    // The model answers in prose when it sees no food.
    throw PhotoAnalysisException(PhotoAnalysisFailure.noFood, cleaned);
  }
  final List<dynamic> mealData;
  if (decoded is Map<String, dynamic> && decoded['meal'] is List) {
    mealData = decoded['meal'] as List;
  } else if (decoded is List) {
    mealData = decoded;
  } else if (decoded is Map<String, dynamic>) {
    mealData = [decoded];
  } else {
    throw PhotoAnalysisException(PhotoAnalysisFailure.noFood, cleaned);
  }
  final foods = <AIFoodItem>[];
  for (final item in mealData) {
    try {
      foods.add(AIFoodItem.fromJson(Map<String, dynamic>.from(item as Map)));
    } catch (_) {
      // Skip malformed items; others may still be usable.
    }
  }
  if (foods.isEmpty) {
    throw PhotoAnalysisException(PhotoAnalysisFailure.noFood, cleaned);
  }
  return foods;
}

/// Older entry point: returns the model's JSON text, or an
/// "Error processing image: ..." string on failure.
Future<String> processImageWithGemini(String imagePath) async {
  try {
    return await _requestAnalysis(imagePath);
  } catch (error) {
    print('Error processing image with Supabase edge function: $error');
    return 'Error processing image: $error';
  }
}
