import 'package:flutter/cupertino.dart';

import '../core/app_palette.dart';
import '../core/ui_helpers.dart';
import '../models/models.dart';
import '../screens/compose_post_screen.dart';
import '../screens/post_detail_screen.dart';
import '../screens/profile_view.dart';
import '../services/api.dart';
import '../services/moderation.dart';
import '../screens/video_viewer_screen.dart';
import 'grok_post_sheet.dart';
import 'post_card.dart';
import 'post_media.dart';
import 'post_menus.dart';
import 'reply_guard.dart';
import 'share_post_sheet.dart';
import 'state_views.dart';
import 'video_reaction.dart';

/// A [PostCard] that talks to the backend: like, repost, bookmark, delete,
/// reply, share, open the post and open the author. It keeps its own copy of
/// the post so lists only need to render `PostTile(post: p)`.
class PostTile extends StatefulWidget {
  const PostTile({
    super.key,
    required this.post,
    this.onDeleted,
    this.onChanged,
    this.openDetail = true,
    this.currentProfileId,
    this.showDivider = true,
    this.style = PostCardStyle.feed,
    this.onReplied,
    this.detailTrailing,
  });

  final Post post;

  /// Called after the post left the list: my own post was deleted, or I hid
  /// it / muted / blocked its author.
  final ValueChanged<Post>? onDeleted;

  /// Called after like / repost / bookmark changed the post.
  final ValueChanged<Post>? onChanged;

  /// False on the post's own detail page.
  final bool openDetail;

  /// Profile page this tile is shown on (tapping its author does nothing).
  final String? currentProfileId;
  final bool showDivider;

  /// Layout of the card (timeline, reply under a post, or the post itself).
  final PostCardStyle style;

  /// Detail layout: widget at the right of the author row (see PostCard).
  final Widget? detailTrailing;

  /// Called after a reply to this post was sent.
  final VoidCallback? onReplied;

  @override
  State<PostTile> createState() => _PostTileState();
}

class _PostTileState extends State<PostTile> {
  late Post _post = widget.post;
  bool _gone = false;

  /// "Not interested" was picked: the post is replaced by a small card.
  bool _notInterested = false;

  /// One of the two follow-up options was picked on that card.
  bool _feedbackGiven = false;

  @override
  void didUpdateWidget(PostTile old) {
    super.didUpdateWidget(old);
    if (!identical(old.post, widget.post)) _post = widget.post;
  }

  void _set(Post next) {
    setState(() => _post = next);
    widget.onChanged?.call(next);
  }

  void _remove() {
    setState(() => _gone = true);
    widget.onDeleted?.call(_post);
  }

  Future<void> _like() async {
    final before = _post;
    final next = before.copyWith(
      likedByMe: !before.likedByMe,
      likeCount: before.likeCount + (before.likedByMe ? -1 : 1),
    );
    _set(next);
    try {
      await Api.setLike(before.id, like: next.likedByMe);
    } catch (e) {
      if (!mounted) return;
      _set(before);
      showError(context, e);
    }
  }

  /// Tap on the repost icon: popup with Repost / Quote / React with Video.
  Future<void> _repostMenu(Rect anchor) async {
    final choice = await showRepostPopup(
      context,
      anchor: anchor,
      reposted: _post.repostedByMe,
    );
    if (choice == null || !mounted) return;
    switch (choice) {
      case RepostChoice.repost:
      case RepostChoice.undo:
        await _repost();
      case RepostChoice.quote:
        await _quote();
      case RepostChoice.video:
        if (await reactWithVideo(context, _post) && mounted) {
          _set(_post.copyWith(repostCount: _post.repostCount + 1));
        }
    }
  }

  Future<void> _quote() async {
    final posted = await Navigator.of(context).push<bool>(
      appRoute(ComposePostScreen(quoting: _post), fullscreen: true),
    );
    if (posted == true && mounted) {
      _set(_post.copyWith(repostCount: _post.repostCount + 1));
      showSuccess(context, 'Your quote was posted');
    }
  }

  Future<void> _repost() async {
    final before = _post;
    final next = before.copyWith(
      repostedByMe: !before.repostedByMe,
      repostCount: before.repostCount + (before.repostedByMe ? -1 : 1),
    );
    _set(next);
    try {
      await Api.setRepost(before.id, reposted: next.repostedByMe);
      if (mounted) {
        showInfo(
          context,
          next.repostedByMe ? 'You reposted' : 'Repost removed',
        );
      }
    } catch (e) {
      if (!mounted) return;
      _set(before);
      showError(context, e);
    }
  }

  Future<void> _bookmark() async {
    final before = _post;
    final saved = !before.bookmarkedByMe;
    final next = before.copyWith(
      bookmarkedByMe: saved,
      bookmarkCount: (before.bookmarkCount + (saved ? 1 : -1))
          .clamp(0, 1 << 31)
          .toInt(),
    );
    _set(next);
    try {
      await Api.setBookmark(before.id, bookmarked: saved);
      if (mounted) {
        showInfo(
          context,
          saved ? 'Added to your Bookmarks' : 'Removed from your Bookmarks',
        );
      }
    } catch (e) {
      if (!mounted) return;
      _set(before);
      showError(context, e);
    }
  }

  Future<void> _reply() async {
    if (!await ensureCanReply(context, _post) || !mounted) return;
    final posted = await Navigator.of(context).push<bool>(
      appRoute(ComposePostScreen(replyTo: _post), fullscreen: true),
    );
    if (posted == true && mounted) {
      _set(_post.copyWith(replyCount: _post.replyCount + 1));
      showSuccess(context, 'Your reply was sent');
      widget.onReplied?.call();
    }
  }

  Future<void> _share() => showSharePostSheet(context, _post);

  Future<void> _grok() => showGrokPostSheet(context, _post);

  Future<void> _more(Rect anchor) async {
    final mine = _post.userId == Api.uid;
    final action = await showPostMenu(
      context,
      anchor: anchor,
      post: _post,
      isMine: mine,
    );
    if (action == null || !mounted) return;
    if (action == PostMenuAction.edit) {
      final updated = await Navigator.of(context).push<Post>(
        appRoute(ComposePostScreen(editing: _post), fullscreen: true),
      );
      if (updated != null && mounted) {
        _set(updated);
        showSuccess(context, 'Your post was updated');
      }
      return;
    }
    if (action == PostMenuAction.notInterested) {
      await Moderation.instance.hidePost(_post.id);
      if (mounted) setState(() => _notInterested = true);
      return;
    }
    final gone = await runPostMenuAction(context, action, _post);
    if (gone && mounted) _remove();
  }

  Future<void> _open() async {
    if (!widget.openDetail) return;
    await Navigator.of(context).push(appRoute(PostDetailScreen(post: _post)));
    // Counts may have changed on the detail page.
    try {
      final fresh = await Api.fetchPost(_post.id);
      if (mounted && fresh != null) setState(() => _post = fresh);
    } catch (_) {}
  }

  Future<void> _openQuote() async {
    final q = _post.quote;
    if (q == null) return;
    try {
      final quoted = await Api.fetchPost(q.id);
      if (!mounted || quoted == null) return;
      await Navigator.of(context).push(appRoute(PostDetailScreen(post: quoted)));
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _openImage(int index) async {
    await Navigator.of(context).push(
      appRoute(
        ImageViewerScreen(urls: _post.images, initial: index, post: _post),
        fullscreen: true,
      ),
    );
    // Likes, reposts, bookmarks ... may have changed in the viewer.
    try {
      final fresh = await Api.fetchPost(_post.id);
      if (mounted && fresh != null) _set(fresh);
    } catch (_) {}
  }

  Future<void> _openVideo() async {
    await Navigator.of(context).push(
      appRoute(VideoViewerScreen(post: _post), fullscreen: true),
    );
    // Likes, reposts ... may have changed in the player.
    try {
      final fresh = await Api.fetchPost(_post.id);
      if (mounted && fresh != null) _set(fresh);
    } catch (_) {}
  }

  void _openAuthor({bool force = false}) {
    if (!force && _post.userId == widget.currentProfileId) return;
    if (_post.userId != Api.uid) Api.logPostEvent(_post.id, 'profile');
    Navigator.of(context).push(appRoute(ProfileScreen(userId: _post.userId)));
  }

  Future<void> _undoNotInterested() async {
    await Moderation.instance.unhidePost(_post.id);
    if (mounted) {
      setState(() {
        _notInterested = false;
        _feedbackGiven = false;
      });
    }
  }

  Widget _optionRow(AppPalette p, String label, VoidCallback onTap) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: p.border, width: 0.5)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: p.text,
            fontSize: 16,
            decoration: TextDecoration.none,
            fontWeight: FontWeight.w400,
          ),
        ),
      ),
    );
  }

  /// "Thanks. X will use this to make your timeline better." + Undo, with two
  /// follow-up options (shown until one is picked).
  Widget _notInterestedCard(BuildContext context) {
    final p = AppPalette.of(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: p.border, width: 1),
              borderRadius: BorderRadius.circular(14),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Thanks. X will use this to make your timeline better.',
                          style: TextStyle(
                            color: p.text,
                            fontSize: 16,
                            height: 1.25,
                            decoration: TextDecoration.none,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: _undoNotInterested,
                        child: Text(
                          'Undo',
                          style: TextStyle(
                            color: p.text,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (!_feedbackGiven) ...[
                  _optionRow(
                    p,
                    'Show fewer posts from ${_post.username}',
                    () => setState(() => _feedbackGiven = true),
                  ),
                  _optionRow(
                    p,
                    'This post isn’t relevant',
                    () => setState(() => _feedbackGiven = true),
                  ),
                ],
              ],
            ),
          ),
        ),
        if (widget.showDivider) const HairlineDivider(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_gone) return const SizedBox.shrink();
    if (_notInterested) return _notInterestedCard(context);
    final mine = _post.userId == Api.uid;
    return PostCard(
      post: _post,
      isMine: mine,
      style: widget.style,
      showDivider: widget.showDivider && widget.style != PostCardStyle.detail,
      onLike: _like,
      onReply: _reply,
      onRepost: _repostMenu,
      onBookmark: _bookmark,
      onShare: _share,
      onMore: _more,
      onGrok: _grok,
      detailTrailing: widget.detailTrailing,
      onOpen: widget.openDetail ? _open : null,
      onOpenAuthor: _openAuthor,
      onOpenQuote: _openQuote,
      onOpenImage: _openImage,
      onOpenVideo: _openVideo,
    );
  }
}
