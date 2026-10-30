import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// One device that is (or was) signed in to the account.
class AppSession {
  const AppSession({
    required this.id,
    required this.device,
    required this.createdAt,
    required this.lastActive,
    this.platform,
    this.location,
    this.endedAt,
  });

  final String id;
  final String device;
  final String? platform;
  final String? location;
  final DateTime createdAt;
  final DateTime lastActive;
  final DateTime? endedAt;

  bool get active => endedAt == null;

  factory AppSession.fromMap(Map<String, dynamic> m) {
    DateTime d(dynamic v) =>
        DateTime.tryParse('$v')?.toLocal() ?? DateTime.now();
    return AppSession(
      id: m['id'] as String,
      device: (m['device'] as String?) ?? 'Unknown device',
      platform: m['platform'] as String?,
      location: m['location'] as String?,
      createdAt: d(m['created_at']),
      lastActive: d(m['last_active']),
      endedAt: m['ended_at'] == null ? null : d(m['ended_at']),
    );
  }
}

/// Records this phone in `user_sessions` so "Apps and sessions" can list the
/// devices that are signed in, and what the access history looks like. (This
/// is app-level bookkeeping; the real sign-out of other devices is done by
/// Supabase's "sign out other sessions".)
class SessionTracker {
  SessionTracker._();

  static String? _currentId;

  /// Id of the row that belongs to this phone (null until [start] finished).
  static String? get currentId => _currentId;

  static SupabaseClient get _db => Supabase.instance.client;

  static String deviceLabel() {
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return 'iPhone / iPad';
      case TargetPlatform.android:
        return 'Android device';
      default:
        return 'This device';
    }
  }

  static String _platformLabel() {
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return 'iOS';
      case TargetPlatform.android:
        return 'Android';
      default:
        return 'Other';
    }
  }

  /// Call once the user is signed in. Re-uses this phone's open session or
  /// creates a new one.
  static Future<void> start() async {
    final user = _db.auth.currentUser;
    if (user == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'session_id_${user.id}';
      var id = prefs.getString(key);
      if (id != null) {
        final rows = await _db
            .from('user_sessions')
            .update({'last_active': DateTime.now().toUtc().toIso8601String()})
            .eq('id', id)
            .isFilter('ended_at', null)
            .select('id');
        if (rows.isEmpty) id = null;
      }
      if (id == null) {
        final row = await _db
            .from('user_sessions')
            .insert({
              'user_id': user.id,
              'device': deviceLabel(),
              'platform': _platformLabel(),
            })
            .select('id')
            .single();
        id = row['id'] as String;
        await prefs.setString(key, id);
      }
      _currentId = id;
    } catch (_) {
      // Table missing (schema.sql not re-run): sessions just stay empty.
    }
  }

  /// This phone signed out: close its session row.
  static Future<void> end() async {
    final id = _currentId;
    if (id == null) return;
    try {
      await _db
          .from('user_sessions')
          .update({'ended_at': DateTime.now().toUtc().toIso8601String()}).eq(
              'id', id);
      final user = _db.auth.currentUser;
      if (user != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('session_id_${user.id}');
      }
    } catch (_) {}
    _currentId = null;
  }

  /// Newest first. [onlyActive] hides sessions that were ended.
  static Future<List<AppSession>> list({bool onlyActive = false}) async {
    final user = _db.auth.currentUser;
    if (user == null) return [];
    var req = _db.from('user_sessions').select().eq('user_id', user.id);
    if (onlyActive) req = req.isFilter('ended_at', null);
    final rows = await req.order('created_at', ascending: false).limit(50);
    return rows.map<AppSession>(AppSession.fromMap).toList();
  }

  /// "Log out of all other sessions".
  static Future<void> endOthers() async {
    final user = _db.auth.currentUser;
    if (user == null) return;
    await _db.auth.signOut(scope: SignOutScope.others);
    var req = _db
        .from('user_sessions')
        .update({'ended_at': DateTime.now().toUtc().toIso8601String()})
        .eq('user_id', user.id)
        .isFilter('ended_at', null);
    final keep = _currentId;
    if (keep != null) req = req.neq('id', keep);
    await req;
  }
}
