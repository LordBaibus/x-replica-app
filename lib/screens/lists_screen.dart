import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';

import '../core/app_icons.dart';
import '../core/app_palette.dart';
import '../core/format.dart';
import '../core/ui_helpers.dart';
import '../models/models.dart';
import '../services/api.dart';
import '../widgets/pill_button.dart';
import '../widgets/plain_scaffold.dart';
import '../widgets/responsive.dart';
import '../widgets/state_views.dart';
import 'create_list_screen.dart';
import 'list_detail_screen.dart';
import 'manage_lists_screen.dart';
import '../core/x_icons.dart';

/// Rounded square for a list: its banner picture, or a pastel tile with a
/// document icon.
class ListIcon extends StatelessWidget {
  const ListIcon({super.key, required this.list, this.size = 64});

  final UserList list;
  final double size;

  static const _tiles = [
    (Color(0xFF9BE0FF), Color(0xFF4DB8F0)),
    (Color(0xFF0F4C9A), Color(0xFF3F78C0)),
    (Color(0xFF0DDBB0), Color(0xFF3AA58E)),
    (Color(0xFFFFC46B), Color(0xFFE59A1F)),
    (Color(0xFFFF9AA2), Color(0xFFE5606E)),
  ];

  @override
  Widget build(BuildContext context) {
    final url = list.bannerUrl;
    final t = _tiles[list.id.hashCode.abs() % _tiles.length];
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.22),
      child: SizedBox(
        width: size,
        height: size,
        child: url != null && url.isNotEmpty
            ? CachedNetworkImage(imageUrl: url, fit: BoxFit.cover)
            : ColoredBox(
                color: t.$1,
                child: Center(
                  child: Icon(CupertinoIcons.doc_text, size: size * 0.5, color: t.$2),
                ),
              ),
      ),
    );
  }
}

/// Lists as X shows them: a search box, "Discover new Lists" with Follow
/// buttons, and "Your Lists" (the ones you made or follow).
class ListsScreen extends StatefulWidget {
  const ListsScreen({super.key});

  @override
  State<ListsScreen> createState() => _ListsScreenState();
}

class _ListsScreenState extends State<ListsScreen> {
  final _search = TextEditingController();
  List<UserList> _mine = const [];
  List<UserList> _discover = const [];
  bool _loading = true;
  bool _showAll = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final r = await Future.wait<List<UserList>>([
        Api.fetchMyLists(),
        Api.fetchDiscoverLists(),
      ]);
      if (!mounted) return;
      setState(() {
        _mine = r[0];
        _discover = r[1];
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (!silent) _error = e;
      });
    }
  }

  Future<void> _create() async {
    final id = await Navigator.of(context)
        .push<String>(appRoute(const CreateListScreen(), fullscreen: true));
    if (id == null || !mounted) return;
    await _load(silent: true);
    final l = await Api.fetchList(id);
    if (l != null && mounted) _open(l);
  }

  Future<void> _open(UserList l) async {
    await Navigator.of(context).push(appRoute(ListDetailScreen(list: l)));
    _load(silent: true);
  }

  Future<void> _follow(UserList l) async {
    // Following moves the list from "Discover" to "Your Lists".
    final before = (_discover, _mine);
    final followed = l.copyWith(followedByMe: true, followerCount: l.followerCount + 1);
    setState(() {
      _discover = _discover.where((x) => x.id != l.id).toList();
      _mine = [followed, ..._mine];
    });
    try {
      await Api.setListFollow(l.id, follow: true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _discover = before.$1;
        _mine = before.$2;
      });
      showError(context, e);
    }
  }

  Future<void> _menu() async {
    final choice = await showCupertinoModalPopup<String>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        actions: [
          CupertinoActionSheetAction(
            onPressed: () => Navigator.of(ctx).pop('create'),
            child: const Text('Create a new List'),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.of(ctx).pop('manage'),
            child: const Text('Manage Lists'),
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
    await Navigator.of(context)
        .push(appRoute(ManageListsScreen(lists: _mine)));
    _load(silent: true);
  }

  bool _matches(UserList l) {
    final q = _search.text.trim().toLowerCase();
    return q.isEmpty || l.name.toLowerCase().contains(q);
  }

  Widget _row(UserList l, AppPalette p,
      {bool withFollow = true, bool pinned = false}) {
    final owner = l.ownerId == Api.uid;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _open(l),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        child: Row(
          children: [
            ListIcon(list: l, size: 64),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: l.name,
                          style: TextStyle(
                            color: p.text,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        TextSpan(
                          text: ' · ${l.memberCount} '
                              '${l.memberCount == 1 ? 'member' : 'members'}',
                          style: TextStyle(color: p.subtext, fontSize: 15),
                        ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    owner
                        ? (l.isPrivate ? 'Private · by you' : 'Public · by you')
                        : '${compactCount(l.followerCount)} '
                            '${l.followerCount == 1 ? 'follower' : 'followers'}'
                            ' · by @${l.ownerUsername}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: p.subtext, fontSize: 15),
                  ),
                ],
              ),
            ),
            if (pinned) ...[
              const SizedBox(width: 10),
              Icon(CupertinoIcons.pin_fill, size: 17, color: p.subtext),
            ],
            if (withFollow && !owner) ...[
              const SizedBox(width: 10),
              PillButton(
                label: 'Follow',
                style: PillStyle.inverse,
                height: 38,
                fontSize: 16,
                onPressed: () => _follow(l),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _title(String text, AppPalette p) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
        child: Text(
          text,
          style: TextStyle(color: p.text, fontSize: 22, fontWeight: FontWeight.w800),
        ),
      );

  Widget _body(AppPalette p) {
    final discover = _discover.where(_matches).toList();
    final shown = _showAll ? discover : discover.take(3).toList();
    final pinned = _mine.where((l) => l.pinnedByMe).where(_matches).toList();
    final mine =
        _mine.where((l) => !l.pinnedByMe).where(_matches).toList();

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      slivers: [
        CupertinoSliverRefreshControl(onRefresh: () => _load(silent: true)),
        SliverList(
          delegate: SliverChildListDelegate([
            if (pinned.isNotEmpty) ...[
              _title('Pinned Lists', p),
              for (final l in pinned) _row(l, p, withFollow: false, pinned: true),
              const SizedBox(height: 6),
              const HairlineDivider(),
            ],
            _title('Discover new Lists', p),
            if (shown.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Text(
                  'No public Lists from other people yet.',
                  style: TextStyle(color: p.subtext, fontSize: 16),
                ),
              )
            else
              for (final l in shown) _row(l, p),
            if (!_showAll && discover.length > 3)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _showAll = true),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
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
            const SizedBox(height: 6),
            const HairlineDivider(),
            _title('Your Lists', p),
            if (mine.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
                child: Text(
                  'You haven\'t created or followed any Lists. When you do, '
                  'they\'ll show up here.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: p.subtext, fontSize: 17, height: 1.3),
                ),
              )
            else
              for (final l in mine) _row(l, p, withFollow: false),
            const SizedBox(height: 120),
          ]),
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
      return _body(p);
    }

    return PlainScaffold(
      floating: RoundFab(icon: CupertinoIcons.doc_append, onPressed: _create),
      child: SafeArea(
        child: ContentWidth(
          child: Column(
            children: [
              SizedBox(
                height: 56,
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
                      child: CupertinoTextField(
                        controller: _search,
                        placeholder: 'Search Lists',
                        textAlign: TextAlign.center,
                        autocorrect: false,
                        onChanged: (_) => setState(() => _showAll = true),
                        cursorColor: p.accent,
                        prefix: Padding(
                          padding: const EdgeInsets.only(left: 14),
                          child: XIcon(XIcons.search, size: 18, color: p.subtext),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
                        decoration: BoxDecoration(
                          color: p.field,
                          borderRadius: BorderRadius.circular(22),
                        ),
                        style: TextStyle(color: p.text, fontSize: 17),
                        placeholderStyle: TextStyle(color: p.subtext, fontSize: 17),
                      ),
                    ),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _menu,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Icon(CupertinoIcons.ellipsis, size: 22, color: p.text),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(child: body()),
            ],
          ),
        ),
      ),
    );
  }
}
