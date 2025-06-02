import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'camera_theme.dart';

class ManualBarcodeEntryDialog extends StatefulWidget {
  const ManualBarcodeEntryDialog({super.key});

  @override
  State<ManualBarcodeEntryDialog> createState() =>
      _ManualBarcodeEntryDialogState();
}

class _ManualBarcodeEntryDialogState extends State<ManualBarcodeEntryDialog>
    with SingleTickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: CameraTheme.normalAnimation,
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));

    _animationController.forward();

    // Auto-focus the text field after animation
    Future.delayed(CameraTheme.normalAnimation, () {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Opacity(
          opacity: _fadeAnimation.value,
          child: Transform.scale(
            scale: _scaleAnimation.value,
            child: AlertDialog(
              backgroundColor: Colors.transparent,
              contentPadding: EdgeInsets.zero,
              content: Container(
                width: MediaQuery.of(context).size.width * 0.85,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: CameraTheme.premiumGold.withValues(alpha: 0.3),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.6),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                    BoxShadow(
                      color: CameraTheme.premiumGold.withValues(alpha: 0.1),
                      blurRadius: 40,
                      spreadRadius: 0,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 20),
                    _buildTextField(),
                    const SizedBox(height: 24),
                    _buildButtons(),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: CameraTheme.premiumGold.withValues(alpha: 0.2),
            shape: BoxShape.circle,
            border: Border.all(
              color: CameraTheme.premiumGold.withValues(alpha: 0.4),
              width: 2,
            ),
          ),
          child: const Icon(
            Icons.keyboard,
            color: CameraTheme.premiumGold,
            size: 28,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Enter Barcode Manually',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Type or paste the barcode number',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 14,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }

  Widget _buildTextField() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: CameraTheme.premiumGold.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w500,
          letterSpacing: 1.0,
        ),
        decoration: InputDecoration(
          hintText: 'Enter barcode number...',
          hintStyle: TextStyle(
            color: Colors.white.withValues(alpha: 0.4),
            fontSize: 16,
          ),
          prefixIcon: Icon(
            Icons.qr_code,
            color: CameraTheme.premiumGold.withValues(alpha: 0.6),
            size: 20,
          ),
          suffixIcon: _controller.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(
                    Icons.clear,
                    color: Colors.white54,
                    size: 20,
                  ),
                  onPressed: () {
                    _controller.clear();
                    setState(() {});
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
        keyboardType: TextInputType.number,
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[0-9]')),
          LengthLimitingTextInputFormatter(
              20), // Reasonable barcode length limit
        ],
        onChanged: (value) {
          setState(() {}); // Rebuild to show/hide clear button
        },
        onSubmitted: (value) {
          if (value.trim().isNotEmpty) {
            _submitBarcode(value.trim());
          }
        },
      ),
    );
  }

  Widget _buildButtons() {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.of(context).pop();
            },
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
              child: const Center(
                child: Text(
                  'Cancel',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: GestureDetector(
            onTap: _controller.text.trim().isNotEmpty
                ? () {
                    HapticFeedback.mediumImpact();
                    _submitBarcode(_controller.text.trim());
                  }
                : null,
            child: AnimatedContainer(
              duration: CameraTheme.fastAnimation,
              height: 48,
              decoration: BoxDecoration(
                color: _controller.text.trim().isNotEmpty
                    ? CameraTheme.premiumGold
                    : CameraTheme.premiumGold.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12),
                boxShadow: _controller.text.trim().isNotEmpty
                    ? [
                        BoxShadow(
                          color: CameraTheme.premiumGold.withValues(alpha: 0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Center(
                child: Text(
                  'Submit',
                  style: TextStyle(
                    color: _controller.text.trim().isNotEmpty
                        ? Colors.black
                        : Colors.black54,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _submitBarcode(String barcode) {
    if (barcode.length < 8) {
      // Show error for too short barcode
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Barcode must be at least 8 digits'),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Close dialog and return the barcode
    Navigator.of(context).pop(barcode);
  }
}

// Helper function to show the dialog
Future<String?> showManualBarcodeEntryDialog(BuildContext context) {
  return showDialog<String>(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.black.withValues(alpha: 0.8),
    builder: (context) => const ManualBarcodeEntryDialog(),
  );
}
