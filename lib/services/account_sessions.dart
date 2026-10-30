import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'moderation.dart';
import 'saved_accounts.dart';
import 'user_prefs.dart';

/// Several accounts on one phone. Every time an account signs in or its login
/// token is refreshed, the newest token is saved on the device
/// ([SavedAccounts]); switching accounts simply opens another saved login.
class AccountSessions {
  AccountSessions._();

  static StreamSubscription<AuthState>? _sub;

  static SupabaseClient get _db => Supabase.instance.client;

  /// Call once after Supabase was initialized.
  static void start() {
    _sub ??= _db.auth.onAuthStateChange.listen((state) {
      final session = state.session;
      final email = session?.user.email;
      final token = session?.refreshToken;
      if (session == null || email == null || email.isEmpty) return;
      if (token == null || token.isEmpty) return;
      SavedAccounts.saveToken(
        email: email,
        userId: session.user.id,
        refreshToken: token,
      );
    });
  }

  /// Accounts that can be opened without a password (the current one first).
  static Future<List<SavedAccount>> switchable() async {
    final current = _db.auth.currentUser?.email?.toLowerCase();
    final list = (await SavedAccounts.load()).where((a) => a.canSwitch).toList();
    list.sort((a, b) {
      final ac = a.email.toLowerCase() == current ? 0 : 1;
      final bc = b.email.toLowerCase() == current ? 0 : 1;
      return ac.compareTo(bc);
    });
    return list;
  }

  /// Opens [account]. AuthGate notices the new session and shows that
  /// account's app. Throws a readable message when the saved login expired.
  static Future<void> switchTo(SavedAccount account) async {
    final token = account.refreshToken;
    if (token == null || token.isEmpty) {
      throw Exception('Please log in to ${account.name} again.');
    }
    UserPrefs.instance.reset();
    Moderation.instance.reset();
    try {
      await _db.auth.setSession(token);
    } catch (_) {
      await SavedAccounts.clearToken(account.email);
      // Still signed in as the old account: bring its data back.
      unawaited(UserPrefs.instance.load());
      unawaited(Moderation.instance.reload());
      throw Exception(
        'The saved login of ${account.name} expired. Log in to it again.',
      );
    }
  }

  /// The signed-in account logged out: its saved login is useless now, so it
  /// needs the password again. It stays on the "Log in to X" screen next to
  /// the other saved accounts.
  static Future<void> afterLogout(String? email) async {
    if (email != null && email.isNotEmpty) {
      await SavedAccounts.clearToken(email);
    }
  }
}
