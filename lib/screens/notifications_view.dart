import 'package:flutter/cupertino.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../core/app_icons.dart';
import '../core/app_palette.dart';
import '../core/ui_helpers.dart';
import '../models/models.dart';
import '../services/api.dart';
import '../widgets/avatar.dart';
import '../widgets/responsive.dart';
import '../widgets/state_views.dart';
import '../widgets/top_bar.dart';
import '../widgets/underline_tabs.dart';
import 'profile_view.dart';
import '../core/x_icons.dart';
import '../widgets/post_skeleton.dart';

/// Notifications tab: likes on my posts, new followers and @mentions,
/// with "All" / "Mentions" tabs like X.
class NotificationsView extends StatefulWidget {
  const NotificationsView({
    super.key,
    required this.me,
    required this.onOpenDrawer,
    this.onLoaded,
  });

  final Profile? me;
  final VoidCallback onOpenDrawer;

  /// Told about every successful load, so the tab badge stays in step.
  final void Function(List<AppNotification> list)? onLoaded;

  @override
  State<NotificationsView> createState() => NotificationsViewState();
}

class NotificationsViewState extends State<NotificationsView> {
  List<AppNotification> _items = const [];
  bool _loading = true;
  Object? _error;
  int _tab = 0; // 0 = All, 1 = Mentions

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Called by the shell whenever the tab is opened.
  Future<void> reload() => _load(silent: true);

  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final list = await Api.fetchNotifications();
      if (!mounted) return;
      setState(() {
        _items = list;
        _loading = false;
        _error = null;
      });
      widget.onLoaded?.call(list);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (!silent) _error = e;
      });
    }
  }

  void _openProfile(Profile actor) {
    Navigator.of(context).push(appRoute(ProfileScreen(userId: actor.id)));
  }

  static String _verb(NotificationKind kind) {
    switch (kind) {
      case NotificationKind.like:
        return 'liked your post';
      case NotificationKind.follow:
        return 'followed you';
      case NotificationKind.mention:
        return 'mentioned you';
    }
  }

  Widget _row(AppNotification n, AppPalette p) {
    final Widget icon;
    switch (n.kind) {
      case NotificationKind.like:
        icon = const XIcon(XIcons.likeFill, size: 28, color: AppPalette.like);
      case NotificationKind.follow:
        icon = const Icon(CupertinoIcons.person_fill,
            size: 28, color: Color(0xFF794BC4));
      case NotificationKind.mention:
        icon = Icon(AppIcons.at, size: 26, color: p.accent);
    }

    return Column(
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _openProfile(n.actor),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 40,
                  child: Align(
                    alignment: Alignment.topRight,
                    child: icon,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Avatar(
                        url: n.actor.avatarUrl,
                        name: n.actor.name,
                        size: 32,
                      ),
                      const SizedBox(height: 8),
                      Text.rich(
                        TextSpan(
                          style: TextStyle(
                            color: p.text,
                            fontSize: 15,
                            height: 1.3,
                          ),
                          children: [
                            TextSpan(
                              text: n.actor.name,
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            TextSpan(text: ' ${_verb(n.kind)}'),
                            TextSpan(
                              text: ' · '
                                  '${timeago.format(n.createdAt, locale: 'en_short')}',
                              style: TextStyle(color: p.subtext),
                            ),
                          ],
                        ),
                      ),
                      if (n.postText.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            n.postText,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: n.kind == NotificationKind.mention
                                  ? p.text
                                  : p.subtext,
                              fontSize: 15,
                              height: 1.3,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const HairlineDivider(),
      ],
    );
  }

  Widget _body(AppPalette p) {
    if (_loading) return const RowSkeletonList();
    if (_error != null) return ErrorView(error: _error!, onRetry: () => _load());

    final shown = _tab == 1
        ? _items.where((n) => n.kind == NotificationKind.mention).toList()
        : _items;

    if (shown.isEmpty) {
      return EmptyState(
        icon: AppIcons.bell,
        title: _tab == 1 ? 'No mentions yet' : 'Nothing to see here — yet',
        subtitle: _tab == 1
            ? 'When someone writes @${widget.me?.username ?? 'you'} in a post, it shows up here.'
            : 'Likes, new followers and mentions will show up here.',
      );
    }

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      slivers: [
        CupertinoSliverRefreshControl(onRefresh: () => _load(silent: true)),
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, i) => _row(shown[i], p),
            childCount: shown.length,
          ),
        ),
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
              middle: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Notifications',
                  style: TextStyle(
                    color: p.text,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            UnderlineTabs(
              labels: const ['All', 'Mentions'],
              index: _tab,
              onChanged: (i) => setState(() => _tab = i),
            ),
            Expanded(child: _body(p)),
          ],
        ),
      ),
    );
  }
}
