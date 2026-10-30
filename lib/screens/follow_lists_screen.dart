import 'package:flutter/cupertino.dart';

import '../core/app_icons.dart';
import '../core/app_palette.dart';
import '../core/ui_helpers.dart';
import '../models/models.dart';
import '../services/api.dart';
import '../widgets/avatar.dart';
import '../widgets/badges.dart';
import '../widgets/page_header.dart';
import '../widgets/pill_button.dart';
import '../widgets/plain_scaffold.dart';
import '../widgets/responsive.dart';
import '../widgets/state_views.dart';
import 'profile_view.dart';
import 'search_screen.dart';

enum FollowTab { verified, followers, following }

/// X's "Verified followers / Followers / Following" page of one account.
/// Tapping "12 Following" or "34 Followers" opens it on the matching tab.
class FollowListsScreen extends StatefulWidget {
  const FollowListsScreen({
    super.key,
    required this.userId,
    required this.title,
    this.initial = FollowTab.followers,
  });

  final String userId;

  /// Display name shown in the header.
  final String title;
  final FollowTab initial;

  @override
  State<FollowListsScreen> createState() => _FollowListsScreenState();
}

class _FollowListsScreenState extends State<FollowListsScreen> {
  late FollowTab _tab = widget.initial;

  // null = not loaded yet.
  List<FollowEntry>? _followers;
  List<FollowEntry>? _following;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load(_tab);
  }

  Future<void> _load(FollowTab tab) async {
    final wantFollowers = tab != FollowTab.following;
    if ((wantFollowers ? _followers : _following) != null) return;
    setState(() => _error = null);
    try {
      final list = await Api.fetchFollowList(
        widget.userId,
        followers: wantFollowers,
      );
      if (!mounted) return;
      setState(() {
        if (wantFollowers) {
          _followers = list;
        } else {
          _following = list;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    }
  }

  void _select(FollowTab tab) {
    if (tab == _tab) return;
    setState(() {
      _tab = tab;
      _error = null;
    });
    _load(tab);
  }

  List<FollowEntry>? get _current {
    switch (_tab) {
      case FollowTab.verified:
        return _followers
            ?.where((e) => (e.profile.verified ?? '').isNotEmpty)
            .toList();
      case FollowTab.followers:
        return _followers;
      case FollowTab.following:
        return _following;
    }
  }

  /// Apply [fn] to this person wherever they appear (both lists).
  void _replace(String id, Profile Function(Profile) fn) {
    List<FollowEntry>? swap(List<FollowEntry>? l) => l
        ?.map((e) => e.profile.id == id
            ? e.copyWith(profile: fn(e.profile))
            : e)
        .toList();
    setState(() {
      _followers = swap(_followers);
      _following = swap(_following);
    });
  }

  Future<void> _toggle(FollowEntry e) async {
    final before = e.profile;
    final after = before.afterFollowTap();
    _replace(before.id, (_) => after);
    try {
      await Api.setFollow(
        before.id,
        follow: after.followedByMe || after.requestedByMe,
      );
    } catch (err) {
      if (!mounted) return;
      _replace(before.id, (_) => before);
      showError(context, err);
    }
  }

  String _label(FollowEntry e) {
    final p = e.profile;
    if (p.followedByMe) return 'Following';
    if (p.requestedByMe) return 'Pending';
    return e.followsMe ? 'Follow back' : 'Follow';
  }

  Widget _tabBar(AppPalette p) {
    const tabs = [
      (FollowTab.verified, 'Verified followers', CupertinoIcons.checkmark_seal),
      (FollowTab.followers, 'Followers', CupertinoIcons.person_2),
      (
        FollowTab.following,
        'Following',
        CupertinoIcons.person_crop_circle_badge_checkmark
      ),
    ];
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: p.border, width: 0.5)),
      ),
      child: Row(
        children: [
          for (final t in tabs)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _select(t.$1),
                child: Center(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: t.$1 == _tab
                              ? p.text
                              : const Color(0x00000000),
                          width: 3,
                        ),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(4, 15, 4, 12),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (t.$1 == _tab) ...[
                            Icon(t.$3, size: 20, color: p.text),
                            const SizedBox(width: 6),
                          ],
                          Flexible(
                            child: Text(
                              t.$2,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: t.$1 == _tab ? p.text : p.subtext,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _row(AppPalette p, FollowEntry e) {
    final who = e.profile;
    final isMe = who.id == Api.uid;
    return Column(
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => Navigator.of(context)
              .push(appRoute(ProfileScreen(userId: who.id))),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Avatar(
                  url: who.avatarUrl,
                  name: who.name,
                  size: 44,
                  square: Avatar.isSquare(who.verified),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      NameWithBadge(
                        name: who.name,
                        verified: who.verified,
                        locked: who.protectedPosts,
                        badgeSize: 15,
                        style: TextStyle(
                          color: p.text,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              '@${who.username}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: p.subtext, fontSize: 15),
                            ),
                          ),
                          if (e.followsMe && !isMe) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: p.field,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'Follows you',
                                style: TextStyle(
                                  color: p.subtext,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (who.bio.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            who.bio,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: p.text,
                              fontSize: 15,
                              height: 1.25,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (!isMe) ...[
                  const SizedBox(width: 10),
                  PillButton(
                    label: _label(e),
                    style: (who.followedByMe || who.requestedByMe)
                        ? PillStyle.outline
                        : PillStyle.inverse,
                    onPressed: () => _toggle(e),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _empty(AppPalette p) {
    final String title;
    final String text;
    switch (_tab) {
      case FollowTab.verified:
        title = 'Looking for followers?';
        text = 'When a verified account follows this one, they’ll show up '
            'here. Posting and interacting with others helps boost followers.';
      case FollowTab.followers:
        title = 'Looking for followers?';
        text = 'When someone follows this account, they’ll show up here. '
            'Posting and interacting with others helps boost followers.';
      case FollowTab.following:
        title = 'Be in the know';
        text = 'Following accounts is an easy way to curate your timeline '
            'and know what’s happening with the topics and people you’re '
            'interested in.';
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 40, 32, 0),
      child: Align(
        alignment: Alignment.topLeft,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                color: p.text,
                fontSize: 30,
                fontWeight: FontWeight.w800,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              text,
              style: TextStyle(color: p.subtext, fontSize: 16, height: 1.35),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final list = _current;
    Widget body;
    if (_error != null && list == null) {
      body = ErrorView(error: _error!, onRetry: () => _load(_tab));
    } else if (list == null) {
      body = const LoadingView();
    } else if (list.isEmpty) {
      body = _empty(p);
    } else {
      body = ListView.builder(
        padding: const EdgeInsets.only(bottom: 80),
        itemCount: list.length,
        itemBuilder: (_, i) => _row(p, list[i]),
      );
    }
    return PlainScaffold(
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            PageHeader(
              title: widget.title,
              trailing: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.of(context)
                    .push(appRoute(const SearchScreen())),
                child: Icon(AppIcons.personAdd, size: 24, color: p.text),
              ),
            ),
            _tabBar(p),
            Expanded(child: ContentWidth(maxWidth: 680, child: body)),
          ],
        ),
      ),
    );
  }
}
