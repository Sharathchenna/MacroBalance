import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:macrotracker/theme/app_theme.dart';
import 'package:macrotracker/services/posthog_service.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class AcquisitionSourcePage extends StatefulWidget {
  final String? currentSource;
  final ValueChanged<String?> onSourceSelected;
  final VoidCallback? onSkip;

  const AcquisitionSourcePage({
    super.key,
    this.currentSource,
    required this.onSourceSelected,
    this.onSkip,
  });

  @override
  State<AcquisitionSourcePage> createState() => _AcquisitionSourcePageState();
}

class _AcquisitionSourcePageState extends State<AcquisitionSourcePage>
    with TickerProviderStateMixin {
  String? _selectedSource;
  final TextEditingController _otherTextController = TextEditingController();
  final FocusNode _otherFocusNode = FocusNode();
  Timer? _debounceTimer;
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _selectedSource = widget.currentSource;
    
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    ));
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));
    
    _fadeController.forward();
    _slideController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _otherTextController.dispose();
    _otherFocusNode.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _handleSourceSelection(String source) {
    HapticFeedback.selectionClick();
    setState(() {
      _selectedSource = source;
    });
    
    // If "other" is selected, focus the text field after a short delay
    if (source == 'other') {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          _otherFocusNode.requestFocus();
        }
      });
    }
    
    // Track the selection with the actual text if it's "other"
    final String trackingSource = source == 'other' && _otherTextController.text.isNotEmpty
        ? 'other: ${_otherTextController.text}'
        : source;
    
    PostHogService.trackEvent('acquisition_source_selected', properties: {
      'source': trackingSource,
      'timestamp': DateTime.now().toIso8601String(),
    });
    
    // Pass the actual text for "other" if available
    if (source == 'other' && _otherTextController.text.isNotEmpty) {
      widget.onSourceSelected('other: ${_otherTextController.text}');
    } else {
      widget.onSourceSelected(source);
    }
  }
  
  void _handleOtherTextChanged(String value) {
    // Cancel the previous timer
    _debounceTimer?.cancel();
    
    // Debounce both callback and PostHog tracking - only fire after user stops typing for 1000ms
    _debounceTimer = Timer(const Duration(milliseconds: 1000), () {
      final String trackingSource = value.isNotEmpty ? 'other: $value' : 'other';
      
      // Update the selected source after debounce
      widget.onSourceSelected(trackingSource);
      
      PostHogService.trackEvent('acquisition_source_other_text_changed', properties: {
        'source': trackingSource,
        'text_length': value.length,
        'timestamp': DateTime.now().toIso8601String(),
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final customColors = Theme.of(context).extension<CustomColors>();
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 24),
                  
                  // Header section
                  _buildHeader(customColors, theme),
                  
                  const SizedBox(height: 16),

                  // Source options in a list
                  Expanded(
                    child: _buildSourceList(context),
                  ),

                  const SizedBox(height: 16),
                  
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(CustomColors? customColors, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'How did you hear about us?',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            fontSize: 26,
            color: customColors?.textPrimary ?? theme.colorScheme.onBackground,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Help us understand our community better and improve our reach',
          style: theme.textTheme.bodyMedium?.copyWith(
            fontSize: 16,
            color: customColors?.textSecondary ?? theme.colorScheme.onSurface.withOpacity(0.7),
          ),
        ),
      ],
    );
  }

  Widget _buildSourceList(BuildContext context) {
    final sources = [
      _SourceData(
        id: 'tiktok',
        title: 'TikTok',
        icon: FontAwesomeIcons.tiktok,
        iconColor: Colors.black,
      ),
      _SourceData(
        id: 'instagram',
        title: 'Instagram',
        icon: FontAwesomeIcons.instagram,
        iconColor: const Color(0xFFE1306C),
      ),
      _SourceData(
        id: 'reddit',
        title: 'Reddit',
        icon: FontAwesomeIcons.reddit,
        iconColor: const Color(0xFFFF4500),
      ),
      _SourceData(
        id: 'other',
        title: 'Other',
        icon: Icons.edit_rounded,
        iconColor: const Color(0xFF9C27B0),
      ),
    ];

    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      padding: const EdgeInsets.only(top: 24),
      itemCount: sources.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final source = sources[index];
        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: Duration(milliseconds: 300 + (index * 80)),
          curve: Curves.easeOutBack,
          builder: (context, value, child) {
            return Transform.translate(
              offset: Offset(0, 20 * (1 - value)),
              child: Opacity(
                opacity: value.clamp(0.0, 1.0),
                child: _buildSourceCard(source),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSourceCard(_SourceData source) {
    final isSelected = _selectedSource == source.id;
    final theme = Theme.of(context);
    final customColors = Theme.of(context).extension<CustomColors>();
    final Color primaryColor = customColors?.textPrimary ?? theme.colorScheme.primary;
    final Color cardBgColor = customColors?.cardBackground ?? theme.cardColor;
    final bool isOther = source.id == 'other';
    
    return GestureDetector(
      onTap: isOther && isSelected ? null : () => _handleSourceSelection(source.id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: cardBgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? primaryColor : Colors.grey.withOpacity(0.15),
            width: isSelected ? 2.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? source.iconColor.withOpacity(0.12)
                  : Colors.black.withOpacity(0.03),
              blurRadius: isSelected ? 10 : 4,
              offset: Offset(0, isSelected ? 3 : 1),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 18.0, horizontal: 20.0),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                height: 56,
                width: 56,
                decoration: BoxDecoration(
                  color: isSelected
                      ? source.iconColor.withOpacity(0.12)
                      : source.iconColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: AnimatedScale(
                    scale: isSelected ? 1.1 : 1.0,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutBack,
                    child: source.icon.runtimeType == IconData
                        ? Icon(
                            source.icon as IconData,
                            size: 28,
                            color: source.iconColor,
                          )
                        : FaIcon(
                            source.icon as IconData,
                            size: 24,
                            color: source.iconColor,
                          ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: isOther && isSelected
                    ? TextField(
                        controller: _otherTextController,
                        focusNode: _otherFocusNode,
                        autofocus: false,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: customColors?.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Type here...',
                          hintStyle: TextStyle(
                            color: customColors?.textSecondary ?? Colors.grey,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                        onChanged: _handleOtherTextChanged,
                      )
                    : AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 300),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                          color: isSelected
                              ? primaryColor
                              : customColors?.textPrimary ?? theme.colorScheme.onSurface,
                        ),
                        child: Text(source.title),
                      ),
              ),
              if (isSelected && !isOther)
                AnimatedScale(
                  scale: 1.0,
                  duration: const Duration(milliseconds: 200),
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: primaryColor,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check,
                      size: 16,
                      color: Colors.white,
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

class _SourceData {
  final String id;
  final String title;
  final dynamic icon;
  final Color iconColor;

  _SourceData({
    required this.id,
    required this.title,
    required this.icon,
    required this.iconColor,
  });
}