import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:macrotracker/theme/app_theme.dart';
import 'package:macrotracker/theme/typography.dart';
import 'package:macrotracker/widgets/onboarding/onboarding_selection_card.dart';
import 'package:macrotracker/services/posthog_service.dart';

class AcquisitionSourcePage extends StatefulWidget {
  final String? currentSource;
  final ValueChanged<String?> onSourceSelected;

  const AcquisitionSourcePage({
    super.key,
    this.currentSource,
    required this.onSourceSelected,
  });

  @override
  State<AcquisitionSourcePage> createState() => _AcquisitionSourcePageState();
}

class _AcquisitionSourcePageState extends State<AcquisitionSourcePage> {
  String? _selectedSource;

  @override
  void initState() {
    super.initState();
    _selectedSource = widget.currentSource;
  }

  void _handleSourceSelection(String source) {
    HapticFeedback.selectionClick();
    setState(() {
      _selectedSource = source;
    });
    
    // Send to PostHog immediately when selected
    PostHogService.trackEvent('acquisition_source_selected', properties: {
      'source': source,
      'timestamp': DateTime.now().toIso8601String(),
    });
    
    widget.onSourceSelected(source);
  }

  void _handleSkip() {
    HapticFeedback.selectionClick();
    setState(() {
      _selectedSource = 'skipped';
    });
    
    // Track skip event
    PostHogService.trackEvent('acquisition_source_skipped', properties: {
      'timestamp': DateTime.now().toIso8601String(),
    });
    
    widget.onSourceSelected('skipped');
  }

  @override
  Widget build(BuildContext context) {
    final customColors = Theme.of(context).extension<CustomColors>();
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Spacer(flex: 1),
          
          // Title and subtitle
          Text(
            'How did you hear about us?',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: customColors?.textPrimary ?? theme.colorScheme.onBackground,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Help us understand where our users come from',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: customColors?.textSecondary ?? theme.colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 32),

          // Source options
          Expanded(
            flex: 6,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _buildSourceCard(
                    context: context,
                    source: 'tiktok',
                    title: 'TikTok',
                    icon: Icons.video_library,
                    description: 'Saw us on TikTok',
                  ),
                  const SizedBox(height: 12),
                  _buildSourceCard(
                    context: context,
                    source: 'youtube',
                    title: 'YouTube',
                    icon: Icons.play_circle,
                    description: 'Found us on YouTube',
                  ),
                  const SizedBox(height: 12),
                  _buildSourceCard(
                    context: context,
                    source: 'instagram',
                    title: 'Instagram',
                    icon: Icons.camera_alt,
                    description: 'Discovered on Instagram',
                  ),
                  const SizedBox(height: 12),
                  _buildSourceCard(
                    context: context,
                    source: 'app_store',
                    title: 'App Store',
                    icon: Icons.store,
                    description: 'Found in App Store search',
                  ),
                  const SizedBox(height: 12),
                  _buildSourceCard(
                    context: context,
                    source: 'google_search',
                    title: 'Google Search',
                    icon: Icons.search,
                    description: 'Found through Google',
                  ),
                  const SizedBox(height: 12),
                  _buildSourceCard(
                    context: context,
                    source: 'website',
                    title: 'Website',
                    icon: Icons.language,
                    description: 'Visited our website',
                  ),
                  const SizedBox(height: 12),
                  _buildSourceCard(
                    context: context,
                    source: 'friend_referral',
                    title: 'Friend Referral',
                    icon: Icons.people,
                    description: 'Recommended by a friend',
                  ),
                  const SizedBox(height: 12),
                  _buildSourceCard(
                    context: context,
                    source: 'reddit',
                    title: 'Reddit',
                    icon: Icons.forum,
                    description: 'Found on Reddit',
                  ),
                  const SizedBox(height: 12),
                  _buildSourceCard(
                    context: context,
                    source: 'other',
                    title: 'Other',
                    icon: Icons.more_horiz,
                    description: 'From somewhere else',
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),
          
          // Skip button
          Center(
            child: TextButton(
              onPressed: _handleSkip,
              child: Text(
                'Skip',
                style: AppTypography.onboardingButton.copyWith(
                  color: customColors?.textSecondary ?? theme.colorScheme.secondary,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          
          const Spacer(flex: 1),
        ],
      ),
    );
  }

  Widget _buildSourceCard({
    required BuildContext context,
    required String source,
    required String title,
    required IconData icon,
    required String description,
  }) {
    return OnboardingSelectionCard(
      isSelected: _selectedSource == source,
      onTap: () => _handleSourceSelection(source),
      icon: icon,
      label: title,
      description: description,
    );
  }
} 