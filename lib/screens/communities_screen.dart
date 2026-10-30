import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';

import '../core/app_icons.dart';
import '../core/app_palette.dart';
import '../core/format.dart';
import '../core/ui_helpers.dart';
import '../models/models.dart';
import '../services/api.dart';
import '../widgets/communities_welcome.dart';
import '../widgets/plain_scaffold.dart';
import '../widgets/post_tile.dart';
import '../widgets/responsive.dart';
import '../widgets/state_views.dart';
import '../widgets/underline_tabs.dart';
import 'community_detail_screen.dart';
import 'compose_post_screen.dart';
import 'create_community_screen.dart';
import 'search_screen.dart';
import '../core/x_icons.dart';

/// Square picture of a community (its image, or a coloured tile with its
/// first letter).
class CommunityIcon extends StatelessWidget {
  const CommunityIcon({super.key, required this.community, this.size = 64});

  final Community community;
  final double size;

  static const _tints = [
    Color(0xFF1D9BF0),
    Color(0xFF7856FF),
    Color(0xFFF91880),
    Color(0xFFFFAD1F),
    Color(0xFF00BA7C),
    Color(0xFF0F1419),
  ];

  @override
  Widget build(BuildContext context) {
    final url = community.imageUrl;
    final tint = _tints[community.name.hashCode.abs() % _tints.length];
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.22),
      child: SizedBox(
        width: size,
        height: size,
        child: url != null && url.isNotEmpty
            ? CachedNetworkImage(imageUrl: url, fit: BoxFit.cover)
            : ColoredBox(
                color: tint,
                child: Center(
                  child: Text(
                    community.name.isEmpty
                        ? '?'
                        : String.fromCharCode(community.name.runes.first).toUpperCase(),
                    style: TextStyle(
                      color: const Color(0xFFFFFFFF),
                      fontSize: size * 0.45,
                      fontWeight: FontWeight.w800,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}

/// Communities as X shows them: back arrow, title, search, and the Home /
/// Explore tabs. Home lists communities to discover (and the ones you joined);
/// Explore shows posts from every community, filterable by topic.
class CommunitiesScreen extends StatefulWidget {
  const CommunitiesScreen({super.key});

  @override
  State<CommunitiesScreen> createState() => _CommunitiesScreenState();
}

class _CommunitiesScreenState extends State<CommunitiesScreen> {
  int _tab = 0;

  List<Community> _joined = const [];
  List<Community> _discover = const [];
  List<Post> _posts = const [];
  String? _category;
  bool _loading = true;
  bool _showAllDiscover = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) maybeShowCommunitiesWelcome(context);
    });
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      if (_tab == 0) {
        final r = await Future.wait<List<Community>>([
          Api.fetchCommunities(joinedOnly: true),
          Api.fetchCommunities(notJoined: true),
        ]);
        if (!mounted) return;
        setState(() {
          _joined = r[0];
          _discover = r[1];
        });
      } else {
        final posts = await Api.fetchCommunityFeed(category: _category);
        if (!mounted) return;
        setState(() => _posts = posts);
      }
      if (mounted) setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (!silent) _error = e;
      });
    }
  }

  Future<void> _open(Community c) async {
    await Navigator.of(context)
        .push(appRoute(CommunityDetailScreen(community: c)));
    _load(silent: true);
  }

  Future<void> _create() async {
    final id = await Navigator.of(context)
        .push<String>(appRoute(const CreateCommunityScreen()));
    if (id == null || !mounted) return;
    await _load(silent: true);
    final c = await Api.fetchCommunity(id);
    if (c != null && mounted) _open(c);
  }

  /// Floating button: post in a community I joined, or start a new one.
  Future<void> _fab() async {
    final choice = await showCupertinoModalPopup<String>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        actions: [
          if (_joined.isNotEmpty)
            CupertinoActionSheetAction(
              onPressed: () => Navigator.of(ctx).pop('post'),
              child: const Text('Post in a Community'),
            ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.of(ctx).pop('create'),
            child: const Text('Create a Community'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Cancel'),
        ),
      ),
    );
    if (!mounted || choice == null) return;
    if (choice == 'create') return _create();

    final picked = await showCupertinoModalPopup<Community>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('Choose a Community'),
        actions: [
          for (final c in _joined)
            CupertinoActionSheetAction(
              onPressed: () => Navigator.of(ctx).pop(c),
              child: Text(c.name),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Cancel'),
        ),
      ),
    );
    if (picked == null || !mounted) return;
    final posted = await Navigator.of(context).push<bool>(
      appRoute(
        ComposePostScreen(communityId: picked.id, communityName: picked.name),
        fullscreen: true,
      ),
    );
    if (posted == true) _load(silent: true);
  }

  void _more() {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(ctx).pop();
              _create();
            },
            child: const Text('Create a Community'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(ctx).pop();
              _load();
            },
            child: const Text('Refresh'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  Widget _row(Community c, AppPalette p) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _open(c),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        child: Row(
          children: [
            CommunityIcon(community: c, size: 64),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    c.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: p.text,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    '${compactCount(c.memberCount)} '
                    '${c.memberCount == 1 ? 'Member' : 'Members'}',
                    style: TextStyle(color: p.subtext, fontSize: 16),
                  ),
                  Text(
                    c.category,
                    style: TextStyle(color: p.text, fontSize: 14),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String text, AppPalette p, {Widget? trailing}) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  color: p.text,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            ?trailing,
          ],
        ),
      );

  Widget _home(AppPalette p) {
    final shown = _showAllDiscover ? _discover : _discover.take(3).toList();
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      slivers: [
        CupertinoSliverRefreshControl(onRefresh: () => _load(silent: true)),
        SliverList(
          delegate: SliverChildListDelegate([
            Container(
              height: 50,
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: p.border, width: 0.5)),
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: p.text, width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(CupertinoIcons.arrow_up_arrow_down, size: 15, color: p.text),
                    const SizedBox(width: 6),
                    Text(
                      'Trending',
                      style: TextStyle(
                        color: p.text,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_joined.isNotEmpty) ...[
              _sectionTitle('Your Communities', p),
              for (final c in _joined) _row(c, p),
              const SizedBox(height: 6),
              const HairlineDivider(),
            ],
            _sectionTitle(
              'Discover new Communities',
              p,
              trailing: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _more,
                child: Icon(CupertinoIcons.ellipsis, size: 20, color: p.subtext),
              ),
            ),
            if (_discover.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Text(
                  _joined.isEmpty
                      ? 'No communities yet. Start the first one with the + button.'
                      : 'You have joined every community there is. Start a new one!',
                  style: TextStyle(color: p.subtext, fontSize: 16, height: 1.3),
                ),
              )
            else ...[
              for (final c in shown) _row(c, p),
              if (!_showAllDiscover && _discover.length > 3)
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() => _showAllDiscover = true),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Show more',
                            style: TextStyle(color: p.accent, fontSize: 17),
                          ),
                        ),
                        Icon(CupertinoIcons.chevron_right, size: 14, color: p.subtext),
                      ],
                    ),
                  ),
                ),
            ],
            const SizedBox(height: 120),
          ]),
        ),
      ],
    );
  }

  Widget _explore(AppPalette p) {
    Widget chip(String? value, String label) {
      final on = _category == value;
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          setState(() => _category = value);
          _load();
        },
        child: Container(
          margin: const EdgeInsets.only(right: 10),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          decoration: BoxDecoration(
            color: on ? p.text : const Color(0x00000000),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: on ? p.text : p.subtext.withValues(alpha: 0.4),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: on ? p.background : p.text,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        SizedBox(
          height: 58,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 10, 6, 10),
            children: [
              for (final c in communityCategories) chip(c, c),
            ],
          ),
        ),
        Expanded(
          child: _posts.isEmpty
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(28, 48, 28, 0),
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: Text(
                      'No community posts here yet.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: p.subtext, fontSize: 16),
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 120),
                  itemCount: _posts.length,
                  itemBuilder: (context, i) => PostTile(
                    key: ValueKey(_posts[i].id),
                    post: _posts[i],
                    onDeleted: (x) => setState(
                      () => _posts = _posts.where((y) => y.id != x.id).toList(),
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);

    Widget body() {
      if (_loading) return const LoadingView();
      if (_error != null) return ErrorView(error: _error!, onRetry: _load);
      return _tab == 0 ? _home(p) : _explore(p);
    }

    return PlainScaffold(
      floating: RoundFab(icon: CupertinoIcons.pencil, onPressed: _fab),
      child: SafeArea(
        child: ContentWidth(
          child: Column(
            children: [
              SizedBox(
                height: 52,
                child: Row(
                  children: [
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => Navigator.of(context).maybePop(),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Icon(AppIcons.back, size: 24, color: p.text),
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: Text(
                          'Communities',
                          style: TextStyle(
                            color: p.text,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => Navigator.of(context)
                          .push(appRoute(const SearchScreen())),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: XIcon(XIcons.search, size: 24, color: p.text),
                      ),
                    ),
                  ],
                ),
              ),
              UnderlineTabs(
                labels: const ['Home', 'Explore'],
                index: _tab,
                onChanged: (i) {
                  if (i == _tab) return;
                  setState(() => _tab = i);
                  _load();
                },
              ),
              Expanded(child: body()),
            ],
          ),
        ),
      ),
    );
  }
}
