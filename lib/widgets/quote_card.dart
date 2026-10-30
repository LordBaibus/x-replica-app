import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../core/app_icons.dart';
import '../core/app_palette.dart';
import '../models/models.dart';
import 'avatar.dart';
import 'badges.dart';

/// The small card of a quoted post (inside a quote post or in the composer).
/// With a picture it is laid out like on X: the picture on the left, the text
/// on the right.
class QuoteCard extends StatelessWidget {
  const QuoteCard({
    super.key,
    required this.quote,
    this.onTap,
    this.onRemove,
  });

  final QuotedPost quote;
  final VoidCallback? onTap;

  /// Shows a ✕ (used in the composer).
  final VoidCallback? onRemove;

  Widget _picture(AppPalette p, {double? width, required double height}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: height,
        width: width ?? double.infinity,
        child: CachedNetworkImage(
          imageUrl: quote.imageUrl!,
          fit: BoxFit.cover,
          placeholder: (context, url) => Container(color: p.surface),
          errorWidget: (context, url, error) => Container(color: p.surface),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final hasImage = quote.imageUrl != null && quote.imageUrl!.isNotEmpty;
    final hasText = quote.content.isNotEmpty;
    final when = quote.createdAt;

    Widget body;
    if (hasImage && hasText) {
      body = Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _picture(p, width: 104, height: 116),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              quote.content,
              maxLines: 6,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: p.text, fontSize: 15, height: 1.3),
            ),
          ),
        ],
      );
    } else if (hasImage) {
      body = _picture(p, height: 140);
    } else {
      body = Text(
        quote.content,
        maxLines: 6,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: p.text, fontSize: 15, height: 1.3),
      );
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: p.border, width: 1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Avatar(
                  url: quote.avatarUrl,
                  name: quote.authorName,
                  size: 20,
                  square: Avatar.isSquare(quote.verified),
                ),
                const SizedBox(width: 8),
                Flexible(
                  flex: 3,
                  child: NameWithBadge(
                    name: quote.authorName,
                    verified: quote.verified,
                    badgeSize: 15,
                    style: TextStyle(
                      color: p.text,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Flexible(
                  flex: 2,
                  child: Text(
                    '@${quote.username}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: p.subtext, fontSize: 14),
                  ),
                ),
                if (when != null)
                  Text(
                    ' · ${timeago.format(when, locale: 'en_short')}',
                    maxLines: 1,
                    style: TextStyle(color: p.subtext, fontSize: 14),
                  ),
                if (onRemove != null) ...[
                  const Spacer(),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onRemove,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Icon(AppIcons.close, size: 16, color: p.subtext),
                    ),
                  ),
                ],
              ],
            ),
            if (hasImage || hasText) ...[
              const SizedBox(height: 8),
              body,
            ],
          ],
        ),
      ),
    );
  }
}
