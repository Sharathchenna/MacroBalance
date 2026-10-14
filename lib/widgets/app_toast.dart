import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../main.dart' show navigatorKey;
import '../theme/typography.dart';

/// Short confirmations ("Added Oats to Breakfast") and in-app notices ("Your
/// lunch is ready") that drop in from the top of the screen and leave on
/// their own. They live in the root overlay, so they stay put across page
/// pops and never collide with the bottom bar or a page's bottom buttons.
/// Swipe up or tap the close area to dismiss early.
class AppToast {
  AppToast._();

  static OverlayEntry? _entry;
  static GlobalKey<_ToastHostState>? _hostKey;

  /// A one-line confirmation, with an optional action such as Undo.
  /// [context] finds the overlay when the app's navigator isn't available
  /// (tests); otherwise the root navigator's overlay is used.
  static void show(
    String message, {
    BuildContext? context,
    IconData icon = Icons.check_circle_rounded,
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = const Duration(milliseconds: 2500),
  }) {
    _present(
      context: context,
      duration: duration,
      builder: (context, dismiss) => _ToastBody(
        leading: Icon(icon, size: 20, color: const Color(0xFFFFC107)),
        title: message,
        actionLabel: actionLabel,
        onAction: onAction == null
            ? null
            : () {
                dismiss();
                onAction();
              },
      ),
    );
  }

  /// A richer notice with a thumbnail and subtitle; tapping it runs [onTap].
  static void showNotice({
    BuildContext? context,
    required String title,
    String? subtitle,
    Widget? leading,
    String? actionLabel,
    VoidCallback? onTap,
    Duration duration = const Duration(seconds: 5),
  }) {
    _present(
      context: context,
      duration: duration,
      builder: (context, dismiss) => _ToastBody(
        leading: leading,
        title: title,
        subtitle: subtitle,
        actionLabel: actionLabel,
        onAction: onTap == null
            ? null
            : () {
                dismiss();
                onTap();
              },
        onTap: onTap == null
            ? null
            : () {
                dismiss();
                onTap();
              },
      ),
    );
  }

  static void _present({
    BuildContext? context,
    required Duration duration,
    required Widget Function(BuildContext context, VoidCallback dismiss)
        builder,
  }) {
    final overlay = navigatorKey.currentState?.overlay ??
        (context != null && context.mounted
            ? Overlay.maybeOf(context, rootOverlay: true)
            : null);
    if (overlay == null) return;
    _removeNow();
    final key = GlobalKey<_ToastHostState>();
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => _ToastHost(
        key: key,
        duration: duration,
        builder: builder,
        onGone: () {
          if (_entry == entry) {
            _entry = null;
            _hostKey = null;
          }
          if (entry.mounted) entry.remove();
        },
      ),
    );
    _entry = entry;
    _hostKey = key;
    overlay.insert(entry);
  }

  /// Hides whatever toast is showing, animating it out.
  static void dismiss() => _hostKey?.currentState?._dismiss();

  static void _removeNow() {
    // An entry whose overlay was torn down (a disposed tree) is already gone.
    if (_entry?.mounted ?? false) _entry!.remove();
    _entry = null;
    _hostKey = null;
  }
}

class _ToastHost extends StatefulWidget {
  const _ToastHost({
    super.key,
    required this.duration,
    required this.builder,
    required this.onGone,
  });

  final Duration duration;
  final Widget Function(BuildContext context, VoidCallback dismiss) builder;
  final VoidCallback onGone;

  @override
  State<_ToastHost> createState() => _ToastHostState();
}

class _ToastHostState extends State<_ToastHost>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 280),
    reverseDuration: const Duration(milliseconds: 200),
  );
  Timer? _timer;
  double _dragOffset = 0;
  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    _controller.forward();
    _timer = Timer(widget.duration, _dismiss);
  }

  Future<void> _dismiss() async {
    if (_leaving || !mounted) return;
    _leaving = true;
    _timer?.cancel();
    await _controller.reverse();
    widget.onGone();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top + 8;
    final curve = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    return Positioned(
      top: top,
      left: 16,
      right: 16,
      child: AnimatedBuilder(
        animation: curve,
        builder: (context, child) => Transform.translate(
          offset: Offset(0, _dragOffset - (1 - curve.value) * (top + 80)),
          child: Opacity(opacity: curve.value.clamp(0.0, 1.0), child: child),
        ),
        child: GestureDetector(
          onVerticalDragUpdate: (d) {
            // Only follow upward drags; a little give downwards.
            setState(() =>
                _dragOffset = (_dragOffset + d.delta.dy).clamp(-200.0, 8.0));
          },
          onVerticalDragEnd: (d) {
            if (_dragOffset < -20 || (d.primaryVelocity ?? 0) < -300) {
              HapticFeedback.selectionClick();
              _dismiss();
            } else {
              setState(() => _dragOffset = 0);
            }
          },
          child: widget.builder(context, _dismiss),
        ),
      ),
    );
  }
}

class _ToastBody extends StatelessWidget {
  const _ToastBody({
    required this.title,
    this.subtitle,
    this.leading,
    this.actionLabel,
    this.onAction,
    this.onTap,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final String? actionLabel;
  final VoidCallback? onAction;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final background =
        isLight ? const Color(0xFF1F1F1F) : const Color(0xFF2C2C2E);
    const foreground = Colors.white;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          padding:
              EdgeInsets.fromLTRB(14, 10, actionLabel == null ? 14 : 6, 10),
          child: Row(
            children: [
              if (leading != null) ...[leading!, const SizedBox(width: 10)],
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: subtitle == null ? 2 : 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.body2.copyWith(
                        color: foreground,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.caption
                            .copyWith(color: Colors.white70),
                      ),
                  ],
                ),
              ),
              if (actionLabel != null)
                TextButton(
                  onPressed: onAction,
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFFFC107),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    minimumSize: const Size(0, 36),
                  ),
                  child: Text(actionLabel!,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
