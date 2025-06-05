import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'camera_theme.dart';

enum CameraMode { barcode, camera, label }

class CameraControls extends StatefulWidget {
  final VoidCallback onShutter;
  final VoidCallback onGallery;
  final VoidCallback onManualEntry;
  final CameraMode currentMode;

  const CameraControls({
    super.key,
    required this.onShutter,
    required this.onGallery,
    required this.onManualEntry,
    required this.currentMode,
  });

  @override
  State<CameraControls> createState() => _CameraControlsState();
}

class _CameraControlsState extends State<CameraControls>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: CameraTheme.fastAnimation,
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.9,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: CameraTheme.bottomControlsGradient,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _buildGalleryButton(),
            _buildShutterButton(),
            _buildManualEntryButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildShutterButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTapDown: (_) => _onShutterPressed(),
        onTapUp: (_) => _onShutterReleased(),
        onTapCancel: _onShutterReleased,
        onTap: () {
          HapticFeedback.heavyImpact();
          widget.onShutter();
        },
        borderRadius: BorderRadius.circular(CameraTheme.shutterSize / 2),
        child: AnimatedBuilder(
          animation: _scaleAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: Container(
                width: CameraTheme.shutterSize,
                height: CameraTheme.shutterSize,
                decoration: CameraTheme.shutterButton,
                child: Center(
                  child: AnimatedContainer(
                    duration: CameraTheme.fastAnimation,
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFFF5F5F5),
                          Color(0xFFE0E0E0),
                        ],
                      ),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: CameraTheme.premiumGold.withValues(alpha: 0.3),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          offset: const Offset(0, 2),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: _getShutterIcon(),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildGalleryButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.mediumImpact();
          widget.onGallery();
        },
        borderRadius: BorderRadius.circular(CameraTheme.borderRadius),
        child: Container(
          width: CameraTheme.floatingButtonSize,
          height: CameraTheme.floatingButtonSize,
          decoration: CameraTheme.floatingButton,
          child: const Icon(
            Icons.photo_library_rounded,
            color: Colors.white,
            size: CameraTheme.iconSize,
          ),
        ),
      ),
    );
  }

  Widget _buildManualEntryButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.mediumImpact();
          widget.onManualEntry();
        },
        borderRadius: BorderRadius.circular(CameraTheme.borderRadius),
        child: Container(
          width: CameraTheme.floatingButtonSize,
          height: CameraTheme.floatingButtonSize,
          decoration: CameraTheme.floatingButton,
          child: const Icon(
            Icons.keyboard_rounded,
            color: Colors.white,
            size: CameraTheme.iconSize,
          ),
        ),
      ),
    );
  }

  Widget _getShutterIcon() {
    switch (widget.currentMode) {
      case CameraMode.barcode:
        return const Icon(
          Icons.qr_code_scanner_rounded,
          color: Color(0xFF616161),
          size: 28,
        );
      case CameraMode.camera:
        return const Icon(
          Icons.camera_alt_rounded,
          color: Color(0xFF616161),
          size: 28,
        );
      case CameraMode.label:
        return const Icon(
          Icons.text_fields_rounded,
          color: Color(0xFF616161),
          size: 28,
        );
    }
  }

  void _onShutterPressed() {
    if (!_isPressed) {
      _isPressed = true;
      _animationController.forward();
      HapticFeedback.selectionClick();
    }
  }

  void _onShutterReleased() {
    if (_isPressed) {
      _isPressed = false;
      _animationController.reverse();
    }
  }
}
