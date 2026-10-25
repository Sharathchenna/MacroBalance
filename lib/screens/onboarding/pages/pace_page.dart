import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:macrotracker/screens/onboarding/widgets/ob_widgets.dart';
import 'package:macrotracker/services/energy/constants.dart';
import 'package:macrotracker/services/energy/targets.dart';
import 'package:macrotracker/theme/ob_theme.dart';

/// One pace on offer: its target after the safety limits, and about how many
/// weeks it takes to reach the goal weight (null if it doesn't get there).
class PaceChoice {
  const PaceChoice({required this.target, this.weeks, this.date});

  final PaceTarget target;

  /// "About N weeks" to the goal, from the projection; null when it doesn't
  /// get there.
  final int? weeks;
  final DateTime? date;
}

/// Plain words for why a pace was slowed down, or null if it wasn't.
String? paceLimitExplanation(PaceTarget target) {
  final limit = target.limitHit;
  if (limit == null) return null;
  final pace = '${_pctText(target.effectivePacePct)}%/week';
  final cals = NumberFormat.decimalPattern().format(target.cals.round());
  return switch (limit) {
    SafetyLimit.floor => target.effectivePacePct < 0.05
        ? 'We\'ve kept your target at $cals cals, our minimum, so you may lose little weight at this activity level.'
        : 'We\'ve set your pace to $pace so your target doesn\'t go below $cals cals, our minimum.',
    SafetyLimit.maxDeficit =>
      'We\'ve set your pace to $pace so you eat no more than ${(kMaxDeficitFrac * 100).round()}% below what you burn.',
    SafetyLimit.maxLossPace =>
      'We\'ve set your pace to $pace, the fastest we recommend for losing weight.',
    SafetyLimit.maxSurplus =>
      'We\'ve set your pace to $pace so you eat no more than ${(kMaxSurplusFrac * 100).round()}% above what you burn.',
    SafetyLimit.maxGainPace =>
      'We\'ve set your pace to $pace, the fastest we recommend for gaining weight.',
    SafetyLimit.checkinStep => 'We\'ve changed your target gradually, to $cals cals.',
  };
}

/// 0.25 → "0.25", 0.5 → "0.5", 0.42 → "0.4", 1.0 → "1".
String _pctText(double pct) {
  final rounded = pct >= 0.2 ? (pct * 10).round() / 10 : (pct * 100).round() / 100;
  final options = [...kLosePaceOptions, ...kGainPaceOptions];
  final value = options.contains(pct) ? pct : rounded;
  return value == value.roundToDouble() ? value.toStringAsFixed(0) : value.toString();
}

/// Step: how fast to go (lose or gain only). Each row shows its real cals
/// after the safety limits; a capped pace explains itself underneath.
class PacePage extends StatelessWidget {
  final String goal;

  /// The paces on offer for the goal, slowest first.
  final List<PaceChoice> paceChoices;

  /// The chosen pace, % of body weight a week.
  final double pacePct;
  final double recommendedPacePct;
  final ValueChanged<double> onPaceChanged;

  /// Today's weight and the goal, for "0.4 kg a week" and "Reach 74 kg";
  /// without them the rows show only the percentage.
  final double? currentWeightKg;
  final double? goalWeightKg;
  final bool isMetricWeight;

  const PacePage({
    super.key,
    required this.goal,
    required this.paceChoices,
    required this.pacePct,
    required this.recommendedPacePct,
    required this.onPaceChanged,
    this.currentWeightKg,
    this.goalWeightKg,
    this.isMetricWeight = true,
  });

  String _weight(double kg, {int decimals = 0}) => isMetricWeight
      ? '${kg.toStringAsFixed(decimals)} kg'
      : '${(kg * 2.20462).toStringAsFixed(decimals)} lb';

  static const _names = ['Relaxed', 'Steady', 'Faster', 'Fastest'];

  PaceChoice? get _selected {
    for (final choice in paceChoices) {
      if (choice.target.pacePct == pacePct) return choice;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final c = ObColors.of(context);
    final selected = _selected;
    final date = selected?.date;
    final explanation = selected == null ? null : paceLimitExplanation(selected.target);
    return ObPageBody(
      children: [
        ObHeader(
          eyebrow: 'Your pace',
          title: 'How fast do you want to go?',
          subtitle: date == null
              ? 'You can change this any time.'
              : '${goalWeightKg == null ? 'You’d reach your goal' : 'Reach ${_weight(goalWeightKg!)}'}'
                  ' around ${DateFormat('MMM d').format(date)}. '
                  'You can change this any time.',
        ),
        const SizedBox(height: 28),
        ObRise(
          index: 2,
          child: Column(
            children: [
              for (var i = 0; i < paceChoices.length; i++) ...[
                if (i > 0) const SizedBox(height: 10),
                _row(c, i, paceChoices[i]),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        if (explanation != null)
          _LimitNote(text: explanation)
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              'We never set a target below what’s safe. If a pace is too fast, we slow it down and tell you why.',
              style: ObText.body(c.muted, size: 13),
            ),
          ),
      ],
    );
  }

  Widget _row(ObColors c, int i, PaceChoice choice) {
    final target = choice.target;
    final on = target.pacePct == pacePct;
    final weeks = choice.weeks;
    // "0.5% a week · about 0.4 kg" when today's weight is known (the date for
    // the chosen pace is in the subtitle), else the weeks to the goal.
    final rate = currentWeightKg != null
        ? '${_pctText(target.pacePct)}% a week · about '
            '${_weight(currentWeightKg! * target.effectivePacePct / 100, decimals: 1)}'
        : '${_pctText(target.pacePct)}% a week'
            '${weeks == null ? '' : ' · about $weeks ${weeks == 1 ? 'week' : 'weeks'}'}';
    return ObOptionTile(
      key: Key('pace_option_${target.pacePct}'),
      title: _names[i.clamp(0, _names.length - 1)],
      subtitle: rate,
      badge: target.pacePct == recommendedPacePct ? 'Recommended' : null,
      selected: on,
      onTap: () => onPaceChanged(target.pacePct),
      leading: ObIconTile(
        size: 40,
        child: CustomPaint(
          size: const Size(26, 14),
          painter: _ChevronsPainter(
            lit: i + 1,
            on: on,
            litColor: on ? c.leaf : c.text2,
            offColor: c.line,
          ),
        ),
      ),
      trailing: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(NumberFormat.decimalPattern().format(target.cals.round()),
              style: ObText.title(c.text)),
          const SizedBox(height: 4),
          Text('cals a day', style: ObText.body(c.text2, size: 12)),
        ],
      ),
    );
  }
}

/// Four chevrons, the first [lit] of them lit.
class _ChevronsPainter extends CustomPainter {
  _ChevronsPainter({required this.lit, required this.on, required this.litColor, required this.offColor});

  final int lit;
  final bool on;
  final Color litColor;
  final Color offColor;

  @override
  void paint(Canvas canvas, Size size) {
    for (var k = 0; k < 4; k++) {
      final x = 2.0 + k * 6;
      final path = Path()
        ..moveTo(x, 2)
        ..lineTo(x + 5, 7)
        ..lineTo(x, 12);
      canvas.drawPath(
        path,
        Paint()
          ..color = k < lit ? litColor : offColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }
  }

  @override
  bool shouldRepaint(_ChevronsPainter old) =>
      old.lit != lit || old.litColor != litColor || old.offColor != offColor;
}

/// The orange note under the rows when the chosen pace was slowed down.
class _LimitNote extends StatelessWidget {
  const _LimitNote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final c = ObColors.of(context);
    return TweenAnimationBuilder<double>(
      key: ValueKey(text),
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, -6 * (1 - t)), child: child),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: c.fat.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Icon(Icons.shield_outlined, size: 18, color: c.fat),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(text, style: ObText.body(c.text2, size: 14))),
          ],
        ),
      ),
    );
  }
}
