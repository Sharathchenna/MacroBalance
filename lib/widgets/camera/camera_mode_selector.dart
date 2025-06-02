import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'camera_theme.dart';
import 'camera_controls.dart'; // Import for CameraMode enum

class CameraModeSelector extends StatefulWidget {
  final CameraMode currentMode;
  final Function(CameraMode) onModeChanged;

  const CameraModeSelector({
    super.key,
    required this.currentMode,
    required this.onModeChanged,
  });

  @override
  State<CameraModeSelector> createState() => _CameraModeSelectorState();
}

class _CameraModeSelectorState extends State<CameraModeSelector>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  final List<CameraMode> _modes = [
    CameraMode.barcode,
    CameraMode.camera,
    CameraMode.label,
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: CameraTheme.normalAnimation,
      vsync: this,
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Mode buttons
        Container(
          height: 44,
          decoration: BoxDecoration(
            color: CameraTheme.glassmorphicBackground,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.1),
              width: 1,
            ),
            boxShadow: CameraTheme.softShadow,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: _modes.map((mode) {
              final isSelected = mode == widget.currentMode;
              final index = _modes.indexOf(mode);
              return _buildModeTab(mode, isSelected, index);
            }).toList(),
          ),
        ),
        const SizedBox(height: 8),
        // Mode indicators
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: _modes.map((mode) {
            final isSelected = mode == widget.currentMode;
            return AnimatedContainer(
              duration: CameraTheme.normalAnimation,
              width: isSelected ? 24 : 8,
              height: 4,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: isSelected
                    ? CameraTheme.premiumGold
                    : Colors.white.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildModeTab(CameraMode mode, bool isSelected, int index) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.mediumImpact();
          widget.onModeChanged(mode);
        },
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: CameraTheme.normalAnimation,
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
          decoration: isSelected
              ? CameraTheme.selectedModeButton
              : CameraTheme.unselectedModeButton,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _getModeIcon(mode),
                color: isSelected
                    ? CameraTheme.premiumGold
                    : Colors.white.withValues(alpha: 0.7),
                size: 18,
              ),
              const SizedBox(width: 6),
              Text(
                _getModeLabel(mode),
                style: isSelected
                    ? CameraTheme.selectedModeText
                    : CameraTheme.modeText,
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getModeIcon(CameraMode mode) {
    switch (mode) {
      case CameraMode.barcode:
        return Icons.qr_code_scanner;
      case CameraMode.camera:
        return Icons.camera_alt;
      case CameraMode.label:
        return Icons.text_fields;
    }
  }

  String _getModeLabel(CameraMode mode) {
    switch (mode) {
      case CameraMode.barcode:
        return 'Barcode';
      case CameraMode.camera:
        return 'Camera';
      case CameraMode.label:
        return 'Label';
    }
  }
}
