import 'package:flutter/material.dart';
import 'camera_theme.dart';
import 'camera_controls.dart'; // Import for CameraMode enum

class CameraGuideOverlay extends StatefulWidget {
  final CameraMode currentMode;
  final bool isAnimating;

  const CameraGuideOverlay({
    super.key,
    required this.currentMode,
    this.isAnimating = false,
  });

  @override
  State<CameraGuideOverlay> createState() => _CameraGuideOverlayState();
}

class _CameraGuideOverlayState extends State<CameraGuideOverlay>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _scanLineController;
  late AnimationController _cornerController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _scanLineAnimation;
  late Animation<double> _cornerAnimation;
  late Animation<Color?> _colorAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();

    // Enhanced pulse animation for the guide border
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.02,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    // Improved scan line animation with different timing
    _scanLineController = AnimationController(
      duration: const Duration(milliseconds: 2500),
      vsync: this,
    );
    _scanLineAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _scanLineController,
      curve: Curves.easeInOut,
    ));

    // Corner accent animation
    _cornerController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _cornerAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _cornerController,
      curve: Curves.easeInOut,
    ));

    // Enhanced color animation
    _colorAnimation = ColorTween(
      begin: CameraTheme.premiumGold,
      end: CameraTheme.premiumGoldLight,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    // Opacity animation for breathing effect
    _opacityAnimation = Tween<double>(
      begin: 0.6,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _startAnimations();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _scanLineController.dispose();
    _cornerController.dispose();
    super.dispose();
  }

  void _startAnimations() {
    if (widget.currentMode != CameraMode.camera) {
      _pulseController.repeat(reverse: true);
      _cornerController.repeat(reverse: true);

      if (widget.currentMode == CameraMode.barcode) {
        _scanLineController.repeat();
      } else {
        // For label mode, use a different animation pattern
        _scanLineController.repeat(reverse: true);
      }
    }
  }

  void _stopAnimations() {
    _pulseController.stop();
    _scanLineController.stop();
    _cornerController.stop();
  }

  @override
  void didUpdateWidget(CameraGuideOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentMode != widget.currentMode) {
      if (widget.currentMode == CameraMode.camera) {
        _stopAnimations();
      } else {
        _startAnimations();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.currentMode == CameraMode.camera) {
      return const SizedBox.shrink();
    }

    return Center(
      child: AnimatedBuilder(
        animation: Listenable.merge([
          _pulseAnimation,
          _scanLineAnimation,
          _cornerAnimation,
          _opacityAnimation,
        ]),
        builder: (context, child) {
          return SizedBox(
            width: _getGuideWidth(),
            height: _getGuideHeight(),
            child: Stack(
              children: [
                // Main guide border with enhanced design
                Transform.scale(
                  scale: _pulseAnimation.value,
                  child: Opacity(
                    opacity: _opacityAnimation.value,
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: widget.isAnimating
                              ? _colorAnimation.value ?? CameraTheme.premiumGold
                              : _colorAnimation.value ??
                                  CameraTheme.premiumGold,
                          width: 2.5,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: (_colorAnimation.value ??
                                    CameraTheme.premiumGold)
                                .withValues(
                                    alpha: 0.4 * _opacityAnimation.value),
                            blurRadius: 20,
                            spreadRadius: 3,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                // Enhanced corner accents
                ..._buildEnhancedCornerAccents(),
                // Premium scan animation
                if (widget.currentMode == CameraMode.barcode)
                  _buildPremiumBarcodeAnimation(),
                if (widget.currentMode == CameraMode.label)
                  _buildPremiumLabelAnimation(),
                // Center text hint
                _buildCenterHint(),
              ],
            ),
          );
        },
      ),
    );
  }

  double _getGuideWidth() {
    final screenWidth = MediaQuery.of(context).size.width;
    switch (widget.currentMode) {
      case CameraMode.barcode:
        return screenWidth * 0.7;
      case CameraMode.label:
        return screenWidth * 0.85;
      default:
        return 0;
    }
  }

  double _getGuideHeight() {
    final screenHeight = MediaQuery.of(context).size.height;
    switch (widget.currentMode) {
      case CameraMode.barcode:
        return screenHeight * 0.12; // Reduced for better positioning
      case CameraMode.label:
        return screenHeight * 0.35; // Reduced to prevent overlap with top bar
      default:
        return 0;
    }
  }

  List<Widget> _buildEnhancedCornerAccents() {
    final cornerSize = 24.0 * _cornerAnimation.value;
    const cornerThickness = 3.0;
    final cornerColor = _colorAnimation.value ?? CameraTheme.premiumGold;

    return [
      // Top-left corner
      Positioned(
        top: -1.5,
        left: -1.5,
        child: Transform.scale(
          scale: _cornerAnimation.value,
          child: Container(
            width: cornerSize,
            height: cornerSize,
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: cornerColor,
                  width: cornerThickness,
                ),
                left: BorderSide(
                  color: cornerColor,
                  width: cornerThickness,
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: cornerColor.withValues(alpha: 0.3),
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
        ),
      ),
      // Top-right corner
      Positioned(
        top: -1.5,
        right: -1.5,
        child: Transform.scale(
          scale: _cornerAnimation.value,
          child: Container(
            width: cornerSize,
            height: cornerSize,
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: cornerColor,
                  width: cornerThickness,
                ),
                right: BorderSide(
                  color: cornerColor,
                  width: cornerThickness,
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: cornerColor.withValues(alpha: 0.3),
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
        ),
      ),
      // Bottom-left corner
      Positioned(
        bottom: -1.5,
        left: -1.5,
        child: Transform.scale(
          scale: _cornerAnimation.value,
          child: Container(
            width: cornerSize,
            height: cornerSize,
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: cornerColor,
                  width: cornerThickness,
                ),
                left: BorderSide(
                  color: cornerColor,
                  width: cornerThickness,
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: cornerColor.withValues(alpha: 0.3),
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
        ),
      ),
      // Bottom-right corner
      Positioned(
        bottom: -1.5,
        right: -1.5,
        child: Transform.scale(
          scale: _cornerAnimation.value,
          child: Container(
            width: cornerSize,
            height: cornerSize,
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: cornerColor,
                  width: cornerThickness,
                ),
                right: BorderSide(
                  color: cornerColor,
                  width: cornerThickness,
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: cornerColor.withValues(alpha: 0.3),
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
        ),
      ),
    ];
  }

  Widget _buildPremiumBarcodeAnimation() {
    final scanProgress = _scanLineAnimation.value;
    final lineColor = _colorAnimation.value ?? CameraTheme.premiumGold;

    return Stack(
      children: [
        // Main scanning beam
        Positioned(
          left: 8,
          right: 8,
          top: scanProgress * (_getGuideHeight() - 24) + 8,
          child: Container(
            height: 3,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  lineColor.withValues(alpha: 0.3),
                  lineColor,
                  lineColor.withValues(alpha: 0.3),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.2, 0.5, 0.8, 1.0],
              ),
              borderRadius: BorderRadius.circular(1.5),
              boxShadow: [
                BoxShadow(
                  color: lineColor.withValues(alpha: 0.6),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
        ),
        // Scanning particles effect
        ...List.generate(3, (index) {
          final delay = index * 0.3;
          final particleProgress = ((scanProgress + delay) % 1.0);
          return Positioned(
            left: 12 + (index * 4.0),
            top: particleProgress * (_getGuideHeight() - 16) + 6,
            child: Container(
              width: 2,
              height: 2,
              decoration: BoxDecoration(
                color: lineColor.withValues(alpha: 0.8),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: lineColor.withValues(alpha: 0.4),
                    blurRadius: 3,
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildPremiumLabelAnimation() {
    final scanProgress = _scanLineAnimation.value;
    final lineColor = _colorAnimation.value ?? CameraTheme.premiumGold;
    final guideHeight = _getGuideHeight();

    return Stack(
      children: [
        // Horizontal scanning grid
        ...List.generate(4, (index) {
          final linePosition = (guideHeight / 5) * (index + 1);
          final animatedOpacity =
              (0.3 + 0.4 * ((scanProgress + index * 0.2) % 1.0))
                  .clamp(0.0, 1.0);

          return Positioned(
            left: 12,
            right: 12,
            top: linePosition,
            child: Opacity(
              opacity: animatedOpacity,
              child: Container(
                height: 1,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      lineColor.withValues(alpha: 0.6),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  ),
                ),
              ),
            ),
          );
        }),
        // Vertical highlight line
        Positioned(
          left: 16,
          right: 16,
          top: scanProgress * (guideHeight - 32) + 16,
          child: Container(
            height: 2,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  lineColor.withValues(alpha: 0.4),
                  lineColor,
                  lineColor.withValues(alpha: 0.4),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.3, 0.5, 0.7, 1.0],
              ),
              borderRadius: BorderRadius.circular(1),
              boxShadow: [
                BoxShadow(
                  color: lineColor.withValues(alpha: 0.5),
                  blurRadius: 6,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCenterHint() {
    String hintText = '';
    IconData hintIcon = Icons.info;

    switch (widget.currentMode) {
      case CameraMode.barcode:
        hintText = 'Position barcode here';
        hintIcon = Icons.qr_code;
        break;
      case CameraMode.label:
        hintText = 'Position nutrition label here';
        hintIcon = Icons.text_fields;
        break;
      default:
        return const SizedBox.shrink();
    }

    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: CameraTheme.premiumGold.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hintIcon,
              color: CameraTheme.premiumGold,
              size: 16,
            ),
            const SizedBox(width: 6),
            Text(
              hintText,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
