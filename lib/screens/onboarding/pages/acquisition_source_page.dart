import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
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
    super.dispose();
  }

  void _handleSourceSelection(String source) {
    HapticFeedback.selectionClick();
    setState(() {
      _selectedSource = source;
    });
    
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
    
    PostHogService.trackEvent('acquisition_source_skipped', properties: {
      'timestamp': DateTime.now().toIso8601String(),
    });
    
    widget.onSourceSelected('skipped');
    
    // Call the onSkip callback if provided to auto-advance
    widget.onSkip?.call();
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

                  // Source options in a grid
                  Expanded(
                    child: _buildSourceGrid(context),
                  ),

                  const SizedBox(height: 16),
                  
                  // Skip button
                  _buildSkipButton(customColors, theme),
                  
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
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withOpacity(0.1.clamp(0.0, 1.0)),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            'Optional',
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.primary,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'How did you discover us?',
          style: GoogleFonts.poppins(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: customColors?.textPrimary ?? theme.colorScheme.onBackground,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Help us understand our community better and improve our reach',
          style: GoogleFonts.poppins(
            fontSize: 16,
            color: customColors?.textSecondary ?? theme.colorScheme.onSurface.withOpacity(0.7.clamp(0.0, 1.0)),
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Widget _buildSourceGrid(BuildContext context) {
    final sources = [
      _SourceData(
        id: 'tiktok',
        title: 'TikTok',
        icon: FontAwesomeIcons.tiktok,
        gradient: [const Color(0xFF25F4EE), const Color(0xFFFE2C55)],
        category: 'Social Media',
      ),
      _SourceData(
        id: 'instagram',
        title: 'Instagram',
        icon: FontAwesomeIcons.instagram,
        gradient: [const Color(0xFF833AB4), const Color(0xFFFD1D1D), const Color(0xFFFCB045)],
        category: 'Social Media',
      ),
      _SourceData(
        id: 'youtube',
        title: 'YouTube',
        icon: FontAwesomeIcons.youtube,
        gradient: [const Color(0xFFFF0000), const Color(0xFFCC0000)],
        category: 'Social Media',
      ),
      _SourceData(
        id: 'reddit',
        title: 'Reddit',
        icon: FontAwesomeIcons.reddit,
        gradient: [const Color(0xFFFF4500), const Color(0xFFFF6B35)],
        category: 'Communities',
      ),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 8),
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 1.1,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: sources.length,
        itemBuilder: (context, index) {
          final source = sources[index];
          return TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: Duration(milliseconds: 400 + (index * 100)),
            curve: Curves.easeOutBack,
            builder: (context, value, child) {
              return Transform.scale(
                scale: 0.8 + (0.2 * value),
                child: Opacity(
                  opacity: value.clamp(0.0, 1.0),
                  child: _buildSourceCard(source),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildSourceCard(_SourceData source) {
    final isSelected = _selectedSource == source.id;
    final theme = Theme.of(context);
    
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: isSelected ? 1 : 0),
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      builder: (context, selectedValue, child) {
        return GestureDetector(
          onTap: () => _handleSourceSelection(source.id),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                colors: source.gradient.map((c) => c.withOpacity((0.1 + (selectedValue * 0.05)).clamp(0.0, 1.0))).toList(),
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(
                color: isSelected 
                  ? source.gradient.first.withOpacity(0.5.clamp(0.0, 1.0))
                  : Colors.grey.withOpacity(0.2.clamp(0.0, 1.0)),
                width: isSelected ? 2 : 1,
              ),
              boxShadow: [
                if (isSelected)
                  BoxShadow(
                    color: source.gradient.first.withOpacity(0.3.clamp(0.0, 1.0)),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: source.gradient,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: source.gradient.first.withOpacity(0.3.clamp(0.0, 1.0)),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: FaIcon(
                      source.icon,
                      size: 28,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    source.title,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 2),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: source.gradient.first.withOpacity(0.2.clamp(0.0, 1.0)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      source.category,
                      style: GoogleFonts.poppins(
                        fontSize: 9,
                        fontWeight: FontWeight.w500,
                        color: source.gradient.first.withOpacity(0.8.clamp(0.0, 1.0)),
                      ),
                    ),
                  ),
                  if (isSelected) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: source.gradient.first,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSkipButton(CustomColors? customColors, ThemeData theme) {
    return Center(
      child: TextButton.icon(
        onPressed: _handleSkip,
        icon: Icon(
          Icons.skip_next_rounded,
          size: 20,
          color: customColors?.textSecondary ?? theme.colorScheme.onSurface.withOpacity(0.6),
        ),
        label: Text(
          'Skip for now',
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: customColors?.textSecondary ?? theme.colorScheme.onSurface.withOpacity(0.6),
          ),
        ),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25),
          ),
        ),
      ),
    );
  }
}

class _SourceData {
  final String id;
  final String title;
  final IconData icon;
  final List<Color> gradient;
  final String category;

  _SourceData({
    required this.id,
    required this.title,
    required this.icon,
    required this.gradient,
    required this.category,
  });
}