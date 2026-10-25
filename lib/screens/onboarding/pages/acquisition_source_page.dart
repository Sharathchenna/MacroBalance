import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:macrotracker/screens/onboarding/widgets/ob_widgets.dart';
import 'package:macrotracker/services/posthog_service.dart';
import 'package:macrotracker/theme/ob_theme.dart';

/// "How did you hear about us?" (docs/onboarding-redesign/mock/Source.dc.html).
/// Chips in two groups and an always-visible "Somewhere else" field. Stored
/// values keep today's keys (tiktok, instagram, reddit, `other: <text>`) and
/// add youtube, ad, friend, club and app_store.
class AcquisitionSourcePage extends StatefulWidget {
  final String? currentSource;
  final ValueChanged<String?> onSourceSelected;
  final VoidCallback? onSkip;

  const AcquisitionSourcePage({
    super.key,
    this.currentSource,
    required this.onSourceSelected,
    this.onSkip,
  });

  @override
  State<AcquisitionSourcePage> createState() => _AcquisitionSourcePageState();
}

class _AcquisitionSourcePageState extends State<AcquisitionSourcePage> {
  static const _social = [
    ('tiktok', 'TikTok'),
    ('instagram', 'Instagram'),
    ('youtube', 'YouTube'),
    ('reddit', 'Reddit'),
  ];
  static const _people = [
    ('ad', 'An ad'),
    ('friend', 'A friend'),
    ('club', 'Gym, club or coach'),
    ('app_store', 'App Store'),
  ];

  String? _selectedSource;
  final TextEditingController _otherText = TextEditingController();
  final FocusNode _otherFocus = FocusNode();
  Timer? _debounce;

  bool get _otherOn => _selectedSource != null && _selectedSource!.startsWith('other');

  @override
  void initState() {
    super.initState();
    _selectedSource = widget.currentSource;
    _otherFocus.addListener(() {
      if (_otherFocus.hasFocus && !_otherOn) _select('other');
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _otherText.dispose();
    _otherFocus.dispose();
    super.dispose();
  }

  void _select(String source) {
    HapticFeedback.selectionClick();
    final tracked = source == 'other' && _otherText.text.isNotEmpty
        ? 'other: ${_otherText.text}'
        : source;
    setState(() => _selectedSource = tracked);
    PostHogService.trackEvent('acquisition_source_selected', properties: {
      'source': tracked,
      'timestamp': DateTime.now().toIso8601String(),
    });
    widget.onSourceSelected(tracked);
  }

  void _otherChanged(String value) {
    final tracked = value.isNotEmpty ? 'other: $value' : 'other';
    setState(() => _selectedSource = tracked);
    // The answer follows each keystroke so Continue never loses text; the
    // event waits until typing stops.
    widget.onSourceSelected(tracked);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 1000), () {
      PostHogService.trackEvent('acquisition_source_other_text_changed', properties: {
        'source': tracked,
        'text_length': value.length,
        'timestamp': DateTime.now().toIso8601String(),
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = ObColors.of(context);
    Widget group(String label, List<(String, String)> chips, int index) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ObRise(
              index: index,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(label, style: ObText.eyebrow(c.text2)),
              ),
            ),
            ObRise(
              index: index,
              child: GridView.count(
                crossAxisCount: 2,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 2.9,
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  for (final o in chips)
                    _Chip(
                      label: o.$2,
                      selected: _selectedSource == o.$1,
                      onTap: () => _select(o.$1),
                    ),
                ],
              ),
            ),
          ],
        );

    return ObPageBody(
      top: 18,
      children: [
        const ObHeader(
          title: 'One quick thing. How did you find us?',
          subtitle: 'It helps a small team know where to show up.',
        ),
        const SizedBox(height: 24),
        group('SOCIAL MEDIA AND CONTENT', _social, 2),
        const SizedBox(height: 20),
        group('SOMEONE OR SOMEWHERE', _people, 3),
        const SizedBox(height: 20),
        ObRise(
          index: 4,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text('SOMEWHERE ELSE?', style: ObText.eyebrow(c.text2)),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 52,
                decoration: BoxDecoration(
                  color: c.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _otherOn ? c.leaf : c.line, width: 2),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                alignment: Alignment.center,
                child: TextField(
                  key: const Key('source_other_field'),
                  controller: _otherText,
                  focusNode: _otherFocus,
                  onChanged: _otherChanged,
                  textInputAction: TextInputAction.done,
                  cursorColor: c.leaf,
                  style: ObText.body(c.text, size: 16, weight: FontWeight.w500),
                  decoration: InputDecoration(
                    hintText: 'Tell us where, e.g. a podcast',
                    hintStyle: ObText.body(c.muted, size: 16, weight: FontWeight.w500),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
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

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = ObColors.of(context);
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: selected ? c.leaf.withValues(alpha: c.isDark ? 0.08 : 0.12) : c.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: selected ? c.leaf : c.line, width: 2),
          ),
          child: Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: ObText.title(c.text, size: 15)),
        ),
      ),
    );
  }
}
