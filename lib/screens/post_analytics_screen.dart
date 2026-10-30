import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/cupertino.dart';

import '../core/app_palette.dart';
import '../core/format.dart';
import '../models/models.dart';
import '../core/ui_helpers.dart';
import '../services/api.dart';
import '../widgets/page_header.dart';
import '../widgets/responsive.dart';
import '../widgets/state_views.dart';
import 'post_extra_screens.dart';

/// "Post analytics": real numbers for one of my posts, from the database
/// (views, likes, reposts, quotes, replies, bookmarks, detail expands,
/// profile visits, shares) plus the last 7 days.
class PostAnalyticsScreen extends StatefulWidget {
  const PostAnalyticsScreen({super.key, required this.post});

  final Post post;

  @override
  State<PostAnalyticsScreen> createState() => _PostAnalyticsScreenState();
}

class _PostAnalyticsScreenState extends State<PostAnalyticsScreen> {
  PostAnalytics? _data;
  Object? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final d = await Api.fetchPostAnalytics(widget.post.id);
      if (!mounted) return;
      setState(() {
        _data = d;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  Widget _big(AppPalette p, String label, int value, {IconData? icon}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          border: Border.all(color: p.border),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              compactCount(value),
              style: TextStyle(
                color: p.text,
                fontSize: 26,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(color: p.subtext, fontSize: 14)),
          ],
        ),
      ),
    );
  }

  Widget _row(AppPalette p, IconData icon, String label, int value,
      {VoidCallback? onTap}) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 22, color: p.subtext),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(color: p.text, fontSize: 16),
              ),
            ),
            Text(
              compactCount(value),
              style: TextStyle(
                color: p.text,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (onTap != null) ...[
              const SizedBox(width: 6),
              Icon(CupertinoIcons.chevron_right, size: 14, color: p.subtext),
            ],
          ],
        ),
      ),
    );
  }

  static const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  Widget _chart(AppPalette p, List<AnalyticsDay> days) {
    final maxTotal = days.fold<int>(1, (m, d) => d.total > m ? d.total : m);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
      decoration: BoxDecoration(
        border: Border.all(color: p.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Engagements, last 7 days',
            style: TextStyle(
              color: p.text,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 130,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final d in days)
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          d.total == 0 ? '' : '${d.total}',
                          style: TextStyle(color: p.subtext, fontSize: 11),
                        ),
                        const SizedBox(height: 3),
                        Container(
                          height: d.total == 0 ? 3 : 4 + 90 * d.total / maxTotal,
                          margin: const EdgeInsets.symmetric(horizontal: 6),
                          decoration: BoxDecoration(
                            color: d.total == 0 ? p.border : p.accent,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _dayLabel(d.day),
                          style: TextStyle(color: p.subtext, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _dayLabel(String iso) {
    final t = DateTime.tryParse(iso);
    return t == null ? '' : _weekdays[t.weekday - 1];
  }

  Widget _content(AppPalette p, PostAnalytics d) {
    final rate = d.views == 0 ? 0.0 : d.engagements * 100 / d.views;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: p.field,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            widget.post.content.isEmpty ? 'Post' : widget.post.content,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: p.subtext, fontSize: 15, height: 1.3),
          ),
        ),
        const SizedBox(height: 14),
        Row(children: [
          _big(p, 'Views', d.views),
          const SizedBox(width: 10),
          _big(p, 'Engagements', d.engagements),
        ]),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Text(
            d.views == 0
                ? 'Engagement rate: not enough views yet'
                : 'Engagement rate: ${rate.toStringAsFixed(1)}%',
            style: TextStyle(color: p.subtext, fontSize: 13),
          ),
        ),
        _chart(p, d.daily),
        const SizedBox(height: 14),
        Text(
          'Interactions',
          style: TextStyle(
            color: p.text,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        _row(p, CupertinoIcons.heart, 'Likes', d.likes),
        _row(
          p,
          CupertinoIcons.arrow_2_squarepath,
          'Reposts',
          d.reposts,
          onTap: () => Navigator.of(context).push(appRoute(
              PostInteractionsScreen(post: widget.post, initialTab: 1))),
        ),
        _row(
          p,
          CupertinoIcons.quote_bubble,
          'Quotes',
          d.quotes,
          onTap: () => Navigator.of(context)
              .push(appRoute(PostInteractionsScreen(post: widget.post))),
        ),
        _row(p, CupertinoIcons.chat_bubble, 'Replies', d.replies),
        _row(p, CupertinoIcons.bookmark, 'Bookmarks', d.bookmarks),
        _row(p, CupertinoIcons.share, 'Shares', d.shares),
        const SizedBox(height: 10),
        Text(
          'Other activity',
          style: TextStyle(
            color: p.text,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        _row(p, CupertinoIcons.arrow_up_left_arrow_down_right,
            'Detail expands', d.detailExpands),
        _row(p, CupertinoIcons.person, 'Profile visits', d.profileVisits),
        _row(p, CupertinoIcons.link, 'Link clicks', d.linkClicks),
        const SizedBox(height: 12),
        Text(
          'Views come from people opening the post. Detail expands, profile '
          'visits and shares are counted when someone else opens the post, '
          'taps your name on it, or shares it.',
          style: TextStyle(color: p.subtext, fontSize: 13, height: 1.3),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    Widget body;
    if (_loading) {
      body = const LoadingView();
    } else if (_error != null) {
      body = ErrorView(error: _error!, onRetry: _load);
    } else {
      body = _content(p, _data!);
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
                const PageHeader(title: 'Post analytics'),
                Expanded(child: body),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
