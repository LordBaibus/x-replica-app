import 'package:flutter/cupertino.dart';

import '../core/app_palette.dart';
import '../core/format.dart';
import '../core/ui_helpers.dart';
import '../models/models.dart';
import '../services/api.dart';
import '../widgets/page_header.dart';
import '../widgets/plain_scaffold.dart';
import '../widgets/post_tile.dart';
import '../widgets/responsive.dart';
import '../widgets/state_views.dart';

/// Creator Studio: programs, tools and support, laid out like X's page.
/// Analytics and Inspiration use my own posts; the programs are shown as
/// "Ineligible" because this educational app has no payouts.
class CreatorStudioScreen extends StatelessWidget {
  const CreatorStudioScreen({super.key});

  void _open(BuildContext context, Widget page) =>
      Navigator.of(context).push(appRoute(page));

  Widget _section(AppPalette p, String title) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 22, 16, 6),
        child: Text(
          title,
          style: TextStyle(
            color: p.text,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
      );

  Widget _badge(AppPalette p, String label, {bool blue = false}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        decoration: BoxDecoration(
          color: blue ? p.accent : p.field,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: blue ? const Color(0xFFFFFFFF) : p.subtext,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      );

  Widget _row(
    AppPalette p, {
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? badge,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 24, color: p.text),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: p.text,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (subtitle != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        subtitle,
                        style: TextStyle(color: p.subtext, fontSize: 14),
                      ),
                    ),
                ],
              ),
            ),
            if (badge != null) ...[badge, const SizedBox(width: 8)],
            Icon(CupertinoIcons.chevron_forward, size: 16, color: p.subtext),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);

    return PlainScaffold(
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const PageHeader(title: 'Creator Studio'),
            Expanded(
              child: ContentWidth(
                child: ListView(
                  padding: const EdgeInsets.only(bottom: 40),
                  children: [
                    _section(p, 'Programs'),
                    _row(
                      p,
                      icon: CupertinoIcons.gift,
                      title: 'Original Content Rewards',
                      subtitle: 'Earn from your posts',
                      badge: _badge(p, 'Ineligible'),
                      onTap: () => notify(
                        context,
                        title: 'Original Content Rewards',
                        message: 'This educational replica has no payouts, so '
                            'every account is shown as ineligible.',
                      ),
                    ),
                    _row(
                      p,
                      icon: CupertinoIcons.person_crop_circle_badge_checkmark,
                      title: 'Subscriptions',
                      badge: _badge(p, 'Ineligible'),
                      onTap: () => notify(
                        context,
                        title: 'Subscriptions',
                        message: 'Paid subscriptions are outside the scope of '
                            'this project.',
                      ),
                    ),
                    _section(p, 'Tools'),
                    _row(
                      p,
                      icon: CupertinoIcons.chart_bar,
                      title: 'Analytics',
                      onTap: () => _open(context, const _AnalyticsScreen()),
                    ),
                    _row(
                      p,
                      icon: CupertinoIcons.sparkles,
                      title: 'Inspiration',
                      subtitle: 'Top posts by engagement',
                      onTap: () => _open(context, const _InspirationScreen()),
                    ),
                    _row(
                      p,
                      icon: CupertinoIcons.book,
                      title: 'Creator Academy',
                      subtitle: 'Tips and guides for creators',
                      badge: _badge(p, 'New', blue: true),
                      onTap: () => notify(
                        context,
                        title: 'Creator Academy',
                        message: 'Post often, add a photo, reply to people and '
                            'keep posts short. Check Analytics to see what '
                            'works.',
                      ),
                    ),
                    _section(p, 'Support'),
                    _row(
                      p,
                      icon: CupertinoIcons.chat_bubble_text,
                      title: 'Contact support',
                      onTap: () => notify(
                        context,
                        title: 'Contact support',
                        message: 'There is no support desk in this project. '
                            'Ask your instructor or the project team.',
                      ),
                    ),
                    _row(
                      p,
                      icon: CupertinoIcons.question_circle,
                      title: 'Learn more',
                      onTap: () => notify(
                        context,
                        title: 'Learn more',
                        message: 'Creator Studio collects tools for people who '
                            'post often: programs, analytics and ideas.',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Totals over my own posts.
class _AnalyticsScreen extends StatefulWidget {
  const _AnalyticsScreen();

  @override
  State<_AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<_AnalyticsScreen> {
  List<Post>? _posts;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final list = await Api.fetchUserPosts(Api.uid);
      if (mounted) setState(() => _posts = list);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Widget _stat(AppPalette p, String label, int value) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
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
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final posts = _posts;

    Widget body;
    if (_error != null) {
      body = ErrorView(error: _error!, onRetry: _load);
    } else if (posts == null) {
      body = const LoadingView();
    } else {
      int sum(int Function(Post) f) => posts.fold(0, (a, x) => a + f(x));
      body = ContentWidth(
        child: ListView(
          children: [
            _stat(p, 'Posts', posts.length),
            _stat(p, 'Views', sum((x) => x.views)),
            _stat(p, 'Likes received', sum((x) => x.likeCount)),
            _stat(p, 'Reposts received', sum((x) => x.repostCount)),
            _stat(p, 'Replies received', sum((x) => x.replyCount)),
          ],
        ),
      );
    }

    return PlainScaffold(
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const PageHeader(title: 'Analytics'),
            Expanded(child: body),
          ],
        ),
      ),
    );
  }
}

/// My posts, best engagement first.
class _InspirationScreen extends StatefulWidget {
  const _InspirationScreen();

  @override
  State<_InspirationScreen> createState() => _InspirationScreenState();
}

class _InspirationScreenState extends State<_InspirationScreen> {
  List<Post>? _posts;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final list = await Api.fetchUserPosts(Api.uid);
      int score(Post x) => x.likeCount + x.repostCount + x.replyCount;
      list.sort((a, b) => score(b).compareTo(score(a)));
      if (mounted) setState(() => _posts = list);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final posts = _posts;

    Widget body;
    if (_error != null) {
      body = ErrorView(error: _error!, onRetry: _load);
    } else if (posts == null) {
      body = const LoadingView();
    } else if (posts.isEmpty) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            'Post something and your best posts will show up here.',
            textAlign: TextAlign.center,
            style: TextStyle(color: p.subtext, fontSize: 16),
          ),
        ),
      );
    } else {
      body = ContentWidth(
        child: ListView.builder(
          itemCount: posts.length,
          itemBuilder: (context, i) => PostTile(
            key: ValueKey(posts[i].id),
            post: posts[i],
            onDeleted: (x) => setState(
              () => _posts = posts.where((y) => y.id != x.id).toList(),
            ),
          ),
        ),
      );
    }

    return PlainScaffold(
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const PageHeader(title: 'Inspiration'),
            Expanded(child: body),
          ],
        ),
      ),
    );
  }
}
