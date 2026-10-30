import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/cupertino.dart';

import '../core/app_palette.dart';
import '../core/ui_helpers.dart';
import '../models/models.dart';
import '../services/api.dart';
import '../widgets/avatar.dart';
import '../widgets/badges.dart';
import '../widgets/pill_button.dart';
import '../widgets/post_tile.dart';
import '../widgets/responsive.dart';
import '../widgets/state_views.dart';
import 'create_community_screen.dart';
import 'profile_view.dart';

// ---------------------------------------------------------------------------
// Settings (admin and moderators)
// ---------------------------------------------------------------------------

/// What the admin and the moderators can do: answer join requests, manage
/// members and moderators, review hidden posts; the admin can also edit or
/// delete the community. Pops with true when the community was deleted.
class CommunitySettingsScreen extends StatefulWidget {
  const CommunitySettingsScreen({super.key, required this.community});

  final Community community;

  @override
  State<CommunitySettingsScreen> createState() =>
      _CommunitySettingsScreenState();
}

class _CommunitySettingsScreenState extends State<CommunitySettingsScreen> {
  late Community _c = widget.community;

  Future<void> _refresh() async {
    final fresh = await Api.fetchCommunity(_c.id);
    if (mounted && fresh != null) setState(() => _c = fresh);
  }

  Future<void> _go(Widget page) async {
    await Navigator.of(context).push(appRoute(page));
    _refresh();
  }

  Future<void> _edit() async {
    final id = await Navigator.of(context).push<String>(
      appRoute(CreateCommunityScreen(existing: _c)),
    );
    if (id != null) _refresh();
  }

  Future<void> _delete() async {
    final ok = await confirm(
      context,
      title: 'Delete ${_c.name}?',
      message: 'Members lose access to the Community. Their posts stay on '
          'their profiles. This can’t be undone.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok || !mounted) return;
    try {
      await Api.deleteCommunity(_c.id);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Widget _row(
    AppPalette p, {
    required IconData icon,
    required String title,
    String? subtitle,
    int badge = 0,
    bool danger = false,
    required VoidCallback onTap,
  }) {
    final color = danger ? p.danger : p.text;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: p.border, width: 0.5)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 24, color: color),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: color,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(color: p.subtext, fontSize: 14),
                    ),
                  ],
                ],
              ),
            ),
            if (badge > 0)
              Container(
                constraints: const BoxConstraints(minWidth: 22),
                height: 22,
                padding: const EdgeInsets.symmetric(horizontal: 6),
                alignment: Alignment.center,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: p.accent,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Text(
                  '$badge',
                  style: const TextStyle(
                    color: Color(0xFFFFFFFF),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            if (!danger)
              Icon(CupertinoIcons.chevron_right, size: 15, color: p.subtext),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return AdaptiveScaffold(
      backgroundColor: p.background,
      appBar: const AdaptiveAppBar(title: 'Community settings'),
      body: SafeArea(
        child: ContentWidth(
          child: ListView(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: Text(
                  _c.name,
                  style: TextStyle(
                    color: p.text,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (_c.isRestricted)
                _row(
                  p,
                  icon: CupertinoIcons.person_badge_plus,
                  title: 'Join requests',
                  subtitle: 'Approve or deny people who asked to join',
                  badge: _c.pendingRequests,
                  onTap: () => _go(CommunityRequestsScreen(community: _c)),
                ),
              _row(
                p,
                icon: CupertinoIcons.person_2,
                title: 'Members and moderators',
                subtitle: _c.isAdmin
                    ? 'Add or remove moderators, remove members'
                    : 'See members, remove people who break the rules',
                onTap: () => _go(CommunityMembersScreen(community: _c)),
              ),
              _row(
                p,
                icon: CupertinoIcons.eye_slash,
                title: 'Hidden posts',
                subtitle: 'Posts hidden because they break a rule',
                onTap: () => _go(CommunityHiddenPostsScreen(community: _c)),
              ),
              if (_c.isAdmin) ...[
                _row(
                  p,
                  icon: CupertinoIcons.pencil,
                  title: 'Edit Community',
                  subtitle: 'Name, description, cover, membership and rules',
                  onTap: _edit,
                ),
                _row(
                  p,
                  icon: CupertinoIcons.trash,
                  title: 'Delete Community',
                  danger: true,
                  onTap: _delete,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Members
// ---------------------------------------------------------------------------

/// Everybody in a community. The admin can make moderators; the admin and
/// the moderators can remove members.
class CommunityMembersScreen extends StatefulWidget {
  const CommunityMembersScreen({super.key, required this.community});

  final Community community;

  @override
  State<CommunityMembersScreen> createState() => _CommunityMembersScreenState();
}

class _CommunityMembersScreenState extends State<CommunityMembersScreen> {
  List<CommunityMember> _members = const [];
  bool _loading = true;
  Object? _error;

  Community get _c => widget.community;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    try {
      final list = await Api.fetchCommunityMembers(_c.id);
      if (!mounted) return;
      setState(() {
        _members = list;
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

  bool _canManage(CommunityMember m) {
    if (m.profile.id == Api.uid || m.isAdmin) return false;
    if (_c.isAdmin) return true;
    return _c.isMod && !m.isModerator;
  }

  void _menu(CommunityMember m) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text('@${m.profile.username}'),
        actions: [
          if (_c.isAdmin && !m.isModerator)
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.of(ctx).pop();
                _setRole(m, 'moderator');
              },
              child: const Text('Make moderator'),
            ),
          if (_c.isAdmin && m.isModerator)
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.of(ctx).pop();
                _setRole(m, 'member');
              },
              child: const Text('Remove as moderator'),
            ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.of(ctx).pop();
              _remove(m);
            },
            child: const Text('Remove from Community'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  Future<void> _setRole(CommunityMember m, String role) async {
    try {
      await Api.setCommunityRole(_c.id, m.profile.id, role);
      if (!mounted) return;
      showSuccess(
        context,
        role == 'moderator'
            ? '@${m.profile.username} is now a moderator'
            : '@${m.profile.username} is a regular member again',
      );
      _load(silent: true);
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _remove(CommunityMember m) async {
    final ok = await confirm(
      context,
      title: 'Remove @${m.profile.username}?',
      message: 'They lose access to ${_c.name}.',
      confirmLabel: 'Remove',
      destructive: true,
    );
    if (!ok || !mounted) return;
    try {
      await Api.removeCommunityMember(_c.id, m.profile.id);
      if (!mounted) return;
      setState(() =>
          _members = _members.where((x) => x.profile.id != m.profile.id).toList());
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);

    Widget body() {
      if (_loading) return const LoadingView();
      if (_error != null) return ErrorView(error: _error!, onRetry: _load);
      return ListView.builder(
        itemCount: _members.length,
        itemBuilder: (context, i) {
          final m = _members[i];
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.of(context)
                .push(appRoute(ProfileScreen(userId: m.profile.id))),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  Avatar(
                    url: m.profile.avatarUrl,
                    name: m.profile.name,
                    size: 46,
                    square: Avatar.isSquare(m.profile.verified),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        NameWithBadge(
                          name: m.profile.name,
                          verified: m.profile.verified,
                          style: TextStyle(
                            color: p.text,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          '@${m.profile.username}',
                          style: TextStyle(color: p.subtext, fontSize: 15),
                        ),
                      ],
                    ),
                  ),
                  if (m.isAdmin || m.isModerator)
                    Container(
                      margin: const EdgeInsets.only(left: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: p.border),
                      ),
                      child: Text(
                        m.isAdmin ? 'Admin' : 'Moderator',
                        style: TextStyle(
                          color: p.text,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  if (_canManage(m))
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _menu(m),
                      child: Padding(
                        padding: const EdgeInsets.only(left: 10),
                        child: Icon(CupertinoIcons.ellipsis,
                            size: 20, color: p.subtext),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      );
    }

    return AdaptiveScaffold(
      backgroundColor: p.background,
      appBar: const AdaptiveAppBar(title: 'Members'),
      body: SafeArea(child: ContentWidth(child: body())),
    );
  }
}

// ---------------------------------------------------------------------------
// Join requests
// ---------------------------------------------------------------------------

class CommunityRequestsScreen extends StatefulWidget {
  const CommunityRequestsScreen({super.key, required this.community});

  final Community community;

  @override
  State<CommunityRequestsScreen> createState() =>
      _CommunityRequestsScreenState();
}

class _CommunityRequestsScreenState extends State<CommunityRequestsScreen> {
  List<CommunityMember> _requests = const [];
  bool _loading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await Api.fetchJoinRequests(widget.community.id);
      if (!mounted) return;
      setState(() {
        _requests = list;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e;
      });
    }
  }

  Future<void> _answer(CommunityMember m, bool approve) async {
    final before = _requests;
    setState(() =>
        _requests = _requests.where((x) => x.profile.id != m.profile.id).toList());
    try {
      await Api.reviewJoinRequest(widget.community.id, m.profile.id,
          approve: approve);
      if (mounted) {
        showSuccess(
          context,
          approve
              ? '@${m.profile.username} joined'
              : 'Request from @${m.profile.username} denied',
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _requests = before);
      showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);

    Widget body() {
      if (_loading) return const LoadingView();
      if (_error != null) return ErrorView(error: _error!, onRetry: _load);
      if (_requests.isEmpty) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(28, 48, 28, 0),
          child: Text(
            'No one is waiting to join.',
            textAlign: TextAlign.center,
            style: TextStyle(color: p.subtext, fontSize: 16),
          ),
        );
      }
      return ListView.builder(
        itemCount: _requests.length,
        itemBuilder: (context, i) {
          final m = _requests[i];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => Navigator.of(context)
                      .push(appRoute(ProfileScreen(userId: m.profile.id))),
                  child: Avatar(
                    url: m.profile.avatarUrl,
                    name: m.profile.name,
                    size: 46,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        m.profile.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: p.text,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        '@${m.profile.username}',
                        style: TextStyle(color: p.subtext, fontSize: 15),
                      ),
                    ],
                  ),
                ),
                PillButton(
                  label: 'Deny',
                  style: PillStyle.outline,
                  height: 34,
                  fontSize: 14,
                  onPressed: () => _answer(m, false),
                ),
                const SizedBox(width: 8),
                PillButton(
                  label: 'Approve',
                  style: PillStyle.inverse,
                  height: 34,
                  fontSize: 14,
                  onPressed: () => _answer(m, true),
                ),
              ],
            ),
          );
        },
      );
    }

    return AdaptiveScaffold(
      backgroundColor: p.background,
      appBar: const AdaptiveAppBar(title: 'Join requests'),
      body: SafeArea(child: ContentWidth(child: body())),
    );
  }
}

// ---------------------------------------------------------------------------
// Hidden posts
// ---------------------------------------------------------------------------

class CommunityHiddenPostsScreen extends StatefulWidget {
  const CommunityHiddenPostsScreen({super.key, required this.community});

  final Community community;

  @override
  State<CommunityHiddenPostsScreen> createState() =>
      _CommunityHiddenPostsScreenState();
}

class _CommunityHiddenPostsScreenState
    extends State<CommunityHiddenPostsScreen> {
  List<Post> _posts = const [];
  bool _loading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await Api.fetchHiddenCommunityPosts(widget.community.id);
      if (!mounted) return;
      setState(() {
        _posts = list;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e;
      });
    }
  }

  Future<void> _unhide(Post post) async {
    try {
      await Api.unhideCommunityPost(post.id);
      if (!mounted) return;
      setState(() => _posts = _posts.where((x) => x.id != post.id).toList());
      showSuccess(context, 'Post is visible again');
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);

    Widget body() {
      if (_loading) return const LoadingView();
      if (_error != null) return ErrorView(error: _error!, onRetry: _load);
      if (_posts.isEmpty) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(28, 48, 28, 0),
          child: Text(
            'No hidden posts. Moderators can hide a post that breaks a rule '
            'from the Community page.',
            textAlign: TextAlign.center,
            style: TextStyle(color: p.subtext, fontSize: 16, height: 1.3),
          ),
        );
      }
      return ListView.builder(
        itemCount: _posts.length,
        itemBuilder: (context, i) {
          final post = _posts[i];
          return Column(
            children: [
              PostTile(key: ValueKey(post.id), post: post),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: PillButton(
                    label: 'Unhide',
                    style: PillStyle.outline,
                    height: 34,
                    fontSize: 14,
                    onPressed: () => _unhide(post),
                  ),
                ),
              ),
            ],
          );
        },
      );
    }

    return AdaptiveScaffold(
      backgroundColor: p.background,
      appBar: const AdaptiveAppBar(title: 'Hidden posts'),
      body: SafeArea(child: ContentWidth(child: body())),
    );
  }
}
