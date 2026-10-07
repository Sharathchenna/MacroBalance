import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'energy/energy_estimator.dart';
import 'energy/estimate_rows.dart';
import 'storage_service.dart';

/// Keeps `energy_estimates` in step with the estimates cached on the device.
///
/// The cache (Hive `energy_estimates`) holds the last [kEstimateCacheDays]
/// days at full precision, with the fields only the device needs (whether the
/// day updated the estimate, the observation). Days that still have to reach
/// the cloud wait in a queue (`pending_energy_estimates`) until an upload
/// succeeds, the same way [WeightSyncService] works. Rows are only ever
/// upserted: a reset keeps the old ones for the chart.
class EnergySyncService {
  EnergySyncService();

  static const String _table = 'energy_estimates';
  static const String _cacheKey = 'energy_estimates';
  static const String _pendingKey = 'pending_energy_estimates';

  /// Rows sent per request.
  static const int _batch = 200;

  SupabaseClient get _client => Supabase.instance.client;

  /// The cached rows, keyed by day.
  Map<DateTime, EnergyEstimate> loadCache() {
    final raw = StorageService().get(_cacheKey);
    if (raw is! String || raw.isEmpty) return {};
    try {
      final out = <DateTime, EnergyEstimate>{};
      for (final json in jsonDecode(raw) as List) {
        final row = estimateFromCache(json);
        if (row != null) out[row.day] = row;
      }
      return out;
    } catch (e) {
      debugPrint('[EnergySync] Unreadable cache, starting again: $e');
      return {};
    }
  }

  Future<void> _writeCache(Map<DateTime, EnergyEstimate> rows) {
    final sorted = rows.values.toList()..sort((a, b) => a.day.compareTo(b.day));
    return StorageService()
        .put(_cacheKey, jsonEncode([for (final r in sorted) r.toCacheJson()]));
  }

  /// Days waiting to upload.
  Set<String> pendingDays() {
    final raw = StorageService().get(_pendingKey);
    if (raw is! String || raw.isEmpty) return {};
    try {
      return {for (final d in jsonDecode(raw) as List) '$d'};
    } catch (_) {
      return {};
    }
  }

  Future<void> _writePending(Set<String> days) =>
      StorageService().put(_pendingKey, jsonEncode(days.toList()..sort()));

  /// Stores a replay's rows: the changed ones go into the cache and the
  /// queue, then the queue uploads. Returns the cache after the save.
  /// Re-saving the same rows changes nothing and sends nothing.
  Future<Map<DateTime, EnergyEstimate>> save(
    List<EnergyEstimate> rows, {
    required DateTime today,
  }) async {
    final cache = loadCache();
    final recent = keepRecent({for (final r in rows) r.day: r}, today: today);
    final changed = rowsToUpload(recent.values, cache);
    // The device-only fields can change without the cloud row changing, so
    // the cache takes every fresh row.
    final merged = keepRecent({...cache, ...recent}, today: today);
    await _writeCache(merged);
    if (changed.isNotEmpty) {
      await _writePending({...pendingDays(), for (final r in changed) dayKey(r.day)});
    }
    await flush(merged);
    return merged;
  }

  /// Uploads the queued days. A failure leaves them queued for next time.
  Future<bool> flush([Map<DateTime, EnergyEstimate>? cache]) async {
    final pending = pendingDays();
    if (pending.isEmpty) return true;
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return false;
    final rows = cache ?? loadCache();
    final toSend = [
      for (final r in rows.values)
        if (pending.contains(dayKey(r.day))) r.toRemoteRow(userId),
    ];
    try {
      for (var i = 0; i < toSend.length; i += _batch) {
        await upload(toSend.sublist(i, (i + _batch).clamp(0, toSend.length)));
      }
      // Days no longer cached (too old) are dropped from the queue too.
      await _writePending({});
      return true;
    } catch (e) {
      debugPrint('[EnergySync] Upload of ${toSend.length} days queued: $e');
      return false;
    }
  }

  @visibleForTesting
  Future<void> upload(List<Map<String, dynamic>> rows) => _client
      .from(_table)
      .upsert(rows, onConflict: 'user_id,day')
      .timeout(const Duration(seconds: 20));

  /// Fills days the cache doesn't have from the cloud (another device, or
  /// rows from before a reset), so the history shows on a new install. Days
  /// the device has computed are left alone.
  Future<Map<DateTime, EnergyEstimate>?> pull({required DateTime today}) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;
    try {
      final from = DateTime(today.year, today.month, today.day - (kEstimateCacheDays - 1));
      final rows = await _client
          .from(_table)
          .select()
          .eq('user_id', userId)
          .gte('day', dayKey(from))
          .timeout(const Duration(seconds: 20));
      final cache = loadCache();
      var added = false;
      for (final row in rows) {
        final r = estimateFromRemote(row);
        if (r != null && !cache.containsKey(r.day)) {
          cache[r.day] = r;
          added = true;
        }
      }
      if (added) await _writeCache(cache);
      return cache;
    } catch (e) {
      debugPrint('[EnergySync] Pull failed, keeping the cache: $e');
      return null;
    }
  }

  /// Clears the cache and queue on logout so the next account starts fresh.
  Future<void> clearLocalState() async {
    await StorageService().delete(_cacheKey);
    await StorageService().delete(_pendingKey);
  }
}
