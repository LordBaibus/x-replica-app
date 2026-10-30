import 'package:flutter/cupertino.dart';

import '../core/app_icons.dart';
import '../core/app_palette.dart';
import '../core/format.dart';
import '../core/topics.dart';
import '../core/ui_helpers.dart';
import '../models/models.dart';
import '../services/api.dart';
import '../widgets/post_tile.dart';
import '../widgets/responsive.dart';
import '../widgets/scroll_tabs.dart';
import '../widgets/state_views.dart';
import '../widgets/suggested_list.dart';
import '../widgets/top_bar.dart';
import 'connect_screen.dart';
import 'search_screen.dart';
import 'settings_screen.dart';
import '../core/x_icons.dart';
import '../widgets/post_skeleton.dart';

/// The Search tab as X shows it: a search pill on top, then
/// Explore / Trending / News / Sports / Entertainment.
class ExploreView extends StatefulWidget {
  const ExploreView({super.key, required this.me, required this.onOpenDrawer});

  final Profile? me;
  final VoidCallback onOpenDrawer;

  @override
  State<ExploreView> createState() => _ExploreViewState();
}

class _ExploreViewState extends State<ExploreView> {
  static const _labels = [
    'Explore',
    'Trending',
    'News',
    'Sports',
    'Entertainment',
  ];
  static const _topicOfTab = {2: 'news', 3: 'sports', 4: 'entertainment'};

  int _tab = 0;
  List<TrendingTag> _trending = const [];
  List<Post> _posts = const [];
  bool _loading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      List<TrendingTag> trending = _trending;
      List<Post> posts = const [];
      if (_tab <= 1) {
        final r = await Future.wait<Object>([
          Api.fetchTrending(limit: _tab == 1 ? 30 : 6),
          if (_tab == 0) Api.fetchFeed(),
        ]);
        trending = r[0] as List<TrendingTag>;
        if (_tab == 0) posts = r[1] as List<Post>;
      } else {
        final topic = Topics.byId(_topicOfTab[_tab]!);
        posts = await Api.fetchFeed(keywords: topic?.keywords ?? const []);
      }
      if (!mounted) return;
      setState(() {
        _trending = trending;
        _posts = posts;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (!silent) _error = e;
      });
    }
  }

  void _selectTab(int i) {
    if (i == _tab) return;
    setState(() {
      _tab = i;
      _posts = const [];
    });
    _load();
  }

  void _openSearch([String? query]) {
    Navigator.of(context)
        .push(appRoute(SearchScreen(initialQuery: query ?? '')));
  }

  Widget _trendRow(TrendingTag t, int rank, AppPalette p) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _openSearch(t.tag),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$rank · Trending',
                    style: TextStyle(color: p.subtext, fontSize: 13),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    t.tag,
                    style: TextStyle(
                      color: p.text,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${compactCount(t.count)} ${t.count == 1 ? 'post' : 'posts'}',
                    style: TextStyle(color: p.subtext, fontSize: 13),
                  ),
                ],
              ),
            ),
            Icon(CupertinoIcons.ellipsis, size: 18, color: p.subtext),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String text, AppPalette p) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
        child: Text(
          text,
          style: TextStyle(
            color: p.text,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
      );

  Widget _link(String text, VoidCallback onTap, AppPalette p) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
          child: Text(text, style: TextStyle(color: p.accent, fontSize: 16)),
        ),
      );

  List<Widget> _postTiles() => [
        for (final post in _posts)
          PostTile(
            key: ValueKey('${_tab}_${post.id}'),
            post: post,
            onDeleted: (x) => setState(
              () => _posts = _posts.where((y) => y.id != x.id).toList(),
            ),
          ),
      ];

  Widget _body(AppPalette p) {
    if (_loading && _posts.isEmpty && _trending.isEmpty) {
      return const PostSkeletonList();
    }
    if (_error != null) {
      return ErrorView(error: _error!, onRetry: () => _load());
    }

    final children = <Widget>[];
    if (_tab == 0) {
      children.add(_sectionTitle('Trends for you', p));
      if (_trending.isEmpty) {
        children.add(Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Text(
            'Nothing is trending yet. Use #hashtags in your posts!',
            style: TextStyle(color: p.subtext, fontSize: 15),
          ),
        ));
      } else {
        for (var i = 0; i < _trending.length && i < 5; i++) {
          children.add(_trendRow(_trending[i], i + 1, p));
        }
        children.add(_link('Show more', () => _selectTab(1), p));
      }
      children.add(Container(height: 8, color: p.surface));
      children.add(_sectionTitle('Who to follow', p));
      children.add(const SuggestedList(maxItems: 3, bottomPadding: 0));
      children.add(_link(
        'Show more',
        () => Navigator.of(context).push(appRoute(const ConnectScreen())),
        p,
      ));
      children.add(Container(height: 8, color: p.surface));
      children.add(_sectionTitle('Posts for you', p));
      children.addAll(_postTiles());
    } else if (_tab == 1) {
      if (_trending.isEmpty) {
        children.add(const SizedBox(height: 40));
        children.add(const EmptyState(
          icon: CupertinoIcons.number,
          title: 'Nothing is trending yet',
          subtitle: 'Hashtags used in posts will show up here.',
        ));
      }
      for (var i = 0; i < _trending.length; i++) {
        children.add(_trendRow(_trending[i], i + 1, p));
      }
    } else {
      if (_posts.isEmpty) {
        children.add(const SizedBox(height: 40));
        children.add(EmptyState(
          icon: CupertinoIcons.news,
          title: 'No ${_labels[_tab].toLowerCase()} posts yet',
          subtitle: 'Posts that mention this topic will show up here.',
        ));
      }
      children.addAll(_postTiles());
    }

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      slivers: [
        CupertinoSliverRefreshControl(onRefresh: () => _load(silent: true)),
        SliverList(delegate: SliverChildListDelegate(children)),
        const SliverToBoxAdapter(child: SizedBox(height: 120)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return SafeArea(
      bottom: false,
      child: ContentWidth(
        child: Column(
          children: [
            TopBar(
              me: widget.me,
              onAvatar: widget.onOpenDrawer,
              middle: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _openSearch,
                child: Container(
                  height: 38,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: p.field,
                    borderRadius: BorderRadius.circular(19),
                  ),
                  child: Row(
                    children: [
                      XIcon(XIcons.search, size: 18, color: p.subtext),
                      const SizedBox(width: 8),
                      Text(
                        'Search',
                        style: TextStyle(color: p.subtext, fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ),
              trailing: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.of(context)
                    .push(appRoute(const SettingsScreen())),
                child: Icon(AppIcons.settings, size: 24, color: p.text),
              ),
            ),
            ScrollTabs(labels: _labels, index: _tab, onChanged: _selectTab),
            Expanded(child: _body(p)),
          ],
        ),
      ),
    );
  }
}
