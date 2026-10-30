import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;

import '../core/app_palette.dart';
import '../core/format.dart';
import '../core/ui_helpers.dart';
import '../core/x_icons.dart';
import '../models/models.dart';
import '../screens/compose_post_screen.dart';
import '../screens/post_detail_screen.dart';
import '../screens/profile_view.dart';
import '../screens/report_screens.dart';
import '../services/api.dart';
import 'anchored_popup.dart' show rectOf;
import 'avatar.dart';
import 'badges.dart';
import 'popover_menu.dart';
import 'post_card.dart' show repostGreen;
import 'post_menus.dart' show copyPostLink, showRepostPopup, RepostChoice;
import 'reply_guard.dart';
import 'share_post_sheet.dart';
import 'video_reaction.dart';

/// The pictures of a post, laid out like X: one wide picture, two portrait
/// pictures side by side, or a 3 / 4 picture grid, with rounded corners and a
/// thin outline. Tapping a picture reports its index.
class PostMedia extends StatelessWidget {
  const PostMedia({
    super.key,
    required this.urls,
    this.radius = 16,
    this.onTap,
  });

  final List<String> urls;
  final double radius;
  final ValueChanged<int>? onTap;

  static const double _gap = 2;

  Widget _img(AppPalette p, int i) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap == null ? null : () => onTap!(i),
      child: CachedNetworkImage(
        imageUrl: urls[i],
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        placeholder: (context, url) => Container(color: p.surface),
        errorWidget: (context, url, error) => Container(color: p.surface),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (urls.isEmpty) return const SizedBox.shrink();
    final p = AppPalette.of(context);
    final n = urls.length > 4 ? 4 : urls.length;

    Widget grid;
    double ratio;
    if (n == 1) {
      ratio = 16 / 9;
      grid = _img(p, 0);
    } else if (n == 2) {
      ratio = 3 / 2;
      grid = Row(
        children: [
          Expanded(child: _img(p, 0)),
          const SizedBox(width: _gap),
          Expanded(child: _img(p, 1)),
        ],
      );
    } else if (n == 3) {
      ratio = 16 / 9;
      grid = Row(
        children: [
          Expanded(child: _img(p, 0)),
          const SizedBox(width: _gap),
          Expanded(
            child: Column(
              children: [
                Expanded(child: _img(p, 1)),
                const SizedBox(height: _gap),
                Expanded(child: _img(p, 2)),
              ],
            ),
          ),
        ],
      );
    } else {
      ratio = 16 / 9;
      grid = Column(
        children: [
          Expanded(
            child: Row(
              children: [
                Expanded(child: _img(p, 0)),
                const SizedBox(width: _gap),
                Expanded(child: _img(p, 1)),
              ],
            ),
          ),
          const SizedBox(height: _gap),
          Expanded(
            child: Row(
              children: [
                Expanded(child: _img(p, 2)),
                const SizedBox(width: _gap),
                Expanded(child: _img(p, 3)),
              ],
            ),
          ),
        ],
      );
    }

    return DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: BoxDecoration(
        border: Border.all(color: p.border, width: 1),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: AspectRatio(
          aspectRatio: ratio,
          child: ColoredBox(color: p.background, child: grid),
        ),
      ),
    );
  }
}

enum _PhotoAction { share, copyPost, copyImage, goToPost, report }

const _vWhite = Color(0xFFFFFFFF);
const _vGlass = Color(0x992A2D31);
const _vBar = Color(0xFF202327);

/// Full-screen picture viewer, laid out like X:
///
/// * the picture fills the page (swipe between the post's pictures, pinch to
///   zoom, one tap hides / shows everything else);
/// * round back button top left, "..." menu top right;
/// * "From <author>" label, then reply / repost / like pills with bookmark and
///   share buttons, then the "Post your reply" bar at the bottom.
///
/// Without a [post] it is only the picture and the back button.
class ImageViewerScreen extends StatefulWidget {
  const ImageViewerScreen({
    super.key,
    required this.urls,
    this.initial = 0,
    this.post,
  });

  final List<String> urls;
  final int initial;
  final Post? post;

  @override
  State<ImageViewerScreen> createState() => _ImageViewerScreenState();
}

class _ImageViewerScreenState extends State<ImageViewerScreen> {
  late final PageController _pages = PageController(initialPage: widget.initial);
  late int _index = widget.initial;
  late Post? _post = widget.post;
  bool _overlays = true;
  final GlobalKey _moreKey = GlobalKey();

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------- actions

  Future<void> _like() async {
    final before = _post;
    if (before == null) return;
    final next = before.copyWith(
      likedByMe: !before.likedByMe,
      likeCount: before.likeCount + (before.likedByMe ? -1 : 1),
    );
    setState(() => _post = next);
    try {
      await Api.setLike(before.id, like: next.likedByMe);
    } catch (e) {
      if (!mounted) return;
      setState(() => _post = before);
      showError(context, e);
    }
  }

  Future<void> _repost() async {
    final before = _post;
    if (before == null) return;
    final next = before.copyWith(
      repostedByMe: !before.repostedByMe,
      repostCount: before.repostCount + (before.repostedByMe ? -1 : 1),
    );
    setState(() => _post = next);
    try {
      await Api.setRepost(before.id, reposted: next.repostedByMe);
      if (mounted) {
        showInfo(context, next.repostedByMe ? 'You reposted' : 'Repost removed');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _post = before);
      showError(context, e);
    }
  }

  Future<void> _repostMenu(Rect anchor) async {
    final post = _post;
    if (post == null) return;
    final choice = await showRepostPopup(
      context,
      anchor: anchor,
      reposted: post.repostedByMe,
    );
    if (choice == null || !mounted) return;
    switch (choice) {
      case RepostChoice.repost:
      case RepostChoice.undo:
        await _repost();
      case RepostChoice.quote:
        final posted = await Navigator.of(context).push<bool>(
          appRoute(ComposePostScreen(quoting: post), fullscreen: true),
        );
        if (posted == true && mounted) {
          setState(() => _post = post.copyWith(repostCount: post.repostCount + 1));
          showSuccess(context, 'Your quote was posted');
        }
      case RepostChoice.video:
        if (await reactWithVideo(context, post) && mounted) {
          setState(() => _post = post.copyWith(repostCount: post.repostCount + 1));
        }
    }
  }

  Future<void> _bookmark() async {
    final before = _post;
    if (before == null) return;
    final saved = !before.bookmarkedByMe;
    final next = before.copyWith(
      bookmarkedByMe: saved,
      bookmarkCount:
          (before.bookmarkCount + (saved ? 1 : -1)).clamp(0, 1 << 31).toInt(),
    );
    setState(() => _post = next);
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
      setState(() => _post = before);
      showError(context, e);
    }
  }

  Future<void> _reply() async {
    final post = _post;
    if (post == null) return;
    if (!await ensureCanReply(context, post) || !mounted) return;
    final posted = await Navigator.of(context).push<bool>(
      appRoute(ComposePostScreen(replyTo: post), fullscreen: true),
    );
    if (posted == true && mounted) {
      setState(() => _post = post.copyWith(replyCount: post.replyCount + 1));
      showSuccess(context, 'Your reply was sent');
    }
  }

  void _openAuthor() {
    final post = _post;
    if (post == null) return;
    Navigator.of(context).push(appRoute(ProfileScreen(userId: post.userId)));
  }

  Future<void> _openMenu() async {
    final post = _post;
    if (post == null) return;
    final pick = await showPopoverMenu<_PhotoAction>(
      context,
      anchor: _moreKey,
      width: 280,
      entries: const [
        PopoverEntry(
          value: _PhotoAction.share,
          label: 'Share post via...',
          icon: CupertinoIcons.share,
        ),
        PopoverEntry(
          value: _PhotoAction.copyPost,
          label: 'Copy link to post',
          icon: CupertinoIcons.link,
        ),
        PopoverEntry(
          value: _PhotoAction.copyImage,
          label: 'Copy image link',
          icon: CupertinoIcons.photo,
        ),
        PopoverEntry(
          value: _PhotoAction.goToPost,
          label: 'Go to post',
          icon: CupertinoIcons.arrow_turn_up_right,
          groupStart: true,
        ),
        PopoverEntry(
          value: _PhotoAction.report,
          label: 'Report post',
          icon: CupertinoIcons.flag,
        ),
      ],
    );
    if (pick == null || !mounted) return;
    switch (pick) {
      case _PhotoAction.share:
        await showSharePostSheet(context, post);
      case _PhotoAction.copyPost:
        await copyPostLink(context, post);
      case _PhotoAction.copyImage:
        await Clipboard.setData(ClipboardData(text: widget.urls[_index]));
        if (mounted) showInfo(context, 'Image link copied');
      case _PhotoAction.goToPost:
        await Navigator.of(context).push(appRoute(PostDetailScreen(post: post)));
      case _PhotoAction.report:
        await Navigator.of(context).push(
          appRoute(ReportPostScreen(post: post), fullscreen: true),
        );
    }
  }

  // ------------------------------------------------------------- pieces

  Widget _circle(IconData icon, VoidCallback onTap, {Key? key}) {
    return GestureDetector(
      key: key,
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: const BoxDecoration(color: _vGlass, shape: BoxShape.circle),
        child: Icon(icon, size: 22, color: _vWhite),
      ),
    );
  }

  Widget _pill({
    required List<XShape> icon,
    required int count,
    required VoidCallback onTap,
    Color color = _vWhite,
    void Function(Rect)? onAnchorTap,
  }) {
    return Expanded(
      child: Builder(
        builder: (ctx) => GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onAnchorTap == null ? onTap : () => onAnchorTap(rectOf(ctx)),
          child: Container(
            height: 44,
            decoration: BoxDecoration(
              color: _vGlass,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                XIcon(icon, size: 21, color: color),
                if (count > 0) ...[
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      compactCount(count),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: color,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _round(List<XShape> icon, VoidCallback onTap, {Color color = _vWhite}) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: const BoxDecoration(color: _vGlass, shape: BoxShape.circle),
        child: Center(child: XIcon(icon, size: 20, color: color)),
      ),
    );
  }

  Widget _fromLabel(Post post) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _openAuthor,
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 6, 12, 6),
        decoration: BoxDecoration(
          color: _vGlass,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'From ',
              style: TextStyle(
                color: Color(0xFFD0D3D6),
                fontSize: 15,
                decoration: TextDecoration.none,
              ),
            ),
            Avatar(
              url: post.avatarUrl,
              name: post.authorName,
              size: 20,
              square: Avatar.isSquare(post.authorVerified),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: NameWithBadge(
                name: post.authorName,
                verified: post.authorVerified,
                locked: post.authorProtected,
                badgeSize: 15,
                style: const TextStyle(
                  color: _vWhite,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bottom(Post post) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _fromLabel(post),
            const SizedBox(height: 10),
            Row(
              children: [
                _pill(icon: XIcons.reply, count: post.replyCount, onTap: _reply),
                const SizedBox(width: 8),
                _pill(
                  icon: XIcons.repost,
                  count: post.repostCount,
                  onTap: _repost,
                  color: post.repostedByMe ? repostGreen : _vWhite,
                  onAnchorTap: _repostMenu,
                ),
                const SizedBox(width: 8),
                _pill(
                  icon: post.likedByMe ? XIcons.likeFill : XIcons.like,
                  count: post.likeCount,
                  onTap: _like,
                  color: post.likedByMe ? AppPalette.like : _vWhite,
                ),
                const SizedBox(width: 8),
                _round(
                  post.bookmarkedByMe ? XIcons.bookmarkFill : XIcons.bookmark,
                  _bookmark,
                  color: post.bookmarkedByMe ? const Color(0xFF1D9BF0) : _vWhite,
                ),
                const SizedBox(width: 8),
                _round(XIcons.share, () => showSharePostSheet(context, post)),
              ],
            ),
            const SizedBox(height: 10),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _reply,
              child: Container(
                width: double.infinity,
                height: 48,
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(horizontal: 22),
                decoration: BoxDecoration(
                  color: _vBar,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Text(
                  'Post your reply',
                  style: TextStyle(
                    color: Color(0xFFB0B4B8),
                    fontSize: 17,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final post = _post;
    return ColoredBox(
      color: const Color(0xFF000000),
      child: DefaultTextStyle(
        style: const TextStyle(
          color: _vWhite,
          fontSize: 16,
          decoration: TextDecoration.none,
        ),
        child: Stack(
          children: [
            PageView.builder(
              controller: _pages,
              itemCount: widget.urls.length,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (context, i) => GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _overlays = !_overlays),
                child: InteractiveViewer(
                  minScale: 1,
                  maxScale: 4,
                  child: Center(
                    child: CachedNetworkImage(
                      imageUrl: widget.urls[i],
                      fit: BoxFit.contain,
                      placeholder: (context, url) =>
                          const CupertinoActivityIndicator(),
                      errorWidget: (context, url, error) => const Icon(
                        CupertinoIcons.photo,
                        size: 48,
                        color: Color(0xFF71767B),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                ignoring: !_overlays,
                child: AnimatedOpacity(
                  opacity: _overlays ? 1 : 0,
                  duration: const Duration(milliseconds: 180),
                  child: Column(
                    children: [
                      SafeArea(
                        bottom: false,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                          child: Row(
                            children: [
                              _circle(
                                CupertinoIcons.arrow_left,
                                () => Navigator.of(context).maybePop(),
                              ),
                              const Spacer(),
                              if (widget.urls.length > 1)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _vGlass,
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Text(
                                    '${_index + 1} / ${widget.urls.length}',
                                  ),
                                ),
                              if (post != null) ...[
                                const SizedBox(width: 8),
                                _circle(
                                  CupertinoIcons.ellipsis,
                                  _openMenu,
                                  key: _moreKey,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const Spacer(),
                      if (post != null) _bottom(post),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
