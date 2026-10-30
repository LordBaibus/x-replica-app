import 'dart:io' show File;
import 'dart:math' show Random, exp, log, pow;

import 'package:flutter/foundation.dart' show ValueNotifier;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config.dart';
import '../models/models.dart';
import 'image_picker_service.dart';
import 'moderation.dart';
import 'snooze_topics.dart';
import 'session_tracker.dart';
import 'user_prefs.dart';

DateTime _ts(dynamic v) =>
    DateTime.tryParse(v?.toString() ?? '')?.toLocal() ?? DateTime.now();

/// Thin wrapper around Supabase. Every backend call in the app goes through
/// here so screens stay free of query details.
/// What a tap on "Follow" led to.
enum FollowState {
  /// Not following (also after unfollowing / cancelling a request).
  none,

  /// Now following.
  following,

  /// The account is protected: a follow request is waiting for its answer.
  requested,
}

class Api {
  Api._();

  static SupabaseClient get _db => Supabase.instance.client;

  // =====================================================================
  // Auth
  // =====================================================================

  static User? get currentUser => _db.auth.currentUser;

  /// Id of the signed-in user. Only call while signed in.
  static String get uid => _db.auth.currentUser!.id;

  static String get email => _db.auth.currentUser?.email ?? '';

  /// Login token of the current session (saved for the account switcher).
  static String? get refreshToken => _db.auth.currentSession?.refreshToken;

  static Future<bool> usernameAvailable(String username) async {
    final res = await _db.rpc(
      'username_available',
      params: {'p_username': username.trim().toLowerCase()},
    );
    return res == true;
  }

  /// True when this email already has a finished account.
  static Future<bool> emailRegistered(String email) async {
    final res = await _db.rpc(
      'email_registered',
      params: {'p_email': email.trim()},
    );
    return res == true;
  }

  /// Step 1 of creating an account: emails a 6-digit code (and creates the
  /// auth user the first time). No password yet; it is chosen later in the
  /// sign-up steps, like on X.
  static Future<void> sendEmailCode(String email) async {
    await _db.auth.signInWithOtp(email: email.trim(), shouldCreateUser: true);
  }

  /// Checks the emailed code and signs the user in.
  static Future<void> verifyEmailCode({
    required String email,
    required String code,
  }) async {
    await _db.auth.verifyOTP(
      type: OtpType.email,
      email: email.trim(),
      token: code.trim(),
    );
  }

  /// Sends a fresh sign-up confirmation code.
  static Future<void> resendSignUpCode(String email) async {
    await _db.auth.resend(type: OtpType.signup, email: email.trim());
  }

  /// "Forgot password": emails a 6-digit recovery code.
  static Future<void> sendPasswordResetCode(String email) async {
    await _db.auth.resetPasswordForEmail(email.trim());
  }

  /// Verifies the recovery code. This signs the user in with a recovery
  /// session, so call [setNewPassword] next.
  static Future<void> verifyRecoveryCode({
    required String email,
    required String code,
  }) async {
    await _db.auth.verifyOTP(
      type: OtpType.recovery,
      email: email.trim(),
      token: code.trim(),
    );
  }

  /// Sets a new password for the signed-in user (after [verifyRecoveryCode]).
  static Future<void> setNewPassword(String password) async {
    await _db.auth.updateUser(UserAttributes(password: password));
  }

  static Future<void> signIn({
    required String email,
    required String password,
  }) async {
    await _db.auth.signInWithPassword(email: email.trim(), password: password);
    // Signing in again brings a deactivated account back.
    try {
      await _db
          .from('profiles')
          .update({'deactivated_at': null})
          .eq('id', uid)
          .not('deactivated_at', 'is', null);
    } catch (_) {}
  }

  static Future<void> signOut() async {
    await SessionTracker.end();
    UserPrefs.instance.reset();
    Moderation.instance.reset();
    await _db.auth.signOut();
  }

  /// Verifies the current password first, then sets the new one.
  static Future<void> changePassword({
    required String current,
    required String next,
  }) async {
    final mail = _db.auth.currentUser?.email;
    if (mail == null) throw AuthException('You are not signed in.');
    await _db.auth.signInWithPassword(email: mail, password: current);
    await _db.auth.updateUser(UserAttributes(password: next));
  }

  // =====================================================================
  // Storage
  // =====================================================================

  static Future<String> uploadImage({
    required String bucket,
    required PickedImage image,
  }) async {
    final path = '$uid/${DateTime.now().millisecondsSinceEpoch}.${image.extension}';
    await _db.storage.from(bucket).uploadBinary(
          path,
          image.bytes,
          fileOptions: FileOptions(contentType: image.contentType),
        );
    return _db.storage.from(bucket).getPublicUrl(path);
  }

  /// Uploads a video file to the `post-videos` bucket and returns its URL.
  static Future<String> uploadVideo(PickedVideo video) async {
    final path =
        '$uid/${DateTime.now().millisecondsSinceEpoch}.${video.extension}';
    await _db.storage.from(AppConfig.postVideosBucket).upload(
          path,
          File(video.path),
          fileOptions: FileOptions(contentType: video.contentType),
        );
    return _db.storage.from(AppConfig.postVideosBucket).getPublicUrl(path);
  }

  // =====================================================================
  // Profiles
  // =====================================================================

  static Future<Profile> getProfile(String id) async {
    final row =
        await _db.from('profile_stats').select().eq('id', id).single();
    return Profile.fromMap(row);
  }

  static Future<void> updateProfile({
    required String displayName,
    required String bio,
    String? avatarUrl,
  }) async {
    await _db.from('profiles').update({
      'display_name': displayName.trim(),
      'bio': bio.trim(),
      'avatar_url': ?avatarUrl,
    }).eq('id', uid);
  }

  /// Updates any of my own profile columns (used by the sign-up steps).
  /// Counts up whenever my own profile changed (protect on / off, edits), so
  /// open screens can reload it.
  static final ValueNotifier<int> profileVersion = ValueNotifier<int>(0);

  static Future<void> updateMyProfile(Map<String, dynamic> fields) async {
    await _db.from('profiles').update(fields).eq('id', uid);
    profileVersion.value++;
  }

  /// Stores the birthday in the private table (never shown to others).
  static Future<void> saveBirthday(DateTime date) async {
    String two(int n) => n.toString().padLeft(2, '0');
    await _db.from('profile_private').upsert({
      'user_id': uid,
      'birthday': '${date.year.toString().padLeft(4, '0')}-'
          '${two(date.month)}-${two(date.day)}',
    });
  }

  /// Strips characters that would break a PostgREST `or(...)` filter.
  static String _clean(String q) => q.replaceAll(RegExp(r'[,()%*\\]'), ' ').trim();

  /// People who follow [userId] (`followers: true`) or whom [userId]
  /// follows, newest first. Each row says whether that person follows me.
  static Future<List<FollowEntry>> fetchFollowList(
    String userId, {
    required bool followers,
  }) async {
    final col = followers ? 'follower_id' : 'following_id';
    final other = followers ? 'following_id' : 'follower_id';
    final links = await _db
        .from('follows')
        .select(col)
        .eq(other, userId)
        .order('created_at', ascending: false)
        .limit(300);
    final ids = links.map<String>((r) => r[col] as String).toList();
    if (ids.isEmpty) return const [];
    final rows = await _db.from('profile_stats').select().inFilter('id', ids);
    final byId = {
      for (final r in rows) r['id'] as String: Profile.fromMap(r),
    };
    final back = await _db
        .from('follows')
        .select('follower_id')
        .eq('following_id', uid)
        .inFilter('follower_id', ids);
    final followsMe = {for (final r in back) r['follower_id'] as String};
    return [
      for (final id in ids)
        if (byId[id] != null)
          FollowEntry(profile: byId[id]!, followsMe: followsMe.contains(id)),
    ];
  }

  /// Search by username / name; empty query returns recent members.
  static Future<List<Profile>> searchProfiles(String query) async {
    final q = _clean(query);
    var req =
        _db.from('profile_stats').select().neq('id', uid).eq('onboarded', true);
    if (q.isNotEmpty) {
      req = req.or('username.ilike.%$q%,display_name.ilike.%$q%');
    }
    final rows = await req.order('created_at', ascending: false).limit(40);
    return rows.map<Profile>(Profile.fromMap).toList();
  }

  /// "Who to follow": people I don't follow yet, most followed first. Each
  /// entry says who I follow that also follows them ("Sam follows").
  static Future<List<Suggestion>> suggestedProfiles({int limit = 20}) async {
    final rows = await _db
        .from('profile_stats')
        .select()
        .neq('id', uid)
        .eq('followed_by_me', false)
        .eq('onboarded', true)
        .order('follower_count', ascending: false)
        .order('created_at', ascending: false)
        .limit(limit);
    final profiles = rows.map<Profile>(Profile.fromMap).toList();
    if (profiles.isEmpty) return const [];

    final context = <String, String>{};
    final following = await followingIds();
    if (following.isNotEmpty) {
      final links = await _db
          .from('follows')
          .select('follower_id, following_id')
          .inFilter('following_id', profiles.map((x) => x.id).toList())
          .inFilter('follower_id', following);
      final firstFollower = <String, String>{};
      for (final r in links) {
        firstFollower.putIfAbsent(
          r['following_id'] as String,
          () => r['follower_id'] as String,
        );
      }
      if (firstFollower.isNotEmpty) {
        final named = await _db
            .from('profiles')
            .select('id, username, display_name')
            .inFilter('id', firstFollower.values.toSet().toList());
        final names = <String, String>{};
        for (final r in named) {
          final dn = ((r['display_name'] as String?) ?? '').trim();
          names[r['id'] as String] =
              dn.isEmpty ? (r['username'] as String? ?? '') : dn;
        }
        firstFollower.forEach((target, follower) {
          final n = names[follower];
          if (n != null && n.isNotEmpty) context[target] = '$n follows';
        });
      }
    }
    return [for (final x in profiles) Suggestion(x, context: context[x.id])];
  }

  // =====================================================================
  // Follow
  // =====================================================================

  static Future<List<String>> followingIds() async {
    final rows =
        await _db.from('follows').select('following_id').eq('follower_id', uid);
    return rows.map<String>((r) => r['following_id'] as String).toList();
  }

  /// Follows (or unfollows) [userId]. A protected account cannot be followed
  /// directly: the database refuses, so a follow request is sent instead
  /// ([FollowState.requested]). Unfollowing also takes back a waiting request.
  static Future<FollowState> setFollow(
    String userId, {
    required bool follow,
  }) async {
    if (!follow) {
      await _db
          .from('follows')
          .delete()
          .match({'follower_id': uid, 'following_id': userId});
      await _db
          .from('follow_requests')
          .delete()
          .match({'requester_id': uid, 'target_id': userId});
      return FollowState.none;
    }
    try {
      await _db
          .from('follows')
          .insert({'follower_id': uid, 'following_id': userId});
      return FollowState.following;
    } on PostgrestException catch (e) {
      // Row level security said no: the account is protected (or blocked).
      if (e.code != '42501') rethrow;
    }
    try {
      await _db.from('follow_requests').upsert(
        {'requester_id': uid, 'target_id': userId},
        onConflict: 'requester_id,target_id',
        ignoreDuplicates: true,
      );
      return FollowState.requested;
    } on PostgrestException catch (e) {
      if (e.code == '42501') {
        throw Exception('You can’t follow this account.');
      }
      rethrow;
    }
  }

  /// People who asked to follow me (my account is protected), newest first.
  static Future<List<Profile>> fetchFollowRequests() async {
    final rows = await _db
        .from('follow_requests')
        .select('requester_id, created_at')
        .eq('target_id', uid)
        .order('created_at', ascending: false)
        .limit(200);
    final ids = rows.map<String>((r) => r['requester_id'] as String).toList();
    if (ids.isEmpty) return const [];
    final profiles =
        await _db.from('profile_stats').select().inFilter('id', ids);
    final byId = {
      for (final m in profiles) m['id'] as String: Profile.fromMap(m),
    };
    return [for (final id in ids) if (byId[id] != null) byId[id]!];
  }

  static Future<int> followRequestCount() async {
    try {
      final rows = await _db
          .from('follow_requests')
          .select('requester_id')
          .eq('target_id', uid);
      return rows.length;
    } catch (_) {
      return 0;
    }
  }

  static Future<void> acceptFollowRequest(String requesterId) async {
    await _db.rpc('accept_follow_request', params: {'p_requester': requesterId});
  }

  static Future<void> acceptAllFollowRequests() async {
    await _db.rpc('accept_all_follow_requests');
  }

  static Future<void> declineFollowRequest(String requesterId) async {
    await _db
        .from('follow_requests')
        .delete()
        .match({'requester_id': requesterId, 'target_id': uid});
  }

  // =====================================================================
  // Posts
  // =====================================================================

  /// Timeline posts (replies are left out). [followingOnly] gives the
  /// "Following" timeline (people I follow + me); [keywords] narrows it to a
  /// topic by matching words in the post text.
  static Future<List<Post>> fetchFeed({
    bool followingOnly = false,
    List<String> keywords = const [],
  }) async {
    var req = _db.from('posts_feed').select().isFilter('parent_id', null);
    if (followingOnly) {
      final ids = await followingIds();
      ids.add(uid);
      req = req.inFilter('user_id', ids);
    }
    if (keywords.isNotEmpty) {
      req = req.or(keywords.map((k) => 'content.ilike.%$k%').join(','));
    }
    final rows = await req.order('created_at', ascending: false).limit(60);
    return _visible(rows.map<Post>(Post.fromMap).toList());
  }

  /// One page of a chronological timeline (newest first): the "Following"
  /// tab, or any list that is read in order. Give [before] (the time of the
  /// last post you have) to get the next page. The second value tells
  /// whether there may be more.
  static Future<(List<Post>, bool)> fetchFeedPage({
    bool followingOnly = false,
    List<String> keywords = const [],
    DateTime? before,
    int size = 20,
  }) async {
    var req = _db.from('posts_feed').select().isFilter('parent_id', null);
    if (followingOnly) {
      final ids = await followingIds();
      ids.add(uid);
      req = req.inFilter('user_id', ids);
    }
    if (keywords.isNotEmpty) {
      req = req.or(keywords.map((k) => 'content.ilike.%$k%').join(','));
    }
    if (before != null) {
      req = req.lt('created_at', before.toUtc().toIso8601String());
    }
    final rows = await req.order('created_at', ascending: false).limit(size);
    final posts = await _visible(rows.map<Post>(Post.fromMap).toList());
    return (posts, rows.length >= size);
  }

  /// The "For you" timeline: a different mix every time it is loaded.
  ///
  /// It takes the 300 newest posts and draws [size] of them at random, but
  /// not evenly: fresh posts, posts people like / repost / reply to, posts of
  /// accounts I follow and my own posts are more likely to be drawn. Pass the
  /// ids already on screen as [exclude] to get the next page when the user
  /// scrolls down; refreshing passes nothing, so the order changes.
  static Future<List<Post>> fetchForYouPage({
    List<String> keywords = const [],
    Set<String> exclude = const {},
    int size = 20,
    bool snooze = false,
  }) async {
    var req = _db.from('posts_feed').select().isFilter('parent_id', null);
    if (keywords.isNotEmpty) {
      req = req.or(keywords.map((k) => 'content.ilike.%$k%').join(','));
    }
    final rows = await req.order('created_at', ascending: false).limit(300);
    final pool = (await _visible(rows.map<Post>(Post.fromMap).toList()))
        .where((p) => !exclude.contains(p.id))
        .where((p) => !snooze || !SnoozedTopics.instance.hides(p))
        .toList();

    final rnd = Random();
    final follows = Moderation.instance.following;
    final now = DateTime.now();
    final keyed = <(double, Post)>[];
    for (final p in pool) {
      final ageHours = now.difference(p.createdAt).inMinutes.abs() / 60.0;
      final buzz = 1 + log(1 + p.likeCount + 2 * p.repostCount + p.replyCount);
      var weight = buzz * exp(-ageHours / 72) + 0.15;
      if (follows.contains(p.userId)) weight *= 2.5;
      if (p.userId == uid) weight *= 1.5;
      // Weighted draw without replacement (Efraimidis-Spirakis).
      keyed.add((pow(rnd.nextDouble(), 1 / weight).toDouble(), p));
    }
    keyed.sort((a, b) => b.$1.compareTo(a.$1));
    return [for (final k in keyed.take(size)) k.$2];
  }

  /// Leaves out posts from blocked / muted accounts and posts with muted
  /// words.
  static Future<List<Post>> _visible(List<Post> posts) async {
    await Moderation.instance.ensureLoaded();
    final shown = Moderation.instance.visiblePosts(posts);
    if (!shown.any((x) => x.communityId != null)) return shown;
    final hidden = await _hiddenCommunityPosts();
    if (hidden.isEmpty) return shown;
    return shown.where((x) => !hidden.contains(x.id)).toList();
  }

  // Posts a community moderator hid (cached for half a minute).
  static Set<String> _hiddenCache = const {};
  static DateTime _hiddenAt = DateTime.fromMillisecondsSinceEpoch(0);

  static Future<Set<String>> _hiddenCommunityPosts({bool force = false}) async {
    if (!force && DateTime.now().difference(_hiddenAt).inSeconds < 30) {
      return _hiddenCache;
    }
    try {
      final rows = await _db.from('community_hidden_posts').select('post_id');
      _hiddenCache = rows.map<String>((r) => r['post_id'] as String).toSet();
      _hiddenAt = DateTime.now();
    } catch (_) {
      // Table missing (schema section 15 not run yet): nothing is hidden.
    }
    return _hiddenCache;
  }

  /// A user's own posts (no replies).
  static Future<List<Post>> fetchUserPosts(String userId) async {
    final rows = await _db
        .from('posts_feed')
        .select()
        .eq('user_id', userId)
        .isFilter('parent_id', null)
        .order('created_at', ascending: false)
        .limit(60);
    return rows.map<Post>(Post.fromMap).toList();
  }

  /// Replies written by a user.
  static Future<List<Post>> fetchUserReplies(String userId) async {
    final rows = await _db
        .from('posts_feed')
        .select()
        .eq('user_id', userId)
        .not('parent_id', 'is', null)
        .order('created_at', ascending: false)
        .limit(60);
    return rows.map<Post>(Post.fromMap).toList();
  }

  /// Replies under one post, oldest first.
  static Future<List<Post>> fetchReplies(String postId) async {
    final rows = await _db
        .from('posts_feed')
        .select()
        .eq('parent_id', postId)
        .order('created_at', ascending: true)
        .limit(100);
    return rows.map<Post>(Post.fromMap).toList();
  }

  /// Posts that quote [postId], newest first.
  static Future<List<Post>> fetchQuotes(String postId) async {
    final rows = await _db
        .from('posts_feed')
        .select()
        .eq('quote_id', postId)
        .order('created_at', ascending: false)
        .limit(60);
    return _visible(rows.map<Post>(Post.fromMap).toList());
  }

  /// Changes the text of my own post (allowed for one hour; the database
  /// enforces it and sets `edited_at`).
  static Future<Post> updatePostContent(String postId, String content) async {
    final text = content.trim();
    await _db.from('posts').update({'content': text}).eq('id', postId).eq('user_id', uid);
    final fresh = await fetchPost(postId);
    if (fresh == null) throw Exception('Post not found.');
    return fresh;
  }

  // ---- analytics, reports and Community Notes ---------------------------

  /// Counts one thing people do with a post (the author sees the totals in
  /// "Post analytics"). Never throws: it is only a statistic.
  static Future<void> logPostEvent(String postId, String kind) async {
    try {
      await _db.from('post_events').insert({
        'post_id': postId,
        'user_id': uid,
        'kind': kind,
      });
    } catch (_) {}
  }

  static Future<PostAnalytics> fetchPostAnalytics(String postId) async {
    final res = await _db.rpc('post_analytics', params: {'p_post': postId});
    return PostAnalytics.fromMap(Map<String, dynamic>.from(res as Map));
  }

  /// Saves a report about a post (the team reads it in the dashboard).
  static Future<void> reportPost(
    Post post,
    String reason, {
    String? details,
  }) async {
    await _db.from('reports').upsert(
      {
        'reporter_id': uid,
        'post_id': post.id,
        'reported_user_id': post.userId,
        'reason': reason.length > 80 ? reason.substring(0, 80) : reason,
        if (details != null && details.trim().isNotEmpty)
          'details': details.trim(),
      },
      onConflict: 'reporter_id,post_id,reason',
      ignoreDuplicates: true,
    );
  }

  /// "Request Community Note".
  static Future<void> requestNote(
    String postId, {
    String? source,
    String? reason,
  }) async {
    await _db.from('note_requests').upsert(
      {
        'post_id': postId,
        'user_id': uid,
        if (source != null && source.trim().isNotEmpty)
          'source_url': source.trim(),
        if (reason != null && reason.trim().isNotEmpty)
          'reason': reason.trim(),
      },
      onConflict: 'post_id,user_id',
    );
  }

  static Future<int> noteRequestCount(String postId) async {
    final rows =
        await _db.from('note_requests').select('user_id').eq('post_id', postId);
    return rows.length;
  }

  static Future<List<CommunityNote>> fetchNotes(String postId) async {
    final rows = await _db
        .from('community_notes_view')
        .select()
        .eq('post_id', postId)
        .order('helpful_count', ascending: false)
        .order('created_at', ascending: false);
    return rows.map<CommunityNote>(CommunityNote.fromMap).toList();
  }

  static Future<void> addNote(
    String postId,
    String body, {
    String? source,
  }) async {
    await _db.from('community_notes').insert({
      'post_id': postId,
      'author_id': uid,
      'body': body.trim(),
      if (source != null && source.trim().isNotEmpty)
        'source_url': source.trim(),
    });
  }

  static Future<void> deleteNote(String noteId) async {
    await _db.from('community_notes').delete().eq('id', noteId);
  }

  /// Rates a note; null takes the rating back.
  static Future<void> rateNote(String noteId, bool? helpful) async {
    if (helpful == null) {
      await _db
          .from('note_ratings')
          .delete()
          .eq('note_id', noteId)
          .eq('user_id', uid);
      return;
    }
    await _db.from('note_ratings').upsert({
      'note_id': noteId,
      'user_id': uid,
      'helpful': helpful,
    });
  }

  /// Accounts that reposted [postId], newest repost first.
  static Future<List<Profile>> fetchReposters(String postId) async {
    final rows = await _db
        .from('reposts')
        .select('user_id, created_at')
        .eq('post_id', postId)
        .order('created_at', ascending: false)
        .limit(100);
    final ids = rows.map<String>((r) => r['user_id'] as String).toList();
    if (ids.isEmpty) return const [];
    final profiles =
        await _db.from('profile_stats').select().inFilter('id', ids);
    final byId = {
      for (final m in profiles) m['id'] as String: Profile.fromMap(m),
    };
    return [for (final id in ids) if (byId[id] != null) byId[id]!];
  }

  static Future<Post?> fetchPost(String postId) async {
    final row =
        await _db.from('posts_feed').select().eq('id', postId).maybeSingle();
    return row == null ? null : Post.fromMap(row);
  }

  /// Videos posted before [after] (newest first), for "Auto-advance" in the
  /// full-screen player. Blocked / muted authors are left out.
  static Future<List<Post>> fetchOlderVideoPosts(Post after) async {
    final rows = await _db
        .from('posts_feed')
        .select()
        .not('video_url', 'is', null)
        .lt('created_at', after.createdAt.toUtc().toIso8601String())
        .order('created_at', ascending: false)
        .limit(12);
    final mod = Moderation.instance;
    return [
      for (final r in rows)
        if (!mod.blocked.contains(r['user_id']) &&
            !mod.muted.contains(r['user_id']))
          Post.fromMap(r),
    ];
  }

  /// Posts that [userId] reposted, newest repost first.
  static Future<List<Post>> fetchUserReposts(String userId) async {
    final marks = await _db
        .from('reposts')
        .select('post_id, created_at')
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(60);
    return _postsInOrder(marks.map<String>((r) => r['post_id'] as String));
  }

  /// Posts whose text contains [query].
  static Future<List<Post>> searchPosts(String query) async {
    final q = _clean(query);
    if (q.isEmpty) return const [];
    final rows = await _db
        .from('posts_feed')
        .select()
        .ilike('content', '%$q%')
        .order('created_at', ascending: false)
        .limit(60);
    return _visible(rows.map<Post>(Post.fromMap).toList());
  }

  /// Hashtags used most in the latest posts.
  static Future<List<TrendingTag>> fetchTrending({int limit = 20}) async {
    final rows = await _db
        .from('posts')
        .select('content')
        .order('created_at', ascending: false)
        .limit(300);
    final re = RegExp(r'#[A-Za-z0-9_]+');
    final counts = <String, int>{};
    final shown = <String, String>{};
    for (final r in rows) {
      final seen = <String>{};
      for (final m in re.allMatches((r['content'] as String?) ?? '')) {
        final tag = m.group(0)!;
        final key = tag.toLowerCase();
        if (seen.add(key)) {
          counts[key] = (counts[key] ?? 0) + 1;
          shown.putIfAbsent(key, () => tag);
        }
      }
    }
    final keys = counts.keys.toList()
      ..sort((a, b) => counts[b]!.compareTo(counts[a]!));
    return [for (final k in keys.take(limit)) TrendingTag(shown[k]!, counts[k]!)];
  }

  /// Counts one view for each of these posts.
  static Future<void> bumpViews(List<String> postIds) async {
    if (postIds.isEmpty) return;
    try {
      await _db.rpc('bump_views', params: {'p_ids': postIds});
    } catch (_) {
      // View counts are cosmetic; never break the feed over them.
    }
  }

  /// Loads posts by id and returns them in the order of [ids].
  static Future<List<Post>> _postsInOrder(Iterable<String> ids) async {
    final list = ids.toList();
    if (list.isEmpty) return const [];
    final rows = await _db.from('posts_feed').select().inFilter('id', list);
    final byId = <String, Post>{
      for (final r in rows) r['id'] as String: Post.fromMap(r),
    };
    return [
      for (final id in list)
        if (byId[id] != null) byId[id]!,
    ];
  }

  static Future<void> setRepost(String postId, {required bool reposted}) async {
    if (reposted) {
      await _db.from('reposts').insert({'post_id': postId, 'user_id': uid});
    } else {
      await _db
          .from('reposts')
          .delete()
          .match({'post_id': postId, 'user_id': uid});
    }
  }

  static Future<void> setBookmark(String postId, {required bool bookmarked}) async {
    if (bookmarked) {
      await _db.from('bookmarks').insert({'post_id': postId, 'user_id': uid});
    } else {
      await _db
          .from('bookmarks')
          .delete()
          .match({'post_id': postId, 'user_id': uid});
    }
  }

  /// My saved posts, most recently saved first.
  static Future<List<Post>> fetchBookmarks() async {
    final marks = await _db
        .from('bookmarks')
        .select('post_id, created_at')
        .eq('user_id', uid)
        .order('created_at', ascending: false)
        .limit(100);
    return _postsInOrder(marks.map<String>((r) => r['post_id'] as String));
  }

  /// Posts that [userId] has liked, newest like first.
  static Future<List<Post>> fetchUserLikes(String userId) async {
    final likes = await _db
        .from('post_likes')
        .select('post_id, created_at')
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(60);
    return _postsInOrder(likes.map<String>((r) => r['post_id'] as String));
  }

  /// Saves a post (plus its poll options) and returns the new post's id.
  ///
  /// Optional columns are only sent when they are used, so plain posts keep
  /// working even on a database that has not got the newest columns yet.
  static Future<String> createPost({
    required String content,
    List<PickedImage> images = const [],
    List<String> extraUrls = const [],
    PickedVideo? video,
    String? parentId,
    String? communityId,
    String replySetting = 'everyone',
    String? location,
    bool paidPartnership = false,
    bool madeWithAi = false,
    DateTime? scheduledAt,
    String? quoteId,
    List<String> pollOptions = const [],
    Duration pollDuration = const Duration(days: 1),
  }) async {
    // Up to 4 media: uploaded photos first, then GIF links (already online).
    final urls = <String>[];
    for (final img in images) {
      urls.add(
        await uploadImage(bucket: AppConfig.postImagesBucket, image: img),
      );
    }
    urls.addAll(extraUrls);
    if (urls.length > 4) urls.removeRange(4, urls.length);
    final url = urls.isEmpty ? null : urls.first;
    final videoUrl = video == null ? null : await uploadVideo(video);
    final options =
        pollOptions.map((o) => o.trim()).where((o) => o.isNotEmpty).toList();

    final row = await _db
        .from('posts')
        .insert({
          'user_id': uid,
          'content': content.trim(),
          'image_url': url,
          if (urls.length > 1) 'image_urls': urls,
          'video_url': ?videoUrl,
          'parent_id': ?parentId,
          'community_id': ?communityId,
          if (replySetting != 'everyone') 'reply_setting': replySetting,
          if (location != null && location.trim().isNotEmpty)
            'location': location.trim(),
          if (paidPartnership) 'paid_partnership': true,
          if (madeWithAi) 'made_with_ai': true,
          if (scheduledAt != null)
            'scheduled_at': scheduledAt.toUtc().toIso8601String(),
          'quote_id': ?quoteId,
          if (options.length >= 2)
            'poll_ends_at':
                DateTime.now().add(pollDuration).toUtc().toIso8601String(),
        })
        .select('id')
        .single();
    final id = row['id'] as String;

    if (options.length >= 2) {
      try {
        await _db.from('poll_options').insert([
          for (var i = 0; i < options.length; i++)
            {'post_id': id, 'label': options[i], 'position': i},
        ]);
      } catch (_) {
        // Do not leave a poll post without answers behind.
        await _db.from('posts').delete().eq('id', id);
        rethrow;
      }
    }
    return id;
  }

  /// Why I may not reply to [post] (null = I can).
  static Future<String?> replyBlockedReason(Post post) async {
    if (post.userId == uid || post.replySetting == 'everyone') return null;
    switch (post.replySetting) {
      case 'following':
        final row = await _db
            .from('follows')
            .select('follower_id')
            .eq('follower_id', post.userId)
            .eq('following_id', uid)
            .maybeSingle();
        return row == null
            ? 'Only accounts @${post.username} follows can reply.'
            : null;
      case 'mentioned':
        final me = await getProfile(uid);
        return post.content.toLowerCase().contains('@${me.username}'.toLowerCase())
            ? null
            : 'Only accounts @${post.username} mentioned can reply.';
      default:
        return 'Only verified accounts can reply.';
    }
  }

  /// Answers of a poll with their vote counts.
  static Future<List<PollOption>> fetchPollResults(String postId) async {
    final rows = await _db.rpc('poll_results', params: {'p_post': postId})
        as List<dynamic>;
    return rows
        .map<PollOption>(
            (r) => PollOption.fromMap((r as Map).cast<String, dynamic>()))
        .toList();
  }

  static Future<void> votePoll(String postId, String optionId) async {
    await _db.from('poll_votes').insert({
      'post_id': postId,
      'option_id': optionId,
      'user_id': uid,
    });
  }

  /// My posts that wait for their publishing time.
  static Future<List<Post>> fetchScheduledPosts() async {
    final rows = await _db
        .from('posts')
        .select()
        .eq('user_id', uid)
        .gt('scheduled_at', DateTime.now().toUtc().toIso8601String())
        .order('scheduled_at', ascending: true);
    final me = await getProfile(uid);
    return rows
        .map<Post>((r) => Post.fromMap({
              ...r,
              'username': me.username,
              'display_name': me.displayName,
              'avatar_url': me.avatarUrl,
            }))
        .toList();
  }

  /// Recent posts to pick from when quoting (optionally filtered).
  static Future<List<Post>> fetchQuotablePosts(String query) async {
    final q = _clean(query);
    var req = _db.from('posts_feed').select().isFilter('parent_id', null);
    if (q.isNotEmpty) {
      req = req.or('content.ilike.%$q%,username.ilike.%$q%,display_name.ilike.%$q%');
    }
    final rows = await req.order('created_at', ascending: false).limit(40);
    return rows.map<Post>(Post.fromMap).toList();
  }

  static Future<void> deletePost(String postId) async {
    await _db.from('posts').delete().eq('id', postId).eq('user_id', uid);
  }

  static Future<void> setLike(String postId, {required bool like}) async {
    if (like) {
      await _db.from('post_likes').insert({'post_id': postId, 'user_id': uid});
    } else {
      await _db
          .from('post_likes')
          .delete()
          .match({'post_id': postId, 'user_id': uid});
    }
  }

  // =====================================================================
  // Notifications (derived from likes, follows and @mentions)
  // =====================================================================

  static Future<List<AppNotification>> fetchNotifications() async {
    final me = uid;

    // Likes on my posts.
    final mine = await _db
        .from('posts')
        .select('id, content, image_url')
        .eq('user_id', me)
        .order('created_at', ascending: false)
        .limit(100);
    final postById = <String, Map<String, dynamic>>{
      for (final r in mine) r['id'] as String: r,
    };
    final likeRows = postById.isEmpty
        ? <Map<String, dynamic>>[]
        : await _db
            .from('post_likes')
            .select('post_id, user_id, created_at')
            .inFilter('post_id', postById.keys.toList())
            .neq('user_id', me)
            .order('created_at', ascending: false)
            .limit(60);

    // New followers.
    final followRows = await _db
        .from('follows')
        .select('follower_id, created_at')
        .eq('following_id', me)
        .order('created_at', ascending: false)
        .limit(60);

    // Posts that contain "@myusername".
    final self = await _db.from('profiles').select('username').eq('id', me).single();
    final handle = (self['username'] as String?) ?? '';
    final mentionRows = handle.isEmpty
        ? <Map<String, dynamic>>[]
        : await _db
            .from('posts_feed')
            .select()
            .neq('user_id', me)
            .ilike('content', '%@$handle%')
            .order('created_at', ascending: false)
            .limit(40);
    final mentionRe = RegExp(
      '(^|[^a-z0-9_])@${RegExp.escape(handle)}(?![a-z0-9_])',
      caseSensitive: false,
    );

    // Who did it.
    final actorIds = <String>{
      for (final r in likeRows) r['user_id'] as String,
      for (final r in followRows) r['follower_id'] as String,
    };
    final actors = <String, Profile>{};
    if (actorIds.isNotEmpty) {
      final rows = await _db
          .from('profiles')
          .select('id, username, display_name, avatar_url, created_at')
          .inFilter('id', actorIds.toList());
      for (final r in rows) {
        actors[r['id'] as String] = Profile.fromMap(r);
      }
    }

    final out = <AppNotification>[];
    for (final r in likeRows) {
      final actor = actors[r['user_id'] as String];
      final post = postById[r['post_id'] as String];
      if (actor == null || post == null) continue;
      out.add(AppNotification(
        kind: NotificationKind.like,
        actor: actor,
        createdAt: _ts(r['created_at']),
        postText: (post['content'] as String?) ?? '',
        postImageUrl: post['image_url'] as String?,
      ));
    }
    for (final r in followRows) {
      final actor = actors[r['follower_id'] as String];
      if (actor == null) continue;
      out.add(AppNotification(
        kind: NotificationKind.follow,
        actor: actor,
        createdAt: _ts(r['created_at']),
      ));
    }
    for (final r in mentionRows) {
      final post = Post.fromMap(r);
      if (!mentionRe.hasMatch(post.content)) continue;
      out.add(AppNotification(
        kind: NotificationKind.mention,
        actor: Profile(
          id: post.userId,
          username: post.username,
          displayName: post.displayName,
          avatarUrl: post.avatarUrl,
        ),
        createdAt: post.createdAt,
        postText: post.content,
        postImageUrl: post.imageUrl,
      ));
    }
    out.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    await Moderation.instance.ensureLoaded();
    return Moderation.instance.visibleNotifications(out);
  }

  // =====================================================================
  // Direct messages
  // =====================================================================

  static Future<List<Conversation>> fetchConversations() async {
    final rows = await _db.rpc('my_conversations') as List<dynamic>;
    return rows
        .map<Conversation>(
            (r) => Conversation.fromMap((r as Map).cast<String, dynamic>()))
        .toList();
  }

  /// When I last "deleted" this chat (null = never).
  static Future<DateTime?> _clearedAt(String chatId) async {
    try {
      final row = await _db
          .from('chat_prefs')
          .select('cleared_at')
          .eq('user_id', uid)
          .eq('chat_id', chatId)
          .maybeSingle();
      final v = row?['cleared_at'];
      return v == null ? null : _parseTime(v);
    } catch (_) {
      return null;
    }
  }

  static DateTime _parseTime(dynamic v) => DateTime.parse(v as String);

  static Future<List<Message>> fetchMessages(
    String partnerId, {
    int limit = 300,
    bool newest = false,
  }) async {
    final me = uid;
    final cleared = await _clearedAt(partnerId);
    var req = _db.from('messages').select().or(
        'and(sender_id.eq.$me,receiver_id.eq.$partnerId),'
        'and(sender_id.eq.$partnerId,receiver_id.eq.$me)');
    if (cleared != null) {
      req = req.gt('created_at', cleared.toUtc().toIso8601String());
    }
    final rows =
        await req.order('created_at', ascending: !newest).limit(limit);
    final list = rows.map<Message>(Message.fromMap).toList();
    return newest ? list.reversed.toList() : list;
  }

  static Future<Message> sendMessage(
    String partnerId,
    String text, {
    String? replyTo,
  }) async {
    try {
      final row = await _db
          .from('messages')
          .insert({
            'sender_id': uid,
            'receiver_id': partnerId,
            'content': text.trim(),
            'reply_to': ?replyTo,
          })
          .select()
          .single();
      return Message.fromMap(row);
    } on PostgrestException catch (e) {
      // Row level security said no: blocked, or "Message Requests" is closed.
      if (e.code == '42501') {
        throw Exception('You can’t send messages to this account.');
      }
      rethrow;
    }
  }

  /// False when [partnerId] has a closed inbox for me (or blocked me), so a
  /// message could not be sent. Errs on the side of "yes" when unsure.
  static Future<bool> canMessage(String partnerId) async {
    try {
      final res = await _db.rpc(
        'can_message',
        params: {'p_sender': uid, 'p_receiver': partnerId},
      );
      return res != false;
    } catch (_) {
      return true;
    }
  }

  /// People a post can be sent to: recent chats first, then people I follow.
  static Future<List<Profile>> shareTargets() async {
    final out = <Profile>[];
    final seen = <String>{};
    try {
      for (final c in await fetchConversations()) {
        if (seen.add(c.partnerId)) out.add(c.partner);
      }
    } catch (_) {}
    try {
      final ids = await followingIds();
      final rest = ids.where((i) => !seen.contains(i)).take(40).toList();
      if (rest.isNotEmpty) {
        final rows =
            await _db.from('profile_stats').select().inFilter('id', rest);
        for (final r in rows) {
          final pr = Profile.fromMap(r);
          if (seen.add(pr.id)) out.add(pr);
        }
      }
    } catch (_) {}
    return out;
  }

  /// "Mark All Read" in the Chat filter menu.
  static Future<void> markAllRead() async {
    await _db
        .from('messages')
        .update({'read_at': DateTime.now().toUtc().toIso8601String()})
        .eq('receiver_id', uid)
        .isFilter('read_at', null);
    try {
      await _db.rpc('mark_all_groups_read');
    } catch (_) {
      // Groups are optional; DMs were already marked.
    }
  }

  // ---------------------------------------------------------------------
  // Support: Contact us, Report a problem, ID verification, data archive
  // ---------------------------------------------------------------------

  /// kind: contact | problem | verification
  static Future<void> submitTicket({
    required String kind,
    required String subject,
    required String message,
  }) async {
    await _db.from('support_tickets').insert({
      'kind': kind,
      'subject': subject.trim(),
      'message': message.trim(),
    });
  }

  /// My requests, newest first ([kinds] limits which ones).
  static Future<List<SupportTicket>> fetchTickets({List<String>? kinds}) async {
    var req = _db.from('support_tickets').select().eq('user_id', uid);
    if (kinds != null) req = req.inFilter('kind', kinds);
    final rows = await req.order('created_at', ascending: false).limit(50);
    return rows.map<SupportTicket>(SupportTicket.fromMap).toList();
  }

  /// Everything the app stores about me, as JSON (for "Download an archive").
  static Future<Map<String, dynamic>> exportMyData() async {
    final res = await _db.rpc('export_my_data');
    return Map<String, dynamic>.from(res as Map);
  }

  // ---------------------------------------------------------------------
  // Chat list options (long-press): pin / mute / archive / unread / delete
  // ---------------------------------------------------------------------

  /// My options for every chat that has any: chat id -> options.
  static Future<Map<String, ChatPref>> fetchChatPrefs() async {
    final rows = await _db.from('chat_prefs').select().eq('user_id', uid);
    return {
      for (final r in rows) r['chat_id'] as String: ChatPref.fromMap(r),
    };
  }

  /// Changes only the options that are passed.
  static Future<void> setChatPref(
    String chatId, {
    bool? pinned,
    bool? muted,
    bool? archived,
    bool? markedUnread,
    DateTime? clearedAt,
  }) async {
    await _db.from('chat_prefs').upsert({
      'user_id': uid,
      'chat_id': chatId,
      'pinned': ?pinned,
      'muted': ?muted,
      'archived': ?archived,
      'marked_unread': ?markedUnread,
      if (clearedAt != null)
        'cleared_at': clearedAt.toUtc().toIso8601String(),
    });
  }

  /// "Delete conversation": hides everything up to now for me only.
  static Future<void> clearConversation(String chatId) => setChatPref(
        chatId,
        pinned: false,
        archived: false,
        markedUnread: false,
        clearedAt: DateTime.now(),
      );

  // ---------------------------------------------------------------------
  // Group chats
  // ---------------------------------------------------------------------

  /// Creates a group (I become its admin) and returns its id.
  static Future<String> createGroup(String name, List<String> memberIds) async {
    final id = await _db.rpc(
      'create_group',
      params: {'p_name': name.trim(), 'p_members': memberIds},
    );
    return id as String;
  }

  static Future<List<GroupChat>> fetchGroups() async {
    final rows = await _db.rpc('my_groups') as List<dynamic>;
    return rows
        .map<GroupChat>(
            (r) => GroupChat.fromMap((r as Map).cast<String, dynamic>()))
        .toList();
  }

  static Future<List<GroupMessage>> fetchGroupMessages(
    String groupId, {
    int limit = 300,
    bool newest = false,
  }) async {
    final cleared = await _clearedAt(groupId);
    var req = _db.from('group_messages').select().eq('group_id', groupId);
    if (cleared != null) {
      req = req.gt('created_at', cleared.toUtc().toIso8601String());
    }
    final rows =
        await req.order('created_at', ascending: !newest).limit(limit);
    final list = rows.map<GroupMessage>(GroupMessage.fromMap).toList();
    return newest ? list.reversed.toList() : list;
  }

  static Future<GroupMessage> sendGroupMessage(
    String groupId,
    String text,
  ) async {
    final row = await _db
        .from('group_messages')
        .insert({
          'group_id': groupId,
          'sender_id': uid,
          'content': text.trim(),
        })
        .select()
        .single();
    return GroupMessage.fromMap(row);
  }

  static Future<List<GroupMember>> fetchGroupMembers(String groupId) async {
    final rows = await _db
        .rpc('group_member_list', params: {'p_group': groupId}) as List<dynamic>;
    return rows
        .map<GroupMember>(
            (r) => GroupMember.fromMap((r as Map).cast<String, dynamic>()))
        .toList();
  }

  static Future<void> markGroupRead(String groupId) =>
      _db.rpc('mark_group_read', params: {'p_group': groupId});

  static Future<void> leaveGroup(String groupId) =>
      _db.rpc('leave_group', params: {'p_group': groupId});

  static Future<void> renameGroup(String groupId, String name) => _db.rpc(
        'rename_group',
        params: {'p_group': groupId, 'p_name': name.trim()},
      );

  static Future<void> addGroupMembers(String groupId, List<String> ids) =>
      _db.rpc(
        'add_group_members',
        params: {'p_group': groupId, 'p_members': ids},
      );

  static Future<void> removeGroupMember(String groupId, String userId) =>
      _db.rpc(
        'remove_group_member',
        params: {'p_group': groupId, 'p_user': userId},
      );

  /// Calls [onMessage] for every new message in a group I'm in (row level
  /// security makes sure only members receive it).
  static RealtimeChannel subscribeGroupMessages(
    void Function(GroupMessage m) onMessage,
  ) {
    return _db
        .channel('group-messages-${DateTime.now().microsecondsSinceEpoch}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'group_messages',
          callback: (payload) {
            try {
              onMessage(GroupMessage.fromMap(payload.newRecord));
            } catch (_) {}
          },
        )
        .subscribe();
  }

  /// Reactions on these messages: message id -> (user id -> emoji).
  static Future<Map<String, Map<String, String>>> fetchReactions(
    List<String> messageIds,
  ) async {
    if (messageIds.isEmpty) return const {};
    final rows = await _db
        .from('message_reactions')
        .select('message_id, user_id, emoji')
        .inFilter('message_id', messageIds);
    final out = <String, Map<String, String>>{};
    for (final r in rows) {
      (out[r['message_id'] as String] ??= {})[r['user_id'] as String] =
          r['emoji'] as String;
    }
    return out;
  }

  /// Sets my reaction on a message; null removes it.
  static Future<void> setReaction(String messageId, String? emoji) async {
    if (emoji == null) {
      await _db
          .from('message_reactions')
          .delete()
          .eq('message_id', messageId)
          .eq('user_id', uid);
      return;
    }
    await _db.from('message_reactions').upsert({
      'message_id': messageId,
      'user_id': uid,
      'emoji': emoji,
    });
  }

  /// Calls [onChange] whenever someone reacts to / un-reacts from a message
  /// of mine.
  static RealtimeChannel subscribeReactions(void Function() onChange) {
    return _db
        .channel('reactions-${DateTime.now().microsecondsSinceEpoch}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'message_reactions',
          callback: (_) => onChange(),
        )
        .subscribe();
  }

  static Future<void> markRead(String partnerId) async {
    await _db
        .from('messages')
        .update({'read_at': DateTime.now().toUtc().toIso8601String()})
        .eq('sender_id', partnerId)
        .eq('receiver_id', uid)
        .isFilter('read_at', null);
  }

  // =====================================================================
  // Realtime
  // =====================================================================

  /// Calls [onMessage] for every new message that involves the signed-in user
  /// (Row level security guarantees only the participants receive it).
  static RealtimeChannel subscribeMessages(void Function(Message m) onMessage) {
    return _db
        .channel('messages-${DateTime.now().microsecondsSinceEpoch}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          callback: (payload) {
            try {
              onMessage(Message.fromMap(payload.newRecord));
            } catch (_) {}
          },
        )
        .subscribe();
  }

  /// Calls [onChange] whenever posts change.
  static RealtimeChannel subscribeFeed(void Function() onChange) {
    return _db
        .channel('feed-${DateTime.now().microsecondsSinceEpoch}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'posts',
          callback: (_) => onChange(),
        )
        .subscribe();
  }

  // =====================================================================
  // Notes (24-hour status)
  // =====================================================================

  /// Active notes I may see: mine and the ones of people I follow,
  /// newest first. Expired notes are filtered by the database.
  static Future<List<StatusNote>> fetchStatusNotes() async {
    final rows = await _db
        .from('status_notes_feed')
        .select()
        .order('created_at', ascending: false)
        .limit(100);
    return rows
        .map<StatusNote>((r) => StatusNote.fromMap(r))
        .where((n) => !n.isExpired)
        .toList();
  }

  /// Creates or replaces my note (restarts the 24 hours).
  static Future<void> setStatusNote(String text) async {
    final t = text.trim();
    if (t.isEmpty) throw Exception('Write something first.');
    if (t.length > StatusNote.maxLength) {
      throw Exception(
          'A note can have at most ${StatusNote.maxLength} characters.');
    }
    await _db.rpc('set_status_note', params: {'p_content': t});
  }

  static Future<void> deleteStatusNote() => _db.rpc('delete_status_note');

  /// Answering a note starts (or continues) a direct message with its author.
  static Future<Message> replyToStatusNote(StatusNote note, String text) {
    return sendMessage(
      note.userId,
      'Replied to your note: “${note.content}”\n\n${text.trim()}',
    );
  }

  /// Calls [onChange] whenever a note is added, replaced or removed.
  static RealtimeChannel subscribeStatusNotes(void Function() onChange) {
    return _db
        .channel('notes-${DateTime.now().microsecondsSinceEpoch}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'status_notes',
          callback: (_) => onChange(),
        )
        .subscribe();
  }

  static Future<void> unsubscribe(RealtimeChannel channel) =>
      _db.removeChannel(channel);

  // =====================================================================
  // Communities
  // =====================================================================

  /// Communities, biggest first. [joinedOnly] keeps the ones I'm in,
  /// [notJoined] the ones I'm not.
  static Future<List<Community>> fetchCommunities({
    bool joinedOnly = false,
    bool notJoined = false,
    String? category,
  }) async {
    var req = _db.from('community_stats').select();
    if (joinedOnly) req = req.eq('joined_by_me', true);
    if (notJoined) req = req.eq('joined_by_me', false);
    if (category != null) req = req.eq('category', category);
    final rows = await req.order('member_count', ascending: false).limit(50);
    return rows.map<Community>(Community.fromMap).toList();
  }

  static Future<Community?> fetchCommunity(String id) async {
    final row = await _db
        .from('community_stats')
        .select()
        .eq('id', id)
        .maybeSingle();
    return row == null ? null : Community.fromMap(row);
  }

  /// Creates a community (I become its admin) and returns its id. A
  /// community needs 1 to 10 [rules].
  static Future<String> createCommunity({
    required String name,
    String description = '',
    String category = 'General',
    String joinPolicy = 'open',
    PickedImage? cover,
    required List<CommunityRule> rules,
  }) async {
    String? coverUrl;
    if (cover != null) {
      coverUrl =
          await uploadImage(bucket: AppConfig.avatarsBucket, image: cover);
    }
    final id = await _db.rpc('create_community', params: {
      'p_name': name.trim(),
      'p_description': description.trim(),
      'p_category': category,
      'p_join_policy': joinPolicy,
      'p_cover_url': coverUrl,
      'p_image_url': coverUrl,
      'p_rules': rules.map((r) => r.toMap()).toList(),
    });
    return id as String;
  }

  /// Admin: change name, description, topic, membership and cover, and
  /// replace the rules.
  static Future<void> updateCommunity(
    String id, {
    required String name,
    required String description,
    required String category,
    required String joinPolicy,
    PickedImage? newCover,
    required List<CommunityRule> rules,
  }) async {
    final fields = <String, dynamic>{
      'name': name.trim(),
      'description': description.trim(),
      'category': category,
      'join_policy': joinPolicy,
    };
    if (newCover != null) {
      final url =
          await uploadImage(bucket: AppConfig.avatarsBucket, image: newCover);
      fields['cover_url'] = url;
      fields['image_url'] = url;
    }
    try {
      await _db.from('communities').update(fields).eq('id', id);
    } on PostgrestException catch (e) {
      if (e.code == '23505') {
        throw Exception('A Community with that name already exists.');
      }
      rethrow;
    }
    await _db.rpc('set_community_rules', params: {
      'p_community': id,
      'p_rules': rules.map((r) => r.toMap()).toList(),
    });
  }

  static Future<void> deleteCommunity(String id) async {
    await _db.from('communities').delete().eq('id', id).eq('owner_id', uid);
  }

  static Future<List<CommunityRule>> fetchCommunityRules(String id) async {
    final rows = await _db
        .from('community_rules')
        .select()
        .eq('community_id', id)
        .order('position');
    return rows.map<CommunityRule>(CommunityRule.fromMap).toList();
  }

  /// Join: returns `joined` (open community) or `requested` (restricted).
  static Future<String> joinCommunity(String id) async {
    final res = await _db.rpc('join_community', params: {'p_community': id});
    return res as String;
  }

  static Future<void> cancelJoinRequest(String id) =>
      _db.rpc('cancel_join_request', params: {'p_community': id});

  static Future<void> leaveCommunity(String id) =>
      _db.rpc('leave_community', params: {'p_community': id});

  /// Everybody in a community, admin first, then moderators.
  static Future<List<CommunityMember>> fetchCommunityMembers(String id) async {
    final rows = await _db
        .from('community_member_list')
        .select()
        .eq('community_id', id)
        .order('joined_at')
        .limit(500);
    final list = rows.map<CommunityMember>(CommunityMember.fromMap).toList();
    int rank(String r) => r == 'admin' ? 0 : (r == 'moderator' ? 1 : 2);
    list.sort((a, b) => rank(a.role).compareTo(rank(b.role)));
    return list;
  }

  /// Pending join requests (moderators only).
  static Future<List<CommunityMember>> fetchJoinRequests(String id) async {
    final rows = await _db
        .from('community_request_list')
        .select()
        .eq('community_id', id)
        .order('created_at');
    return rows.map<CommunityMember>(CommunityMember.fromMap).toList();
  }

  static Future<void> reviewJoinRequest(
    String communityId,
    String userId, {
    required bool approve,
  }) =>
      _db.rpc('review_join_request', params: {
        'p_community': communityId,
        'p_user': userId,
        'p_approve': approve,
      });

  static Future<void> setCommunityRole(
    String communityId,
    String userId,
    String role,
  ) =>
      _db.rpc('set_community_role', params: {
        'p_community': communityId,
        'p_user': userId,
        'p_role': role,
      });

  static Future<void> removeCommunityMember(
    String communityId,
    String userId,
  ) =>
      _db.rpc('remove_community_member', params: {
        'p_community': communityId,
        'p_user': userId,
      });

  /// Moderators: hide a post that breaks a community rule.
  static Future<void> hideCommunityPost(String postId, {String? reason}) async {
    await _db.rpc('hide_community_post', params: {
      'p_post': postId,
      'p_reason': reason,
    });
    _hiddenAt = DateTime.fromMillisecondsSinceEpoch(0);
  }

  static Future<void> unhideCommunityPost(String postId) async {
    await _db.rpc('unhide_community_post', params: {'p_post': postId});
    _hiddenAt = DateTime.fromMillisecondsSinceEpoch(0);
  }

  /// Posts hidden in one community (moderators review them).
  static Future<List<Post>> fetchHiddenCommunityPosts(String id) async {
    final rows = await _db
        .from('community_hidden_posts')
        .select('post_id')
        .eq('community_id', id);
    final ids = rows.map<String>((r) => r['post_id'] as String).toList();
    if (ids.isEmpty) return const [];
    final posts = await _db
        .from('posts_feed')
        .select()
        .inFilter('id', ids)
        .order('created_at', ascending: false);
    return posts.map<Post>(Post.fromMap).toList();
  }

  /// Posts written inside one community (hidden ones left out), newest
  /// first. "Top" and "Media" are sorted / filtered by the screen.
  static Future<List<Post>> fetchCommunityPosts(String communityId) async {
    final rows = await _db
        .from('posts_feed')
        .select()
        .eq('community_id', communityId)
        .isFilter('parent_id', null)
        .order('created_at', ascending: false)
        .limit(100);
    return _visible(rows.map<Post>(Post.fromMap).toList());
  }

  /// Replies of the signed-in account to the given posts (the "My replies"
  /// view of a Community).
  static Future<List<Post>> fetchMyCommunityReplies(List<String> postIds) async {
    if (postIds.isEmpty) return const [];
    final rows = await _db
        .from('posts_feed')
        .select()
        .eq('user_id', uid)
        .inFilter('parent_id', postIds)
        .order('created_at', ascending: false)
        .limit(100);
    return _visible(rows.map<Post>(Post.fromMap).toList());
  }

  /// Posts from all communities (or only those of one [category]).
  static Future<List<Post>> fetchCommunityFeed({String? category}) async {
    var req = _db.from('posts_feed').select().not('community_id', 'is', null);
    if (category != null) {
      final ids = await _db
          .from('communities')
          .select('id')
          .eq('category', category);
      final list = ids.map<String>((r) => r['id'] as String).toList();
      if (list.isEmpty) return const [];
      req = req.inFilter('community_id', list);
    }
    final rows = await req.order('created_at', ascending: false).limit(60);
    return _visible(rows.map<Post>(Post.fromMap).toList());
  }

  // =====================================================================
  // Lists
  // =====================================================================

  /// Lists I created, follow or pinned (pinned first in the screen).
  static Future<List<UserList>> fetchMyLists() async {
    final rows = await _db
        .from('list_stats')
        .select()
        .or('owner_id.eq.$uid,followed_by_me.eq.true,pinned_by_me.eq.true')
        .order('created_at', ascending: false);
    return rows.map<UserList>(UserList.fromMap).toList();
  }

  /// Public lists made by other people that I don't follow yet.
  static Future<List<UserList>> fetchDiscoverLists({int limit = 20}) async {
    final rows = await _db
        .from('list_stats')
        .select()
        .eq('is_private', false)
        .neq('owner_id', uid)
        .eq('followed_by_me', false)
        .order('follower_count', ascending: false)
        .limit(limit);
    return rows.map<UserList>(UserList.fromMap).toList();
  }

  static Future<UserList?> fetchList(String id) async {
    final row =
        await _db.from('list_stats').select().eq('id', id).maybeSingle();
    return row == null ? null : UserList.fromMap(row);
  }

  /// Creates a list and returns its id.
  static Future<String> createList({
    required String name,
    String description = '',
    bool isPrivate = false,
    PickedImage? banner,
  }) async {
    String? bannerUrl;
    if (banner != null) {
      bannerUrl =
          await uploadImage(bucket: AppConfig.avatarsBucket, image: banner);
    }
    final row = await _db
        .from('lists')
        .insert({
          'owner_id': uid,
          'name': name.trim(),
          'description': description.trim(),
          'is_private': isPrivate,
          'banner_url': bannerUrl,
        })
        .select('id')
        .single();
    return row['id'] as String;
  }

  /// Owner: change name, description, privacy and (optionally) the banner.
  static Future<void> updateList(
    String id, {
    required String name,
    required String description,
    required bool isPrivate,
    PickedImage? newBanner,
  }) async {
    final fields = <String, dynamic>{
      'name': name.trim(),
      'description': description.trim(),
      'is_private': isPrivate,
    };
    if (newBanner != null) {
      fields['banner_url'] =
          await uploadImage(bucket: AppConfig.avatarsBucket, image: newBanner);
    }
    await _db.from('lists').update(fields).eq('id', id).eq('owner_id', uid);
  }

  static Future<void> deleteList(String id) async {
    await _db.from('lists').delete().eq('id', id).eq('owner_id', uid);
  }

  static Future<void> setListFollow(String listId, {required bool follow}) async {
    if (follow) {
      await _db.from('list_follows').upsert({'list_id': listId, 'user_id': uid});
    } else {
      await _db
          .from('list_follows')
          .delete()
          .eq('list_id', listId)
          .eq('user_id', uid);
    }
  }

  /// Pin a list to the top of my Lists page (up to 10) or unpin it.
  static Future<void> setListPinned(String listId, {required bool pinned}) async {
    if (pinned) {
      await _db.from('list_pins').upsert({'list_id': listId, 'user_id': uid});
    } else {
      await _db
          .from('list_pins')
          .delete()
          .eq('list_id', listId)
          .eq('user_id', uid);
    }
  }

  static Future<List<Profile>> fetchListMembers(String listId) async {
    final rows = await _db
        .from('list_members')
        .select('user_id')
        .eq('list_id', listId);
    final ids = rows.map<String>((r) => r['user_id'] as String).toList();
    if (ids.isEmpty) return const [];
    final profiles =
        await _db.from('profile_stats').select().inFilter('id', ids);
    return profiles.map<Profile>(Profile.fromMap).toList();
  }

  /// People who follow a list.
  static Future<List<Profile>> fetchListFollowers(String listId) async {
    final rows = await _db
        .from('list_follows')
        .select('user_id')
        .eq('list_id', listId);
    final ids = rows.map<String>((r) => r['user_id'] as String).toList();
    if (ids.isEmpty) return const [];
    final profiles =
        await _db.from('profile_stats').select().inFilter('id', ids);
    return profiles.map<Profile>(Profile.fromMap).toList();
  }

  static Future<void> setListMember(
    String listId,
    String userId, {
    required bool add,
  }) async {
    if (add) {
      await _db.from('list_members').upsert({'list_id': listId, 'user_id': userId});
    } else {
      await _db
          .from('list_members')
          .delete()
          .eq('list_id', listId)
          .eq('user_id', userId);
    }
  }

  /// Latest posts from the members of a list.
  static Future<List<Post>> fetchListPosts(String listId) async {
    final rows = await _db
        .from('list_members')
        .select('user_id')
        .eq('list_id', listId);
    final ids = rows.map<String>((r) => r['user_id'] as String).toList();
    if (ids.isEmpty) return const [];
    final posts = await _db
        .from('posts_feed')
        .select()
        .inFilter('user_id', ids)
        .isFilter('parent_id', null)
        .order('created_at', ascending: false)
        .limit(60);
    return posts.map<Post>(Post.fromMap).toList();
  }

  // =====================================================================
  // Account settings
  // =====================================================================

  /// Changes my @username (the database keeps it unique).
  static Future<void> changeUsername(String username) async {
    await _db
        .from('profiles')
        .update({'username': username.trim()}).eq('id', uid);
  }

  /// Phone number kept in the private table (not verified by SMS).
  static Future<String?> getPhone() async {
    final row = await _db
        .from('profile_private')
        .select('phone')
        .eq('user_id', uid)
        .maybeSingle();
    final v = row?['phone'] as String?;
    return (v == null || v.isEmpty) ? null : v;
  }

  static Future<void> savePhone(String? phone) async {
    await _db.from('profile_private').upsert({
      'user_id': uid,
      'phone': (phone == null || phone.isEmpty) ? null : phone,
    });
  }

  /// Starts an email change: Supabase emails a code.
  static Future<void> requestEmailChange(String newEmail) async {
    await _db.auth.updateUser(UserAttributes(email: newEmail.trim()));
  }

  static Future<void> confirmEmailChange({
    required String email,
    required String code,
  }) async {
    await _db.auth.verifyOTP(
      email: email.trim(),
      token: code.trim(),
      type: OtpType.emailChange,
    );
    await _db.auth.refreshSession();
  }

  static Future<void> setCountry(String? country) =>
      updateMyProfile({'country': country});

  /// null removes the label. Changes are locked for 48 hours (database
  /// trigger).
  static Future<void> setProfileLabel(String? label) =>
      updateMyProfile({'profile_label': label});

  /// The account that manages my automated account (null = not automated).
  static Future<void> setManagingAccount(String? accountId) => updateMyProfile({
        'managed_by': accountId,
        'automated': accountId != null,
      });

  static Future<void> setProtected(bool value) =>
      updateMyProfile({'protected': value});

  /// everyone | verified | none
  static Future<String> getDmSetting() async {
    final row = await _db
        .from('profiles')
        .select('dm_setting')
        .eq('id', uid)
        .maybeSingle();
    return (row?['dm_setting'] as String?) ?? 'everyone';
  }

  static Future<void> setDmSetting(String value) =>
      updateMyProfile({'dm_setting': value});

  /// Checks the password of the signed-in account ("Confirm your password").
  static Future<void> verifyPassword(String password) async {
    final mail = _db.auth.currentUser?.email;
    if (mail == null) throw AuthException('You are not signed in.');
    await _db.auth.signInWithPassword(email: mail, password: password);
  }

  /// Hides the account and signs out. Signing in again reactivates it.
  static Future<void> deactivateAccount() async {
    await updateMyProfile({
      'deactivated_at': DateTime.now().toUtc().toIso8601String(),
    });
    await signOut();
  }

  /// Accounts matching [query], for pickers (managing account ...).
  static Future<List<Profile>> findAccounts(String query) async {
    final q = _clean(query).replaceAll('@', '');
    if (q.isEmpty) return const [];
    final rows = await _db
        .from('profiles')
        .select('id, username, display_name, avatar_url, bio')
        .neq('id', uid)
        .or('username.ilike.%$q%,display_name.ilike.%$q%')
        .limit(20);
    return rows.map<Profile>(Profile.fromMap).toList();
  }
}
