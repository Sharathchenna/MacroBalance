import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:macrotracker/providers/weight_unit_provider.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:macrotracker/auth/auth_actions.dart';
import 'package:macrotracker/providers/goals_provider.dart';
import 'package:macrotracker/screens/onboarding/widgets/ob_widgets.dart';
import 'package:macrotracker/services/storage_service.dart';
import 'package:macrotracker/theme/ob_theme.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Which plan the account goes on with, once signed in on the [SaveScreen].
enum SavedPlan {
  /// The plan just made: it still has to be saved to the account.
  newPlan,

  /// The account's existing plan, now on this device in place of the new one.
  accountPlan,
}

/// "Save your plan" (docs/onboarding-redesign/mock/Save.dc.html): account
/// creation after the plan reveal. Apple, Google or email, plus a log-in mode
/// for people who already have an account. Pops a [SavedPlan] once signed
/// in, null if the user goes back.
class SaveScreen extends StatefulWidget {
  const SaveScreen({super.key});

  /// Puts the account's plan on this device. The new plan's device copy
  /// goes first: `nutrition_goals` wins over the account cache in
  /// [GoalsProvider.load], and would otherwise be synced over the account's.
  @visibleForTesting
  static Future<void> keepAccountPlan(Map<String, dynamic> row) async {
    final storage = StorageService();
    await storage.delete('nutrition_goals');
    await storage.delete('macro_results');
    await GoalsProvider.cacheUserMacros(row);
  }

  @override
  State<SaveScreen> createState() => _SaveScreenState();
}

class _SaveScreenState extends State<SaveScreen> {
  bool _logIn = false;
  bool _emailOpen = false;
  bool _busy = false;
  bool _showPassword = false;
  String? _error;
  String? _info;

  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();

  Map<String, dynamic>? _plan;

  @override
  void initState() {
    super.initState();
    try {
      final raw = StorageService().get('macro_results');
      final data = raw is String ? jsonDecode(raw) : raw;
      if (data is Map && data['target_calories'] != null) {
        _plan = Map<String, dynamic>.from(data);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _setMode(bool logIn) => setState(() {
        _logIn = logIn;
        _error = null;
        _info = null;
        if (logIn) _emailOpen = false;
      });

  Future<void> _run(Future<AuthResult> Function() action, String failure) async {
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });
    final result = await action();
    if (!mounted) return;
    switch (result.outcome) {
      case AuthOutcome.signedIn:
        await _finish();
      case AuthOutcome.needsConfirmation:
        setState(() {
          _busy = false;
          _info = 'Almost there. Check your email to confirm your account, '
              'then come back and log in.';
        });
      case AuthOutcome.cancelled:
        setState(() => _busy = false);
      case AuthOutcome.failed:
        setState(() {
          _busy = false;
          _error = failure.isEmpty ? (result.message ?? 'Something went wrong') : failure;
        });
    }
  }

  Future<void> _emailSubmit() async {
    final email = _email.text.trim();
    final password = _password.text;
    if (_logIn) {
      if (email.isEmpty || password.isEmpty) {
        setState(() => _error = 'Enter your email and password.');
        return;
      }
      await _run(() => AuthActions.signInWithEmail(email: email, password: password), '');
      return;
    }
    if (_name.text.trim().isEmpty || email.isEmpty || password.isEmpty) {
      setState(() => _error = 'Fill in your name, email and a password.');
      return;
    }
    await _run(
        () => AuthActions.signUpWithEmail(
            name: _name.text.trim(), email: email, password: password),
        '');
  }

  /// Signed in. If the account already has a plan, the user picks which one
  /// to keep; otherwise the new plan is the account's.
  Future<void> _finish() async {
    Map<String, dynamic>? saved;
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        final row = await Supabase.instance.client
            .from('user_macros')
            .select()
            .eq('id', user.id)
            .maybeSingle();
        if (row != null && row['calories_goal'] != null) saved = row;
      }
    } catch (e) {
      debugPrint('[Save] Could not check for a saved plan: $e');
    }
    if (!mounted) return;
    var result = SavedPlan.newPlan;
    if (saved != null) {
      final keep = await _askWhichPlan(saved);
      if (!mounted) return;
      if (keep == true) {
        await SaveScreen.keepAccountPlan(saved);
        if (!mounted) return;
        await context.read<GoalsProvider>().load();
        result = SavedPlan.accountPlan;
      }
    }
    if (!mounted) return;
    Navigator.of(context).pop(result);
  }

  Future<bool?> _askWhichPlan(Map<String, dynamic> saved) {
    final c = ObColors.of(context);
    final cals = NumberFormat('#,###').format((saved['calories_goal'] as num).round());
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: c.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('You already have a plan', style: ObText.title(c.text, size: 20)),
        content: Text(
          'This account has a saved plan of $cals cals a day. Keep it, or use '
          'the plan you just made?',
          style: ObText.body(c.text2),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Keep your saved plan',
                style: ObText.body(c.leafText, weight: FontWeight.w600)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Use this new plan',
                style: ObText.body(c.text, weight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = ObColors.of(context);
    final showForm = _emailOpen || _logIn;
    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => FocusScope.of(context).unfocus(),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 18, 24, 20),
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: ObBackButton(
                      onPressed: _busy ? null : () => Navigator.of(context).pop()),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.only(top: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_plan != null && !showForm) ...[
                          Center(child: _PlanCard(plan: _plan!)),
                          const SizedBox(height: 30),
                        ],
                        ObRise(
                          index: 1,
                          child: Text(
                            _logIn ? 'Welcome back' : 'Save your plan',
                            textAlign: TextAlign.center,
                            style: ObText.h1(c.text),
                          ),
                        ),
                        ObRise(
                          index: 2,
                          child: Padding(
                            padding: const EdgeInsets.only(top: 10, bottom: 24),
                            child: Text(
                              _logIn
                                  ? 'Log in to bring your account and its history into this plan.'
                                  : 'Create a free account to keep your plan, logs and progress in sync on every device.',
                              textAlign: TextAlign.center,
                              style: ObText.body(c.text2),
                            ),
                          ),
                        ),
                        if (showForm) ..._form(c),
                        if (_error != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Text(_error!,
                                key: const Key('save_error'),
                                textAlign: TextAlign.center,
                                style: ObText.body(c.protein, size: 14)),
                          ),
                        if (_info != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Text(_info!,
                                key: const Key('save_info'),
                                textAlign: TextAlign.center,
                                style: ObText.body(c.leafText, size: 14)),
                          ),
                        const SizedBox(height: 16),
                        ObRise(
                          index: 2,
                          child: ObSecondaryButton(
                            label: 'Continue with Apple',
                            inverted: true,
                            onPressed: _busy
                                ? null
                                : () => _run(AuthActions.signInWithApple,
                                    'There was a problem signing in with Apple'),
                            icon: Icon(Icons.apple, size: 22, color: c.bg),
                          ),
                        ),
                        const SizedBox(height: 10),
                        ObRise(
                          index: 3,
                          child: _OutlinedAuth(
                            label: 'Continue with Google',
                            onPressed: _busy
                                ? null
                                : () => _run(AuthActions.signInWithGoogle,
                                    'There was a problem signing in with Google'),
                            icon: SvgPicture.asset('assets/icons/Google.svg',
                                width: 18, height: 18),
                          ),
                        ),
                        if (!_logIn && !_emailOpen) ...[
                          const SizedBox(height: 10),
                          ObRise(
                            index: 4,
                            child: _OutlinedAuth(
                              label: 'Continue with email',
                              borderless: true,
                              onPressed: _busy
                                  ? null
                                  : () => setState(() {
                                        _emailOpen = true;
                                        _error = null;
                                      }),
                              icon: Icon(Icons.mail_outline_rounded,
                                  size: 20, color: c.text),
                            ),
                          ),
                        ],
                        const SizedBox(height: 10),
                        Center(
                          child: TextButton(
                            onPressed: _busy ? null : () => _setMode(!_logIn),
                            child: Text.rich(
                              TextSpan(children: [
                                TextSpan(
                                    text: _logIn
                                        ? 'New here? '
                                        : 'Already have an account? ',
                                    style: ObText.body(c.text2, size: 14)),
                                TextSpan(
                                    text: _logIn ? 'Create an account' : 'Log in',
                                    style: ObText.body(c.leafText,
                                        size: 14, weight: FontWeight.w600)),
                              ]),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            'By continuing you agree to our Terms and Privacy Policy.',
                            textAlign: TextAlign.center,
                            style: ObText.body(c.muted, size: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _form(ObColors c) => [
        if (!_logIn) ...[
          _Field(
              fieldKey: const Key('save_name'),
              controller: _name,
              hint: 'Your name',
              icon: Icons.person_outline_rounded),
          const SizedBox(height: 10),
        ],
        _Field(
            fieldKey: const Key('save_email'),
            controller: _email,
            hint: 'Email',
            icon: Icons.mail_outline_rounded,
            keyboard: TextInputType.emailAddress),
        const SizedBox(height: 10),
        _Field(
          fieldKey: const Key('save_password'),
          controller: _password,
          hint: _logIn ? 'Password' : 'Create a password',
          icon: Icons.lock_outline_rounded,
          obscure: !_showPassword,
          trailing: IconButton(
            icon: Icon(
                _showPassword ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                size: 20,
                color: c.muted),
            onPressed: () => setState(() => _showPassword = !_showPassword),
          ),
        ),
        const SizedBox(height: 14),
        ObPrimaryButton(
          label: _logIn ? 'Log in' : 'Create account',
          loading: _busy,
          onPressed: _busy ? null : _emailSubmit,
        ),
        const SizedBox(height: 4),
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Text('or', style: ObText.body(c.muted, size: 13)),
          ),
        ),
      ];
}

class _Field extends StatelessWidget {
  const _Field({
    required this.fieldKey,
    required this.controller,
    required this.hint,
    required this.icon,
    this.obscure = false,
    this.keyboard,
    this.trailing,
  });

  final Key fieldKey;
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool obscure;
  final TextInputType? keyboard;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final c = ObColors.of(context);
    return Container(
      height: 56,
      padding: const EdgeInsets.only(left: 16, right: 4),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.line),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: c.muted),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              key: fieldKey,
              controller: controller,
              obscureText: obscure,
              keyboardType: keyboard,
              autocorrect: false,
              cursorColor: c.leaf,
              style: ObText.body(c.text, size: 16),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: ObText.body(c.muted, size: 16),
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
          if (trailing != null) trailing! else const SizedBox(width: 12),
        ],
      ),
    );
  }
}

class _OutlinedAuth extends StatelessWidget {
  const _OutlinedAuth(
      {required this.label, required this.onPressed, required this.icon, this.borderless = false});

  final String label;
  final VoidCallback? onPressed;
  final Widget icon;
  final bool borderless;

  @override
  Widget build(BuildContext context) {
    final c = ObColors.of(context);
    return Material(
      color: borderless ? Colors.transparent : c.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: borderless ? BorderSide.none : BorderSide(color: c.line),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onPressed,
        child: SizedBox(
          height: 56,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              icon,
              const SizedBox(width: 10),
              Text(label,
                  style: ObText.body(c.text, size: 16, weight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}

/// The small plan card at the top: macro ring, cals and the goal line.
class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.plan});

  final Map<String, dynamic> plan;

  @override
  Widget build(BuildContext context) {
    final c = ObColors.of(context);
    double n(String k) => (plan[k] as num?)?.toDouble() ?? 0;
    final stats = plan['weight_stats'] as Map? ?? const {};
    final goalKg = (stats['goal_weight'] as num?)?.toDouble();
    final date = DateTime.tryParse('${stats['goal_date']}');
    final kc = [n('protein_g') * 4, n('carb_g') * 4, n('fat_g') * 9];
    final parts = <String>[
      if (goalKg != null)
        context.read<WeightUnitProvider>().isMetric
            ? 'Goal ${goalKg.toStringAsFixed(goalKg % 1 == 0 ? 0 : 1)} kg'
            : 'Goal ${(goalKg * 2.20462).round()} lb',
      if (date != null) DateFormat('MMM d').format(date),
      'Check-ins ${DateFormat('EEE').format(DateTime.now())}',
    ];
    return Transform.rotate(
      angle: -0.035,
      child: Container(
        width: 300,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: c.line),
        ),
        child: Column(
          children: [
            Row(
              children: [
                SizedBox(
                  width: 64,
                  height: 64,
                  child: CustomPaint(
                    painter: _DonutPainter(
                        values: kc,
                        colors: [c.protein, c.carbs, c.fat],
                        track: c.raised),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(NumberFormat('#,###').format(n('target_calories').round()),
                          style: ObText.display(26, color: c.text, height: 1)),
                      const SizedBox(height: 4),
                      Text('cals a day', style: ObText.body(c.text2, size: 13)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (final p in parts)
                  Flexible(
                    child: Text(p,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: ObText.body(c.text2, size: 12)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter({required this.values, required this.colors, required this.track});

  final List<double> values;
  final List<Color> colors;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromCircle(center: size.center(Offset.zero), radius: 26);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(rect.center, 26, paint..color = track);
    final total = values.fold<double>(0, (a, b) => a + b);
    if (total <= 0) return;
    const gap = 0.35;
    var start = -1.5708;
    for (var i = 0; i < values.length; i++) {
      final sweep = values[i] / total * 6.2832;
      final draw = (sweep - gap).clamp(0.05, 7.0);
      canvas.drawArc(rect, start, draw, false, paint..color = colors[i]);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) => old.values != values;
}
