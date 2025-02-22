import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:macrotracker/theme/app_theme.dart';

class ResultsPage extends StatelessWidget {
  final String nutritionInfo;

  const ResultsPage({
    super.key,
    required this.nutritionInfo,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: CupertinoNavigationBarBackButton(
          color: Theme.of(context).primaryColor,
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Nutrition Results',
          style: TextStyle(
            color: Theme.of(context).primaryColor,
            fontWeight: FontWeight.w500,
          ),
        ),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Column(
          // crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              elevation: 4,
              color:
                  Theme.of(context).extension<CustomColors>()?.cardBackground,
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  // crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Text(
                    //   'Analysis Results',
                    //   style: TextStyle(
                    //     color: Theme.of(context).primaryColor,
                    //     fontWeight: FontWeight.w500,
                    //     fontSize: 18,
                    //   ),
                    // ),
                    // SizedBox(height: 16),
                    Text(
                      nutritionInfo,
                      style: TextStyle(
                          color: Theme.of(context).primaryColor,
                          fontWeight: FontWeight.w500,
                          fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
