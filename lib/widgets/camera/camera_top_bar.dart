import 'dart:ui';
import 'package:flutter/material.dart';
import 'camera_theme.dart';

class CameraTopBar extends StatelessWidget {
  final VoidCallback onClose;
  final VoidCallback onFlash;
  final VoidCallback onInfo;
  final bool isFlashOn;
  final String instructionText;

  const CameraTopBar({
    super.key,
    required this.onClose,
    required this.onFlash,
    required this.onInfo,
    required this.isFlashOn,
    required this.instructionText,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: const BoxDecoration(
            gradient: CameraTheme.topBarGradient,
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Button row
                  SizedBox(
                    height: 48,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildCloseButton(),
                        Row(
                          children: [
                            _buildInfoButton(),
                            const SizedBox(width: 12),
                            _buildFlashButton(),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Instruction label
                  _buildInstructionLabel(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCloseButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onClose,
        borderRadius: BorderRadius.circular(CameraTheme.borderRadius),
        child: Container(
          width: CameraTheme.buttonSize,
          height: CameraTheme.buttonSize,
          decoration: CameraTheme.premiumButton,
          child: const Icon(
            Icons.close_rounded,
            color: Colors.white,
            size: CameraTheme.iconSize,
          ),
        ),
      ),
    );
  }

  Widget _buildFlashButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onFlash,
        borderRadius: BorderRadius.circular(CameraTheme.borderRadius),
        child: AnimatedContainer(
          duration: CameraTheme.fastAnimation,
          width: CameraTheme.buttonSize,
          height: CameraTheme.buttonSize,
          decoration: isFlashOn
              ? CameraTheme.premiumButton.copyWith(
                  color: CameraTheme.premiumGold.withValues(alpha: 0.2),
                  border: Border.all(
                    color: CameraTheme.premiumGold,
                    width: 1.5,
                  ),
                  boxShadow: CameraTheme.goldGlow,
                )
              : CameraTheme.premiumButton,
          child: Icon(
            isFlashOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
            color: isFlashOn
                ? CameraTheme.premiumGold
                : Colors.white.withValues(alpha: 0.8),
            size: CameraTheme.iconSize,
          ),
        ),
      ),
    );
  }

  Widget _buildInfoButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onInfo,
        borderRadius: BorderRadius.circular(CameraTheme.borderRadius),
        child: Container(
          width: CameraTheme.buttonSize,
          height: CameraTheme.buttonSize,
          decoration: CameraTheme.premiumButton,
          child: const Icon(
            Icons.info_outline_rounded,
            color: Colors.white,
            size: CameraTheme.iconSize,
          ),
        ),
      ),
    );
  }

  Widget _buildInstructionLabel() {
    return Flexible(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: CameraTheme.glassmorphicBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: CameraTheme.premiumGold.withValues(alpha: 0.2),
            width: 1,
          ),
          boxShadow: CameraTheme.softShadow,
        ),
        child: Text(
          instructionText,
          style: CameraTheme.instructionText.copyWith(fontSize: 16),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}
