import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Settings that belong to one account (switches, picked options, muted
/// words, pinned timelines ...).
///
/// They are kept as one JSON map. Every change is written at once to this
/// device (SharedPreferences) and, a moment later, to the `user_prefs` table
/// in Supabase, so the settings follow the account to another phone. When the
/// table has not been created yet (schema.sql not re-run) everything still
/// works on this device.
class UserPrefs extends ChangeNotifier {
  UserPrefs._();

  static final UserPrefs instance = UserPrefs._();

  Map<String, dynamic> _data = {};
  String? _uid;
  Timer? _push;

  SupabaseClient get _db => Supabase.instance.client;

  String get _cacheKey => 'user_prefs_$_uid';

  /// Loads the saved settings of the signed-in account.
  Future<void> load() async {
    final user = _db.auth.currentUser;
    if (user == null) return;
    if (_uid != user.id) _data = {};
    _uid = user.id;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey);
      if (raw != null) {
        _data = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      }
    } catch (_) {}
    notifyListeners();
    try {
      final row = await _db
          .from('user_prefs')
          .select('prefs')
          .eq('user_id', user.id)
          .maybeSingle();
      final remote = row?['prefs'];
      if (remote is Map) {
        _data = {..._data, ...Map<String, dynamic>.from(remote)};
        await _saveLocal();
        notifyListeners();
      }
    } catch (_) {
      // Table missing or offline: the local copy is enough.
    }
  }

  /// Forget everything in memory (sign-out). The saved copy stays on disk.
  void reset() {
    _push?.cancel();
    _data = {};
    _uid = null;
    notifyListeners();
  }

  // --- reading -------------------------------------------------------------

  bool flag(String key, [bool fallback = false]) {
    final v = _data[key];
    return v is bool ? v : fallback;
  }

  String text(String key, [String fallback = '']) {
    final v = _data[key];
    return v is String ? v : fallback;
  }

  int number(String key, [int fallback = 0]) {
    final v = _data[key];
    return v is num ? v.toInt() : fallback;
  }

  List<String> strings(String key) {
    final v = _data[key];
    return v is List ? v.map((e) => e.toString()).toList() : <String>[];
  }

  List<Map<String, dynamic>> maps(String key) {
    final v = _data[key];
    if (v is! List) return <Map<String, dynamic>>[];
    return [
      for (final e in v)
        if (e is Map) Map<String, dynamic>.from(e),
    ];
  }

  // --- writing -------------------------------------------------------------

  /// Stores [value] (bool, int, String, List, Map) under [key]; null removes
  /// the key.
  Future<void> set(String key, Object? value) async {
    if (value == null) {
      _data.remove(key);
    } else {
      _data[key] = value;
    }
    notifyListeners();
    await _saveLocal();
    _schedulePush();
  }

  Future<void> _saveLocal() async {
    if (_uid == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, jsonEncode(_data));
    } catch (_) {}
  }

  void _schedulePush() {
    _push?.cancel();
    _push = Timer(const Duration(milliseconds: 700), _pushNow);
  }

  Future<void> _pushNow() async {
    final id = _uid;
    if (id == null) return;
    try {
      await _db.from('user_prefs').upsert({
        'user_id': id,
        'prefs': _data,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (_) {}
  }
}
