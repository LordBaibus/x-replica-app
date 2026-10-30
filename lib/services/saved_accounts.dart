import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// An account that signed in on this device. It is shown on the "Log in"
/// screen and in the account switcher. The password is never kept; the
/// refresh token (the same kind of token the Supabase library already keeps
/// on this device) is what lets the switcher open the account without asking
/// for the password again.
class SavedAccount {
  const SavedAccount({
    required this.email,
    required this.name,
    required this.username,
    this.avatarUrl,
    this.userId,
    this.refreshToken,
  });

  final String email;
  final String name;
  final String username;
  final String? avatarUrl;
  final String? userId;

  /// null = this account has to be logged in with its password again.
  final String? refreshToken;

  bool get canSwitch => refreshToken != null && refreshToken!.isNotEmpty;

  SavedAccount copyWith({
    String? name,
    String? username,
    String? avatarUrl,
    String? userId,
    String? refreshToken,
    bool clearToken = false,
  }) =>
      SavedAccount(
        email: email,
        name: name ?? this.name,
        username: username ?? this.username,
        avatarUrl: avatarUrl ?? this.avatarUrl,
        userId: userId ?? this.userId,
        refreshToken: clearToken ? null : (refreshToken ?? this.refreshToken),
      );

  Map<String, dynamic> toJson() => {
        'email': email,
        'name': name,
        'username': username,
        'avatar_url': avatarUrl,
        'user_id': userId,
        'refresh_token': refreshToken,
      };

  factory SavedAccount.fromJson(Map<String, dynamic> j) => SavedAccount(
        email: (j['email'] as String?) ?? '',
        name: (j['name'] as String?) ?? '',
        username: (j['username'] as String?) ?? '',
        avatarUrl: j['avatar_url'] as String?,
        userId: j['user_id'] as String?,
        refreshToken: j['refresh_token'] as String?,
      );
}

/// Small list of accounts used on this device, stored on the device.
class SavedAccounts {
  SavedAccounts._();

  static const _key = 'saved_accounts_v1';
  static const _max = 8;

  // Reads and writes run one after the other, so a token refresh and a
  // profile update can never overwrite each other.
  static Future<void> _chain = Future<void>.value();

  static Future<void> _sync(Future<void> Function() job) {
    final next = _chain.then((_) => job()).catchError((_) {});
    _chain = next;
    return next;
  }

  static Future<List<SavedAccount>> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null || raw.isEmpty) return const [];
      final list = (jsonDecode(raw) as List<dynamic>)
          .map((e) => SavedAccount.fromJson((e as Map).cast<String, dynamic>()))
          .where((a) => a.email.isNotEmpty)
          .toList();
      return list;
    } catch (_) {
      return const [];
    }
  }

  static Future<void> _save(List<SavedAccount> list) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _key,
        jsonEncode(list.map((a) => a.toJson()).toList()),
      );
    } catch (_) {
      // Remembering accounts is a convenience; ignore storage problems.
    }
  }

  /// Adds (or moves to the top) the account that just signed in. The login
  /// token already stored for that e-mail is kept.
  static Future<void> remember(SavedAccount account) => _sync(() async {
    final list = await load();
    final key = account.email.toLowerCase();
    final old = list.where((a) => a.email.toLowerCase() == key).toList();
    final merged = old.isEmpty
        ? account
        : account.copyWith(
            userId: account.userId ?? old.first.userId,
            refreshToken: account.refreshToken ?? old.first.refreshToken,
          );
    final next = [
      merged,
      ...list.where((a) => a.email.toLowerCase() != key),
    ].take(_max).toList();
    await _save(next);
  });

  /// Stores the newest login token of an account (called on every sign-in
  /// and token refresh). A new account gets a placeholder name until its
  /// profile is loaded.
  static Future<void> saveToken({
    required String email,
    required String userId,
    required String refreshToken,
  }) => _sync(() async {
    final list = await load();
    final key = email.toLowerCase();
    final i = list.indexWhere((a) => a.email.toLowerCase() == key);
    if (i >= 0) {
      list[i] = list[i].copyWith(userId: userId, refreshToken: refreshToken);
      await _save(list);
    } else {
      final handle = email.split('@').first;
      await _save([
        SavedAccount(
          email: email,
          name: handle,
          username: handle,
          userId: userId,
          refreshToken: refreshToken,
        ),
        ...list,
      ].take(_max).toList());
    }
  });

  /// The login token is no longer valid (logged out / expired); the account
  /// stays in the list but needs its password again.
  static Future<void> clearToken(String email) => _sync(() async {
    final list = await load();
    final key = email.toLowerCase();
    await _save([
      for (final a in list)
        a.email.toLowerCase() == key ? a.copyWith(clearToken: true) : a,
    ]);
  });

  static Future<void> remove(String email) => _sync(() async {
    final key = email.toLowerCase();
    final list = await load();
    await _save(list.where((a) => a.email.toLowerCase() != key).toList());
  });
}
