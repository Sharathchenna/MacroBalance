import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../providers/energy_provider.dart';
import '../../services/checkin_notifier.dart';
import '../../services/energy/constants.dart';
import '../../services/energy/energy_estimator.dart';
import '../../services/energy/estimate_rows.dart';
import '../../theme/app_theme.dart';
import '../../widgets/progress_card.dart';

/// Developer-only view of the expenditure estimator running in shadow mode:
/// the latest estimate, the filter state, the latest window and every stored
/// row. Reached from the account screen's Developer section.
class EnergyDebugScreen extends StatelessWidget {
  const EnergyDebugScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<CustomColors>()!;
    final energy = context.watch<EnergyProvider>();
    final latest = energy.latest;
    final rows = energy.estimates.reversed.toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Energy estimates',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: colors.textPrimary,
          ),
        ),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: theme.brightness == Brightness.light
            ? SystemUiOverlayStyle.dark
            : SystemUiOverlayStyle.light,
        iconTheme: IconThemeData(color: colors.textPrimary),
        actions: [
          IconButton(
            tooltip: 'Recompute',
            onPressed: energy.isRefreshing ? null : energy.refresh,
            icon: energy.isRefreshing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            _Headline(latest: latest),
            const SizedBox(height: 12),
            _StateCard(energy: energy),
            if (latest != null) ...[
              const SizedBox(height: 12),
              _WindowCard(row: latest),
            ],
            const SizedBox(height: 12),
            _RowsCard(rows: rows),
          ],
        ),
      ),
    );
  }
}

final _day = DateFormat('EEE d MMM');
final _time = DateFormat('HH:mm:ss');

String _when(DateTime? t) => t == null ? 'none' : DateFormat('EEE MMM d, HH:mm').format(t);

String _n(num? v, {int places = 0}) =>
    v == null ? '—' : NumberFormat.decimalPatternDigits(decimalDigits: places).format(v);

String _d(DateTime? d) => d == null ? '—' : _day.format(d);

class _Headline extends StatelessWidget {
  const _Headline({required this.latest});

  final EnergyEstimate? latest;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<CustomColors>()!;
    final row = latest;
    return ProgressCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            row == null ? 'No estimates yet' : 'Estimate for ${_d(row.day)}',
            style: GoogleFonts.inter(fontSize: 13, color: colors.textSecondary),
          ),
          const SizedBox(height: 6),
          if (row == null)
            Text(
              'Rows start the day after learning starts.',
              style: GoogleFonts.inter(fontSize: 15, color: colors.textPrimary),
            )
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  '${_n(row.tdee)} cals',
                  style: GoogleFonts.inter(
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '± ${_n(row.tdeeSd)}',
                  style: GoogleFonts.inter(fontSize: 15, color: colors.textSecondary),
                ),
                const Spacer(),
                _StatePill(state: row.state),
              ],
            ),
        ],
      ),
    );
  }
}

class _StatePill extends StatelessWidget {
  const _StatePill({required this.state});

  final EnergyState state;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<CustomColors>()!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: colors.accentPrimary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        state.code,
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: colors.textPrimary,
        ),
      ),
    );
  }
}

/// A label on the left, a value on the right.
class _Line extends StatelessWidget {
  const _Line(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<CustomColors>()!;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: GoogleFonts.inter(fontSize: 14, color: colors.textSecondary)),
          ),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: colors.textPrimary,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _StateCard extends StatelessWidget {
  const _StateCard({required this.energy});

  final EnergyProvider energy;

  @override
  Widget build(BuildContext context) {
    final inputs = energy.lastInputs;
    final latest = energy.latest;
    final took = energy.lastRunTook;
    return ProgressCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ProgressCardTitle('State'),
          const SizedBox(height: 8),
          _Line('Learning started', _d(inputs?.learningStartedOn)),
          _Line('Formula TDEE (prior)', '${_n(inputs?.formulaTdee)} cals'),
          _Line('Variance', _n(latest == null ? null : latest.tdeeSd * latest.tdeeSd)),
          _Line('SD (confident ≤ ${_n(kConfidentSd)})', _n(latest?.tdeeSd, places: 1)),
          _Line('Last update', _d(latest?.lastUpdateDay)),
          _Line('Algorithm version', '${latest?.algoVersion ?? algoVersion}'),
          _Line('Days stored', '${energy.estimates.length} (keeps $kEstimateCacheDays)'),
          _Line('Waiting to upload', '${energy.pendingUploads}'),
          _Line(
            'Last run',
            energy.lastRunAt == null
                ? '—'
                : '${_time.format(energy.lastRunAt!)}'
                    '${took == null ? '' : ' · ${took.inMilliseconds} ms'}',
          ),
          if (energy.lastError != null) _Line('Error', energy.lastError!),
          _Line('Check-in notification', _when(energy.checkinNotificationTime)),
          FutureBuilder<bool>(
            future: CheckinNotifier.device.isPending().catchError((_) => false),
            builder: (context, pending) => _Line(
              'Scheduled on device',
              pending.data == null
                  ? '…'
                  : pending.data!
                      ? _when(CheckinNotifier.device.scheduledFor)
                      : 'no',
            ),
          ),
        ],
      ),
    );
  }
}

class _WindowCard extends StatelessWidget {
  const _WindowCard({required this.row});

  final EnergyEstimate row;

  @override
  Widget build(BuildContext context) {
    final slope = row.slopeKgPerDay;
    final ed = row.energyDensity;
    return ProgressCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ProgressCardTitle('Window to ${_d(row.day)}'),
          const SizedBox(height: 8),
          _Line('Updated the estimate', row.updated ? 'yes' : 'no (gate closed)'),
          _Line('Complete or fasting days', '${row.completeDays} (needs $kMinCompleteDays)'),
          _Line('Weigh-ins used', '${row.weighIns} (needs $kMinWeighIns)'),
          _Line('Avg intake', '${_n(row.avgIntake)} cals'),
          _Line('Trend weight', '${_n(row.trendWeightKg, places: 2)} kg'),
          _Line('Slope', slope == null ? '—' : '${_n(slope * 7, places: 3)} kg/wk'),
          _Line('Energy density', '${_n(ed)} cals/kg'),
          _Line('Slope × ED',
              slope == null || ed == null ? '—' : '${_n(slope * ed)} cals/day'),
          _Line('Observed TDEE', '${_n(row.observedTdee)} cals'),
        ],
      ),
    );
  }
}

class _RowsCard extends StatelessWidget {
  const _RowsCard({required this.rows});

  /// Newest first.
  final List<EnergyEstimate> rows;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<CustomColors>()!;
    TextStyle cell(Color c, {FontWeight w = FontWeight.w400}) => GoogleFonts.inter(
          fontSize: 12,
          fontWeight: w,
          color: c,
          fontFeatures: const [FontFeature.tabularFigures()],
        );
    final header = cell(colors.textSecondary, w: FontWeight.w600);
    const widths = [64.0, 50.0, 40.0, 72.0, 28.0, 28.0, 32.0];
    Widget line(List<String> values, TextStyle style) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            children: [
              for (var i = 0; i < values.length; i++)
                SizedBox(
                  width: widths[i],
                  child: Text(values[i],
                      style: style,
                      textAlign: i == 0 || i == 3 ? TextAlign.left : TextAlign.right),
                ),
            ],
          ),
        );
    final shown = rows.take(math.min(rows.length, 120)).toList();
    return ProgressCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ProgressCardTitle('Rows (${rows.length})'),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                line(['Day', 'TDEE', '±SD', ' State', 'C', 'W', 'Upd'], header),
                for (final r in shown)
                  line([
                    dayKey(r.day).substring(5),
                    _n(r.tdee),
                    _n(r.tdeeSd),
                    ' ${r.state.code}',
                    '${r.completeDays}',
                    '${r.weighIns}',
                    r.updated ? '✓' : '',
                  ], cell(colors.textPrimary)),
              ],
            ),
          ),
          if (rows.length > shown.length)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('Showing the newest ${shown.length}.',
                  style: cell(colors.textSecondary)),
            ),
        ],
      ),
    );
  }
}
