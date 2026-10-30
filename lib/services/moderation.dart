import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/models.dart';
import 'user_prefs.dart';

/// Blocked accounts, muted accounts, muted words and the "Muted
/// notifications" switches. The lists are loaded once and used to clean the
/// timeline and the notifications on the phone.
class Moderation extends ChangeNotifier {
  Moderation._();

  static final Moderation instance = Moderation._();

  Set<String> blocked = {};
  Set<String> muted = {};

  /// People I follow / people who follow me (for the notification filters).
  Set<String> following = {};
  Set<String> followers = {};

  /// Protected accounts I asked to follow and that have not answered yet.
  Set<String> requested = {};

  bool _loaded = false;
  Future<void>? _loading;

  SupabaseClient get _db => Supabase.instance.client;

  String? get _me => _db.auth.currentUser?.id;

  Future<void> ensureLoaded() {
    if (_loaded) return Future.value();
    return _loading ??= reload().whenComplete(() => _loading = null);
  }

  /// Sign-out: the next account starts clean.
  void reset() {
    blocked = {};
    muted = {};
    following = {};
    followers = {};
    requested = {};
    _loaded = false;
    notifyListeners();
  }

  Future<void> reload() async {
    final me = _me;
    if (me == null) return;
    try {
      final b =
          await _db.from('user_blocks').select('blocked_id').eq('blocker_id', me);
      blocked = {for (final r in b) r['blocked_id'] as String};
    } catch (_) {}
    try {
      final m = await _db.from('user_mutes').select('muted_id').eq('muter_id', me);
      muted = {for (final r in m) r['muted_id'] as String};
    } catch (_) {}
    try {
      final f = await _db.from('follows').select('following_id').eq('follower_id', me);
      following = {for (final r in f) r['following_id'] as String};
      final g = await _db.from('follows').select('follower_id').eq('following_id', me);
      followers = {for (final r in g) r['follower_id'] as String};
    } catch (_) {}
    try {
      final q = await _db
          .from('follow_requests')
          .select('target_id')
          .eq('requester_id', me);
      requested = {for (final r in q) r['target_id'] as String};
    } catch (_) {}
    _loaded = true;
    notifyListeners();
  }

  // --- blocking / muting -----------------------------------------------------

  Future<void> block(String userId) async {
    await _db.rpc('block_user', params: {'p_target': userId});
    blocked = {...blocked, userId};
    following = {...following}..remove(userId);
    followers = {...followers}..remove(userId);
    requested = {...requested}..remove(userId);
    notifyListeners();
  }

  Future<void> unblock(String userId) async {
    final me = _me;
    if (me == null) return;
    await _db
        .from('user_blocks')
        .delete()
        .match({'blocker_id': me, 'blocked_id': userId});
    blocked = {...blocked}..remove(userId);
    notifyListeners();
  }

  Future<void> mute(String userId) async {
    final me = _me;
    if (me == null) return;
    await _db.from('user_mutes').upsert({'muter_id': me, 'muted_id': userId});
    muted = {...muted, userId};
    notifyListeners();
  }

  Future<void> unmute(String userId) async {
    final me = _me;
    if (me == null) return;
    await _db
        .from('user_mutes')
        .delete()
        .match({'muter_id': me, 'muted_id': userId});
    muted = {...muted}..remove(userId);
    notifyListeners();
  }

  Future<List<Profile>> _profilesOf(Set<String> ids) async {
    if (ids.isEmpty) return [];
    final rows = await _db
        .from('profiles')
        .select('id, username, display_name, avatar_url, bio')
        .inFilter('id', ids.toList());
    return rows.map<Profile>(Profile.fromMap).toList();
  }

  Future<List<Profile>> blockedProfiles() async {
    await reload();
    return _profilesOf(blocked);
  }

  Future<List<Profile>> mutedProfiles() async {
    await reload();
    return _profilesOf(muted);
  }

  // --- muted words -----------------------------------------------------------

  static const String wordsKey = 'muted_words';

  /// Words that are still active (a word can be muted for a limited time).
  List<Map<String, dynamic>> activeWords() {
    final now = DateTime.now();
    return [
      for (final w in UserPrefs.instance.maps(wordsKey))
        if (w['until'] == null ||
            (DateTime.tryParse('${w['until']}')?.isAfter(now) ?? true))
          w,
    ];
  }

  /// Normalised form used to compare / store a muted word.
  static String normalizeWord(String raw) => raw.trim().toLowerCase();

  /// Whole-word match, so muting "art" does not hide "party".
  static bool wordHits(String text, String word) {
    if (word.isEmpty) return false;
    final re = RegExp(
      '(^|[^A-Za-z0-9_])${RegExp.escape(word)}(?![A-Za-z0-9_])',
      caseSensitive: false,
    );
    return re.hasMatch(text);
  }

  bool _wordMutes(String text, String authorId, {required bool forHome}) {
    if (text.isEmpty) return false;
    for (final w in activeWords()) {
      if (forHome ? w['home'] == false : w['notif'] == false) continue;
      if (w['from'] == 'unfollowed' && following.contains(authorId)) continue;
      if (wordHits(text, '${w['w']}')) return true;
    }
    return false;
  }

  // --- filters ---------------------------------------------------------------

  /// True when [post] must not be shown in a timeline.
  bool hidesPost(Post post) {
    final me = _me;
    if (post.userId == me) return false;
    if (blocked.contains(post.userId) || muted.contains(post.userId)) {
      return true;
    }
    return _wordMutes(post.content, post.userId, forHome: true);
  }

  // --- posts I hid ("Not interested", "Mark as spam") ----------------------

  static const String hiddenKey = 'hidden_posts';

  /// Hides [postId] from every timeline of this account.
  Future<void> hidePost(String postId) async {
    final list = UserPrefs.instance.strings(hiddenKey);
    if (list.contains(postId)) return;
    final next = [...list, postId];
    await UserPrefs.instance.set(
      hiddenKey,
      next.length > 500 ? next.sublist(next.length - 500) : next,
    );
  }

  /// Undo of [hidePost] ("Undo" on the "Not interested" card).
  Future<void> unhidePost(String postId) async {
    final list = UserPrefs.instance.strings(hiddenKey);
    if (!list.contains(postId)) return;
    await UserPrefs.instance.set(
      hiddenKey,
      [for (final id in list) if (id != postId) id],
    );
  }

  List<Post> visiblePosts(List<Post> posts) {
    final hidden = UserPrefs.instance.strings(hiddenKey).toSet();
    return posts
        .where((p) => !hidden.contains(p.id) && !hidesPost(p))
        .toList();
  }

  /// Applies blocks, mutes, muted words and the "Muted notifications"
  /// switches. Notifications from people I follow only lose to blocks,
  /// mutes and muted words (like on X).
  List<AppNotification> visibleNotifications(List<AppNotification> list) {
    final prefs = UserPrefs.instance;
    final notFollowing = prefs.flag('mute_n_not_following');
    final notFollowingMe = prefs.flag('mute_n_not_following_me');
    final newAccount = prefs.flag('mute_n_new_account');
    final defaultPhoto = prefs.flag('mute_n_default_photo');
    final cutoff = DateTime.now().subtract(const Duration(days: 30));

    return list.where((n) {
      final id = n.actor.id;
      if (blocked.contains(id) || muted.contains(id)) return false;
      if (_wordMutes(n.postText, id, forHome: false)) return false;
      if (following.contains(id)) return true;
      if (notFollowing) return false;
      if (notFollowingMe && !followers.contains(id)) return false;
      final created = n.actor.createdAt;
      if (newAccount && created != null && created.isAfter(cutoff)) {
        return false;
      }
      if (defaultPhoto && (n.actor.avatarUrl ?? '').isEmpty) return false;
      return true;
    }).toList();
  }
}
