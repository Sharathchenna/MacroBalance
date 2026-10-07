import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'energy/day_status.dart';
import 'storage_service.dart';

/// Keeps `food_day_status` in step with the copy cached on the device.
///
/// The cache (Hive `food_day_status`) is a `{day: code}` map; days without an
/// entry are "not finished". Changes go into a pending queue
/// (`pending_day_status`, `{day: code or ''}`, where '' means delete) until
/// they upload, and the local value wins until then, the same way
/// [WeightSyncService] works.
class DayStatusSyncService {
  static final DayStatusSyncService _instance = DayStatusSyncService._internal();
  factory DayStatusSyncService() => _instance;
  DayStatusSyncService._internal();

  static const String _table = 'food_day_status';
  static const String _cacheKey = 'food_day_status';
  static const String _pendingKey = 'pending_day_status';

  SupabaseClient get _client => Supabase.instance.client;

  Map<String, String> _readMap(String key) {
    final raw = StorageService().get(key);
    if (raw is! String || raw.isEmpty) return {};
    try {
      return (jsonDecode(raw) as Map)
          .map((k, v) => MapEntry(k.toString(), v.toString()));
    } catch (_) {
      return {};
    }
  }

  Future<void> _writeMap(String key, Map<String, String> map) =>
      StorageService().put(key, jsonEncode(map));

  /// The days the user has finished, from the device cache.
  Map<String, ExplicitDayStatus> loadCache() {
    final out = <String, ExplicitDayStatus>{};
    _readMap(_cacheKey).forEach((day, code) {
      final s = ExplicitDayStatus.fromCode(code);
      if (s != null) out[day] = s;
    });
    return out;
  }

  /// Sets (or, with null, clears) [day]'s status: cache first, then upload.
  /// A failed upload stays queued for the next [sync].
  Future<void> set(String day, ExplicitDayStatus? status) async {
    final cache = _readMap(_cacheKey);
    if (status == null) {
      cache.remove(day);
    } else {
      cache[day] = status.code;
    }
    await _writeMap(_cacheKey, cache);
    await _writeMap(_pendingKey, _readMap(_pendingKey)..[day] = status?.code ?? '');

    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;
    try {
      await _upload(userId, {day: status?.code ?? ''});
      await _writeMap(_pendingKey, _readMap(_pendingKey)..remove(day));
    } catch (e) {
      debugPrint('[DayStatusSync] Upload of $day queued for retry: $e');
    }
  }

  Future<void> _upload(String userId, Map<String, String> changes) async {
    final upserts = [
      for (final e in changes.entries)
        if (e.value.isNotEmpty)
          {
            'user_id': userId,
            'day': e.key,
            'status': e.value,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          },
    ];
    final deletes = [
      for (final e in changes.entries)
        if (e.value.isEmpty) e.key,
    ];
    if (upserts.isNotEmpty) {
      await _client
          .from(_table)
          .upsert(upserts, onConflict: 'user_id,day')
          .timeout(const Duration(seconds: 15));
    }
    if (deletes.isNotEmpty) {
      await _client
          .from(_table)
          .delete()
          .eq('user_id', userId)
          .inFilter('day', deletes)
          .timeout(const Duration(seconds: 15));
    }
  }

  /// Uploads the pending changes, then pulls the cloud rows and merges them
  /// with the cache (pending local changes win). Returns the merged map, or
  /// null if the cloud couldn't be reached.
  Future<Map<String, ExplicitDayStatus>?> sync() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;
    try {
      final pending = _readMap(_pendingKey);
      if (pending.isNotEmpty) {
        await _upload(userId, pending);
        await _writeMap(_pendingKey, {});
      }
      final rows = await _client
          .from(_table)
          .select('day, status')
          .eq('user_id', userId)
          .timeout(const Duration(seconds: 20));
      final merged = mergeCloud(rows, pending: const {});
      await _writeMap(_cacheKey, merged);
      return loadCache();
    } catch (e) {
      debugPrint('[DayStatusSync] Sync failed, keeping local status: $e');
      return null;
    }
  }

  /// The cloud rows are the truth for days with nothing pending; days still
  /// pending keep their local value.
  @visibleForTesting
  static Map<String, String> mergeCloud(
    List<dynamic> cloudRows, {
    required Map<String, String> pending,
  }) {
    final merged = <String, String>{
      for (final row in cloudRows)
        (row['day'] as String): row['status'] as String,
    };
    pending.forEach((day, code) {
      if (code.isEmpty) {
        merged.remove(day);
      } else {
        merged[day] = code;
      }
    });
    return merged;
  }

  /// Clears the cache and queue on logout so the next account starts fresh.
  Future<void> clearLocalState() async {
    await StorageService().delete(_cacheKey);
    await StorageService().delete(_pendingKey);
  }
}
