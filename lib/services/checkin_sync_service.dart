import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'energy/checkin.dart';
import 'energy/estimate_rows.dart' show dayKey;
import 'storage_service.dart';

/// Keeps `goal_checkins` in step with the check-ins cached on the device.
///
/// One account's state is one Hive entry (`goal_checkins:<user id>`), so a
/// change to it is all-or-nothing:
/// - `rows`: every check-in, keyed by `week_start`;
/// - `pending`: what waits to upload (`{week: insert|seen}`). The local copy
///   wins until it uploads, as in [WeightSyncService]; the one exception is a
///   week another device checked in first, whose row replaces this device's
///   (the account has one row per week);
/// - `apply`: check-ins whose targets this device still has to apply and
///   confirm in `user_macros`, each with the targets it may replace. It's
///   written with the row, so a restart finishes an apply instead of deciding
///   again, and an adoption isn't lost when a later read fails.
///
/// Operations run one at a time, and after [clearLocalState] (logout) an
/// upload still in flight writes nothing back.
class CheckinSyncService {
  CheckinSyncService({String? userId}) : _userId = userId;

  static const String _table = 'goal_checkins';
  static const String _keyPrefix = 'goal_checkins:';
  // Before the state was per account (AG-13's first build).
  static const List<String> _legacyKeys = ['goal_checkins', 'pending_goal_checkins'];
  static const String _insert = 'insert';
  static const String _seen = 'seen';

  final String? _userId;
  bool _closed = false;
  Future<void> _tail = Future.value();

  SupabaseClient get _client => Supabase.instance.client;

  /// The account this device state belongs to.
  @visibleForTesting
  String? get userId => _userId;

  @visibleForTesting
  String? get stateKey => userId == null ? null : '$_keyPrefix$userId';

  // --- Device state ---

  _State _read() {
    final key = stateKey;
    final raw = key == null ? null : StorageService().get(key);
    if (raw is! String || raw.isEmpty) return _State();
    try {
      return _State.fromJson(jsonDecode(raw) as Map);
    } catch (e) {
      debugPrint('[CheckinSync] Unreadable cache, starting again: $e');
      return _State();
    }
  }

  Future<void> _write(_State state) async {
    final key = stateKey;
    if (key == null || _closed) return;
    await StorageService().put(key, jsonEncode(state.toJson()));
  }

  /// Runs [op] after every operation before it.
  Future<T> _locked<T>(Future<T> Function() op) {
    final result = _tail.then((_) => op());
    _tail = result.then((_) {}, onError: (_) {});
    return result;
  }

  /// Every cached check-in, keyed by `week_start`.
  Map<String, GoalCheckin> loadCache() => _read().rows;

  /// Weeks waiting to upload.
  Set<String> pendingWeeks() => _read().pending.keys.toSet();

  /// Weeks whose row hasn't reached the cloud yet.
  Set<String> pendingInserts() =>
      {for (final e in _read().pending.entries) if (e.value == _insert) e.key};

  /// Check-ins whose targets still need applying here or confirming in
  /// `user_macros`, with the targets each may replace.
  Map<String, List<CheckinTargets>> applyQueue() => _read().apply;

  /// Whether anything waits for the cloud.
  bool get hasWork {
    final s = _read();
    return s.pending.isNotEmpty || s.apply.isNotEmpty;
  }

  /// Records a new check-in on the device, to upload with [upload]. When it
  /// changes the targets, it's queued to apply in the same write (from
  /// [CheckinTargets] `oldTargets`), so the row and the change can't part.
  Future<void> stage(GoalCheckin checkin) => _locked(() async {
        final week = dayKey(checkin.weekStart);
        final s = _read();
        s.rows[week] = checkin;
        s.pending[week] = _insert;
        if (checkin.newTargets != checkin.oldTargets) s.apply[week] = [checkin.oldTargets];
        await _write(s);
      });

  /// The targets of [week]'s check-in are applied here and in `user_macros`
  /// (or no longer should be).
  Future<void> settleApply(String week) => _locked(() async {
        final s = _read();
        if (s.apply.remove(week) != null) await _write(s);
      });

  /// Records that the sheet for [weekStart] was dismissed at [at]. The
  /// first dismissal is the one kept.
  Future<GoalCheckin?> markSeen(DateTime weekStart, DateTime at) => _locked(() async {
        final week = dayKey(weekStart);
        final s = _read();
        final c = s.rows[week];
        if (c == null) return null;
        if (c.seenAt != null) return c;
        final seen = c.copyWith(seenAt: at);
        s.rows[week] = seen;
        // A queued insert carries seen_at with it.
        if (s.pending[week] != _insert) s.pending[week] = _seen;
        await _write(s);
        await _flush();
        return seen;
      });

  /// Uploads what's queued; failures stay queued.
  Future<void> upload() => _locked(() => _flush());

  /// Uploads what's queued, then pulls the account's check-ins and merges
  /// them into the cache. A newer check-in from another device is queued to
  /// apply here. Returns false when the cloud couldn't be reached.
  Future<bool> sync() => _locked(() async {
        if (userId == null) return false;
        try {
          await _flush(throwOnError: true);
          final cloud = await fetchRemote();
          if (_closed) return false;
          final s = _read();
          final known = s.rows.keys.toSet();
          for (final c in cloud) {
            final week = dayKey(c.weekStart);
            if (s.pending[week] == _insert) continue;
            final local = s.rows[week];
            // A dismissal still queued here outlives the cloud's null.
            s.rows[week] = local?.seenAt != null && c.seenAt == null
                ? c.copyWith(seenAt: local!.seenAt)
                : c;
          }
          // Another device's check-in, the latest: its targets apply here if
          // this device is still on the ones it started from.
          final latest = s.latestWeek;
          final row = latest == null ? null : s.rows[latest];
          if (row != null &&
              !known.contains(latest) &&
              row.newTargets != row.oldTargets &&
              !s.apply.containsKey(latest)) {
            s.apply[latest!] = [row.oldTargets];
          }
          await _write(s);
          return true;
        } catch (e) {
          debugPrint('[CheckinSync] Sync failed, keeping local check-ins: $e');
          return false;
        }
      });

  /// Uploads the queue, one week at a time, saving after each. A week
  /// another device stored first takes the cloud's row, and its targets are
  /// queued to apply (over this device's old or new ones).
  Future<void> _flush({bool throwOnError = false}) async {
    final uid = userId;
    if (uid == null) return;
    try {
      for (final week in _read().pending.keys.toList()) {
        if (_closed) return;
        final c = _read().rows[week];
        final kind = _read().pending[week];
        GoalCheckin? winner;
        if (c != null && kind == _insert) {
          winner = await insertRemote(c.toRemoteRow(uid));
          // The other device's sheet may not be dismissed yet; this one was.
          if (winner != null && winner.seenAt == null && c.seenAt != null) {
            await markSeenRemote(c.weekStart, c.seenAt!);
            winner = winner.copyWith(seenAt: c.seenAt);
          }
        } else if (c?.seenAt != null) {
          await markSeenRemote(c!.weekStart, c.seenAt!);
        }
        if (_closed) return;
        // Re-read: a dismissal may have been saved meanwhile.
        final s = _read();
        if (winner != null) {
          final mine = s.rows[week] ?? c!;
          s.rows[week] = winner.seenAt == null && mine.seenAt != null
              ? winner.copyWith(seenAt: mine.seenAt)
              : winner;
          if (winner.newTargets != mine.newTargets) {
            s.apply[week] = [mine.oldTargets, mine.newTargets];
          } else {
            s.apply.remove(week);
          }
        }
        s.pending.remove(week);
        await _write(s);
      }
    } catch (e) {
      debugPrint('[CheckinSync] Upload queued for retry: $e');
      if (throwOnError) rethrow;
    }
  }

  /// Inserts a row. Returns null when it's stored, or the account's existing
  /// row for that week when one is already there.
  @visibleForTesting
  Future<GoalCheckin?> insertRemote(Map<String, Object?> row) async {
    try {
      await _client.from(_table).insert(row).timeout(const Duration(seconds: 15));
      return null;
    } on PostgrestException catch (e) {
      if (e.code != '23505') rethrow; // unique_violation
      final existing = await _client
          .from(_table)
          .select()
          .eq('user_id', row['user_id'] as String)
          .eq('week_start', row['week_start'] as String)
          .single()
          .timeout(const Duration(seconds: 15));
      return GoalCheckin.fromJson(existing);
    }
  }

  @visibleForTesting
  Future<void> markSeenRemote(DateTime weekStart, DateTime at) => _client
      .from(_table)
      .update({'seen_at': at.toUtc().toIso8601String()})
      .eq('user_id', userId!)
      .eq('week_start', dayKey(weekStart))
      .isFilter('seen_at', null)
      .timeout(const Duration(seconds: 15));

  @visibleForTesting
  Future<List<GoalCheckin>> fetchRemote() async {
    final rows = await _client
        .from(_table)
        .select()
        .eq('user_id', userId!)
        .timeout(const Duration(seconds: 20));
    return [for (final r in rows) if (GoalCheckin.fromJson(r) case final c?) c];
  }

  /// Forgets this account's check-ins on the device (logout). An upload
  /// still in flight stops and saves nothing.
  Future<void> clearLocalState() async {
    _closed = true;
    final key = stateKey;
    if (key != null) await StorageService().delete(key);
    for (final k in _legacyKeys) {
      await StorageService().delete(k);
    }
  }
}

/// One account's check-in state on the device.
class _State {
  _State({Map<String, GoalCheckin>? rows, Map<String, String>? pending, Map<String, List<CheckinTargets>>? apply})
      : rows = rows ?? {},
        pending = pending ?? {},
        apply = apply ?? {};

  final Map<String, GoalCheckin> rows;
  final Map<String, String> pending;
  final Map<String, List<CheckinTargets>> apply;

  String? get latestWeek {
    String? out;
    for (final k in rows.keys) {
      if (out == null || k.compareTo(out) > 0) out = k;
    }
    return out;
  }

  factory _State.fromJson(Map json) => _State(
        rows: {
          for (final r in (json['rows'] as List? ?? const []))
            if (GoalCheckin.fromJson(r) case final c?) dayKey(c.weekStart): c,
        },
        pending: (json['pending'] as Map? ?? const {}).map((k, v) => MapEntry('$k', '$v')),
        apply: (json['apply'] as Map? ?? const {}).map((k, v) => MapEntry('$k', [
              for (final t in v as List)
                if (CheckinTargets.fromJson(t) case final targets?) targets,
            ])),
      );

  Map<String, Object?> toJson() {
    final sorted = rows.values.toList()..sort((a, b) => a.weekStart.compareTo(b.weekStart));
    return {
      'rows': [for (final c in sorted) c.toCacheJson()],
      'pending': pending,
      'apply': {
        for (final e in apply.entries) e.key: [for (final t in e.value) t.toJson()],
      },
    };
  }
}
