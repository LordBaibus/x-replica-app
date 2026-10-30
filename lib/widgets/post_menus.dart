import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;

import '../core/app_palette.dart';
import '../core/ui_helpers.dart';
import '../models/models.dart';
import '../screens/post_analytics_screen.dart';
import '../screens/post_extra_screens.dart';
import '../screens/report_screens.dart';
import '../services/api.dart';
import '../services/moderation.dart';
import 'anchored_popup.dart';
import 'lists_sheet.dart';

/// What the person picked in a post's "…" menu.
enum PostMenuAction {
  edit,
  notInterested,
  interactions,
  report,
  spam,
  communityNote,
  follow,
  unfollow,
  lists,
  mute,
  block,
  copyLink,
  delete,
}

/// My own post can be edited for one hour (the database enforces it too).
/// Polls and scheduled posts are left out.
bool canEditPost(Post post) =>
    post.userId == Api.uid &&
    post.pollEndsAt == null &&
    post.scheduledAt == null &&
    DateTime.now().difference(post.createdAt) < const Duration(hours: 1);

/// Link to a post that can be copied or sent in a message. The app has no web
/// domain, so the link uses the app's own scheme.
String postLink(Post post) => 'xreplica://post/${post.id}';

Future<void> copyPostLink(BuildContext context, Post post) async {
  if (post.userId != Api.uid) Api.logPostEvent(post.id, 'share');
  await Clipboard.setData(ClipboardData(text: postLink(post)));
  if (context.mounted) showInfo(context, 'Copied to clipboard');
}

/// One row of the post menu: label on the left, icon on the right.
Widget _menuTile(
  BuildContext context, {
  required String label,
  required ValueChanged<Rect> onTap,
  IconData? icon,
  bool chevron = false,
  bool first = false,
  bool destructive = false,
}) {
  final p = AppPalette.of(context);
  final color = destructive ? p.danger : p.text;
  return Builder(
    builder: (c) => GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onTap(rectOf(c)),
      child: Container(
        decoration: BoxDecoration(
          border: first
              ? null
              : Border(top: BorderSide(color: p.border, width: 0.5)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 17,
                  height: 1.2,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
            const SizedBox(width: 12),
            if (chevron)
              Icon(CupertinoIcons.chevron_right, size: 16, color: p.subtext)
            else if (icon != null)
              Icon(icon, size: 22, color: color),
          ],
        ),
      ),
    ),
  );
}

class _PostMenuBody extends StatelessWidget {
  const _PostMenuBody({
    required this.post,
    required this.isMine,
    required this.following,
  });

  final Post post;
  final bool isMine;
  final bool following;

  /// "@user ›": the smaller menu next to the main one.
  Future<void> _openSub(BuildContext context, Rect row) async {
    final menu = rectOf(context);
    final requested = Moderation.instance.requested.contains(post.userId);
    final x = menu.left + 17;
    final y = row.top - 41;
    final picked = await showAnchoredPopup<PostMenuAction>(
      context,
      anchor: Rect.fromLTRB(x - 1, y - 1, x, y),
      width: 240,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _menuTile(
            ctx,
            first: true,
            label: following
                ? 'Unfollow'
                : (requested ? 'Cancel follow request' : 'Follow'),
            icon: following || requested
                ? CupertinoIcons.person_badge_minus
                : CupertinoIcons.person_badge_plus,
            onTap: (_) => Navigator.of(ctx).pop(
              following || requested
                  ? PostMenuAction.unfollow
                  : PostMenuAction.follow,
            ),
          ),
          _menuTile(
            ctx,
            label: 'Add/remove from Lists',
            icon: CupertinoIcons.text_badge_plus,
            onTap: (_) => Navigator.of(ctx).pop(PostMenuAction.lists),
          ),
          _menuTile(
            ctx,
            label: 'Mute',
            icon: CupertinoIcons.speaker_slash,
            onTap: (_) => Navigator.of(ctx).pop(PostMenuAction.mute),
          ),
          _menuTile(
            ctx,
            label: 'Block',
            icon: CupertinoIcons.nosign,
            onTap: (_) => Navigator.of(ctx).pop(PostMenuAction.block),
          ),
        ],
      ),
    );
    if (picked != null && context.mounted) {
      Navigator.of(context).pop(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    void pick(PostMenuAction a) => Navigator.of(context).pop(a);

    if (isMine) {
      final canEdit = canEditPost(post);
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (canEdit)
            _menuTile(
              context,
              first: true,
              label: 'Edit post',
              icon: CupertinoIcons.pencil,
              onTap: (_) => pick(PostMenuAction.edit),
            ),
          _menuTile(
            context,
            first: !canEdit,
            label: 'View post analytics',
            icon: CupertinoIcons.chart_bar,
            onTap: (_) => pick(PostMenuAction.interactions),
          ),
          _menuTile(
            context,
            label: 'Copy link',
            icon: CupertinoIcons.link,
            onTap: (_) => pick(PostMenuAction.copyLink),
          ),
          _menuTile(
            context,
            label: 'Delete post',
            icon: CupertinoIcons.delete,
            destructive: true,
            onTap: (_) => pick(PostMenuAction.delete),
          ),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _menuTile(
          context,
          first: true,
          label: 'Not interested in this post',
          icon: CupertinoIcons.hand_thumbsdown,
          onTap: (_) => pick(PostMenuAction.notInterested),
        ),
        _menuTile(
          context,
          label: 'View Post Interactions',
          icon: CupertinoIcons.chart_bar,
          onTap: (_) => pick(PostMenuAction.interactions),
        ),
        _menuTile(
          context,
          label: 'Report post',
          icon: CupertinoIcons.flag,
          onTap: (_) => pick(PostMenuAction.report),
        ),
        _menuTile(
          context,
          label: 'Mark as spam',
          icon: CupertinoIcons.ant,
          onTap: (_) => pick(PostMenuAction.spam),
        ),
        _menuTile(
          context,
          label: 'Request Community Note',
          icon: CupertinoIcons.speaker_2,
          onTap: (_) => pick(PostMenuAction.communityNote),
        ),
        _menuTile(
          context,
          label: '@${post.username}',
          chevron: true,
          onTap: (row) => _openSub(context, row),
        ),
      ],
    );
  }
}

/// The menu next to the "…" of a post. Returns the action picked.
Future<PostMenuAction?> showPostMenu(
  BuildContext context, {
  required Rect anchor,
  required Post post,
  required bool isMine,
}) {
  final following = Moderation.instance.following.contains(post.userId);
  return showAnchoredPopup<PostMenuAction>(
    context,
    anchor: anchor,
    width: 270,
    builder: (ctx) => SingleChildScrollView(
      child: _PostMenuBody(post: post, isMine: isMine, following: following),
    ),
  );
}

/// Runs a [PostMenuAction]. Returns true when the post should disappear from
/// the list (hidden, deleted, author muted / blocked).
Future<bool> runPostMenuAction(
  BuildContext context,
  PostMenuAction action,
  Post post,
) async {
  final handle = '@${post.username}';
  try {
    switch (action) {
      case PostMenuAction.edit:
        // The caller opens the composer (it needs the result).
        return false;
      case PostMenuAction.notInterested:
        await Moderation.instance.hidePost(post.id);
        return true;
      case PostMenuAction.interactions:
        await Navigator.of(context).push(
          appRoute(
            post.userId == Api.uid
                ? PostAnalyticsScreen(post: post)
                : PostInteractionsScreen(post: post),
          ),
        );
        return false;
      case PostMenuAction.report:
        await Navigator.of(context).push(
          appRoute(ReportPostScreen(post: post), fullscreen: true),
        );
        return false;
      case PostMenuAction.spam:
        await Api.reportPost(post, 'Spam');
        if (context.mounted) showInfo(context, 'Spam reported');
        return false;
      case PostMenuAction.communityNote:
        await Navigator.of(context).push(
          appRoute(CommunityNoteScreen(post: post), fullscreen: true),
        );
        return false;
      case PostMenuAction.follow:
        final state = await Api.setFollow(post.userId, follow: true);
        await Moderation.instance.reload();
        if (context.mounted) {
          if (state == FollowState.requested) {
            showInfo(context, 'Follow request sent to $handle');
          } else {
            showSuccess(context, 'You followed $handle');
          }
        }
        return false;
      case PostMenuAction.unfollow:
        final cancelled = Moderation.instance.requested.contains(post.userId);
        await Api.setFollow(post.userId, follow: false);
        await Moderation.instance.reload();
        if (context.mounted) {
          showInfo(
            context,
            cancelled
                ? 'Follow request to $handle cancelled'
                : 'You unfollowed $handle',
          );
        }
        return false;
      case PostMenuAction.lists:
        await showListsSheet(context, userId: post.userId, handle: handle);
        return false;
      case PostMenuAction.mute:
        await Moderation.instance.mute(post.userId);
        if (context.mounted) showInfo(context, '$handle was muted');
        return true;
      case PostMenuAction.block:
        if (!await confirm(
          context,
          title: 'Block $handle?',
          message:
              'They will not be able to follow you or see your posts, and you will not see theirs.',
          confirmLabel: 'Block',
          destructive: true,
        )) {
          return false;
        }
        await Moderation.instance.block(post.userId);
        if (context.mounted) showInfo(context, '$handle was blocked');
        return true;
      case PostMenuAction.copyLink:
        if (context.mounted) await copyPostLink(context, post);
        return false;
      case PostMenuAction.delete:
        return deletePostWithConfirm(context, post);
    }
  } catch (e) {
    if (context.mounted) showError(context, e);
    return false;
  }
}

/// "Delete post?" dialog + delete. True when the post is gone.
Future<bool> deletePostWithConfirm(BuildContext context, Post post) async {
  final ok = await confirm(
    context,
    title: 'Delete post?',
    message:
        'This can’t be undone and it will be removed from your profile, the timeline of any accounts that follow you, and from search results.',
    confirmLabel: 'Delete',
    destructive: true,
  );
  if (!ok || !context.mounted) return false;
  try {
    await Api.deletePost(post.id);
    return true;
  } catch (e) {
    if (context.mounted) showError(context, e);
    return false;
  }
}

/// What the person picked in the repost popup.
enum RepostChoice { repost, undo, quote, video }

/// "Repost / Quote / React with Video" popup next to the repost icon.
Future<RepostChoice?> showRepostPopup(
  BuildContext context, {
  required Rect anchor,
  required bool reposted,
}) {
  return showMenuAt<RepostChoice>(
    context,
    anchor: anchor,
    alignRight: false,
    preferAbove: true,
    width: 270,
    leadingIcons: true,
    rows: [
      MenuRow(
        value: reposted ? RepostChoice.undo : RepostChoice.repost,
        label: reposted ? 'Undo repost' : 'Repost',
        icon: CupertinoIcons.arrow_2_squarepath,
        destructive: reposted,
      ),
      const MenuRow(
        value: RepostChoice.quote,
        label: 'Quote',
        icon: CupertinoIcons.pencil,
      ),
      const MenuRow(
        value: RepostChoice.video,
        label: 'React with Video',
        icon: CupertinoIcons.videocam,
      ),
    ],
  );
}

/// How the replies under a post are ordered.
enum ReplySort { relevant, recent, liked }

String replySortLabel(ReplySort s) {
  switch (s) {
    case ReplySort.relevant:
      return 'Relevant';
    case ReplySort.recent:
      return 'Recent';
    case ReplySort.liked:
      return 'Liked';
  }
}

/// "Relevant ⌄" menu above the replies.
Future<ReplySort?> showReplySortMenu(
  BuildContext context, {
  required Rect anchor,
  required ReplySort current,
}) {
  return showMenuAt<ReplySort>(
    context,
    anchor: anchor,
    alignRight: false,
    width: 220,
    rows: [
      for (final s in ReplySort.values)
        MenuRow(
          value: s,
          label: replySortLabel(s),
          checked: s == current,
        ),
    ],
  );
}
