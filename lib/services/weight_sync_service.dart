import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'storage_service.dart';

/// Backs up weight history to the `weight_entries` table, one row per day.
///
/// The weight screen keeps its list in Hive (`weight_history`) as
/// `{'date': iso8601, 'weight': kg}` maps; this service mirrors that list to
/// Supabase and merges it back after a reinstall or on another device.
class WeightSyncService {
  static final WeightSyncService _instance = WeightSyncService._internal();
  factory WeightSyncService() => _instance;
  WeightSyncService._internal();

  static const String _table = 'weight_entries';
  static const String _pendingKey = 'pending_weight_days';
  static const String _backfillKey = 'weight_backfill_done';
  static const String _deletedKey = 'deleted_weight_days';
  static const String _historyKey = 'weight_history';
  static final DateFormat _dayFormat = DateFormat('yyyy-MM-dd');

  SupabaseClient get _client => Supabase.instance.client;

  static String dayKey(DateTime date) => _dayFormat.format(date.toLocal());

  Set<String> _pendingDays() {
    final raw = StorageService().get(_pendingKey);
    if (raw is! String || raw.isEmpty) return <String>{};
    try {
      return (jsonDecode(raw) as List).map((e) => e.toString()).toSet();
    } catch (_) {
      return <String>{};
    }
  }

  Future<void> _savePendingDays(Set<String> days) =>
      StorageService().put(_pendingKey, jsonEncode(days.toList()));

  /// Days deleted on this device whose cloud row may still exist.
  Set<String> _deletedDays() {
    final raw = StorageService().get(_deletedKey);
    if (raw is! String || raw.isEmpty) return <String>{};
    try {
      return (jsonDecode(raw) as List).map((e) => e.toString()).toSet();
    } catch (_) {
      return <String>{};
    }
  }

  Future<void> _saveDeletedDays(Set<String> days) =>
      StorageService().put(_deletedKey, jsonEncode(days.toList()));

  Map<String, dynamic> _row(String userId, String day, double kg) => {
        'user_id': userId,
        'recorded_on': day,
        'weight_kg': double.parse(kg.toStringAsFixed(2)),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };

  /// Saves one day's weight. If the upload fails it is retried on the next
  /// [mergeWithCloud], and the local value wins until then.
  Future<void> upsertDay(DateTime date, double weightKg) async {
    final day = dayKey(date);
    await _savePendingDays(_pendingDays()..add(day));
    await _saveDeletedDays(_deletedDays()..remove(day));
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;
    try {
      await _client
          .from(_table)
          .upsert(_row(userId, day, weightKg), onConflict: 'user_id,recorded_on')
          .timeout(const Duration(seconds: 15));
      await _savePendingDays(_pendingDays()..remove(day));
    } catch (e) {
      debugPrint('[WeightSync] Upload of $day queued for retry: $e');
    }
  }

  /// Deletes one day's weight. Until the cloud row is gone, merges leave the
  /// day out so it doesn't come back.
  Future<void> deleteDay(DateTime date) async {
    final day = dayKey(date);
    await _savePendingDays(_pendingDays()..remove(day));
    await _saveDeletedDays(_deletedDays()..add(day));
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;
    try {
      await _client
          .from(_table)
          .delete()
          .eq('user_id', userId)
          .eq('recorded_on', day)
          .timeout(const Duration(seconds: 15));
      await _saveDeletedDays(_deletedDays()..remove(day));
    } catch (e) {
      debugPrint('[WeightSync] Delete of $day queued for retry: $e');
    }
  }

  /// Uploads anything not yet in the cloud, then returns the merged history in
  /// the weight screen's format, sorted oldest first. Returns null if the
  /// cloud can't be reached, so the caller keeps its local list.
  Future<List<Map<String, dynamic>>?> mergeWithCloud(
      List<Map<String, dynamic>> local) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;

    try {
      final localByDay = <String, Map<String, dynamic>>{
        for (final entry in local)
          dayKey(DateTime.parse(entry['date'] as String)): entry,
      };

      // Upload: everything once (history from before sync existed), and after
      // that only days whose upload failed.
      final pending = _pendingDays();
      final backfillDone = StorageService().get(_backfillKey) == true;
      final toUpload = backfillDone
          ? localByDay.keys.where(pending.contains).toList()
          : localByDay.keys.toList();
      if (toUpload.isNotEmpty) {
        await _client
            .from(_table)
            .upsert([
              for (final day in toUpload)
                _row(userId, day, (localByDay[day]!['weight'] as num).toDouble()),
            ], onConflict: 'user_id,recorded_on')
            .timeout(const Duration(seconds: 20));
      }
      await _savePendingDays(<String>{});
      await StorageService().put(_backfillKey, true);

      // Retry deletes that didn't reach the cloud.
      final deleted = _deletedDays();
      if (deleted.isNotEmpty) {
        await _client
            .from(_table)
            .delete()
            .eq('user_id', userId)
            .inFilter('recorded_on', deleted.toList())
            .timeout(const Duration(seconds: 20));
        await _saveDeletedDays(<String>{});
      }

      final rows = await _client
          .from(_table)
          .select('recorded_on, weight_kg')
          .eq('user_id', userId)
          .order('recorded_on')
          .timeout(const Duration(seconds: 20));

      return mergeHistory(
          local.where((e) => !deleted.contains(dayKey(DateTime.parse(e['date'] as String)))).toList(),
          rows);
    } catch (e) {
      debugPrint('[WeightSync] Merge failed, keeping local history: $e');
      return null;
    }
  }

  /// Merges the device's history with `weight_entries` rows, one entry per
  /// day, sorted oldest first. Days present remotely take the cloud value (it
  /// may come from another device); local-only days are kept.
  static List<Map<String, dynamic>> mergeHistory(
      List<Map<String, dynamic>> local, List<Map<String, dynamic>> cloudRows) {
    final merged = <String, Map<String, dynamic>>{
      for (final entry in local)
        dayKey(DateTime.parse(entry['date'] as String)): entry,
    };
    for (final row in cloudRows) {
      final day = row['recorded_on'] as String;
      final kg = (row['weight_kg'] as num).toDouble();
      final existing = merged[day];
      merged[day] = {
        // Keep the local timestamp when there is one; otherwise use midday
        // so the day never shifts across time zones.
        'date': existing?['date'] ??
            DateTime.parse(day).add(const Duration(hours: 12)).toIso8601String(),
        'weight': kg,
      };
    }

    return merged.values.toList()
      ..sort((a, b) => DateTime.parse(a['date'] as String)
          .compareTo(DateTime.parse(b['date'] as String)));
  }

  /// Reads the weight screen's stored history. Entries without a date or
  /// weight are skipped; returns null if the data can't be read at all, so it
  /// is never overwritten.
  static List<Map<String, dynamic>>? parseLocalHistory(Object? raw) {
    if (raw is! String || raw.isEmpty) return [];
    try {
      return (jsonDecode(raw) as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .where((e) => e['date'] is String && e['weight'] is num)
          .toList();
    } catch (e) {
      debugPrint('[WeightSync] Unreadable local history, not syncing: $e');
      return null;
    }
  }

  /// Backs up the weight history stored on this device and pulls in any from
  /// the cloud, without the weight screen being open. Run at sign-in and app
  /// start, so people who log weight on an older build keep it after updating,
  /// even if they never open the weight screen. Returns the merged history,
  /// or null if the cloud couldn't be reached (local data is left untouched).
  Future<List<Map<String, dynamic>>?> syncLocalHistory() async {
    final local = parseLocalHistory(StorageService().get(_historyKey));
    if (local == null) return null; // never overwrite data we couldn't read
    final merged = await mergeWithCloud(local);
    if (merged != null) {
      await StorageService().put(_historyKey, jsonEncode(merged));
    }
    return merged;
  }

  /// Clears sync bookkeeping on logout so the next account starts fresh.
  Future<void> clearLocalState() async {
    await StorageService().delete(_pendingKey);
    await StorageService().delete(_backfillKey);
    await StorageService().delete(_deletedKey);
  }
}
