import 'package:flutter/cupertino.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../core/x_icons.dart';
import '../core/app_palette.dart';
import '../core/format.dart';
import '../core/ui_helpers.dart';
import '../models/models.dart';
import 'ai_dialogs.dart' show AiGlyph;
import 'anchored_popup.dart';
import 'avatar.dart';
import 'badges.dart';
import '../screens/community_notes_screen.dart';
import 'poll_view.dart';
import 'post_media.dart';
import 'post_video.dart';
import 'quote_card.dart';
import 'state_views.dart';

/// Colour of the repost icon once I reposted.
const Color repostGreen = Color(0xFF00BA7C);

/// How a [PostCard] is laid out.
///
/// * [feed]   - a post in a timeline: the small "X" at the top right opens the
///   post menu.
/// * [reply]  - a reply under a post: Grok button and "…" at the top right.
/// * [detail] - the post itself on its own page: bigger text, date and views,
///   counts with the bookmark, no divider.
enum PostCardStyle { feed, reply, detail }

/// One post, laid out like a post on X: avatar on the left, then name, badge,
/// @handle and time on one line, the text right under it, the pictures, and
/// the action row (reply, repost, like, views, bookmark, share).
///
/// Purely presentational; [PostTile] wires it to the backend. Callbacks that
/// open a popup get the screen rectangle of the tapped icon, so the popup can
/// float next to it.
class PostCard extends StatelessWidget {
  const PostCard({
    super.key,
    required this.post,
    required this.isMine,
    required this.onLike,
    required this.onOpenAuthor,
    this.style = PostCardStyle.feed,
    this.onReply,
    this.onRepost,
    this.onBookmark,
    this.onShare,
    this.onMore,
    this.onGrok,
    this.onOpen,
    this.onDelete,
    this.onOpenQuote,
    this.onOpenImage,
    this.onOpenVideo,
    this.showDivider = true,
  });

  final Post post;
  final bool isMine;
  final PostCardStyle style;
  final VoidCallback onLike;
  final VoidCallback onOpenAuthor;

  /// Writes a reply to this post.
  final VoidCallback? onReply;

  /// Repost / Quote popup (gets the rectangle of the repost icon).
  final ValueChanged<Rect>? onRepost;

  /// Saves / un-saves the post in my Bookmarks.
  final VoidCallback? onBookmark;

  /// Opens the share sheet.
  final VoidCallback? onShare;

  /// Opens the post menu (gets the rectangle of the button).
  final ValueChanged<Rect>? onMore;

  /// Opens Grok with this post.
  final VoidCallback? onGrok;

  /// Opens the post with its replies.
  final VoidCallback? onOpen;
  final VoidCallback? onDelete;

  /// Opens the post this one quotes.
  final VoidCallback? onOpenQuote;

  /// Opens a picture of the post full screen.
  final ValueChanged<int>? onOpenImage;

  /// Tap on the video of the post (opens the full-screen player).
  final VoidCallback? onOpenVideo;
  final bool showDivider;

  static final RegExp _tokens = RegExp(r'(@[A-Za-z0-9_]+|#[A-Za-z0-9_]+)');

  /// Post text with @mentions and #hashtags in the accent colour.
  TextSpan _body(AppPalette p, double fontSize) {
    final style = TextStyle(color: p.text, fontSize: fontSize, height: 1.3);
    final spans = <InlineSpan>[];
    var last = 0;
    for (final m in _tokens.allMatches(post.content)) {
      if (m.start > last) {
        spans.add(TextSpan(text: post.content.substring(last, m.start)));
      }
      spans.add(TextSpan(
        text: m.group(0),
        style: TextStyle(color: p.accent),
      ));
      last = m.end;
    }
    if (last < post.content.length) {
      spans.add(TextSpan(text: post.content.substring(last)));
    }
    return TextSpan(style: style, children: spans);
  }

  /// Poll, quote, disclosures and location: the same in every layout.
  List<Widget> _extras(AppPalette p) {
    return [
      if (post.hasPoll)
        PollView(
          key: ValueKey('poll-${post.id}'),
          post: post,
        ),
      if (post.quote != null)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: QuoteCard(
            quote: post.quote!,
            onTap: onOpenQuote,
          ),
        ),
      if (post.noteBody != null && post.noteBody!.isNotEmpty)
        Builder(
          builder: (context) => GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.of(context).push(
              appRoute(PostNotesScreen(post: post)),
            ),
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: p.border),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(CupertinoIcons.person_3_fill,
                          size: 16, color: p.subtext),
                      const SizedBox(width: 6),
                      Text(
                        'Readers added context',
                        style: TextStyle(
                          color: p.text,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    post.noteBody!,
                    maxLines: 6,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: p.text, fontSize: 15, height: 1.3),
                  ),
                  if (post.noteSource != null && post.noteSource!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        post.noteSource!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: p.accent, fontSize: 13),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      if (post.paidPartnership || post.madeWithAi)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              if (post.paidPartnership)
                _DisclosureLabel(
                  icon: CupertinoIcons.money_dollar_circle,
                  text: 'Paid partnership',
                  color: p.subtext,
                ),
              if (post.madeWithAi)
                _DisclosureLabel(
                  icon: CupertinoIcons.sparkles,
                  text: 'Made with AI',
                  color: p.subtext,
                ),
            ],
          ),
        ),
      if (post.location != null)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(
            children: [
              Icon(CupertinoIcons.location_solid, size: 14, color: p.subtext),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  post.location!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: p.subtext, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
    ];
  }

  Widget _media(double top) {
    if (post.hasVideo) {
      return Padding(
        padding: EdgeInsets.only(top: top),
        child: VideoPoster(url: post.videoUrl, onTap: onOpenVideo),
      );
    }
    final urls = post.images;
    if (urls.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.only(top: top),
      child: PostMedia(urls: urls, onTap: onOpenImage),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    if (style == PostCardStyle.detail) return _detail(context, p);
    return _timeline(context, p);
  }

  // ------------------------------------------------------------- timeline

  Widget _timeline(BuildContext context, AppPalette p) {
    final time = timeago.format(post.createdAt, locale: 'en_short');

    return Column(
      children: [
        if (post.communityName != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(68, 10, 16, 0),
            child: Row(
              children: [
                Icon(CupertinoIcons.person_2_fill, size: 15, color: p.subtext),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    post.communityName!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: p.subtext,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onOpen,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: onOpenAuthor,
                  behavior: HitTestBehavior.opaque,
                  child: Avatar(
                    url: post.avatarUrl,
                    name: post.authorName,
                    size: 40,
                    square: Avatar.isSquare(post.authorVerified),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Name ✓ @handle · 20h ................ Grok …
                      Row(
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Flexible(
                                  flex: 3,
                                  child: GestureDetector(
                                    onTap: onOpenAuthor,
                                    child: NameWithBadge(
                                      name: post.authorName,
                                      verified: post.authorVerified,
                                      locked: post.authorProtected,
                                      style: TextStyle(
                                        color: p.text,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  flex: 2,
                                  child: Text(
                                    '@${post.username}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: p.subtext,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                                // Never shrinks, so the time stays visible.
                                Text(
                                  post.editedAt == null
                                      ? ' · $time'
                                      : ' · $time · Edited',
                                  maxLines: 1,
                                  style: TextStyle(
                                    color: p.subtext,
                                    fontSize: 15,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          _replyButtons(context, p),
                        ],
                      ),
                      if (post.authorBadge != null)
                        Text(
                          post.authorBadge!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: p.subtext, fontSize: 13),
                        ),
                      if (post.content.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text.rich(_body(p, 15)),
                        ),
                      _media(12),
                      ..._extras(p),
                      _actions(context, p),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (showDivider) const HairlineDivider(),
      ],
    );
  }

  /// Grok button and "…" at the top right of every post (like on X).
  Widget _replyButtons(BuildContext context, AppPalette p) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onGrok,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 2, 6, 4),
            child: AiGlyph(size: 18, color: p.subtext),
          ),
        ),
        Builder(
          builder: (c) => GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onMore == null ? null : () => onMore!(rectOf(c)),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(6, 2, 0, 4),
              child: Icon(CupertinoIcons.ellipsis, size: 18, color: p.subtext),
            ),
          ),
        ),
      ],
    );
  }

  Widget _actions(BuildContext context, AppPalette p) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _Action(
            icon: XIcons.reply,
            count: post.replyCount,
            color: p.subtext,
            onTap: onReply,
          ),
          _Action(
            icon: XIcons.repost,
            count: post.repostCount,
            color: post.repostedByMe ? repostGreen : p.subtext,
            onTapRect: onRepost,
          ),
          _Action(
            icon: post.likedByMe ? XIcons.likeFill : XIcons.like,
            count: post.likeCount,
            color: post.likedByMe ? AppPalette.like : p.subtext,
            onTap: onLike,
          ),
          _Action(
            icon: XIcons.views,
            count: post.views,
            color: p.subtext,
            onTap: onOpen,
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _Action(
                icon: post.bookmarkedByMe
                    ? XIcons.bookmarkFill
                    : XIcons.bookmark,
                color: post.bookmarkedByMe ? p.accent : p.subtext,
                onTap: onBookmark,
              ),
              const SizedBox(width: 10),
              _Action(
                icon: XIcons.share,
                color: p.subtext,
                onTap: onShare,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------- detail

  static String _two(int n) => n.toString().padLeft(2, '0');

  /// "20:06 · 10/23/26 · " (or "8:06 PM · ..." on a 12-hour phone).
  String _stamp(BuildContext context, [DateTime? at]) {
    final t = at ?? post.createdAt;
    final h24 = MediaQuery.alwaysUse24HourFormatOf(context);
    final hour12 = t.hour % 12 == 0 ? 12 : t.hour % 12;
    final time = h24
        ? '${_two(t.hour)}:${_two(t.minute)}'
        : '$hour12:${_two(t.minute)} ${t.hour < 12 ? 'AM' : 'PM'}';
    final date = '${_two(t.month)}/${_two(t.day)}/${_two(t.year % 100)}';
    return '$time · $date · ';
  }

  Widget _detail(BuildContext context, AppPalette p) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // [avatar]  Name ✓                              Grok  …
          //           @handle
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: onOpenAuthor,
                behavior: HitTestBehavior.opaque,
                child: Avatar(
                  url: post.avatarUrl,
                  name: post.authorName,
                  size: 46,
                  square: Avatar.isSquare(post.authorVerified),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: onOpenAuthor,
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      NameWithBadge(
                        name: post.authorName,
                        verified: post.authorVerified,
                        locked: post.authorProtected,
                        badgeSize: 18,
                        style: TextStyle(
                          color: p.text,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        '@${post.username}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: p.subtext, fontSize: 15),
                      ),
                      if (post.authorBadge != null)
                        Text(
                          post.authorBadge!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: p.subtext, fontSize: 13),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _replyButtons(context, p),
            ],
          ),
          if (post.content.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Text.rich(_body(p, 18)),
            ),
          _media(14),
          ..._extras(p),
          if (post.editedAt != null)
            Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(CupertinoIcons.pencil, size: 15, color: p.subtext),
                  const SizedBox(width: 4),
                  Text(
                    'Last edited ${_stamp(context, post.editedAt).replaceAll(RegExp(r' · $'), '')}',
                    style: TextStyle(color: p.subtext, fontSize: 14),
                  ),
                ],
              ),
            ),
          // 20:06 · 10/23/26 · 56K Views
          Padding(
            padding: EdgeInsets.only(top: post.editedAt != null ? 6 : 14),
            child: Text.rich(
              TextSpan(
                style: TextStyle(color: p.subtext, fontSize: 15),
                children: [
                  TextSpan(text: _stamp(context)),
                  TextSpan(
                    text: compactCount(post.views),
                    style: TextStyle(
                      color: p.text,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const TextSpan(text: ' Views'),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _Action(
                  icon: XIcons.reply,
                  count: post.replyCount,
                  color: p.subtext,
                  onTap: onReply,
                  size: 23,
                  fontSize: 15,
                ),
                _Action(
                  icon: XIcons.repost,
                  count: post.repostCount,
                  color: post.repostedByMe ? repostGreen : p.subtext,
                  onTapRect: onRepost,
                  size: 23,
                  fontSize: 15,
                ),
                _Action(
                  icon: post.likedByMe ? XIcons.likeFill : XIcons.like,
                  count: post.likeCount,
                  color: post.likedByMe ? AppPalette.like : p.subtext,
                  onTap: onLike,
                  size: 23,
                  fontSize: 15,
                ),
                _Action(
                  icon: post.bookmarkedByMe
                      ? XIcons.bookmarkFill
                      : XIcons.bookmark,
                  count: post.bookmarkCount,
                  color: post.bookmarkedByMe ? p.accent : p.subtext,
                  onTap: onBookmark,
                  size: 23,
                  fontSize: 15,
                ),
                _Action(
                  icon: XIcons.share,
                  color: p.subtext,
                  onTap: onShare,
                  size: 23,
                  fontSize: 15,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Icon (+ optional count) in the action row under a post.
class _Action extends StatelessWidget {
  const _Action({
    required this.icon,
    required this.color,
    this.onTap,
    this.onTapRect,
    this.count = 0,
    this.size = 19,
    this.fontSize = 13,
  });

  final List<XShape> icon;
  final Color color;
  final VoidCallback? onTap;

  /// Like [onTap], but also tells where the icon is on the screen.
  final ValueChanged<Rect>? onTapRect;
  final int count;
  final double size;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (onTapRect != null) {
          onTapRect!(rectOf(context));
        } else {
          onTap?.call();
        }
      },
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            XIcon(icon, size: size, color: color),
            if (count > 0) ...[
              const SizedBox(width: 5),
              Text(
                compactCount(count),
                style: TextStyle(color: color, fontSize: fontSize),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Small "Paid partnership" / "Made with AI" label under a post.
class _DisclosureLabel extends StatelessWidget {
  const _DisclosureLabel({
    required this.icon,
    required this.text,
    required this.color,
  });

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(color: color, fontSize: 13)),
      ],
    );
  }
}
