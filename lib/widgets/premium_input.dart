import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';

/// Premium input field with enhanced styling and animations
class PremiumInput extends StatefulWidget {
  final String? label;
  final String? hint;
  final String? helperText;
  final String? errorText;
  final IconData? prefixIcon;
  final IconData? suffixIcon;
  final VoidCallback? onSuffixIconTap;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onTap;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final bool obscureText;
  final bool enabled;
  final bool readOnly;
  final int? maxLines;
  final int? maxLength;
  final FocusNode? focusNode;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final EdgeInsets? contentPadding;
  final double? borderRadius;
  final Color? fillColor;
  final String? initialValue;

  const PremiumInput({
    super.key,
    this.label,
    this.hint,
    this.helperText,
    this.errorText,
    this.prefixIcon,
    this.suffixIcon,
    this.onSuffixIconTap,
    this.controller,
    this.onChanged,
    this.onTap,
    this.keyboardType,
    this.inputFormatters,
    this.obscureText = false,
    this.enabled = true,
    this.readOnly = false,
    this.maxLines = 1,
    this.maxLength,
    this.focusNode,
    this.textInputAction,
    this.onSubmitted,
    this.contentPadding,
    this.borderRadius,
    this.fillColor,
    this.initialValue,
  });

  @override
  State<PremiumInput> createState() => _PremiumInputState();
}

class _PremiumInputState extends State<PremiumInput>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _labelAnimation;
  late Animation<Color?> _borderColorAnimation;
  late FocusNode _focusNode;
  bool _hasValue = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: PremiumAnimations.medium,
      vsync: this,
    );

    _labelAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: PremiumAnimations.smooth,
    ));

    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode.addListener(_handleFocusChange);

    // Check initial value
    _hasValue = (widget.controller?.text.isNotEmpty == true) ||
        (widget.initialValue?.isNotEmpty == true);

    if (_hasValue || _focusNode.hasFocus) {
      _animationController.value = 1.0;
    }

    // Listen to controller changes
    widget.controller?.addListener(_handleControllerChange);
  }

  @override
  void didUpdateWidget(PremiumInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.removeListener(_handleControllerChange);
      widget.controller?.addListener(_handleControllerChange);
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    widget.controller?.removeListener(_handleControllerChange);
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  void _handleFocusChange() {
    if (_focusNode.hasFocus || _hasValue) {
      _animationController.forward();
    } else {
      _animationController.reverse();
    }
    setState(() {});
  }

  void _handleControllerChange() {
    final hasValue = widget.controller?.text.isNotEmpty == true;
    if (hasValue != _hasValue) {
      setState(() {
        _hasValue = hasValue;
      });
      if (_hasValue || _focusNode.hasFocus) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    }
  }

  Color _getBorderColor(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (widget.errorText != null) {
      return PremiumColors.red500;
    } else if (_focusNode.hasFocus) {
      return PremiumColors.blue500;
    } else if (!widget.enabled) {
      return isDark ? PremiumColors.slate700 : PremiumColors.slate300;
    } else {
      return isDark ? PremiumColors.slate600 : PremiumColors.slate200;
    }
  }

  Color _getIconColor(BuildContext context) {
    final theme = Theme.of(context);
    final customColors = theme.extension<CustomColors>();

    if (widget.errorText != null) {
      return PremiumColors.red500;
    } else if (_focusNode.hasFocus) {
      return PremiumColors.blue500;
    } else {
      return customColors?.textSecondary ?? PremiumColors.slate500;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final customColors = theme.extension<CustomColors>();
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label
        if (widget.label != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              widget.label!,
              style: theme.textTheme.labelMedium?.copyWith(
                color: widget.errorText != null
                    ? PremiumColors.red500
                    : customColors?.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

        // Input field
        AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            return Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(widget.borderRadius ?? 12),
                boxShadow: _focusNode.hasFocus && widget.errorText == null
                    ? [
                        BoxShadow(
                          color: PremiumColors.blue500.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: TextFormField(
                controller: widget.controller,
                focusNode: _focusNode,
                onChanged: widget.onChanged,
                onTap: widget.onTap,
                onFieldSubmitted: widget.onSubmitted,
                keyboardType: widget.keyboardType,
                inputFormatters: widget.inputFormatters,
                obscureText: widget.obscureText,
                enabled: widget.enabled,
                readOnly: widget.readOnly,
                maxLines: widget.maxLines,
                maxLength: widget.maxLength,
                textInputAction: widget.textInputAction,
                initialValue: widget.initialValue,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: customColors?.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText: widget.hint,
                  hintStyle: theme.textTheme.bodyLarge?.copyWith(
                    color: customColors?.textSecondary?.withOpacity(0.6),
                  ),
                  filled: true,
                  fillColor: widget.fillColor ??
                      (isDark ? PremiumColors.slate800 : PremiumColors.slate50),
                  border: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(widget.borderRadius ?? 12),
                    borderSide: BorderSide(
                      color: _getBorderColor(context),
                      width: 1.5,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(widget.borderRadius ?? 12),
                    borderSide: BorderSide(
                      color: _getBorderColor(context),
                      width: 1,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(widget.borderRadius ?? 12),
                    borderSide: BorderSide(
                      color: _getBorderColor(context),
                      width: 2,
                    ),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(widget.borderRadius ?? 12),
                    borderSide: const BorderSide(
                      color: PremiumColors.red500,
                      width: 1.5,
                    ),
                  ),
                  focusedErrorBorder: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(widget.borderRadius ?? 12),
                    borderSide: const BorderSide(
                      color: PremiumColors.red500,
                      width: 2,
                    ),
                  ),
                  disabledBorder: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(widget.borderRadius ?? 12),
                    borderSide: BorderSide(
                      color: isDark
                          ? PremiumColors.slate700
                          : PremiumColors.slate300,
                      width: 1,
                    ),
                  ),
                  contentPadding: widget.contentPadding ??
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  prefixIcon: widget.prefixIcon != null
                      ? Icon(
                          widget.prefixIcon,
                          color: _getIconColor(context),
                          size: 20,
                        )
                      : null,
                  suffixIcon: widget.suffixIcon != null
                      ? GestureDetector(
                          onTap: widget.onSuffixIconTap,
                          child: Icon(
                            widget.suffixIcon,
                            color: _getIconColor(context),
                            size: 20,
                          ),
                        )
                      : null,
                  errorText: null, // Handle error text separately
                  counterText: widget.maxLength != null ? null : '',
                ),
              ),
            );
          },
        ),

        // Helper and error text
        if (widget.helperText != null || widget.errorText != null)
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 4),
            child: Row(
              children: [
                if (widget.errorText != null)
                  Icon(
                    Icons.error_outline,
                    size: 16,
                    color: PremiumColors.red500,
                  ),
                if (widget.errorText != null) const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    widget.errorText ?? widget.helperText!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: widget.errorText != null
                          ? PremiumColors.red500
                          : customColors?.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Premium search input with built-in search functionality
class PremiumSearchInput extends StatelessWidget {
  final String? hint;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onClear;
  final TextEditingController? controller;
  final bool autofocus;

  const PremiumSearchInput({
    super.key,
    this.hint,
    this.onChanged,
    this.onClear,
    this.controller,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    return PremiumInput(
      hint: hint ?? 'Search...',
      prefixIcon: Icons.search_rounded,
      suffixIcon:
          controller?.text.isNotEmpty == true ? Icons.clear_rounded : null,
      onSuffixIconTap: onClear ?? () => controller?.clear(),
      controller: controller,
      onChanged: onChanged,
      keyboardType: TextInputType.text,
      textInputAction: TextInputAction.search,
    );
  }
}

/// Premium number input with increment/decrement buttons
class PremiumNumberInput extends StatefulWidget {
  final String? label;
  final double value;
  final ValueChanged<double> onChanged;
  final double min;
  final double max;
  final double step;
  final int decimals;
  final String? suffix;

  const PremiumNumberInput({
    super.key,
    this.label,
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max = double.infinity,
    this.step = 1,
    this.decimals = 0,
    this.suffix,
  });

  @override
  State<PremiumNumberInput> createState() => _PremiumNumberInputState();
}

class _PremiumNumberInputState extends State<PremiumNumberInput> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.decimals > 0
          ? widget.value.toStringAsFixed(widget.decimals)
          : widget.value.toInt().toString(),
    );
  }

  @override
  void didUpdateWidget(PremiumNumberInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _controller.text = widget.decimals > 0
          ? widget.value.toStringAsFixed(widget.decimals)
          : widget.value.toInt().toString();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _increment() {
    final newValue = (widget.value + widget.step).clamp(widget.min, widget.max);
    widget.onChanged(newValue);
  }

  void _decrement() {
    final newValue = (widget.value - widget.step).clamp(widget.min, widget.max);
    widget.onChanged(newValue);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Decrement button
        _NumberButton(
          icon: Icons.remove_rounded,
          onTap: widget.value > widget.min ? _decrement : null,
        ),

        const SizedBox(width: 12),

        // Input field
        Expanded(
          child: PremiumInput(
            label: widget.label,
            controller: _controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textInputAction: TextInputAction.done,
            onChanged: (value) {
              final parsed = double.tryParse(value);
              if (parsed != null) {
                final clamped = parsed.clamp(widget.min, widget.max);
                widget.onChanged(clamped);
              }
            },
            suffixIcon: widget.suffix != null ? null : Icons.numbers,
          ),
        ),

        if (widget.suffix != null) ...[
          const SizedBox(width: 8),
          Text(
            widget.suffix!,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context)
                      .extension<CustomColors>()
                      ?.textSecondary,
                ),
          ),
        ],

        const SizedBox(width: 12),

        // Increment button
        _NumberButton(
          icon: Icons.add_rounded,
          onTap: widget.value < widget.max ? _increment : null,
        ),
      ],
    );
  }
}

class _NumberButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _NumberButton({
    required this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEnabled = onTap != null;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: PremiumAnimations.fast,
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: isEnabled
              ? PremiumColors.slate100
              : PremiumColors.slate100.withOpacity(0.5),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isEnabled
                ? PremiumColors.slate300
                : PremiumColors.slate300.withOpacity(0.5),
          ),
        ),
        child: Icon(
          icon,
          size: 18,
          color: isEnabled
              ? PremiumColors.slate700
              : PremiumColors.slate700.withOpacity(0.5),
        ),
      ),
    );
  }
}
