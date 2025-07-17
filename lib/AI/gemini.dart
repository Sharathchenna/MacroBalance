// ignore_for_file: avoid_print

import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<String> processImageWithGemini(String imagePath) async {
  try {
    print('[Gemini Debug] Starting Gemini processing with Supabase edge function at ${DateTime.now().toString()}');
    final startTime = DateTime.now();
    
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
    print(
        '[Gemini Debug] Compressed to ${imageBytes.length} bytes (${(imageBytes.length / originalBytes.length * 100).toStringAsFixed(1)}% of original)');
    print(
        '[Gemini Debug] Compression completed in ${DateTime.now().difference(compressedImageStart).inMilliseconds}ms');
    print(
        '[Gemini Debug] Total image processing time: ${DateTime.now().difference(imageReadStart).inMilliseconds}ms');

    print('[Gemini Debug] Preparing request to Supabase edge function...');
    
    // Get Supabase client and current session
    final supabase = Supabase.instance.client;
    final session = supabase.auth.currentSession;
    
    if (session == null) {
      throw Exception('User not authenticated');
    }
    
    // Prepare multipart request
    final uri = Uri.parse('https://mdivtblabmnftdqlgysv.supabase.co/functions/v1/process-withgemini');
    var request = http.MultipartRequest('POST', uri);
    
    // Add authorization header
    request.headers['Authorization'] = 'Bearer ${session.accessToken}';
    
    // Add compressed image as multipart file with explicit MIME type
    final multipartFile = http.MultipartFile.fromBytes(
      'image',
      imageBytes,
      filename: 'image.jpg',
      contentType: MediaType('image', 'jpeg'),
    );
    request.files.add(multipartFile);

    print('[Gemini Debug] Sending request to Supabase edge function...');
    final apiCallStart = DateTime.now();
    
    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    
    print('[Gemini Debug] Supabase edge function response received in ${DateTime.now().difference(apiCallStart).inMilliseconds}ms');
    
    // Clean up temp file
    try {
      await File(targetPath).delete();
      print('[Gemini Debug] Temporary compressed image deleted');
    } catch (e) {
      print('[Gemini Debug] Warning: Could not delete temp file: $e');
    }
    
    if (response.statusCode == 200) {
      final responseData = json.decode(response.body);
      final responseText = responseData['result'] ?? 'No response from Gemini';
      print('[Gemini Debug] Total Supabase processing time: ${DateTime.now().difference(startTime).inMilliseconds}ms');
      return responseText;
    } else {
      final errorData = json.decode(response.body);
      final errorMessage = errorData['error'] ?? 'Unknown error occurred';
      throw Exception('Supabase edge function error: $errorMessage');
    }
    
  } catch (error) {
    print('Error processing image with Supabase edge function: $error');
    return 'Error processing image: $error';
  }
}
