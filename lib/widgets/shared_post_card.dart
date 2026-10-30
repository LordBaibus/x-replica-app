import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../core/app_palette.dart';
import '../core/ui_helpers.dart';
import '../models/models.dart';
import '../screens/post_detail_screen.dart';
import '../services/api.dart';
import 'avatar.dart';
import 'badges.dart';

/// Messages that share a post carry its link (`xreplica://post/<id>`).
/// These helpers find the link and the text typed next to it.
class SharedPost {
  const SharedPost._();

  static final RegExp _link = RegExp(r'xreplica://post/([0-9a-fA-F-]{36})');

  /// The id of the shared post, or null when [content] is a normal message.
  static String? idIn(String content) => _link.firstMatch(content)?.group(1);

  /// What the sender typed besides the link ('' when nothing).
  static String textIn(String content) =>
      content.replaceAll(_link, '').trim();

  /// One-line text for the inbox ("Shared a post" / "Shared a post · hi").
  static String preview(String content) {
    if (idIn(content) == null) return content;
    final text = textIn(content);
    return text.isEmpty ? 'Shared a post' : 'Shared a post · $text';
  }
}

/// The preview card of a post sent in a message: author, text and the first
/// picture. Tapping it opens the post.
class SharedPostCard extends StatefulWidget {
  const SharedPostCard({super.key, required this.postId});

  final String postId;

  @override
  State<SharedPostCard> createState() => _SharedPostCardState();
}

class _SharedPostCardState extends State<SharedPostCard> {
  // Posts already fetched, so scrolling the chat does not reload them.
  static final Map<String, Post?> _cache = {};

  Post? _post;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(SharedPostCard old) {
    super.didUpdateWidget(old);
    if (old.postId != widget.postId) _load();
  }

  Future<void> _load() async {
    final id = widget.postId;
    if (_cache.containsKey(id)) {
      setState(() {
        _post = _cache[id];
        _loading = false;
      });
      return;
    }
    setState(() => _loading = true);
    Post? post;
    try {
      post = await Api.fetchPost(id);
      _cache[id] = post;
    } catch (_) {
      // Not cached, so the next build can try again.
    }
    if (!mounted || widget.postId != id) return;
    setState(() {
      _post = post;
      _loading = false;
    });
  }

  Future<void> _open() async {
    final post = _post;
    if (post == null) return;
    await Navigator.of(context).push(appRoute(PostDetailScreen(post: post)));
  }

  Widget _frame(AppPalette p, Widget child, {VoidCallback? onTap}) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: double.infinity,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: p.background,
          border: Border.all(color: p.border, width: 1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);

    if (_loading) {
      return _frame(
        p,
        const SizedBox(height: 88, child: Center(child: CupertinoActivityIndicator())),
      );
    }
    final post = _post;
    if (post == null) {
      return _frame(
        p,
        Padding(
          padding: const EdgeInsets.all(14),
          child: Text(
            'This post is not available.',
            style: TextStyle(color: p.subtext, fontSize: 14),
          ),
        ),
      );
    }

    final images = post.images;
    final hasImage = images.isNotEmpty;
    final hasText = post.content.trim().isNotEmpty;

    return _frame(
      p,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasImage)
            SizedBox(
              height: 150,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
                    imageUrl: images.first,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(color: p.surface),
                    errorWidget: (context, url, error) =>
                        Container(color: p.surface),
                  ),
                  if (images.length > 1)
                    Positioned(
                      right: 8,
                      bottom: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0x99000000),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '+${images.length - 1}',
                          style: const TextStyle(
                            color: Color(0xFFFFFFFF),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            )
          else if (post.hasVideo)
            Container(
              height: 110,
              width: double.infinity,
              color: p.surface,
              alignment: Alignment.center,
              child: Icon(CupertinoIcons.play_circle_fill, size: 40, color: p.subtext),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Avatar(
                      url: post.avatarUrl,
                      name: post.authorName,
                      size: 20,
                      square: Avatar.isSquare(post.authorVerified),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      flex: 3,
                      child: NameWithBadge(
                        name: post.authorName,
                        verified: post.authorVerified,
                        badgeSize: 15,
                        style: TextStyle(
                          color: p.text,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          decoration: TextDecoration.none,
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
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ),
                    Text(
                      ' · ${timeago.format(post.createdAt, locale: 'en_short')}',
                      maxLines: 1,
                      style: TextStyle(
                        color: p.subtext,
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ],
                ),
                if (hasText) ...[
                  const SizedBox(height: 6),
                  Text(
                    post.content,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: p.text,
                      fontSize: 15,
                      height: 1.3,
                      fontWeight: FontWeight.w400,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
      onTap: _open,
    );
  }
}
