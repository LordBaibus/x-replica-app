import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show RealtimeChannel;

import '../core/app_icons.dart';
import '../core/app_palette.dart';
import '../core/topics.dart';
import '../models/models.dart';
import '../services/api.dart';
import '../widgets/brand_mark.dart';
import '../widgets/popover_menu.dart';
import '../widgets/post_skeleton.dart';
import '../widgets/post_tile.dart';
import '../widgets/responsive.dart';
import '../widgets/scroll_tabs.dart';
import '../widgets/snooze_topics_dialog.dart';
import '../widgets/state_views.dart';
import '../widgets/top_bar.dart';
import '../core/ui_helpers.dart';
import 'connect_screen.dart';
import 'timeline_panel.dart';

/// Home timeline: "For you", "Following" and one tab per interest picked
/// during sign-up. Updates live through Supabase realtime.
class FeedView extends StatefulWidget {
  const FeedView({
    super.key,
    required this.me,
    required this.onOpenDrawer,
    this.onMeChanged,
  });

  /// Signed-in user (avatar in the header, interests for the extra tabs).
  final Profile? me;
  final VoidCallback onOpenDrawer;

  /// Called after the user changed their interests.
  final VoidCallback? onMeChanged;

  @override
  State<FeedView> createState() => FeedViewState();
}

class FeedViewState extends State<FeedView> {
  /// 0 = For you, 1 = Following, 2.. = interest topics.
  int _tab = 0;
  List<Post> _posts = const [];
  bool _loading = true;
  Object? _error;

  /// More posts may exist below (the list loads the next page when the
  /// bottom is reached).
  bool _hasMore = true;
  bool _loadingMore = false;

  /// When the list was last built from scratch; posts that appear later
  /// (realtime) are added on top.
  DateTime _openedAt = DateTime.now();

  /// Bumped on every tab change / refresh so late answers are ignored.
  int _generation = 0;

  static const _pageSize = 20;

  /// Where the "For you ⌄" tab is (the menu opens under it).
  final GlobalKey _forYouKey = GlobalKey();

  /// "For you ⌄": Snooze topics, or a fresh mix.
  Future<void> _forYouMenu() async {
    final pick = await showPopoverMenu<String>(
      context,
      anchor: _forYouKey,
      entries: const [
        PopoverEntry(
          value: 'snooze',
          label: 'Snooze topics',
          icon: CupertinoIcons.moon_zzz,
        ),
        PopoverEntry(
          value: 'refresh',
          label: 'Refresh For you',
          icon: CupertinoIcons.refresh,
        ),
      ],
    );
    if (!mounted || pick == null) return;
    if (pick == 'refresh') {
      _load();
    } else if (pick == 'snooze') {
      final changed = await showSnoozeTopicsDialog(context);
      if (changed && mounted) _load();
    }
  }

  RealtimeChannel? _channel;
  Timer? _debounce;

  /// Up to three of my interests become extra tabs.
  List<Topic> get _topics =>
      Topics.fromIds(widget.me?.interests ?? const []).take(3).toList();

  @override
  void initState() {
    super.initState();
    _load();
    _channel = Api.subscribeFeed(_scheduleReload);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    final channel = _channel;
    if (channel != null) Api.unsubscribe(channel);
    super.dispose();
  }

  void _scheduleReload() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (mounted) _mergeNew();
    });
  }

  /// Called by the shell after a new post is published.
  Future<void> reload() => _mergeNew();

  Topic? get _currentTopic {
    final topics = _topics;
    return _tab >= 2 && _tab - 2 < topics.length ? topics[_tab - 2] : null;
  }

  /// Brand-new posts (live from other people, or my own) go to the top
  /// without reshuffling what is already on screen.
  Future<void> _mergeNew() async {
    final gen = _generation;
    try {
      final (fresh, _) = await Api.fetchFeedPage(
        followingOnly: _tab == 1,
        keywords: _currentTopic?.keywords ?? const [],
        size: 10,
      );
      if (!mounted || gen != _generation) return;
      final have = _posts.map((x) => x.id).toSet();
      final added = fresh
          .where((x) => !have.contains(x.id) && x.createdAt.isAfter(_openedAt))
          .toList();
      if (added.isEmpty) return;
      setState(() => _posts = [...added, ..._posts]);
    } catch (_) {
      // Live updates are best effort.
    }
  }

  /// First page of the current tab. "For you" and the topic tabs are a fresh
  /// random mix each time; "Following" is newest first.
  Future<(List<Post>, bool)> _firstPage() async {
    final keywords = _currentTopic?.keywords ?? const <String>[];
    if (_tab == 1) {
      return Api.fetchFeedPage(
        followingOnly: true,
        keywords: keywords,
        size: _pageSize,
      );
    }
    final list = await Api.fetchForYouPage(
      keywords: keywords,
      size: _pageSize,
      snooze: _tab == 0,
    );
    return (list, list.length >= _pageSize);
  }

  /// Loads the tab from scratch. Pull to refresh uses it too, so "For you"
  /// shows different posts after every refresh.
  Future<void> _load({bool silent = false}) async {
    final gen = ++_generation;
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final (list, more) = await _firstPage();
      if (!mounted || gen != _generation) return;
      setState(() {
        _posts = list;
        _hasMore = more;
        _loadingMore = false;
        _loading = false;
        _error = null;
        _openedAt = DateTime.now();
      });
      Api.bumpViews(list.take(20).map((x) => x.id).toList());
    } catch (e) {
      if (!mounted || gen != _generation) return;
      setState(() {
        _loading = false;
        if (!silent) _error = e;
      });
    }
  }

  /// The user reached the bottom: add the next page.
  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore || _posts.isEmpty || _loading) return;
    final gen = _generation;
    _loadingMore = true;
    try {
      final List<Post> next;
      final bool more;
      if (_tab == 1) {
        final page = await Api.fetchFeedPage(
          followingOnly: true,
          before: _posts.last.createdAt,
          size: _pageSize,
        );
        next = page.$1;
        more = page.$2;
      } else {
        next = await Api.fetchForYouPage(
          keywords: _currentTopic?.keywords ?? const [],
          exclude: _posts.map((x) => x.id).toSet(),
          size: _pageSize,
          snooze: _tab == 0,
        );
        more = next.length >= _pageSize;
      }
      if (!mounted || gen != _generation) return;
      final have = _posts.map((x) => x.id).toSet();
      final added = next.where((x) => !have.contains(x.id)).toList();
      setState(() {
        _posts = [..._posts, ...added];
        _hasMore = more && added.isNotEmpty;
        _loadingMore = false;
      });
      Api.bumpViews(added.take(20).map((x) => x.id).toList());
    } catch (_) {
      if (!mounted || gen != _generation) return;
      setState(() {
        _hasMore = false;
        _loadingMore = false;
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

  Future<void> _editTopics() async {
    final changed = await showTimelinesPanel(context, widget.me);
    if (changed) {
      widget.onMeChanged?.call();
      if (mounted) {
        setState(() => _tab = 0);
        _load();
      }
    }
  }

  // ---- UI ----------------------------------------------------------------

  /// Under the last post: placeholders while the next page loads, or the
  /// "all caught up" line when there is nothing more.
  Widget _footer(BuildContext context) {
    if (_hasMore) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loadMore();
      });
      return const PostSkeletons(count: 2);
    }
    final p = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Center(
        child: Text(
          'You’re all caught up',
          style: TextStyle(color: p.subtext, fontSize: 15),
        ),
      ),
    );
  }

  Widget _body() {
    if (_loading && _posts.isEmpty) return const PostSkeletonList();
    if (_error != null && _posts.isEmpty) {
      return ErrorView(error: _error!, onRetry: () => _load());
    }

    final String title;
    final String subtitle;
    if (_tab == 1) {
      title = 'Nothing here yet';
      subtitle = 'Follow people from Explore to see their posts here.';
    } else if (_tab >= 2) {
      title = 'No posts on this topic yet';
      subtitle = 'Be the first to post about it — tap the + button.';
    } else {
      title = 'No posts yet';
      subtitle = 'Be the first to post — tap the + button.';
    }

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      slivers: [
        CupertinoSliverRefreshControl(onRefresh: () => _load(silent: true)),
        if (_posts.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyState(
              icon: AppIcons.chat,
              title: title,
              subtitle: subtitle,
            ),
          )
        else
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, i) {
                if (i == _posts.length) return _footer(context);
                final post = _posts[i];
                return PostTile(
                  key: ValueKey('${_tab}_${post.id}'),
                  post: post,
                  onDeleted: (x) => setState(
                    () => _posts = _posts.where((y) => y.id != x.id).toList(),
                  ),
                );
              },
              childCount: _posts.length + 1,
            ),
          ),
        // Room so the last post is not hidden behind the button / tab bar.
        const SliverToBoxAdapter(child: SizedBox(height: 120)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final topics = _topics;
    final labels = ['For you', 'Following', ...topics.map((t) => t.label)];
    // The topic list can shrink after editing interests.
    final index = _tab < labels.length ? _tab : 0;

    return SafeArea(
      bottom: false,
      child: ContentWidth(
        child: Column(
          children: [
            TopBar(
              me: widget.me,
              onAvatar: widget.onOpenDrawer,
              middle: const Center(child: BrandMark(size: 30)),
              trailing: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.of(context)
                    .push(appRoute(const ConnectScreen())),
                child: Icon(CupertinoIcons.person_add, size: 24, color: p.text),
              ),
            ),
            ScrollTabs(
              labels: labels,
              index: index,
              onChanged: _selectTab,
              onAdd: _editTopics,
              dropdownIndex: 0,
              dropdownKey: _forYouKey,
              onDropdown: _forYouMenu,
            ),
            Expanded(child: _body()),
          ],
        ),
      ),
    );
  }
}
