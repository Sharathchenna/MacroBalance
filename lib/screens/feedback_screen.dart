import 'package:flutter/cupertino.dart'; // Import Cupertino widgets
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:image_picker/image_picker.dart'; // Import image_picker
import 'dart:io'; // For Platform check and File operations

import '../models/feedback.dart'
    as app_feedback; // Use prefix to avoid name clash
import '../services/supabase_service.dart'; // Assuming SupabaseService handles insertions
import '../theme/app_theme.dart'; // For styling and AppColors extension
import '../theme/typography.dart'; // For AppTypography

class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  app_feedback.FeedbackType _selectedType =
      app_feedback.FeedbackType.feedback; // Default to feedback
  int _rating = 0;
  final _commentController = TextEditingController();
  XFile? _screenshotFile; // To hold the selected screenshot
  final ImagePicker _picker = ImagePicker(); // ImagePicker instance

  bool _isLoading = false;
  String _errorMessage = '';
  String _successMessage = '';

  final SupabaseService _supabaseService =
      SupabaseService(); // Instantiate SupabaseService

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  // Method to pick screenshot from gallery
  Future<void> _pickScreenshot() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        setState(() {
          _screenshotFile = image;
          _errorMessage = ''; // Clear error on new selection
        });
      }
    } catch (e) {
      print("Error picking screenshot: $e");
      setState(() {
        _errorMessage = 'Failed to pick screenshot.';
      });
    }
  }

  Future<String> _getDeviceInfo() async {
    DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    String appVersion = packageInfo.version;
    String buildNumber = packageInfo.buildNumber;
    String osVersion = '';
    String deviceModel = '';

    try {
      if (Platform.isAndroid) {
        AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
        osVersion =
            'Android ${androidInfo.version.release} (SDK ${androidInfo.version.sdkInt})';
        deviceModel = '${androidInfo.manufacturer} ${androidInfo.model}';
      } else if (Platform.isIOS) {
        IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
        osVersion = 'iOS ${iosInfo.systemVersion}';
        deviceModel =
            iosInfo.utsname.machine ?? 'Unknown iOS Device'; // Use machine name
      } else {
        osVersion = Platform.operatingSystem;
        // Device model might be harder to get reliably on desktop/web
      }
    } catch (e) {
      print("Error getting device info: $e");
      osVersion = 'Unknown OS';
      deviceModel = 'Unknown Device';
    }

    return 'App Version: $appVersion ($buildNumber), OS: $osVersion, Device: $deviceModel';
  }

  Future<void> _submitFeedback() async {
    // Validation based on type
    if (_selectedType == app_feedback.FeedbackType.feedback && _rating == 0) {
      setState(() {
        _errorMessage = 'Please select a rating for feedback.';
        _successMessage = '';
      });
      return;
    }
    if (_selectedType == app_feedback.FeedbackType.bug &&
        _commentController.text.trim().isEmpty) {
      setState(() {
        _errorMessage = 'Please provide a description for the bug report.';
        _successMessage = '';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
      _successMessage = '';
    });

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        throw Exception('User not logged in');
      }

      final deviceInfo = await _getDeviceInfo();
      String? screenshotUrl;

      // Upload screenshot if it's a bug report and a file is selected
      if (_selectedType == app_feedback.FeedbackType.bug &&
          _screenshotFile != null) {
        screenshotUrl =
            await _supabaseService.uploadScreenshot(_screenshotFile!);
        if (screenshotUrl == null) {
          setState(() {
            _errorMessage = 'Failed to upload screenshot. Please try again.';
            _isLoading = false;
          });
          return; // Stop submission if upload fails
        }
      }

      final feedbackData = app_feedback.Feedback(
        userId: user.id,
        type: _selectedType, // Pass the selected type
        rating: _selectedType == app_feedback.FeedbackType.feedback
            ? _rating
            : null, // Rating only for feedback
        comment: _commentController.text.trim().isEmpty
            ? null
            : _commentController.text.trim(), // Comment or description
        screenshotUrl: screenshotUrl, // Pass the uploaded URL
        createdAt: DateTime.now(),
        deviceInfo: deviceInfo,
      );

      // Use the existing addFeedback method in SupabaseService
      await _supabaseService.addFeedback(feedbackData);

      setState(() {
        _successMessage = _selectedType == app_feedback.FeedbackType.feedback
            ? 'Feedback submitted successfully! Thank you.'
            : 'Bug report submitted successfully! Thank you.';
        _rating = 0; // Reset rating
        _commentController.clear(); // Clear comment/description
        _screenshotFile = null; // Reset screenshot
      });

      // Optional: Navigate back after a delay
      // Future.delayed(Duration(seconds: 2), () {
      //   if (mounted) Navigator.pop(context);
      // });
    } catch (e) {
      print('Error submitting feedback: $e');
      setState(() {
        _errorMessage = 'Failed to submit feedback. Please try again.';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final customColors = theme.extension<CustomColors>();
    final appColors =
        theme.extension<CustomColors>()!; // Corrected to CustomColors

    // Add this InputDecoration builder
    InputDecoration getInputDecoration(String hintText) {
      final brightness = Theme.of(context).brightness;
      return InputDecoration(
        hintText: hintText,
        hintStyle: AppTypography.body1.copyWith(color: appColors.textSecondary),
        filled: true,
        fillColor: appColors.cardBackground,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: BorderSide(color: theme.primaryColor, width: 1.5),
        ),
        isDense: true,
        contentPadding: const EdgeInsets.all(16),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: BorderSide.none,
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Submit Feedback / Report Bug',
            style: AppTypography.h3
                .copyWith(color: appColors.textPrimary)), // Updated title
        backgroundColor: theme.scaffoldBackgroundColor,
        iconTheme: IconThemeData(color: appColors.textPrimary),
        elevation: 0,
      ),
      backgroundColor: theme.scaffoldBackgroundColor,
      // Wrap body with GestureDetector to dismiss keyboard
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(), // Dismiss keyboard on tap outside
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch, // Stretch children
          children: [
            // Type Selector
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Feedback',
                  style: AppTypography.h3.copyWith(
                    color: !(_selectedType == app_feedback.FeedbackType.bug)
                        ? theme.primaryColor
                        : appColors.textSecondary,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: CupertinoSwitch(
                    value: _selectedType == app_feedback.FeedbackType.bug,
                    onChanged: (bool value) {
                      setState(() {
                        _selectedType = value
                            ? app_feedback.FeedbackType.bug
                            : app_feedback.FeedbackType.feedback;
                        _errorMessage = '';
                        _successMessage = '';
                        if (value) _rating = 0;
                        if (!value) _screenshotFile = null;
                      });
                    },
                    activeColor: theme.primaryColor,
                  ),
                ),
                Text(
                  'Report Bug',
                  style: AppTypography.h3.copyWith(
                    color: _selectedType == app_feedback.FeedbackType.bug
                        ? theme.primaryColor
                        : appColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 30),

            // Conditional UI based on type
            if (_selectedType == app_feedback.FeedbackType.feedback) ...[
              // --- Feedback UI ---
              Text(
                'How would you rate your experience?',
                style: AppTypography.h3.copyWith(color: appColors.textPrimary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 15),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  return IconButton(
                    icon: Icon(
                      index < _rating ? Icons.star : Icons.star_border,
                      color: index < _rating
                          ? Colors.amber
                          : appColors.textSecondary,
                      size: 40,
                    ),
                    onPressed: () {
                      setState(() {
                        _rating = index + 1;
                        _errorMessage = ''; // Clear error when rating changes
                      });
                    },
                  );
                }),
              ),
              const SizedBox(height: 30),
              Text(
                'Any comments or suggestions? (Optional)',
                style: AppTypography.h3.copyWith(color: appColors.textPrimary),
              ),
              const SizedBox(height: 15),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12.0),
                  boxShadow: theme.brightness == Brightness.light
                      ? [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : null,
                ),
                child: TextField(
                  controller: _commentController,
                  maxLines: 5,
                  style: AppTypography.body1
                      .copyWith(color: appColors.textPrimary),
                  decoration:
                      getInputDecoration('Tell us how we can improve...'),
                ),
              ),
            ] else ...[
              // --- Bug Report UI ---
              Text(
                'Describe the issue you encountered:',
                style: AppTypography.h3.copyWith(color: appColors.textPrimary),
              ),
              const SizedBox(height: 15),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12.0),
                  boxShadow: theme.brightness == Brightness.light
                      ? [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : null,
                ),
                child: TextField(
                  controller: _commentController,
                  maxLines: 5,
                  style: AppTypography.body1
                      .copyWith(color: appColors.textPrimary),
                  decoration: getInputDecoration(
                      'Please provide details about the bug...'),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Attach a screenshot (Optional)',
                style: AppTypography.h3.copyWith(color: appColors.textPrimary),
              ),
              const SizedBox(height: 10),
              if (_screenshotFile != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10.0),
                  child: Stack(
                    alignment: Alignment.topRight,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12.0),
                        child: Image.file(
                          File(_screenshotFile!.path),
                          height: 150,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                      IconButton(
                        icon: const CircleAvatar(
                          backgroundColor: Colors.black54,
                          child:
                              Icon(Icons.close, color: Colors.white, size: 18),
                        ),
                        onPressed: () => setState(() => _screenshotFile = null),
                      ),
                    ],
                  ),
                ),
              OutlinedButton.icon(
                icon: const Icon(Icons.attach_file),
                label: Text(_screenshotFile == null
                    ? 'Select Screenshot'
                    : 'Change Screenshot'),
                onPressed: _pickScreenshot,
                style: OutlinedButton.styleFrom(
                  foregroundColor: theme.primaryColor,
                  side: BorderSide(color: theme.primaryColor),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ],

            // Common UI (Error/Success Messages, Submit Button)
            const SizedBox(height: 30),
            if (_errorMessage.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 15.0),
                child: Text(
                  _errorMessage,
                  style: AppTypography.body2.copyWith(color: Colors.redAccent),
                  textAlign: TextAlign.center,
                ),
              ),
            if (_successMessage.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 15.0),
                child: Text(
                  _successMessage,
                  style: AppTypography.body2.copyWith(color: Colors.green),
                  textAlign: TextAlign.center,
                ),
              ),
            Center(
              child: _isLoading
                  ? CircularProgressIndicator(color: theme.primaryColor)
                  : ElevatedButton(
                      onPressed: _submitFeedback,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: customColors!.textPrimary,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 50, vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30.0),
                        ),
                      ),
                      child: Text(
                        _selectedType == app_feedback.FeedbackType.feedback
                            ? 'Submit Feedback'
                            : 'Submit Bug Report',
                        style: AppTypography.button.copyWith(
                            color: theme.colorScheme.onPrimary
                                .withValues(alpha: 0.8)),
                      ),
                    ),
            ),
          ],
        ),
       ),
      ),
    );
  }
}
