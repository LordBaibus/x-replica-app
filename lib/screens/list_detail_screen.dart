import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';

import '../core/app_icons.dart';
import '../core/app_palette.dart';
import '../core/format.dart';
import '../core/ui_helpers.dart';
import '../models/models.dart';
import '../services/api.dart';
import '../widgets/avatar.dart';
import '../widgets/person_tile.dart';
import '../widgets/pill_button.dart';
import '../widgets/plain_scaffold.dart';
import '../widgets/post_skeleton.dart';
import '../widgets/post_tile.dart';
import '../widgets/responsive.dart';
import '../widgets/state_views.dart';
import '../widgets/underline_tabs.dart';
import 'edit_list_screen.dart';
import 'profile_view.dart';

/// A List like on X: banner, name, description, who made it, the Followers /
/// Members counts (tap to see the people), Follow / Following (or Edit List
/// for the owner), and the timeline of the members' posts.
class ListDetailScreen extends StatefulWidget {
  const ListDetailScreen({super.key, required this.list});

  final UserList list;

  @override
  State<ListDetailScreen> createState() => _ListDetailScreenState();
}

class _ListDetailScreenState extends State<ListDetailScreen> {
  late UserList _l = widget.list;
  List<Post> _posts = const [];
  bool _hasMembers = true;
  bool _loading = true;
  Object? _error;

  bool get _isOwner => _l.ownerId == Api.uid;

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
      final r = await Future.wait<Object?>([
        Api.fetchListPosts(_l.id),
        Api.fetchList(_l.id),
      ]);
      if (!mounted) return;
      final fresh = r[1] as UserList?;
      setState(() {
        _posts = r[0] as List<Post>;
        if (fresh != null) _l = fresh;
        _hasMembers = _l.memberCount > 0;
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

  Future<void> _toggleFollow() async {
    final before = _l;
    final follow = !before.followedByMe;
    setState(() {
      _l = before.copyWith(
        followedByMe: follow,
        followerCount: before.followerCount + (follow ? 1 : -1),
      );
    });
    try {
      await Api.setListFollow(before.id, follow: follow);
    } catch (e) {
      if (!mounted) return;
      setState(() => _l = before);
      showError(context, e);
    }
  }

  Future<void> _togglePin() async {
    final pin = !_l.pinnedByMe;
    final before = _l;
    setState(() => _l = before.copyWith(pinnedByMe: pin));
    try {
      await Api.setListPinned(_l.id, pinned: pin);
      if (mounted) {
        showSuccess(context, pin ? 'List pinned' : 'List unpinned');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _l = before);
      showError(context, e);
    }
  }

  Future<void> _edit() async {
    final result = await Navigator.of(context)
        .push<String>(appRoute(EditListScreen(list: _l), fullscreen: true));
    if (!mounted) return;
    if (result == 'deleted') {
      Navigator.of(context).pop();
      return;
    }
    _load(silent: true);
  }

  Future<void> _people(int tab) async {
    await Navigator.of(context)
        .push(appRoute(ListPeopleScreen(list: _l, initialTab: tab)));
    if (mounted) _load(silent: true);
  }

  void _menu() {
    final canPin = _isOwner || _l.followedByMe;
    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        actions: [
          if (canPin)
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.of(ctx).pop();
                _togglePin();
              },
              child: Text(_l.pinnedByMe ? 'Unpin from Lists' : 'Pin to Lists'),
            ),
          if (_isOwner)
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.of(ctx).pop();
                _edit();
              },
              child: const Text('Edit List'),
            ),
          if (!_isOwner)
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.of(ctx).pop();
                showInfo(context, 'Thanks. We’ll review this List.');
              },
              child: const Text('Report List'),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  Widget _banner(AppPalette p) {
    final url = _l.bannerUrl;
    return SizedBox(
      height: 130,
      width: double.infinity,
      child: url != null && url.isNotEmpty
          ? CachedNetworkImage(imageUrl: url, fit: BoxFit.cover)
          : ColoredBox(
              color: const Color(0xFF9BE0FF),
              child: const Center(
                child: Icon(CupertinoIcons.doc_text,
                    size: 44, color: Color(0xFF4DB8F0)),
              ),
            ),
    );
  }

  Widget _count(AppPalette p, int n, String singular, String plural, int tab) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _people(tab),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: compactCount(n),
              style: TextStyle(
                color: p.text,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
            TextSpan(
              text: ' ${n == 1 ? singular : plural}',
              style: TextStyle(color: p.subtext, fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(AppPalette p) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _banner(p),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      _l.name,
                      style: TextStyle(
                        color: p.text,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (_l.isPrivate) ...[
                    const SizedBox(width: 8),
                    Icon(CupertinoIcons.lock_fill, size: 18, color: p.subtext),
                  ],
                ],
              ),
              if (_l.description.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  _l.description,
                  style: TextStyle(color: p.text, fontSize: 16, height: 1.3),
                ),
              ],
              const SizedBox(height: 10),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.of(context)
                    .push(appRoute(ProfileScreen(userId: _l.ownerId))),
                child: Row(
                  children: [
                    Avatar(
                      url: _l.ownerAvatarUrl,
                      name: _l.owner,
                      size: 22,
                      square: Avatar.isSquare(_l.ownerVerified),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: _l.owner,
                              style: TextStyle(
                                color: p.text,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            TextSpan(
                              text: '  @${_l.ownerUsername}',
                              style: TextStyle(color: p.subtext, fontSize: 15),
                            ),
                          ],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _count(p, _l.followerCount, 'Follower', 'Followers', 0),
                  const SizedBox(width: 18),
                  _count(p, _l.memberCount, 'Member', 'Members', 1),
                ],
              ),
              const SizedBox(height: 14),
              if (_isOwner)
                PillButton(
                  label: 'Edit List',
                  height: 38,
                  fontSize: 16,
                  onPressed: _edit,
                )
              else
                PillButton(
                  label: _l.followedByMe ? 'Following' : 'Follow',
                  style: _l.followedByMe ? PillStyle.outline : PillStyle.inverse,
                  height: 38,
                  fontSize: 16,
                  onPressed: _toggleFollow,
                ),
            ],
          ),
        ),
        const HairlineDivider(),
      ],
    );
  }

  Widget _timeline(AppPalette p) {
    if (_loading) return const PostSkeletons(count: 4);
    if (_error != null) return ErrorView(error: _error!, onRetry: _load);
    if (_posts.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(28, 40, 28, 0),
        child: Text(
          !_hasMembers
              ? (_isOwner
                  ? 'There’s no one in this List yet. Tap Edit List to add people.'
                  : 'There’s no one in this List yet.')
              : 'Nobody in this List has posted yet.',
          textAlign: TextAlign.center,
          style: TextStyle(color: p.subtext, fontSize: 16, height: 1.3),
        ),
      );
    }
    return Column(
      children: [
        for (final post in _posts) PostTile(key: ValueKey(post.id), post: post),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return PlainScaffold(
      child: SafeArea(
        bottom: false,
        child: ContentWidth(
          child: Column(
            children: [
              SizedBox(
                height: 50,
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
                      child: Text(
                        _l.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: p.text,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _menu,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child:
                            Icon(CupertinoIcons.ellipsis, size: 22, color: p.text),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: RefreshableList(
                  onRefresh: () => _load(silent: true),
                  children: [
                    _header(p),
                    _timeline(p),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Followers and Members of a list (two tabs).
class ListPeopleScreen extends StatefulWidget {
  const ListPeopleScreen({super.key, required this.list, this.initialTab = 0});

  final UserList list;
  final int initialTab;

  @override
  State<ListPeopleScreen> createState() => _ListPeopleScreenState();
}

class _ListPeopleScreenState extends State<ListPeopleScreen> {
  late int _tab = widget.initialTab;
  List<Profile> _followers = const [];
  List<Profile> _members = const [];
  bool _loading = true;
  Object? _error;

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
      final r = await Future.wait<List<Profile>>([
        Api.fetchListFollowers(widget.list.id),
        Api.fetchListMembers(widget.list.id),
      ]);
      if (!mounted) return;
      setState(() {
        _followers = r[0];
        _members = r[1];
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final people = _tab == 0 ? _followers : _members;

    Widget body() {
      if (_loading) return const LoadingView();
      if (_error != null) return ErrorView(error: _error!, onRetry: _load);
      if (people.isEmpty) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(28, 40, 28, 0),
          child: Text(
            _tab == 0
                ? 'No one follows this List yet.'
                : 'There’s no one in this List yet.',
            textAlign: TextAlign.center,
            style: TextStyle(color: p.subtext, fontSize: 16),
          ),
        );
      }
      return ListView(
        children: [
          for (final m in people)
            PersonTile(
              profile: m,
              onTap: () => Navigator.of(context)
                  .push(appRoute(ProfileScreen(userId: m.id))),
            ),
        ],
      );
    }

    return AdaptiveScaffold(
      backgroundColor: p.background,
      appBar: AdaptiveAppBar(title: widget.list.name),
      body: SafeArea(
        child: ContentWidth(
          child: Column(
            children: [
              UnderlineTabs(
                labels: [
                  'Followers (${_followers.length})',
                  'Members (${_members.length})',
                ],
                index: _tab,
                onChanged: (i) => setState(() => _tab = i),
              ),
              Expanded(child: body()),
            ],
          ),
        ),
      ),
    );
  }
}

/// A scrolling column with pull-to-refresh.
class RefreshableList extends StatelessWidget {
  const RefreshableList({super.key, required this.children, required this.onRefresh});

  final List<Widget> children;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      slivers: [
        CupertinoSliverRefreshControl(onRefresh: onRefresh),
        SliverList(delegate: SliverChildListDelegate(children)),
        const SliverToBoxAdapter(child: SizedBox(height: 80)),
      ],
    );
  }
}
