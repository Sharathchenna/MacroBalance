import 'package:google_generative_ai/google_generative_ai.dart';

const apiKey = "AIzaSyDe8qpEeJHOYJtJviyr4GVH2_ssCUy9gZc";

void main() async {
  final model = GenerativeModel(
      model: 'gemini-1.5-flash-latest',
      apiKey: apiKey,
  );

  final prompt = 'Write a story about a magic backpack.';
  final content = [Content.text(prompt)];
  final response = await model.generateContent(content);

  print(response.text);
}