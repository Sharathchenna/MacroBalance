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
        return screenWidth * 0.9; // Increased to better fit nutrition labels
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
        return screenHeight * 0.45; // Increased to better fit nutrition labels
      default:
        return 0;
    }
  }

  List<Widget> _buildEnhancedCornerAccents() {
    final cornerSize = 28.0 * _cornerAnimation.value;
    const cornerThickness = 4.0;
    final cornerColor = _colorAnimation.value ?? CameraTheme.premiumGold;

    return [
      // Top-left corner with enhanced styling
      Positioned(
        top: -2,
        left: -2,
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
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
              ),
              boxShadow: [
                BoxShadow(
                  color: cornerColor.withValues(alpha: 0.5),
                  blurRadius: 8,
                  spreadRadius: 2,
                ),
                BoxShadow(
                  color: cornerColor.withValues(alpha: 0.2),
                  blurRadius: 16,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: Positioned(
              top: 2,
              left: 2,
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: cornerColor.withValues(alpha: 0.8),
                  boxShadow: [
                    BoxShadow(
                      color: cornerColor.withValues(alpha: 0.6),
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      // Top-right corner with enhanced styling
      Positioned(
        top: -2,
        right: -2,
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
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(16),
              ),
              boxShadow: [
                BoxShadow(
                  color: cornerColor.withValues(alpha: 0.5),
                  blurRadius: 8,
                  spreadRadius: 2,
                ),
                BoxShadow(
                  color: cornerColor.withValues(alpha: 0.2),
                  blurRadius: 16,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: Positioned(
              top: 2,
              right: 2,
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: cornerColor.withValues(alpha: 0.8),
                  boxShadow: [
                    BoxShadow(
                      color: cornerColor.withValues(alpha: 0.6),
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      // Bottom-left corner with enhanced styling
      Positioned(
        bottom: -2,
        left: -2,
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
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(16),
              ),
              boxShadow: [
                BoxShadow(
                  color: cornerColor.withValues(alpha: 0.5),
                  blurRadius: 8,
                  spreadRadius: 2,
                ),
                BoxShadow(
                  color: cornerColor.withValues(alpha: 0.2),
                  blurRadius: 16,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: Positioned(
              bottom: 2,
              left: 2,
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: cornerColor.withValues(alpha: 0.8),
                  boxShadow: [
                    BoxShadow(
                      color: cornerColor.withValues(alpha: 0.6),
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      // Bottom-right corner with enhanced styling
      Positioned(
        bottom: -2,
        right: -2,
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
              borderRadius: const BorderRadius.only(
                bottomRight: Radius.circular(16),
              ),
              boxShadow: [
                BoxShadow(
                  color: cornerColor.withValues(alpha: 0.5),
                  blurRadius: 8,
                  spreadRadius: 2,
                ),
                BoxShadow(
                  color: cornerColor.withValues(alpha: 0.2),
                  blurRadius: 16,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: Positioned(
              bottom: 2,
              right: 2,
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: cornerColor.withValues(alpha: 0.8),
                  boxShadow: [
                    BoxShadow(
                      color: cornerColor.withValues(alpha: 0.6),
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ];
  }

  Widget _buildPremiumBarcodeAnimation() {
    final scanProgress = _scanLineAnimation.value;
    final lineColor = _colorAnimation.value ?? CameraTheme.premiumGold;
    final guideHeight = _getGuideHeight();

    return Stack(
      children: [
        // Main scanning beam with enhanced gradient
        Positioned(
          left: 6,
          right: 6,
          top: scanProgress * (guideHeight - 28) + 12,
          child: Container(
            height: 4,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  lineColor.withValues(alpha: 0.2),
                  lineColor.withValues(alpha: 0.6),
                  lineColor,
                  lineColor.withValues(alpha: 0.9),
                  lineColor,
                  lineColor.withValues(alpha: 0.6),
                  lineColor.withValues(alpha: 0.2),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.1, 0.3, 0.45, 0.5, 0.55, 0.7, 0.9, 1.0],
              ),
              borderRadius: BorderRadius.circular(2),
              boxShadow: [
                BoxShadow(
                  color: lineColor.withValues(alpha: 0.8),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
                BoxShadow(
                  color: lineColor.withValues(alpha: 0.4),
                  blurRadius: 20,
                  spreadRadius: 4,
                ),
              ],
            ),
          ),
        ),

        // Secondary beam for depth effect
        Positioned(
          left: 8,
          right: 8,
          top: scanProgress * (guideHeight - 26) + 13,
          child: Container(
            height: 2,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  Colors.white.withValues(alpha: 0.3),
                  Colors.white.withValues(alpha: 0.8),
                  Colors.white.withValues(alpha: 0.3),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.3, 0.5, 0.7, 1.0],
              ),
              borderRadius: BorderRadius.circular(1),
            ),
          ),
        ),

        // Animated scanning particles with trails
        ...List.generate(6, (index) {
          final delay = index * 0.15;
          final particleProgress = ((scanProgress + delay) % 1.0);
          final particleOpacity = (1.0 - (index * 0.15)).clamp(0.2, 1.0);

          return Positioned(
            left: 14 + (index * 8.0),
            top: particleProgress * (guideHeight - 20) + 8,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: particleOpacity,
              child: Container(
                width: 3,
                height: 8,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      lineColor.withValues(alpha: 0.6 * particleOpacity),
                      lineColor.withValues(alpha: 0.9 * particleOpacity),
                      Colors.transparent,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(1.5),
                  boxShadow: [
                    BoxShadow(
                      color: lineColor.withValues(alpha: 0.4 * particleOpacity),
                      blurRadius: 4,
                    ),
                  ],
                ),
              ),
            ),
          );
        }),

        // Edge glow effects
        Positioned(
          left: 0,
          right: 0,
          top: scanProgress * (guideHeight - 24) + 10,
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      lineColor.withValues(alpha: 0.8),
                      lineColor.withValues(alpha: 0.3),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
              const Spacer(),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      lineColor.withValues(alpha: 0.8),
                      lineColor.withValues(alpha: 0.3),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPremiumLabelAnimation() {
    final scanProgress = _scanLineAnimation.value;
    final lineColor = _colorAnimation.value ?? CameraTheme.premiumGold;
    final guideHeight = _getGuideHeight();

    return Stack(
      children: [
        // Animated scanning grid with shimmer effect
        ...List.generate(6, (index) {
          final linePosition = (guideHeight / 7) * (index + 1);
          final animatedOpacity =
              (0.2 + 0.6 * ((scanProgress + index * 0.15) % 1.0))
                  .clamp(0.1, 0.8);
          final shimmerOffset = ((scanProgress * 2 + index * 0.2) % 1.0) - 0.5;

          return Positioned(
            left: 16,
            right: 16,
            top: linePosition,
            child: Opacity(
              opacity: animatedOpacity,
              child: Container(
                height: 1.5,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Colors.transparent,
                      lineColor.withValues(alpha: 0.3),
                      lineColor.withValues(alpha: 0.7),
                      lineColor.withValues(alpha: 0.9),
                      lineColor.withValues(alpha: 0.7),
                      lineColor.withValues(alpha: 0.3),
                      Colors.transparent,
                    ],
                    stops: [
                      0.0,
                      (0.2 + shimmerOffset * 0.3).clamp(0.0, 1.0),
                      (0.35 + shimmerOffset * 0.3).clamp(0.0, 1.0),
                      (0.5 + shimmerOffset * 0.3).clamp(0.0, 1.0),
                      (0.65 + shimmerOffset * 0.3).clamp(0.0, 1.0),
                      (0.8 + shimmerOffset * 0.3).clamp(0.0, 1.0),
                      1.0,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(0.75),
                  boxShadow: [
                    BoxShadow(
                      color: lineColor.withValues(alpha: 0.3 * animatedOpacity),
                      blurRadius: 3,
                    ),
                  ],
                ),
              ),
            ),
          );
        }),

        // Main vertical scanning sweep
        Positioned(
          left: 12,
          right: 12,
          top: scanProgress * (guideHeight - 36) + 18,
          child: Container(
            height: 6,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  lineColor.withValues(alpha: 0.3),
                  lineColor.withValues(alpha: 0.7),
                  lineColor,
                  lineColor.withValues(alpha: 0.9),
                  lineColor,
                  lineColor.withValues(alpha: 0.7),
                  lineColor.withValues(alpha: 0.3),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.15, 0.3, 0.45, 0.5, 0.55, 0.7, 0.85, 1.0],
              ),
              borderRadius: BorderRadius.circular(3),
              boxShadow: [
                BoxShadow(
                  color: lineColor.withValues(alpha: 0.7),
                  blurRadius: 15,
                  spreadRadius: 3,
                ),
                BoxShadow(
                  color: lineColor.withValues(alpha: 0.3),
                  blurRadius: 25,
                  spreadRadius: 6,
                ),
              ],
            ),
          ),
        ),

        // Trailing glow effect
        Positioned(
          left: 14,
          right: 14,
          top: scanProgress * (guideHeight - 34) + 19,
          child: Container(
            height: 4,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  Colors.white.withValues(alpha: 0.4),
                  Colors.white.withValues(alpha: 0.8),
                  Colors.white.withValues(alpha: 0.4),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.3, 0.5, 0.7, 1.0],
              ),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),

        // Scanning focus points
        ...List.generate(4, (verticalIndex) {
          final verticalPosition = (guideHeight / 5) * (verticalIndex + 1);
          return Row(
            children: List.generate(3, (horizontalIndex) {
              final horizontalOffset = (horizontalIndex + 1) * 0.25;
              final focusOpacity = (0.4 +
                      0.4 *
                          ((scanProgress +
                                  verticalIndex * 0.2 +
                                  horizontalIndex * 0.1) %
                              1.0))
                  .clamp(0.2, 0.8);

              return Expanded(
                child: Align(
                  alignment: Alignment(horizontalOffset - 1.0, 0.0),
                  child: Positioned(
                    top: verticalPosition,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 300),
                      opacity: focusOpacity,
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              lineColor.withValues(alpha: 0.9 * focusOpacity),
                              lineColor.withValues(alpha: 0.4 * focusOpacity),
                              Colors.transparent,
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: lineColor.withValues(
                                  alpha: 0.5 * focusOpacity),
                              blurRadius: 8,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          );
        }),

        // Corner focus indicators
        ...List.generate(4, (index) {
          final isLeft = index % 2 == 0;
          final isTop = index < 2;
          final indicatorOpacity =
              (0.5 + 0.3 * ((scanProgress + index * 0.25) % 1.0))
                  .clamp(0.3, 0.8);

          return Positioned(
            left: isLeft ? 8 : null,
            right: isLeft ? null : 8,
            top: isTop ? 8 : null,
            bottom: isTop ? null : 8,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 400),
              opacity: indicatorOpacity,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: lineColor.withValues(alpha: 0.8 * indicatorOpacity),
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: [
                    BoxShadow(
                      color:
                          lineColor.withValues(alpha: 0.4 * indicatorOpacity),
                      blurRadius: 6,
                    ),
                  ],
                ),
                child: Center(
                  child: Container(
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color:
                          lineColor.withValues(alpha: 0.9 * indicatorOpacity),
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildCenterHint() {
    // Don't show any hint text for any mode
    return const SizedBox.shrink();
  }
}
