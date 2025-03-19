import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

Future<String> processImageWithGemini(String imagePath) async {
  try {
    // Replace with your Supabase project URL and function name
    final supabaseUrl = 'https://mdivtblabmnftdqlgysv.supabase.co';
    final functionName =
        'process-withgemini'; // Change to your actual function name

    // Prepare the image file
    final imageFile = File(imagePath);

    if (!await imageFile.exists()) {
      return 'Error: Image file does not exist';
    }

    final bytes = await imageFile.readAsBytes();

    // Determine content type based on file extension
    String contentType = 'image/jpeg'; // Default
    if (imagePath.toLowerCase().endsWith('.png')) {
      contentType = 'image/png';
    }

    // Create a multipart request
    final request = http.MultipartRequest(
        'POST', Uri.parse('$supabaseUrl/functions/v1/$functionName'));

    // Add the image as a file part
    request.files.add(http.MultipartFile.fromBytes(
      'image',
      bytes,
      filename: imagePath.split('/').last,
      contentType: MediaType.parse(contentType),
    ));

    // Optional: Add authentication if your function requires it
    final supabaseAuthToken =
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1kaXZ0YmxhYm1uZnRkcWxneXN2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3Mzg4NjUyMDksImV4cCI6MjA1NDQ0MTIwOX0.zzdtVddtl8Wb8K2k-HyS3f95j3g9FT0zy-pqjmBElrU';
    request.headers['Authorization'] = 'Bearer $supabaseAuthToken';

    // Send the request
    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    // Check if the request was successful
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final jsonResponse = jsonDecode(response.body);
      return jsonResponse['result'] ?? 'No result in response';
    } else {
      throw Exception('Error: ${response.statusCode}, ${response.body}');
    }
  } catch (e) {
    print('Error processing image with Supabase Edge Function: $e');
    return 'Error processing image: $e';
  }
}
