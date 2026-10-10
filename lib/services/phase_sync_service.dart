import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'energy/phase_engine.dart';
import 'storage_service.dart';

/// Keeps `goal_phases` in step with the phases cached on the device.
///
/// One account's phases are one Hive entry (`goal_phases:<user id>`), so a
/// change is all-or-nothing:
/// - `rows`: every phase, by seq;
/// - `pending`: seqs waiting to upload (`{seq: upsert|delete}`). The local
///   copy wins until it uploads, as in [WeightSyncService].
///
/// Operations run one at a time, and after [clearLocalState] (logout) an
/// upload still in flight writes nothing back.
class PhaseSyncService {
  PhaseSyncService({String? userId}) : _userId = userId;

  static const String _table = 'goal_phases';
  static const String _keyPrefix = 'goal_phases:';
  static const String _upsert = 'upsert';
  static const String _delete = 'delete';

  final String? _userId;
  bool _closed = false;
  Future<void> _tail = Future.value();

  SupabaseClient get _client => Supabase.instance.client;

  /// The account these phases belong to.
  @visibleForTesting
  String? get userId => _userId;

  @visibleForTesting
  String? get stateKey => userId == null ? null : '$_keyPrefix$userId';

  _State _read() {
    final key = stateKey;
    final raw = key == null ? null : StorageService().get(key);
    if (raw is! String || raw.isEmpty) return _State();
    try {
      return _State.fromJson(jsonDecode(raw) as Map);
    } catch (e) {
      debugPrint('[PhaseSync] Unreadable cache, starting again: $e');
      return _State();
    }
  }

  Future<void> _write(_State state) async {
    final key = stateKey;
    if (key == null || _closed) return;
    await StorageService().put(key, jsonEncode(state.toJson()));
  }

  Future<T> _locked<T>(Future<T> Function() op) {
    final result = _tail.then((_) => op());
    _tail = result.then((_) {}, onError: (_) {});
    return result;
  }

  /// Every cached phase, oldest first.
  List<GoalPhase> loadCache() => _read().sorted;

  /// Whether anything waits to upload.
  bool get hasWork => _read().pending.isNotEmpty;

  /// Makes [edit] on the device and queues it to upload. Returns the phases
  /// after it.
  Future<List<GoalPhase>> edit(PhaseEdit edit) => _locked(() async {
        final s = _read();
        if (edit.isEmpty) return s.sorted;
        for (final seq in edit.deletes) {
          s.rows.remove(seq);
          s.pending[seq] = _delete;
        }
        for (final p in edit.upserts) {
          s.rows[p.seq] = p;
          s.pending[p.seq] = _upsert;
        }
        await _write(s);
        return s.sorted;
      });

  /// Uploads what's queued; failures stay queued.
  Future<void> upload() => _locked(() => _flush());

  /// Uploads what's queued, then pulls the account's phases: the cloud's
  /// copy wins for every seq that isn't waiting to upload. Returns false when
  /// the cloud couldn't be reached.
  Future<bool> sync() => _locked(() async {
        if (userId == null) return false;
        try {
          await _flush(throwOnError: true);
          final cloud = await fetchRemote();
          if (_closed) return false;
          final s = _read();
          final cloudSeqs = {for (final p in cloud) p.seq};
          s.rows.removeWhere((seq, _) => !cloudSeqs.contains(seq) && !s.pending.containsKey(seq));
          for (final p in cloud) {
            if (!s.pending.containsKey(p.seq)) s.rows[p.seq] = p;
          }
          await _write(s);
          return true;
        } catch (e) {
          debugPrint('[PhaseSync] Sync failed, keeping local phases: $e');
          return false;
        }
      });

  Future<void> _flush({bool throwOnError = false}) async {
    final uid = userId;
    if (uid == null) return;
    try {
      for (final MapEntry(key: seq, value: kind) in _read().pending.entries.toList()) {
        if (_closed) return;
        final row = _read().rows[seq];
        if (kind == _upsert && row != null) {
          await upsertRemote({'user_id': uid, ...row.toJson()});
        } else {
          await deleteRemote(seq);
        }
        if (_closed) return;
        // Re-read: an edit may have been saved meanwhile.
        final s = _read();
        if (s.pending[seq] == kind && (kind == _delete || s.rows[seq] == row)) {
          s.pending.remove(seq);
          await _write(s);
        }
      }
    } catch (e) {
      debugPrint('[PhaseSync] Upload queued for retry: $e');
      if (throwOnError) rethrow;
    }
  }

  @visibleForTesting
  Future<void> upsertRemote(Map<String, Object?> row) => _client
      .from(_table)
      .upsert(row, onConflict: 'user_id,seq')
      .timeout(const Duration(seconds: 15));

  @visibleForTesting
  Future<void> deleteRemote(int seq) => _client
      .from(_table)
      .delete()
      .eq('user_id', userId!)
      .eq('seq', seq)
      .timeout(const Duration(seconds: 15));

  @visibleForTesting
  Future<List<GoalPhase>> fetchRemote() async {
    final rows = await _client
        .from(_table)
        .select()
        .eq('user_id', userId!)
        .timeout(const Duration(seconds: 20));
    return [for (final r in rows) if (GoalPhase.fromJson(r) case final p?) p];
  }

  /// Forgets this account's phases on the device (logout). An upload still
  /// in flight stops and saves nothing.
  Future<void> clearLocalState() async {
    _closed = true;
    final key = stateKey;
    if (key != null) await StorageService().delete(key);
  }
}

class _State {
  _State({Map<int, GoalPhase>? rows, Map<int, String>? pending})
      : rows = rows ?? {},
        pending = pending ?? {};

  final Map<int, GoalPhase> rows;
  final Map<int, String> pending;

  List<GoalPhase> get sorted => rows.values.toList()..sort((a, b) => a.seq.compareTo(b.seq));

  factory _State.fromJson(Map json) => _State(
        rows: {
          for (final r in (json['rows'] as List? ?? const []))
            if (GoalPhase.fromJson(r) case final p?) p.seq: p,
        },
        pending: (json['pending'] as Map? ?? const {})
            .map((k, v) => MapEntry(int.parse('$k'), '$v')),
      );

  Map<String, Object?> toJson() => {
        'rows': [for (final p in sorted) p.toJson()],
        'pending': {for (final e in pending.entries) '${e.key}': e.value},
      };
}
