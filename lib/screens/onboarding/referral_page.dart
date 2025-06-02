import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:macrotracker/theme/app_theme.dart';
import 'package:macrotracker/services/superwall_service.dart';

/// Dedicated referral page that appears after onboarding results but before paywall
class ReferralPage extends StatefulWidget {
  final VoidCallback onContinue;
  final VoidCallback? onSkip;

  const ReferralPage({
    super.key,
    required this.onContinue,
    this.onSkip,
  });

  @override
  State<ReferralPage> createState() => _ReferralPageState();
}

class _ReferralPageState extends State<ReferralPage>
    with SingleTickerProviderStateMixin {
  final TextEditingController _codeController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _isValidating = false;
  String? _errorMessage;
  String? _successMessage;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));

    _animationController.forward();
  }

  @override
  void dispose() {
    _codeController.dispose();
    _focusNode.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _validateAndApplyCode() async {
    final code = _codeController.text.trim();

    if (code.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter a referral code';
        _successMessage = null;
      });
      return;
    }

    setState(() {
      _isValidating = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      // Simulate validation with your server
      await Future.delayed(const Duration(seconds: 1));

      final isValid = await SuperwallService().validateReferralCode(code);

      if (isValid) {
        setState(() {
          _successMessage =
              'Referral code applied! You\'ll see special pricing on the next screen.';
          _errorMessage = null;
        });

        // Store the referral code for use in the paywall
        await _storeReferralCode(code);

        // Continue to paywall after a brief delay
        await Future.delayed(const Duration(seconds: 2));
        widget.onContinue();
      } else {
        setState(() {
          _errorMessage = 'Invalid referral code. Please check and try again.';
          _successMessage = null;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error validating code. Please try again.';
        _successMessage = null;
      });
      debugPrint('Error validating referral code: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isValidating = false;
        });
      }
    }
  }

  /// Store referral code for use in paywall
  Future<void> _storeReferralCode(String code) async {
    debugPrint('Storing referral code for paywall: $code');

    // Store in SuperwallService for later use in paywall
    SuperwallService().setReferralCode(code);
  }

  void _skipReferral() {
    HapticFeedback.lightImpact();
    widget.onContinue();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final customColors = theme.extension<CustomColors>();

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              // Progress indicator (if you want to show progress)
              const SizedBox(height: 20),

              Expanded(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Icon
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: (customColors?.accentPrimary ??
                                    theme.primaryColor)
                                .withAlpha((0.1 * 255).round()),
                          ),
                          child: Icon(
                            Icons.card_giftcard,
                            size: 50,
                            color: customColors?.accentPrimary ??
                                theme.primaryColor,
                          ),
                        ),

                        const SizedBox(height: 32),

                        // Title
                        Text(
                          'Have a Referral Code?',
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: customColors?.textPrimary,
                          ),
                          textAlign: TextAlign.center,
                        ),

                        const SizedBox(height: 16),

                        // Description
                        Text(
                          'Enter your referral or promo code to unlock special pricing on your MacroBalance subscription.',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: customColors?.textSecondary,
                            height: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ),

                        const SizedBox(height: 40),

                        // Input field
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _errorMessage != null
                                  ? Colors.red
                                  : _successMessage != null
                                      ? Colors.green
                                      : Colors.grey.shade300,
                              width: 2,
                            ),
                            color: customColors?.cardBackground ??
                                Colors.grey.shade50,
                          ),
                          child: TextField(
                            controller: _codeController,
                            focusNode: _focusNode,
                            textCapitalization: TextCapitalization.characters,
                            enabled: !_isValidating,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.2,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Enter code here',
                              hintStyle: TextStyle(
                                color: customColors?.textSecondary
                                    .withAlpha((0.6 * 255).round()),
                                fontWeight: FontWeight.normal,
                                letterSpacing: 0,
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.all(20),
                              prefixIcon: Icon(
                                Icons.local_offer,
                                color: customColors?.accentPrimary,
                              ),
                            ),
                            onSubmitted: (_) => _validateAndApplyCode(),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Error/Success message
                        if (_errorMessage != null || _successMessage != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: _errorMessage != null
                                  ? Colors.red.shade50
                                  : Colors.green.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: _errorMessage != null
                                    ? Colors.red.shade200
                                    : Colors.green.shade200,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  _errorMessage != null
                                      ? Icons.error_outline
                                      : Icons.check_circle_outline,
                                  color: _errorMessage != null
                                      ? Colors.red.shade700
                                      : Colors.green.shade700,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _errorMessage ?? _successMessage ?? '',
                                    style: TextStyle(
                                      color: _errorMessage != null
                                          ? Colors.red.shade700
                                          : Colors.green.shade700,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        const SizedBox(height: 32),

                        // Apply button
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed:
                                _isValidating ? null : _validateAndApplyCode,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: customColors?.accentPrimary ??
                                  theme.primaryColor,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                            child: _isValidating
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text(
                                    'Apply Code',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Skip button
                        TextButton(
                          onPressed: _isValidating ? null : _skipReferral,
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                          ),
                          child: Text(
                            'Skip - Continue to Subscription',
                            style: TextStyle(
                              color: customColors?.textSecondary,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Bottom benefits section
              FadeTransition(
                opacity: _fadeAnimation,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: (customColors?.accentPrimary ?? theme.primaryColor)
                        .withAlpha((0.05 * 255).round()),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: (customColors?.accentPrimary ?? theme.primaryColor)
                          .withAlpha((0.1 * 255).round()),
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Referral codes can unlock:',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: customColors?.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildBenefitItem(
                            icon: Icons.percent,
                            text: 'Discounts',
                            color: customColors?.accentPrimary ??
                                theme.primaryColor,
                          ),
                          _buildBenefitItem(
                            icon: Icons.access_time,
                            text: 'Extended Trials',
                            color: customColors?.accentPrimary ??
                                theme.primaryColor,
                          ),
                          _buildBenefitItem(
                            icon: Icons.star,
                            text: 'Bonus Features',
                            color: customColors?.accentPrimary ??
                                theme.primaryColor,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBenefitItem({
    required IconData icon,
    required String text,
    required Color color,
  }) {
    return Column(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withAlpha((0.1 * 255).round()),
          ),
          child: Icon(
            icon,
            color: color,
            size: 20,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          text,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: color,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
