import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:google_fonts/google_fonts.dart';

import 'package:google_generative_ai/google_generative_ai.dart';

class Askai extends StatefulWidget {
  const Askai({super.key});

  @override
  State<Askai> createState() => _AskaiState();
}

class _AskaiState extends State<Askai> with AutomaticKeepAliveClientMixin {
  final TextEditingController _mealController = TextEditingController();

  String _nutritionResult = '';

  bool _isLoading = false;

  bool _canSend = false;

  @override
  void initState() {
    super.initState();

    _mealController.addListener(() {
      setState(() {
        _canSend = _mealController.text.isNotEmpty;
      });
    });
  }

  @override
  bool get wantKeepAlive => true;

  Future<void> _analyzeNutrition() async {
    if (_mealController.text.isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    try {
      const apiKey = 'AIzaSyDe8qpEeJHOYJtJviyr4GVH2_ssCUy9gZc';

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
Meal to analyze: ${_mealController.text}
''';

      final content = [Content.text(prompt)];

      final response = await model.generateContent(content);

      setState(() {
        _nutritionResult = response.text ?? 'Unable to analyze meal';

        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _nutritionResult = 'Error analyzing meal: ${e.toString()}';

        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F4F0),
      appBar: AppBar(
        backgroundColor: CupertinoColors.systemGrey.withOpacity(0.0),
        leading: CupertinoNavigationBarBackButton(
          color: CupertinoColors.black,
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Ask AI',
          style: GoogleFonts.roboto(
            color: CupertinoColors.black,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          FocusScope.of(context).unfocus();
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Container(
                constraints: const BoxConstraints(
                  minHeight: 60, // Minimum height when empty

                  maxHeight: 300, // Maximum expansion height
                ),
                decoration: BoxDecoration(
                  color: CupertinoColors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withValues(alpha: 95.0),
                      spreadRadius: 1,
                      blurRadius: 1,
                      offset: Offset(0, 3),
                    ),
                  
                  ],
                ),
                child: CupertinoTextField(
                  controller: _mealController,
                  maxLines: null,
                  textAlignVertical: TextAlignVertical.top,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  placeholder: 'Describe your meal...',
                  placeholderStyle:
                      GoogleFonts.roboto(color: CupertinoColors.systemGrey),
                  // Remove the default inner border since we wrapped the field in a container
                  decoration: const BoxDecoration(),
                  suffix: CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: _canSend ? _analyzeNutrition : null,
                    child: Icon(
                      CupertinoIcons.arrowtriangle_right,
                      color: _canSend
                          ? const Color(0xFFFFC107)
                          : CupertinoColors.inactiveGray,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              if (_isLoading)
                const CupertinoActivityIndicator()
              else if (_nutritionResult.isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: CupertinoColors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: const [
                      BoxShadow(
                        color: CupertinoColors.systemGrey,
                        spreadRadius: 1,
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    _nutritionResult,
                    style: GoogleFonts.roboto(
                      fontSize: 16,
                      height: 1.5,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _mealController.dispose();

    super.dispose();
  }
}
