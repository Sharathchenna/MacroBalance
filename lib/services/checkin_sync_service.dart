import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'energy/checkin.dart';
import 'energy/estimate_rows.dart' show dayKey;
import 'storage_service.dart';

/// Keeps `goal_checkins` in step with the check-ins cached on the device.
///
/// The cache (Hive `goal_checkins`) holds every check-in. Changes wait in a
/// queue (`pending_goal_checkins`, `{week: insert|seen}`) until they upload,
/// and the local copy wins until then, the same way [WeightSyncService]
/// works. The one exception is a week another device checked in first: the
/// account has one row per week, so the cloud's row replaces this device's.
class CheckinSyncService {
  CheckinSyncService();

  static const String _table = 'goal_checkins';
  static const String _cacheKey = 'goal_checkins';
  static const String _pendingKey = 'pending_goal_checkins';
  static const String _insert = 'insert';
  static const String _seen = 'seen';

  SupabaseClient get _client => Supabase.instance.client;

  @visibleForTesting
  String? get userId => _client.auth.currentUser?.id;

  /// Every cached check-in, keyed by `week_start`.
  Map<String, GoalCheckin> loadCache() {
    final raw = StorageService().get(_cacheKey);
    if (raw is! String || raw.isEmpty) return {};
    try {
      return {
        for (final json in jsonDecode(raw) as List)
          if (GoalCheckin.fromJson(json) case final c?) dayKey(c.weekStart): c,
      };
    } catch (e) {
      debugPrint('[CheckinSync] Unreadable cache, starting again: $e');
      return {};
    }
  }

  Future<void> _writeCache(Map<String, GoalCheckin> rows) {
    final sorted = rows.values.toList()..sort((a, b) => a.weekStart.compareTo(b.weekStart));
    return StorageService()
        .put(_cacheKey, jsonEncode([for (final c in sorted) c.toCacheJson()]));
  }

  Map<String, String> _pending() {
    final raw = StorageService().get(_pendingKey);
    if (raw is! String || raw.isEmpty) return {};
    try {
      return (jsonDecode(raw) as Map).map((k, v) => MapEntry('$k', '$v'));
    } catch (_) {
      return {};
    }
  }

  Future<void> _writePending(Map<String, String> pending) =>
      StorageService().put(_pendingKey, jsonEncode(pending));

  /// Weeks waiting to upload.
  Set<String> pendingWeeks() => _pending().keys.toSet();

  /// Stores a new check-in on the device, then uploads it. Returns the row
  /// the account has for that week: [checkin], or the one another device
  /// stored first. Offline, it stays queued and [checkin] is returned.
  Future<GoalCheckin> add(GoalCheckin checkin) async {
    final week = dayKey(checkin.weekStart);
    await _writeCache(loadCache()..[week] = checkin);
    await _writePending(_pending()..[week] = _insert);
    final adopted = await _flush();
    return adopted[week] ?? checkin;
  }

  /// Records that the sheet for [weekStart] was dismissed at [at]. The
  /// first dismissal is the one kept.
  Future<GoalCheckin?> markSeen(DateTime weekStart, DateTime at) async {
    final week = dayKey(weekStart);
    final cache = loadCache();
    final c = cache[week];
    if (c == null) return null;
    if (c.seenAt != null) return c;
    final seen = c.copyWith(seenAt: at);
    await _writeCache(cache..[week] = seen);
    final pending = _pending();
    // A queued insert carries seen_at with it.
    if (pending[week] != _insert) await _writePending(pending..[week] = _seen);
    await _flush();
    return seen;
  }

  /// Uploads what's queued, then pulls the account's check-ins and merges
  /// them into the cache. Returns the merged rows and the weeks another
  /// device had already checked in (whose rows replaced this device's), or
  /// null when the cloud couldn't be reached.
  Future<CheckinSyncResult?> sync() async {
    if (userId == null) return null;
    try {
      final adopted = await _flush(throwOnError: true);
      final cloud = await fetchRemote();
      final cache = loadCache();
      final pending = _pending();
      for (final c in cloud) {
        final week = dayKey(c.weekStart);
        final local = cache[week];
        if (pending[week] == _insert) continue;
        // A dismissal still queued here outlives the cloud's null.
        cache[week] = local?.seenAt != null && c.seenAt == null
            ? c.copyWith(seenAt: local!.seenAt)
            : c;
      }
      await _writeCache(cache);
      return CheckinSyncResult(cache, adopted);
    } catch (e) {
      debugPrint('[CheckinSync] Sync failed, keeping local check-ins: $e');
      return null;
    }
  }

  /// Uploads the queue. Returns the cloud rows that won a week this device
  /// also checked in (already in the cache). Failures stay queued.
  Future<Map<String, GoalCheckin>> _flush({bool throwOnError = false}) async {
    final adopted = <String, GoalCheckin>{};
    final uid = userId;
    final pending = _pending();
    if (uid == null || pending.isEmpty) return adopted;
    final cache = loadCache();
    try {
      for (final e in pending.entries.toList()) {
        final c = cache[e.key];
        if (c != null) {
          if (e.value == _insert) {
            final winner = await insertRemote(c.toRemoteRow(uid));
            if (winner != null) {
              cache[e.key] = winner.seenAt == null && c.seenAt != null
                  ? winner.copyWith(seenAt: c.seenAt)
                  : winner;
              adopted[e.key] = cache[e.key]!;
            }
          } else if (c.seenAt != null) {
            await markSeenRemote(c.weekStart, c.seenAt!);
          }
        }
        pending.remove(e.key);
      }
    } catch (e) {
      debugPrint('[CheckinSync] Upload queued for retry: $e');
      if (throwOnError) rethrow;
    } finally {
      await _writeCache(cache);
      await _writePending(pending);
    }
    return adopted;
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

  /// Clears the cache and queue on logout so the next account starts fresh.
  Future<void> clearLocalState() async {
    await StorageService().delete(_cacheKey);
    await StorageService().delete(_pendingKey);
  }
}

/// What [CheckinSyncService.sync] found.
class CheckinSyncResult {
  const CheckinSyncResult(this.rows, this.adopted);

  /// Every check-in, keyed by `week_start`.
  final Map<String, GoalCheckin> rows;

  /// Weeks another device checked in first; their rows replaced this
  /// device's.
  final Map<String, GoalCheckin> adopted;
}
