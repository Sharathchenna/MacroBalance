import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:macrotracker/theme/ob_theme.dart';

/// A horizontal strip of [count] equal items that snaps the one under the
/// centre line. Swiping changes the index; a new [index] from outside (a
/// typed value) glides the strip to it. Base for [ObRuler] and the age strip.
class ObSnapStrip extends StatefulWidget {
  const ObSnapStrip({
    super.key,
    required this.count,
    required this.index,
    required this.onChanged,
    required this.itemExtent,
    required this.itemBuilder,
    required this.height,
    this.fadeColor,
    this.indicator,
  });

  final int count;
  final int index;
  final ValueChanged<int> onChanged;
  final double itemExtent;
  final double height;
  final Widget Function(BuildContext context, int index, bool selected) itemBuilder;

  /// Colour the edges fade into (the colour behind the strip).
  final Color? fadeColor;

  /// Drawn over the centre (the green line or box).
  final Widget? indicator;

  @override
  State<ObSnapStrip> createState() => _ObSnapStripState();
}

class _ObSnapStripState extends State<ObSnapStrip> {
  late final ScrollController _controller =
      ScrollController(initialScrollOffset: widget.index * widget.itemExtent);
  late int _index = widget.index;
  bool _dragging = false;

  @override
  void didUpdateWidget(ObSnapStrip old) {
    super.didUpdateWidget(old);
    if (widget.index != _index && !_dragging) {
      _index = widget.index;
      if (_controller.hasClients) {
        _controller.animateTo(widget.index * widget.itemExtent,
            duration: const Duration(milliseconds: 350), curve: Curves.easeOutCubic);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  int _indexAt(double offset) =>
      (offset / widget.itemExtent).round().clamp(0, widget.count - 1);

  bool _onNotification(ScrollNotification n) {
    if (n is ScrollStartNotification && n.dragDetails != null) {
      _dragging = true;
    } else if (n is ScrollUpdateNotification && _dragging) {
      final i = _indexAt(n.metrics.pixels);
      if (i != _index) {
        _index = i;
        HapticFeedback.selectionClick();
        widget.onChanged(i);
      }
    } else if (n is ScrollEndNotification && _dragging) {
      _dragging = false;
      final i = _indexAt(n.metrics.pixels);
      final target = i * widget.itemExtent;
      if ((n.metrics.pixels - target).abs() > 0.5) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_controller.hasClients) {
            _controller.animateTo(target,
                duration: const Duration(milliseconds: 180), curve: Curves.easeOut);
          }
        });
      }
      if (i != _index) {
        _index = i;
        widget.onChanged(i);
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final fade = widget.fadeColor ?? ObColors.of(context).bg;
    return SizedBox(
      height: widget.height,
      child: LayoutBuilder(builder: (context, box) {
        final side = (box.maxWidth - widget.itemExtent) / 2;
        return Stack(
          children: [
            NotificationListener<ScrollNotification>(
              onNotification: _onNotification,
              child: ListView.builder(
                controller: _controller,
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.symmetric(horizontal: side),
                itemExtent: widget.itemExtent,
                itemCount: widget.count,
                itemBuilder: (context, i) => widget.itemBuilder(context, i, i == _index),
              ),
            ),
            if (widget.indicator != null)
              Positioned.fill(child: IgnorePointer(child: Center(child: widget.indicator))),
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: 72,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [fade, fade.withValues(alpha: 0)])),
                ),
              ),
            ),
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              width: 72,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [fade.withValues(alpha: 0), fade])),
                ),
              ),
            ),
          ],
        );
      }),
    );
  }
}

/// A tick ruler from [min] to [max] in [step]s: a tall labelled tick every
/// [majorEvery] steps, a medium one every [midEvery]. Swipe to change.
class ObRuler extends StatelessWidget {
  const ObRuler({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.step = 0.1,
    this.majorEvery = 50,
    this.midEvery = 10,
    this.tickWidth = 6,
    this.height = 74,
    this.label,
    this.fadeColor,
  });

  final double value;
  final double min;
  final double max;
  final double step;
  final int majorEvery;
  final int midEvery;
  final double tickWidth;
  final double height;
  final ValueChanged<double> onChanged;

  /// Label under a major tick; defaults to the whole number.
  final String Function(double value)? label;
  final Color? fadeColor;

  int get _count => ((max - min) / step).round() + 1;

  double _valueAt(int i) => double.parse((min + i * step).toStringAsFixed(2));

  @override
  Widget build(BuildContext context) {
    final c = ObColors.of(context);
    final index = ((value.clamp(min, max) - min) / step).round();
    final longest = height - 26;
    return Semantics(
      slider: true,
      value: value.toStringAsFixed(step < 1 ? 1 : 0),
      increasedValue: _valueAt((index + 1).clamp(0, _count - 1)).toString(),
      decreasedValue: _valueAt((index - 1).clamp(0, _count - 1)).toString(),
      onIncrease: () => onChanged(_valueAt((index + 1).clamp(0, _count - 1))),
      onDecrease: () => onChanged(_valueAt((index - 1).clamp(0, _count - 1))),
      child: ObSnapStrip(
        count: _count,
        index: index,
        itemExtent: tickWidth,
        height: height,
        fadeColor: fadeColor,
        onChanged: (i) => onChanged(_valueAt(i)),
        indicator: Padding(
          padding: EdgeInsets.only(bottom: height - longest - 6),
          child: Container(
            width: 4,
            height: longest + 12,
            decoration: BoxDecoration(color: c.leaf, borderRadius: BorderRadius.circular(2)),
          ),
        ),
        itemBuilder: (context, i, _) {
          final major = i % majorEvery == 0;
          final mid = i % midEvery == 0;
          return OverflowBox(
            maxWidth: 48,
            alignment: Alignment.topCenter,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 2,
                  height: major ? longest : mid ? longest * 0.6 : longest * 0.33,
                  decoration: BoxDecoration(
                    color: major ? c.text2 : mid ? c.muted.withValues(alpha: 0.6) : c.line,
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 16,
                  child: major
                      ? Text(label?.call(_valueAt(i)) ?? _valueAt(i).round().toString(),
                          style: ObText.body(c.muted, size: 12, weight: FontWeight.w500)
                              .copyWith(height: 1.2))
                      : null,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// The big typed number above a ruler or strip. Typing a value inside
/// [min]..[max] reports it at once; leaving the field restores the current
/// value if what was typed is out of range.
class ObNumberField extends StatefulWidget {
  const ObNumberField({
    super.key,
    required this.value,
    required this.onChanged,
    required this.min,
    required this.max,
    this.decimals = 1,
    this.fontSize = 76,
    this.width,
    this.semanticLabel,
    this.textAlign = TextAlign.right,
  });

  final double value;
  final ValueChanged<double> onChanged;
  final double min;
  final double max;
  final int decimals;
  final double fontSize;

  /// Fixed width; null sizes the field to what's in it.
  final double? width;
  final String? semanticLabel;
  final TextAlign textAlign;

  @override
  State<ObNumberField> createState() => _ObNumberFieldState();
}

class _ObNumberFieldState extends State<ObNumberField> {
  late final TextEditingController _text = TextEditingController(text: _format(widget.value));
  final FocusNode _focus = FocusNode();

  String _format(double v) => v.toStringAsFixed(widget.decimals);

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus) _text.text = _format(widget.value);
      setState(() {});
    });
  }

  @override
  void didUpdateWidget(ObNumberField old) {
    super.didUpdateWidget(old);
    if (!_focus.hasFocus && _text.text != _format(widget.value)) {
      _text.text = _format(widget.value);
    }
  }

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = ObColors.of(context);
    final field = TextField(
        controller: _text,
        focusNode: _focus,
        textAlign: widget.textAlign,
        keyboardType: TextInputType.numberWithOptions(decimal: widget.decimals > 0),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(widget.decimals > 0 ? r'[0-9.,]' : r'[0-9]')),
          LengthLimitingTextInputFormatter(widget.decimals > 0 ? 5 : 3),
        ],
        cursorColor: c.leaf,
        style: ObText.display(widget.fontSize, color: _focus.hasFocus ? c.leafText : c.text, height: 1),
        decoration: InputDecoration(
          isCollapsed: true,
          border: InputBorder.none,
          semanticCounterText: widget.semanticLabel,
        ),
        onTapOutside: (_) => _focus.unfocus(),
        onChanged: (raw) {
          if (widget.width == null) setState(() {}); // re-measure
          final v = double.tryParse(raw.replaceAll(',', '.'));
          if (v != null && v >= widget.min && v <= widget.max) widget.onChanged(v);
        },
        onSubmitted: (_) => _focus.unfocus(),
      );
    var width = widget.width;
    if (width == null) {
      // As wide as what's typed (Onest digits are about 0.62 em), at least
      // one digit, plus room for the cursor.
      final chars = _text.text.isEmpty ? 1 : _text.text.length;
      width = MediaQuery.textScalerOf(context).scale(widget.fontSize) * 0.62 * chars + 6;
    }
    return SizedBox(width: width, child: field);
  }
}
