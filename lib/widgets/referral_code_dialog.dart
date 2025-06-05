import 'package:flutter/material.dart';
import 'package:macrotracker/services/superwall_service.dart';

/// A dialog widget for entering referral or promo codes
class ReferralCodeDialog extends StatefulWidget {
  final VoidCallback? onSuccess;
  final VoidCallback? onCancel;

  const ReferralCodeDialog({
    super.key,
    this.onSuccess,
    this.onCancel,
  });

  @override
  State<ReferralCodeDialog> createState() => _ReferralCodeDialogState();
}

class _ReferralCodeDialogState extends State<ReferralCodeDialog> {
  final TextEditingController _codeController = TextEditingController();
  bool _isValidating = false;
  String? _errorMessage;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _validateAndApplyCode() async {
    final code = _codeController.text.trim();

    if (code.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter a referral code';
      });
      return;
    }

    setState(() {
      _isValidating = true;
      _errorMessage = null;
    });

    try {
      // Validate and show the referral paywall
      final isValid = await SuperwallService().validateAndShowReferralPaywall(
        code,
        influencerName: _getInfluencerName(code),
        discountPercentage: _getDiscountPercentage(code),
      );

      if (isValid) {
        // Close the dialog on success
        if (mounted) {
          Navigator.of(context).pop();
        }
        widget.onSuccess?.call();
      } else {
        // Show error message if validation failed
        setState(() {
          _errorMessage = 'Invalid referral code. Please try again.';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error validating code. Please try again.';
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

  /// Get influencer name based on referral code
  /// This would typically come from your server response
  String? _getInfluencerName(String code) {
    switch (code.toUpperCase()) {
      case 'WELCOME50':
        return 'WelcomeInfluencer';
      case 'FRIEND20':
        return 'FriendReferral';
      case 'NEWUSER':
        return 'NewUserPromo';
      case 'SAVE30':
        return 'SaveMore';
      case 'TESTCODE':
        return 'TestInfluencer';
      default:
        return null;
    }
  }

  /// Get discount percentage based on referral code
  /// This would typically come from your server response
  double? _getDiscountPercentage(String code) {
    switch (code.toUpperCase()) {
      case 'WELCOME50':
        return 50.0;
      case 'FRIEND20':
        return 20.0;
      case 'NEWUSER':
        return 25.0;
      case 'SAVE30':
        return 30.0;
      case 'TESTCODE':
        return 50.0;
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Enter Referral Code'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Have a referral or promo code? Enter it below to unlock special pricing!',
            style: TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _codeController,
            decoration: InputDecoration(
              labelText: 'Referral Code',
              hintText: 'Enter your code here',
              border: const OutlineInputBorder(),
              errorText: _errorMessage,
            ),
            textCapitalization: TextCapitalization.characters,
            enabled: !_isValidating,
            onSubmitted: (_) => _validateAndApplyCode(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isValidating
              ? null
              : () {
                  Navigator.of(context).pop();
                  widget.onCancel?.call();
                },
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isValidating ? null : _validateAndApplyCode,
          child: _isValidating
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Apply Code'),
        ),
      ],
    );
  }
}
