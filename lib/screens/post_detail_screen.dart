import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/cupertino.dart';

import '../core/app_icons.dart';
import '../core/app_palette.dart';
import '../core/ui_helpers.dart';
import '../models/models.dart';
import '../services/ai_service.dart';
import '../services/api.dart';
import '../widgets/ai_dialogs.dart' show AiGlyph;
import '../widgets/anchored_popup.dart';
import '../widgets/grok_post_sheet.dart';
import '../widgets/post_card.dart';
import '../widgets/post_menus.dart';
import '../widgets/post_tile.dart';
import '../widgets/reply_guard.dart';
import '../widgets/responsive.dart';
import '../widgets/state_views.dart';
import 'chat_view.dart';
import 'compose_post_screen.dart';
import 'community_notes_screen.dart';
import 'post_extra_screens.dart';
import '../widgets/post_skeleton.dart';

/// A post with the replies under it, and a "Post your reply" bar.
class PostDetailScreen extends StatefulWidget {
  const PostDetailScreen({super.key, required this.post});

  final Post post;

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  late Post _post = widget.post;

  /// Posts above this one (it is a reply), oldest first.
  List<Post> _ancestors = const [];
  bool _showAncestors = false;
  List<Post> _replies = const [];
  bool _loading = true;
  Object? _error;
  ReplySort _sort = ReplySort.relevant;

  @override
  void initState() {
    super.initState();
    if (_post.userId != Api.uid) Api.logPostEvent(_post.id, 'detail');
    _load();
    _loadAncestors();
    _loadNoteInfo();
    _loadAuthor();
    AiAssist.grokReplied.addListener(_onGrokReplied);
  }

  @override
  void dispose() {
    AiAssist.grokReplied.removeListener(_onGrokReplied);
    super.dispose();
  }

  void _onGrokReplied() {
    if (mounted) _load(silent: true);
  }

  // The author's follow state (for the Follow / Message button).
  Profile? _author;

  Future<void> _loadAuthor() async {
    if (_post.userId == Api.uid) return;
    final id = _post.userId;
    try {
      final who = await Api.getProfile(id);
      if (mounted && _post.userId == id) setState(() => _author = who);
    } catch (_) {}
  }

  Future<void> _toggleFollow() async {
    final before = _author;
    if (before == null) return;
    final after = before.afterFollowTap();
    setState(() => _author = after);
    try {
      await Api.setFollow(
        before.id,
        follow: after.followedByMe || after.requestedByMe,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _author = before);
      showError(context, e);
    }
  }

  /// "Follow" for people I do not follow, "Message" for the ones I do
  /// (small outlined pill at the right of the author, like on X).
  Widget _authorButton(AppPalette p) {
    final who = _author;
    if (who == null || _post.userId == Api.uid) return const SizedBox.shrink();
    final following = who.followedByMe;
    final pending = who.requestedByMe;
    final label = following ? 'Message' : (pending ? 'Pending' : 'Follow');
    final filled = !following && !pending;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: following
          ? () => Navigator.of(context)
              .push(appRoute(ChatScreen(partner: who)))
          : _toggleFollow,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: filled ? p.text : null,
          borderRadius: BorderRadius.circular(16),
          border: filled ? null : Border.all(color: p.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: filled ? p.background : p.subtext,
            fontSize: 14,
            fontWeight: filled ? FontWeight.w700 : FontWeight.w600,
            decoration: TextDecoration.none,
          ),
        ),
      ),
    );
  }

  /// Notes + requests, for the "Community Notes" row under the post.
  int _noteCount = 0;
  int _noteRequests = 0;

  Future<void> _loadNoteInfo() async {
    try {
      final r = await Future.wait([
        Api.fetchNotes(_post.id),
        Api.noteRequestCount(_post.id),
      ]);
      if (!mounted) return;
      setState(() {
        _noteCount = (r[0] as List).length;
        _noteRequests = r[1] as int;
      });
    } catch (_) {
      // The row simply stays hidden.
    }
  }

  Widget _notesRow(AppPalette p) {
    final parts = <String>[
      if (_noteCount > 0) '$_noteCount ${_noteCount == 1 ? 'note' : 'notes'}',
      if (_noteRequests > 0)
        '$_noteRequests ${_noteRequests == 1 ? 'request' : 'requests'}',
    ];
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () async {
        await Navigator.of(context)
            .push(appRoute(PostNotesScreen(post: _post)));
        if (mounted) _loadNoteInfo();
      },
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: p.border, width: 0.5)),
        ),
        child: Row(
          children: [
            Icon(CupertinoIcons.person_3_fill, size: 20, color: p.subtext),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Community Notes · ${parts.join(' · ')}',
                style: TextStyle(
                  color: p.text,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Icon(CupertinoIcons.chevron_right, size: 14, color: p.subtext),
          ],
        ),
      ),
    );
  }

  Future<void> _loadAncestors() async {
    final chain = <Post>[];
    var id = _post.parentId;
    try {
      while (id != null && chain.length < 10) {
        final a = await Api.fetchPost(id);
        if (a == null) break;
        chain.insert(0, a);
        id = a.parentId;
      }
    } catch (_) {
      // The thread link is optional: show what could be loaded.
    }
    if (mounted && chain.isNotEmpty) setState(() => _ancestors = chain);
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final list = await Api.fetchReplies(_post.id);
      if (!mounted) return;
      setState(() {
        _replies = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (!silent) _error = e;
      });
    }
  }

  List<Post> get _sorted {
    final list = [..._replies];
    int score(Post x) => x.likeCount * 3 + x.replyCount * 2 + x.repostCount;
    switch (_sort) {
      case ReplySort.relevant:
        list.sort((a, b) {
          final c = score(b).compareTo(score(a));
          return c != 0 ? c : b.createdAt.compareTo(a.createdAt);
        });
      case ReplySort.recent:
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      case ReplySort.liked:
        list.sort((a, b) {
          final c = b.likeCount.compareTo(a.likeCount);
          return c != 0 ? c : b.createdAt.compareTo(a.createdAt);
        });
    }
    return list;
  }

  Future<void> _reply() async {
    final post = _post;
    if (!await ensureCanReply(context, post) || !mounted) return;
    final posted = await Navigator.of(context).push<bool>(
      appRoute(ComposePostScreen(replyTo: post), fullscreen: true),
    );
    if (posted == true) _load(silent: true);
  }

  Future<void> _headerMenu(Rect anchor) async {
    final post = _post;
    final mine = post.userId == Api.uid;
    final action = await showPostMenu(
      context,
      anchor: anchor,
      post: post,
      isMine: mine,
    );
    if (action == null || !mounted) return;
    if (action == PostMenuAction.edit) {
      final updated = await Navigator.of(context).push<Post>(
        appRoute(ComposePostScreen(editing: post), fullscreen: true),
      );
      if (updated != null && mounted) {
        setState(() => _post = updated);
        showSuccess(context, 'Your post was updated');
      }
      return;
    }
    final gone = await runPostMenuAction(context, action, post);
    if (gone && mounted) Navigator.of(context).maybePop();
  }

  Future<void> _sortMenu(Rect anchor) async {
    final picked = await showReplySortMenu(
      context,
      anchor: anchor,
      current: _sort,
    );
    if (picked != null && mounted) setState(() => _sort = picked);
  }

  Widget _header(AppPalette p) {
    return SizedBox(
      height: 52,
      child: Row(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.of(context).maybePop(),
            child: SizedBox(
              width: 52,
              height: 52,
              child: Icon(AppIcons.back, size: 22, color: p.text),
            ),
          ),
          Expanded(
            child: Text(
              'Post',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: p.text,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => showGrokPostSheet(context, _post),
            child: SizedBox(
              width: 40,
              height: 52,
              child: Center(child: AiGlyph(size: 22, color: p.text)),
            ),
          ),
          Builder(
            builder: (c) => GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _headerMenu(rectOf(c)),
              child: SizedBox(
                width: 48,
                height: 52,
                child: Icon(CupertinoIcons.ellipsis, size: 22, color: p.text),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// "Show this thread" above a reply (earlier posts of the conversation).
  Widget _threadLink(AppPalette p) {
    final sameAuthor = _ancestors.every((a) => a.userId == _post.userId);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _showAncestors = true),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: p.border, width: 0.5)),
        ),
        child: Text(
          sameAuthor ? 'Show this thread' : 'Show earlier posts',
          style: TextStyle(
            color: p.accent,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _toolbar(AppPalette p) {
    final post = _post;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: p.border, width: 0.5),
          bottom: BorderSide(color: p.border, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          Builder(
            builder: (c) => GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _sortMenu(rectOf(c)),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      replySortLabel(_sort),
                      style: TextStyle(
                        color: p.accent,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      CupertinoIcons.chevron_down,
                      size: 14,
                      color: p.accent,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const Spacer(),
          if (post.repostCount > 0)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(context)
                  .push(appRoute(PostInteractionsScreen(post: post))),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'View quotes',
                      style: TextStyle(color: p.subtext, fontSize: 15),
                    ),
                    const SizedBox(width: 2),
                    Icon(
                      CupertinoIcons.chevron_right,
                      size: 14,
                      color: p.subtext,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final post = _post;

    Widget replies() {
      if (_loading) {
        return const PostSkeletons(count: 3, firstWithMedia: false);
      }
      if (_error != null) {
        return ErrorView(error: _error!, onRetry: _load);
      }
      if (_replies.isEmpty) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(28, 40, 28, 40),
          child: Text(
            'No replies yet. Start the conversation!',
            textAlign: TextAlign.center,
            style: TextStyle(color: p.subtext, fontSize: 16),
          ),
        );
      }
      return Column(
        children: [
          for (final r in _sorted)
            PostTile(
              key: ValueKey(r.id),
              post: r,
              style: PostCardStyle.reply,
              onDeleted: (x) => setState(
                () => _replies = _replies.where((y) => y.id != x.id).toList(),
              ),
            ),
        ],
      );
    }

    return AdaptiveScaffold(
      backgroundColor: p.background,
      body: DefaultTextStyle(
        style: TextStyle(
          color: p.text,
          fontSize: 15,
          decoration: TextDecoration.none,
          fontWeight: FontWeight.w400,
        ),
        child: SafeArea(
          child: ContentWidth(
            child: Column(
              children: [
                _header(p),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        if (_ancestors.isNotEmpty && !_showAncestors)
                          _threadLink(p),
                        if (_showAncestors)
                          for (final a in _ancestors)
                            PostTile(key: ValueKey('anc-${a.id}'), post: a),
                        PostTile(
                          post: post,
                          openDetail: false,
                          style: PostCardStyle.detail,
                          detailTrailing: _post.userId == Api.uid
                              ? const SizedBox.shrink()
                              : _authorButton(p),
                          onDeleted: (_) => Navigator.of(context).maybePop(),
                          onReplied: () => _load(silent: true),
                        ),
                        if (_noteCount > 0 || _noteRequests > 0) _notesRow(p),
                        _toolbar(p),
                        replies(),
                      ],
                    ),
                  ),
                ),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _reply,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                    decoration: BoxDecoration(
                      border:
                          Border(top: BorderSide(color: p.border, width: 0.5)),
                    ),
                    child: Container(
                      height: 44,
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      alignment: Alignment.centerLeft,
                      decoration: BoxDecoration(
                        color: p.field,
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Text(
                        'Post your reply',
                        style: TextStyle(color: p.subtext, fontSize: 17),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
